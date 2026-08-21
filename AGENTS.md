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
- Naming: `run<model>.bat`; suffix `v`/`vision` adds `--mmproj`, `nv` = NVFP4 quant, `Think` = reasoning budget/preserve.
- Shared arg block is kept consistent across bats (`--batch-size 4096 --ubatch-size 4096 --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 --fit on --load-mode mlock --jinja --host 0.0.0.0 --port 8080 --threads 24 --api-key sk-123 --log-file %name%.log -n -1 -lv 4 --parallel 1 -ngl 999`); per-bat differences are model path, alias, ctx-size, sampling, spec/reasoning, mmproj.
- Flag gotchas (newer builds): `--ctx-size` (not `--nctx`), `--batch-size`/`--ubatch-size`. `--reasoning` takes a value (`on|off|auto`) — never put `--reasoning-budget` right after a bare `--reasoning`, or the parser consumes it as the value. Verify flags against the deployed build's `llama-server --help` before editing.

## Environment
- Test/production box: RTX 5090 (32 GB), Core Ultra 9 285K, 24 threads, CUDA build of llama.cpp with `BLACKWELL_NATIVE_FP4`.
