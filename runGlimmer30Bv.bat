cd /d %~dp0
set "name=%~n0"
title %name%
if exist %name%.log.5 del %name%.log.5
if exist %name%.log.4 ren %name%.log.4 %name%.log.5
if exist %name%.log.3 ren %name%.log.3 %name%.log.4
if exist %name%.log.2 ren %name%.log.2 %name%.log.3
if exist %name%.log.1 ren %name%.log.1 %name%.log.2
if exist %name%.log ren %name%.log %name%.log.1

powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\Desktop\UpdateLastModel.ps1" "%~f0"

rem === model ===
set "args=--model "D:\models\Muse-Glimmer-30B-UD-Q4_K_XL.gguf" --alias "Muse-Glimmer-30B""
rem === batch ===
set "args=%args% --batch-size 4096 --ubatch-size 4096"
rem === attention + cache ===
set "args=%args% --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0"
rem === spec ===
set "args=%args% --spec-type draft-dflash --spec-draft-n-max 8 --spec-draft-p-min 0.8 --model-draft "D:\models\dflash-kquant.gguf""
rem === sampling ===
set "args=%args% --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 --presence-penalty 0.0 --repeat-penalty 1.0"
rem === reasoning ===
set "args=%args% --reasoning on --reasoning-format deepseek --reasoning-preserve --reasoning-budget 16384"
rem === loading ===
set "args=%args% --load-mode mlock"
rem === template ===
set "args=%args% --jinja"
rem === network ===
set "args=%args% --host 0.0.0.0 --port 8080 --threads 24 --api-key sk-123"
rem === logging ===
set "args=%args% --log-file %name%.log"
rem === priority ===
set "args=%args% --prio-batch 2"
rem === runtime ===
set "args=%args% -n -1 -lv 4 --parallel 1 -ngl 999"
rem === vision ===
set "args=%args% --image-min-tokens 1024 --mmproj "D:\models\mmproj-Muse-Glimmer-30B-Q8_0.gguf""

.\llama-server %args%

pause
