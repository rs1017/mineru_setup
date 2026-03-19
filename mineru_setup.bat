@echo off
chcp 949 >nul
setlocal EnableDelayedExpansion

echo ============================================
echo   MinerU Portable Package Builder
echo ============================================
echo.

set "BASE_DIR=%~dp0"
set "INSTALL_DIR=%BASE_DIR%MinerU-Portable"
set "PYTHON_DIR=%INSTALL_DIR%\python"
set "MODELS_DIR=%INSTALL_DIR%\models"
set "PYTHON_VERSION=3.12.8"
set "PYTHON_ZIP=python-3.12.8-embed-amd64.zip"
set "PYTHON_URL=https://www.python.org/ftp/python/3.12.8/python-3.12.8-embed-amd64.zip"
set "GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py"

echo.
echo [1/8] Creating folders...
if exist "%INSTALL_DIR%" (
    rmdir /s /q "%INSTALL_DIR%" 2>nul
    timeout /t 2 >nul
)
mkdir "%INSTALL_DIR%"
mkdir "%PYTHON_DIR%"
mkdir "%MODELS_DIR%"

echo.
echo [2/8] Downloading Python %PYTHON_VERSION%...
cd /d "%INSTALL_DIR%"
curl -L -o "%PYTHON_ZIP%" "%PYTHON_URL%"
if not exist "%PYTHON_ZIP%" (
    powershell -Command "Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_ZIP%'"
)
if not exist "%PYTHON_ZIP%" (
    echo [ERROR] Python download failed!
    pause
    exit /b 1
)
powershell -Command "Expand-Archive -Path '%PYTHON_ZIP%' -DestinationPath '%PYTHON_DIR%' -Force"
del "%PYTHON_ZIP%"
if not exist "%PYTHON_DIR%\python.exe" (
    echo [ERROR] Python extraction failed!
    pause
    exit /b 1
)
echo [OK] Python installed

echo.
echo [3/8] Setting up pip...
set "PTH_FILE=%PYTHON_DIR%\python312._pth"
(
echo python312.zip
echo .
echo Lib\site-packages
echo import site
) > "%PTH_FILE%"
mkdir "%PYTHON_DIR%\Lib\site-packages" 2>nul

curl -L -o "%PYTHON_DIR%\get-pip.py" "%GET_PIP_URL%"
if not exist "%PYTHON_DIR%\get-pip.py" (
    echo [ERROR] get-pip.py download failed!
    pause
    exit /b 1
)
"%PYTHON_DIR%\python.exe" "%PYTHON_DIR%\get-pip.py" --no-warn-script-location
if errorlevel 1 (
    echo [ERROR] pip install failed!
    pause
    exit /b 1
)
del "%PYTHON_DIR%\get-pip.py"
echo [OK] pip installed

echo.
echo [4/8] Installing MinerU...
"%PYTHON_DIR%\python.exe" -m pip install --upgrade pip --no-warn-script-location
"%PYTHON_DIR%\python.exe" -m pip install setuptools wheel --no-warn-script-location
if errorlevel 1 (
    echo [ERROR] setuptools/wheel install failed!
    pause
    exit /b 1
)
"%PYTHON_DIR%\python.exe" -m pip install "mineru[all]" --no-warn-script-location
if errorlevel 1 (
    echo [ERROR] MinerU install failed!
    pause
    exit /b 1
)
echo [OK] MinerU installed

echo.
echo [5/8] Installing PyTorch CUDA (force reinstall)...
"%PYTHON_DIR%\python.exe" -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --force-reinstall --no-warn-script-location
if errorlevel 1 (
    echo [ERROR] PyTorch CUDA install failed!
    pause
    exit /b 1
)
echo [OK] PyTorch CUDA installed

echo.
echo [6/8] Downloading AI models...
set "HF_HUB_CACHE=%MODELS_DIR%\huggingface"
"%PYTHON_DIR%\python.exe" -m pip install huggingface_hub --no-warn-script-location
"%PYTHON_DIR%\python.exe" -c "from huggingface_hub import snapshot_download; snapshot_download('opendatalab/PDF-Extract-Kit-1.0', cache_dir=r'%MODELS_DIR%\huggingface')"
if errorlevel 1 (
    echo [ERROR] PDF-Extract-Kit model download failed!
    pause
    exit /b 1
)
"%PYTHON_DIR%\python.exe" -c "from huggingface_hub import snapshot_download; snapshot_download('opendatalab/MinerU2.5-2509-1.2B', cache_dir=r'%MODELS_DIR%\huggingface')"
if errorlevel 1 (
    echo [ERROR] MinerU model download failed!
    pause
    exit /b 1
)
echo [OK] AI models downloaded

echo.
echo [7/8] Creating config generator and batch files...
REM =====================================================
REM  echo로 Python 코드를 쓰면 chcp 949 환경에서
REM  특수문자({, }, ( 등)가 깨지므로,
REM  _update_config.py 생성도 _mkbat.py 안에서 처리합니다.
REM =====================================================

set "PYSCRIPT=%INSTALL_DIR%\_mkbat.py"

echo import os > "%PYSCRIPT%"
echo d = r'%INSTALL_DIR%' >> "%PYSCRIPT%"
echo. >> "%PYSCRIPT%"
echo # ============================================= >> "%PYSCRIPT%"
echo # Create _update_config.py >> "%PYSCRIPT%"
echo # ============================================= >> "%PYSCRIPT%"
echo cfg = open(os.path.join(d, '_update_config.py'), 'w', encoding='utf-8') >> "%PYSCRIPT%"
echo cfg.write('import os, sys, json, glob\n') >> "%PYSCRIPT%"
echo cfg.write('\n') >> "%PYSCRIPT%"
echo cfg.write('script_dir = os.path.dirname(os.path.abspath(sys.argv[0]))\n') >> "%PYSCRIPT%"
echo cfg.write('models_dir = os.path.join(script_dir, "models", "huggingface")\n') >> "%PYSCRIPT%"
echo cfg.write('\n') >> "%PYSCRIPT%"
echo cfg.write('pipeline_pattern = os.path.join(models_dir, "models--opendatalab--PDF-Extract-Kit-1.0", "snapshots", "*")\n') >> "%PYSCRIPT%"
echo cfg.write('vlm_pattern = os.path.join(models_dir, "models--opendatalab--MinerU2.5-2509-1.2B", "snapshots", "*")\n') >> "%PYSCRIPT%"
echo cfg.write('\n') >> "%PYSCRIPT%"
echo cfg.write('pipeline_dirs = sorted(glob.glob(pipeline_pattern))\n') >> "%PYSCRIPT%"
echo cfg.write('vlm_dirs = sorted(glob.glob(vlm_pattern))\n') >> "%PYSCRIPT%"
echo cfg.write('\n') >> "%PYSCRIPT%"
echo cfg.write('if not pipeline_dirs:\n') >> "%PYSCRIPT%"
echo cfg.write('    print("[ERROR] Pipeline model not found: " + pipeline_pattern)\n') >> "%PYSCRIPT%"
echo cfg.write('    sys.exit(1)\n') >> "%PYSCRIPT%"
echo cfg.write('if not vlm_dirs:\n') >> "%PYSCRIPT%"
echo cfg.write('    print("[ERROR] VLM model not found: " + vlm_pattern)\n') >> "%PYSCRIPT%"
echo cfg.write('    sys.exit(1)\n') >> "%PYSCRIPT%"
echo cfg.write('\n') >> "%PYSCRIPT%"
echo cfg.write('pipeline_path = pipeline_dirs[-1].replace(chr(92), "/")\n') >> "%PYSCRIPT%"
echo cfg.write('vlm_path = vlm_dirs[-1].replace(chr(92), "/")\n') >> "%PYSCRIPT%"
echo cfg.write('\n') >> "%PYSCRIPT%"
echo cfg.write('config = {"models-dir": {"pipeline": pipeline_path, "vlm": vlm_path}, "config_version": "1.3.0"}\n') >> "%PYSCRIPT%"
echo cfg.write('\n') >> "%PYSCRIPT%"
echo cfg.write('config_file = os.path.join(os.path.expanduser("~"), "mineru.json")\n') >> "%PYSCRIPT%"
echo cfg.write('with open(config_file, "w", encoding="utf-8") as cf:\n') >> "%PYSCRIPT%"
echo cfg.write('    json.dump(config, cf, indent=4)\n') >> "%PYSCRIPT%"
echo cfg.write('\n') >> "%PYSCRIPT%"
echo cfg.write('print("[OK] Config updated: " + config_file)\n') >> "%PYSCRIPT%"
echo cfg.write('print("     pipeline: " + pipeline_path)\n') >> "%PYSCRIPT%"
echo cfg.write('print("     vlm:      " + vlm_path)\n') >> "%PYSCRIPT%"
echo cfg.close() >> "%PYSCRIPT%"
echo print('[OK] _update_config.py created') >> "%PYSCRIPT%"
echo. >> "%PYSCRIPT%"
echo # ============================================= >> "%PYSCRIPT%"
echo # Common header that all batch files share >> "%PYSCRIPT%"
echo # ============================================= >> "%PYSCRIPT%"
echo COMMON_HEADER = ( >> "%PYSCRIPT%"
echo     '@echo off\n' >> "%PYSCRIPT%"
echo     'chcp 949 ^>nul\n' >> "%PYSCRIPT%"
echo     'setlocal EnableDelayedExpansion\n' >> "%PYSCRIPT%"
echo     'set "SCRIPT_DIR=%%~dp0"\n' >> "%PYSCRIPT%"
echo     'set "MINERU_MODEL_SOURCE=local"\n' >> "%PYSCRIPT%"
echo     'set "HF_HUB_CACHE=%%SCRIPT_DIR%%models\\huggingface"\n' >> "%PYSCRIPT%"
echo     'set "HUGGINGFACE_HUB_CACHE=%%SCRIPT_DIR%%models\\huggingface"\n' >> "%PYSCRIPT%"
echo     'set "HF_HUB_OFFLINE=1"\n' >> "%PYSCRIPT%"
echo     '"%%SCRIPT_DIR%%python\\python.exe" "%%SCRIPT_DIR%%_update_config.py"\n' >> "%PYSCRIPT%"
echo     'if errorlevel 1 (\n' >> "%PYSCRIPT%"
echo     '    echo [ERROR] Config update failed!\n' >> "%PYSCRIPT%"
echo     '    pause\n' >> "%PYSCRIPT%"
echo     '    exit /b 1\n' >> "%PYSCRIPT%"
echo     ')\n' >> "%PYSCRIPT%"
echo ) >> "%PYSCRIPT%"
echo. >> "%PYSCRIPT%"
echo # convert_auto.bat >> "%PYSCRIPT%"
echo f1 = open(os.path.join(d, 'convert_auto.bat'), 'w') >> "%PYSCRIPT%"
echo f1.write(COMMON_HEADER) >> "%PYSCRIPT%"
echo f1.write('echo ============================================\n') >> "%PYSCRIPT%"
echo f1.write('echo   MinerU PDF Converter [Auto Mode]\n') >> "%PYSCRIPT%"
echo f1.write('echo ============================================\n') >> "%PYSCRIPT%"
echo f1.write('echo.\n') >> "%PYSCRIPT%"
echo f1.write('if "%%~1"=="" (\n') >> "%PYSCRIPT%"
echo f1.write('    echo [Usage] Drag PDF files onto this batch file.\n') >> "%PYSCRIPT%"
echo f1.write('    pause\n') >> "%PYSCRIPT%"
echo f1.write('    exit /b\n') >> "%PYSCRIPT%"
echo f1.write(')\n') >> "%PYSCRIPT%"
echo f1.write('echo Checking GPU...\n') >> "%PYSCRIPT%"
echo f1.write('"%%SCRIPT_DIR%%python\\python.exe" -c "import torch; assert torch.cuda.is_available(); cc=torch.cuda.get_device_capability(); assert cc[0] in [5,6,7,8,9]"\n') >> "%PYSCRIPT%"
echo f1.write('if errorlevel 1 (\n') >> "%PYSCRIPT%"
echo f1.write('    echo [INFO] Using CPU mode.\n') >> "%PYSCRIPT%"
echo f1.write('    set "USE_CPU=-d cpu"\n') >> "%PYSCRIPT%"
echo f1.write(') else (\n') >> "%PYSCRIPT%"
echo f1.write('    echo [INFO] Using GPU mode.\n') >> "%PYSCRIPT%"
echo f1.write('    set "USE_CPU="\n') >> "%PYSCRIPT%"
echo f1.write(')\n') >> "%PYSCRIPT%"
echo f1.write('echo.\n') >> "%PYSCRIPT%"
echo f1.write(':loop\n') >> "%PYSCRIPT%"
echo f1.write('if "%%~1"=="" goto end\n') >> "%PYSCRIPT%"
echo f1.write('set "INPUT=%%~1"\n') >> "%PYSCRIPT%"
echo f1.write('set "OUTPUT_DIR=%%~dp1output"\n') >> "%PYSCRIPT%"
echo f1.write('if not exist "%%OUTPUT_DIR%%" mkdir "%%OUTPUT_DIR%%"\n') >> "%PYSCRIPT%"
echo f1.write('echo Input: %%~nx1\n') >> "%PYSCRIPT%"
echo f1.write('echo Output: %%OUTPUT_DIR%%\n') >> "%PYSCRIPT%"
echo f1.write('"%%SCRIPT_DIR%%python\\python.exe" -m mineru.cli.client -p "%%INPUT%%" -o "%%OUTPUT_DIR%%" -m ocr -l korean -b pipeline %%USE_CPU%%\n') >> "%PYSCRIPT%"
echo f1.write('if errorlevel 1 (echo [Error] %%~nx1) else (echo [Done] %%~nx1)\n') >> "%PYSCRIPT%"
echo f1.write('shift\n') >> "%PYSCRIPT%"
echo f1.write('goto loop\n') >> "%PYSCRIPT%"
echo f1.write(':end\n') >> "%PYSCRIPT%"
echo f1.write('echo Complete!\n') >> "%PYSCRIPT%"
echo f1.write('pause\n') >> "%PYSCRIPT%"
echo f1.write('endlocal\n') >> "%PYSCRIPT%"
echo f1.close() >> "%PYSCRIPT%"
echo. >> "%PYSCRIPT%"
echo # convert_gpu.bat >> "%PYSCRIPT%"
echo f2 = open(os.path.join(d, 'convert_gpu.bat'), 'w') >> "%PYSCRIPT%"
echo f2.write(COMMON_HEADER) >> "%PYSCRIPT%"
echo f2.write('echo ============================================\n') >> "%PYSCRIPT%"
echo f2.write('echo   MinerU PDF Converter [GPU Mode]\n') >> "%PYSCRIPT%"
echo f2.write('echo ============================================\n') >> "%PYSCRIPT%"
echo f2.write('echo.\n') >> "%PYSCRIPT%"
echo f2.write('if "%%~1"=="" (\n') >> "%PYSCRIPT%"
echo f2.write('    echo [Usage] Drag PDF files onto this batch file.\n') >> "%PYSCRIPT%"
echo f2.write('    pause\n') >> "%PYSCRIPT%"
echo f2.write('    exit /b\n') >> "%PYSCRIPT%"
echo f2.write(')\n') >> "%PYSCRIPT%"
echo f2.write('echo Checking GPU...\n') >> "%PYSCRIPT%"
echo f2.write('"%%SCRIPT_DIR%%python\\python.exe" -c "import torch; assert torch.cuda.is_available(); cc=torch.cuda.get_device_capability(); assert cc[0] in [5,6,7,8,9]"\n') >> "%PYSCRIPT%"
echo f2.write('if errorlevel 1 (\n') >> "%PYSCRIPT%"
echo f2.write('    echo [ERROR] GPU not compatible. Use convert_cpu.bat\n') >> "%PYSCRIPT%"
echo f2.write('    pause\n') >> "%PYSCRIPT%"
echo f2.write('    exit /b 1\n') >> "%PYSCRIPT%"
echo f2.write(')\n') >> "%PYSCRIPT%"
echo f2.write('echo [OK] GPU compatible.\n') >> "%PYSCRIPT%"
echo f2.write('echo.\n') >> "%PYSCRIPT%"
echo f2.write(':loop\n') >> "%PYSCRIPT%"
echo f2.write('if "%%~1"=="" goto end\n') >> "%PYSCRIPT%"
echo f2.write('set "INPUT=%%~1"\n') >> "%PYSCRIPT%"
echo f2.write('set "OUTPUT_DIR=%%~dp1output"\n') >> "%PYSCRIPT%"
echo f2.write('if not exist "%%OUTPUT_DIR%%" mkdir "%%OUTPUT_DIR%%"\n') >> "%PYSCRIPT%"
echo f2.write('echo Input: %%~nx1\n') >> "%PYSCRIPT%"
echo f2.write('echo Output: %%OUTPUT_DIR%%\n') >> "%PYSCRIPT%"
echo f2.write('"%%SCRIPT_DIR%%python\\python.exe" -m mineru.cli.client -p "%%INPUT%%" -o "%%OUTPUT_DIR%%" -m ocr -l korean -b pipeline\n') >> "%PYSCRIPT%"
echo f2.write('if errorlevel 1 (echo [Error] %%~nx1) else (echo [Done] %%~nx1)\n') >> "%PYSCRIPT%"
echo f2.write('shift\n') >> "%PYSCRIPT%"
echo f2.write('goto loop\n') >> "%PYSCRIPT%"
echo f2.write(':end\n') >> "%PYSCRIPT%"
echo f2.write('echo Complete!\n') >> "%PYSCRIPT%"
echo f2.write('pause\n') >> "%PYSCRIPT%"
echo f2.write('endlocal\n') >> "%PYSCRIPT%"
echo f2.close() >> "%PYSCRIPT%"
echo. >> "%PYSCRIPT%"
echo # convert_cpu.bat >> "%PYSCRIPT%"
echo f3 = open(os.path.join(d, 'convert_cpu.bat'), 'w') >> "%PYSCRIPT%"
echo f3.write(COMMON_HEADER) >> "%PYSCRIPT%"
echo f3.write('echo ============================================\n') >> "%PYSCRIPT%"
echo f3.write('echo   MinerU PDF Converter [CPU Mode]\n') >> "%PYSCRIPT%"
echo f3.write('echo ============================================\n') >> "%PYSCRIPT%"
echo f3.write('echo.\n') >> "%PYSCRIPT%"
echo f3.write('if "%%~1"=="" (\n') >> "%PYSCRIPT%"
echo f3.write('    echo [Usage] Drag PDF files onto this batch file.\n') >> "%PYSCRIPT%"
echo f3.write('    pause\n') >> "%PYSCRIPT%"
echo f3.write('    exit /b\n') >> "%PYSCRIPT%"
echo f3.write(')\n') >> "%PYSCRIPT%"
echo f3.write(':loop\n') >> "%PYSCRIPT%"
echo f3.write('if "%%~1"=="" goto end\n') >> "%PYSCRIPT%"
echo f3.write('set "INPUT=%%~1"\n') >> "%PYSCRIPT%"
echo f3.write('set "OUTPUT_DIR=%%~dp1output"\n') >> "%PYSCRIPT%"
echo f3.write('if not exist "%%OUTPUT_DIR%%" mkdir "%%OUTPUT_DIR%%"\n') >> "%PYSCRIPT%"
echo f3.write('echo Input: %%~nx1\n') >> "%PYSCRIPT%"
echo f3.write('echo Output: %%OUTPUT_DIR%%\n') >> "%PYSCRIPT%"
echo f3.write('"%%SCRIPT_DIR%%python\\python.exe" -m mineru.cli.client -p "%%INPUT%%" -o "%%OUTPUT_DIR%%" -m ocr -l korean -b pipeline -d cpu\n') >> "%PYSCRIPT%"
echo f3.write('if errorlevel 1 (echo [Error] %%~nx1) else (echo [Done] %%~nx1)\n') >> "%PYSCRIPT%"
echo f3.write('shift\n') >> "%PYSCRIPT%"
echo f3.write('goto loop\n') >> "%PYSCRIPT%"
echo f3.write(':end\n') >> "%PYSCRIPT%"
echo f3.write('echo Complete!\n') >> "%PYSCRIPT%"
echo f3.write('pause\n') >> "%PYSCRIPT%"
echo f3.write('endlocal\n') >> "%PYSCRIPT%"
echo f3.close() >> "%PYSCRIPT%"
echo. >> "%PYSCRIPT%"
echo # mineru.bat >> "%PYSCRIPT%"
echo f4 = open(os.path.join(d, 'mineru.bat'), 'w') >> "%PYSCRIPT%"
echo f4.write('@echo off\n') >> "%PYSCRIPT%"
echo f4.write('setlocal\n') >> "%PYSCRIPT%"
echo f4.write('set "SCRIPT_DIR=%%~dp0"\n') >> "%PYSCRIPT%"
echo f4.write('set "MINERU_MODEL_SOURCE=local"\n') >> "%PYSCRIPT%"
echo f4.write('set "HF_HUB_CACHE=%%SCRIPT_DIR%%models\\huggingface"\n') >> "%PYSCRIPT%"
echo f4.write('set "HUGGINGFACE_HUB_CACHE=%%SCRIPT_DIR%%models\\huggingface"\n') >> "%PYSCRIPT%"
echo f4.write('set "HF_HUB_OFFLINE=1"\n') >> "%PYSCRIPT%"
echo f4.write('"%%SCRIPT_DIR%%python\\python.exe" "%%SCRIPT_DIR%%_update_config.py"\n') >> "%PYSCRIPT%"
echo f4.write('if errorlevel 1 (\n') >> "%PYSCRIPT%"
echo f4.write('    echo [ERROR] Config update failed!\n') >> "%PYSCRIPT%"
echo f4.write('    pause\n') >> "%PYSCRIPT%"
echo f4.write('    exit /b 1\n') >> "%PYSCRIPT%"
echo f4.write(')\n') >> "%PYSCRIPT%"
echo f4.write('"%%SCRIPT_DIR%%python\\python.exe" -m mineru.cli.client %%*\n') >> "%PYSCRIPT%"
echo f4.write('endlocal\n') >> "%PYSCRIPT%"
echo f4.close() >> "%PYSCRIPT%"
echo. >> "%PYSCRIPT%"
echo # README.md >> "%PYSCRIPT%"
echo f5 = open(os.path.join(d, 'README.md'), 'w', encoding='utf-8') >> "%PYSCRIPT%"
echo f5.write('# MinerU Portable\n\n') >> "%PYSCRIPT%"
echo f5.write('## Batch Files\n\n') >> "%PYSCRIPT%"
echo f5.write('- convert_auto.bat : Auto (GPU first, fallback CPU)\n') >> "%PYSCRIPT%"
echo f5.write('- convert_gpu.bat : GPU mode (GTX 900 ~ RTX 4000)\n') >> "%PYSCRIPT%"
echo f5.write('- convert_cpu.bat : CPU mode (RTX 5000 or no GPU)\n') >> "%PYSCRIPT%"
echo f5.write('- mineru.bat : CLI\n\n') >> "%PYSCRIPT%"
echo f5.write('## Usage\n\n') >> "%PYSCRIPT%"
echo f5.write('Drag PDF onto convert_auto.bat\n') >> "%PYSCRIPT%"
echo f5.close() >> "%PYSCRIPT%"
echo. >> "%PYSCRIPT%"
echo print('All files created.') >> "%PYSCRIPT%"

"%PYTHON_DIR%\python.exe" "%PYSCRIPT%"
if errorlevel 1 (
    echo [ERROR] Failed to create files!
    pause
    exit /b 1
)
del "%PYSCRIPT%"
echo [OK] Config generator and batch files created

echo.
echo [8/8] Generating initial config...
"%PYTHON_DIR%\python.exe" "%INSTALL_DIR%\_update_config.py"
if errorlevel 1 (
    echo [ERROR] Config generation failed!
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Installation Complete!
echo ============================================
echo.
echo Location: %INSTALL_DIR%
echo.
echo [Created Files]
echo   convert_auto.bat   : Auto mode (recommended)
echo   convert_gpu.bat    : GPU mode
echo   convert_cpu.bat    : CPU mode
echo   mineru.bat         : CLI tool
echo   _update_config.py  : Config auto-updater
echo   README.md          : Usage guide
echo.
echo [NOTE] mineru.json is auto-generated on every run.
echo        You can freely move/copy this folder.
echo.
pause
endlocal