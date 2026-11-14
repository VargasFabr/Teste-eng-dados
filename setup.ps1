$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (Get-Command py -ErrorAction SilentlyContinue) {
    py -3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)"
    if ($LASTEXITCODE -ne 0) { throw "Precisa de Python 3.10 ou mais novo." }
    if (-not (Test-Path .venv\Scripts\python.exe)) {
        py -3 -m venv .venv
    }
} else {
    python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)"
    if ($LASTEXITCODE -ne 0) { throw "Precisa de Python 3.10 ou mais novo." }
    if (-not (Test-Path .venv\Scripts\python.exe)) {
        python -m venv .venv
    }
}

$pip = ".\.venv\Scripts\python.exe"
& $pip -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    & $pip -m pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org pip-system-certs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $pip -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($MyInvocation.InvocationName -ne ".") {
    Write-Host "Ambiente pronto. Nesta janela, rode: . .\setup.ps1"
    Write-Host "Depois: dbt seed, dbt run e dbt test."
    return
}

. .\.venv\Scripts\Activate.ps1
