param(
    [ValidateSet(
        'help',
        'build', 'build-onnx',
        'run', 'run-onnx',
        'db-setup', 'db-test',
        'docker-up', 'docker-up-onnx', 'docker-down',
        'local', 'local-onnx'
    )]
    [string]$Action = 'help'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root

function Show-Usage {
    Write-Host ''
    Write-Host 'Dogonomics Dev Command Hub' -ForegroundColor Cyan
    Write-Host 'Usage: .\scripts\dev.ps1 <action>'
    Write-Host ''
    Write-Host 'Actions:'
    Write-Host '  build            Build standard backend binary'
    Write-Host '  build-onnx       Build ONNX backend binary'
    Write-Host '  run              Run standard backend binary'
    Write-Host '  run-onnx         Run ONNX backend binary'
    Write-Host '  db-setup         Setup local PostgreSQL for backend'
    Write-Host '  db-test          Test local PostgreSQL connection'
    Write-Host '  docker-up        Start docker compose stack'
    Write-Host '  docker-up-onnx   Start docker compose stack with onnx profile'
    Write-Host '  docker-down      Stop docker compose stack'
    Write-Host '  local            db-setup -> build -> run'
    Write-Host '  local-onnx       install-runtime -> build-onnx -> run-onnx'
    Write-Host ''
}

switch ($Action) {
    'help' { Show-Usage }
    'build' { & .\scripts\build\build.ps1 }
    'build-onnx' { & .\scripts\build\build-onnx.ps1 }
    'run' { & .\scripts\run\run.ps1 }
    'run-onnx' { & .\scripts\run\run-onnx.ps1 }
    'db-setup' { & .\scripts\database\setup-postgres-local.ps1 }
    'db-test' { & .\scripts\database\test-db-connection.ps1 }
    'docker-up' { & .\scripts\docker\docker-compose-up.ps1 }
    'docker-up-onnx' { & .\scripts\docker\docker-compose-up.ps1 -Profiles onnx }
    'docker-down' { & .\scripts\docker\docker-compose-down.ps1 }
    'local' {
        & .\scripts\database\setup-postgres-local.ps1
        & .\scripts\build\build.ps1
        & .\scripts\run\run.ps1
    }
    'local-onnx' {
        & .\scripts\onnx\install-runtime.ps1
        & .\scripts\build\build-onnx.ps1
        & .\scripts\run\run-onnx.ps1
    }
}
