$ErrorActionPreference = 'Stop'
# User-confirmed path: do not replace this with 3dsmaxbatch.exe or another version.
$maxExe = 'C:\Program Files\Autodesk\3ds Max 2023\3dsmax.exe'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runner = (Join-Path $projectRoot 'tests\ribbon-gui-runner.ms').Replace('\','/')
if (-not (Test-Path -LiteralPath $maxExe)) { throw "找不到用户指定的 Max 2023：$maxExe" }
if (Get-Process -Name 3dsmax -ErrorAction SilentlyContinue) { throw '当前已有 Max 实例；为避免许可或启动冲突，不启动第二个测试实例。当前场景未修改。' }
& (Join-Path $PSScriptRoot 'build-ribbon-widener.ps1')
$previousToken = $env:XP_RIBBON_TEST_OWNER
try {
    $env:XP_RIBBON_TEST_OWNER = 'XP_RIBBON_TEST_' + [guid]::NewGuid().ToString('N')
    $testProcess = Start-Process -FilePath $maxExe -ArgumentList @('-q','-silent','-U','MAXScript',('"' + $runner + '"')) -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    $testProcess.Id | Set-Content -LiteralPath (Join-Path $projectRoot 'artifacts\ribbon-gui-pid.txt')
    [pscustomobject]@{ PID=$testProcess.Id; Executable=$maxExe; Result=(Join-Path $projectRoot 'artifacts\ribbon-gui-status.txt') }
}
finally { $env:XP_RIBBON_TEST_OWNER = $previousToken }
