# llama-cpp-launchers

Windows launcher scripts (`run*.bat`) for `llama-server`, one per model config. No build system — the repo is `.bat` files plus a test harness.

## Deployment
- Bats must sit in the same folder as `llama-server.exe` (they `cd /d %~dp0` then run `.\llama-server`).
- The deployed build is the **highest-numbered** `D:\llama.cpp.b<N>` folder (older builds like `b10472` also exist on disk and are not the target).
- Deploy: copy `*.bat` (including `stop.bat`) into that folder.
- Models live in `D:\models\` (GGUF + `mmproj-*.gguf`). `%USERPROFILE%\Desktop\UpdateLastModel.ps1` is external/gitignored — each bat calls it with its own path to record the last launched model.

## Testing
- `powershell -File Test-BatFiles.ps1 -Folder D:\llama.cpp.b<N>` — kills any running `llama-server`, runs each `run*.bat` via `cmd /c` for 10 s, writes `bat_test_results.csv` into the build folder.
- The script's default `-Folder` (`D:\llama.cpp.b10472`) is stale — always pass `-Folder` explicitly.
- CSV status semantics: `TimedOut` = healthy (server started and was still running when the timeout killed it); `OK` = the bat exited early — check `StdErr` (usually a bad flag or crash); `Error`/`Exception` = failure.
- The repo-root `bat_test_results.csv` is committed; copy the fresh CSV back from the build folder after a test run.
- All launchers bind port 8080 — only one runs at a time. `stop.bat` force-kills `llama-server.exe`; the test harness also kills it first.

## Bat conventions
- Each `run*.bat`: rotates its own logs (`<name>.log` → `.log.1`…`.log.5`), calls `UpdateLastModel.ps1`, runs `.\llama-server` with model-specific args, ends with `pause`.
- Naming: `run<model>.bat`; suffix `v`/`vision` adds `--mmproj`, `nv` = NVFP4 quant, `Think` = reasoning (effort/budget), `Q5K` = Q5K quant variant.
- Each bat builds the `llama-server` command line by accumulating an `args` var — one `set "args=..."` line per concern-group, in this order: `model` (`--model`/`--alias`), `context` (`--ctx-size`/`--fit` — `--fit` adjusts unset args like ctx to fit device memory), `batch` (`--batch-size`/`--ubatch-size`), `attention + cache` (`--flash-attn`/`--cache-type-k`/`--cache-type-v`), `sampling` (`--temp`/`--top-p`/`--top-k`/`--min-p`/`--presence-penalty`/`--repeat-penalty`), `reasoning`, `spec`, `loading` (`--load-mode`), `template` (`--jinja`), `network` (`--host`/`--port`/`--threads`/`--api-key` — **keep these grouped on one line**), `logging` (`--log-file %name%.log`), `priority` (`--prio`/`--prio-batch`), `runtime` (`-n -1 -lv 4 --parallel 1 -ngl 999`), `vision` (`--image-min-tokens`/`--mmproj`). Then `.\llama-server %args%`.
- Shared groups are byte-identical across bats; per-bat differences (model path, alias, sampling, reasoning, priority, vision) sit on their own `set args` line (absent when not applicable) so a plain-vs-Think `git diff` shows only the changed groups. Model/alias/mmproj stay quoted; `set "args=..."` preserves inner quotes (verified: the program receives them unquoted).
- Flag gotchas (newer builds): `--ctx-size` (not `--nctx`), `--batch-size`/`--ubatch-size`. `--reasoning` takes a value (`on|off|auto`) — never put `--reasoning-budget` right after a bare `--reasoning`, or the parser consumes it as the value. Verify flags against the deployed build's `llama-server --help` before editing.
- Reasoning/thinking flags: `--reasoning on|off|auto` (auto = detect from template; `off` sets `enable_thinking=false`), `--reasoning-effort <level>` passes the effort to the chat template (use this instead of `--chat-template-kwargs`), `--reasoning-budget N` = thinking token budget. `--reasoning-preserve` defaults to the template default — for the Qwen3.8 template that is already "preserve", so the flag is a no-op there.
- Qwen3.8 template quirks (verified from the GGUF `tokenizer.chat_template`): default `reasoning_effort` is `xhigh`, which injects a "think carefully" instruction into the system prompt; `medium` injects **no** instruction text (only `xhigh` and `low` have instruction strings; `high` is aliased to `xhigh`); `enable_thinking=false` disables thinking (empty `think` block). `preserve_thinking` defaults to true.
- JSON args in `.bat` files: escape quotes as `\"` and avoid spaces — single quotes are literal in cmd and unquoted spaces split the arg (e.g. `--chat-template-kwargs "{\"a\":1}"`).

## Environment
- Test/production box: RTX 5090 (32 GB), Core Ultra 9 285K, 24 threads, CUDA build of llama.cpp with `BLACKWELL_NATIVE_FP4`.
