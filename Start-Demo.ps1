param([switch]$NoPhone, [switch]$Preview)
$ErrorActionPreference = 'Stop'
$demoRoot = $PSScriptRoot
$demoBackend = Join-Path $demoRoot 'backend'
$demoLocal = Join-Path $demoRoot '.local'
New-Item -ItemType Directory -Force -Path $demoLocal | Out-Null
$demoNode = Join-Path $demoLocal 'node-v24.22.0-win-x64/node.exe'
if (-not (Test-Path -LiteralPath $demoNode)) { $demoNode = (Get-Command node -ErrorAction Stop).Source }
$demoNodeMajor = & $demoNode -p 'process.versions.node.split(".")[0]'
if ([int]$demoNodeMajor -lt 24) { throw 'Can Node.js 24 tro len de chay backend demo.' }
Push-Location $demoBackend
try {
    & $demoNode node_modules/typescript/bin/tsc -p tsconfig.json
    if ($LASTEXITCODE -ne 0) { throw 'Backend build failed.' }
    & $demoNode --env-file=.env --env-file-if-exists=../.local/demo.env dist/scripts/seed-showcase.js
    if ($LASTEXITCODE -ne 0) { throw 'Demo seed failed; see the message above.' }
    $demoSettings = & $demoNode --env-file=.env --env-file-if-exists=../.local/demo.env --input-type=module -e 'console.log(JSON.stringify({port:Number(process.env.PORT||3000)}))'
    $demoPort = ($demoSettings | ConvertFrom-Json).port
    $demoHealth = "http://127.0.0.1:$demoPort/api/health"
    $demoReady = $false
    try { $demoReady = (Invoke-RestMethod -Uri $demoHealth -TimeoutSec 2).status -eq 'ok' } catch {}
    if (-not $demoReady) {
        $demoServer = Start-Process -FilePath $demoNode -ArgumentList @('--env-file=.env','--env-file-if-exists=../.local/demo.env','dist/src/server.js') -WorkingDirectory $demoBackend -WindowStyle Hidden -RedirectStandardOutput (Join-Path $demoLocal 'demo-api.log') -RedirectStandardError (Join-Path $demoLocal 'demo-api-errors.log') -PassThru
        for ($demoAttempt = 0; $demoAttempt -lt 20; $demoAttempt++) {
            Start-Sleep -Milliseconds 500
            try { $demoReady = (Invoke-RestMethod -Uri $demoHealth -TimeoutSec 2).status -eq 'ok' } catch {}
            if ($demoReady) { break }
            if ($demoServer.HasExited) { throw 'Backend stopped. See .local/demo-api-errors.log.' }
        }
        if (-not $demoReady) { throw 'Backend did not become ready. See .local/demo-api.log.' }
        @{ pid = $demoServer.Id; port = $demoPort } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $demoLocal 'demo-server.json')
    }
    Write-Host "API DEMO: http://127.0.0.1:$demoPort/api"
    if (-not $NoPhone) {
        $demoAdbCandidates = @(
            (Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'),
            (Join-Path $env:USERPROFILE '.codex/android-sdk/platform-tools/adb.exe')
        )
        $demoAdb = $demoAdbCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($demoAdb) {
            & $demoAdb -d reverse tcp:3000 "tcp:$demoPort"
            $demoUsbReady = $LASTEXITCODE -eq 0
            if ($demoUsbReady -and $demoPort -ne 3000) {
                & $demoAdb -d reverse "tcp:$demoPort" "tcp:$demoPort"
                $demoUsbReady = $LASTEXITCODE -eq 0
            }
            if ($demoUsbReady) {
                $demoPackage = if ($Preview) { 'vn.edu.smartfarm.smart_farm.preview' } else { 'vn.edu.smartfarm.smart_farm' }
                & $demoAdb -d shell am start -n "$demoPackage/com.example.smart_farm.MainActivity"
            } else { Write-Host 'Ket noi mot dien thoai USB de tu dong noi API.' }
        }
    }
    Write-Host 'Tai khoan va kich ban: docs/DEMO.md'
} finally { Pop-Location }
