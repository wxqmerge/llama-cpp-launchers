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

.\llama-server --model "D:\models\Muse-Glimmer-30B-NVFP4-Q8_0.gguf" --alias "Muse-Glimmer-30B-NVFP4" --ctx-size 131072 --batch-size 4096 --ubatch-size 4096 --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 --temp 0.6 --top-p 1.0 --top-k 20 --min-p 0.0 --presence-penalty 0.0 --repeat-penalty 1.0 --fit on --load-mode mlock --jinja --host 0.0.0.0 --port 8080 --threads 24 --api-key sk-123 --log-file %name%.log --image-min-tokens 1024 -n -1 -lv 4 --parallel 1 -ngl 999 --mmproj "D:\models\mmproj-Muse-Glimmer-30B-Q8_0.gguf" --reasoning-budget 16384

pause
