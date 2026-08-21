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
set "args=--model "D:\models\NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4-noMTP.gguf" --alias "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4""
rem === context ===
set "args=%args% --ctx-size 1048576 --fit on"
rem === batch ===
set "args=%args% -b 4096 -ub 1024"
rem === attention + cache ===
set "args=%args% -ctk q8_0 -ctv q8_0 --kv-offload --flash-attn on"
rem === sampling ===
set "args=%args% --temp 0.6 --top-p 1.0 --top-k 20 --min-p 0.0 --presence-penalty 0.0 --repeat-penalty 1.0"
rem === loading ===
set "args=%args% --load-mode none"
rem === template ===
set "args=%args% --jinja"
rem === network ===
set "args=%args% --host 0.0.0.0 --port 8080 --threads 24 --api-key sk-123"
rem === logging ===
set "args=%args% --log-file %name%.log"
rem === runtime ===
set "args=%args% -n -1 -lv 4 --parallel 1 -ngl 999"
rem === vision ===
set "args=%args% --image-min-tokens 1024"

.\llama-server %args%

pause
