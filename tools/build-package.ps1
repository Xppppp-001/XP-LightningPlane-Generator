$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceScript = Join-Path $projectRoot 'src\XP_LightningGenerator.ms'
$runControl = Join-Path $projectRoot 'package\mzp.run'
$buildRoot = Join-Path $projectRoot 'build'
$stageRoot = Join-Path $buildRoot 'mzp-stage'
$distRoot = Join-Path $projectRoot 'dist'
$zipPath = Join-Path $buildRoot 'XP_LightningGenerator_v1.2.0.zip'
$mzpPath = Join-Path $distRoot 'XP闪电面片生成器_V1.2.0.mzp'
$previousMzpPath = Join-Path $distRoot 'XP闪电面片生成器_V1.1.0.mzp'
$legacyMzpPath = Join-Path $distRoot '写实闪电生成器_V1.1.0.mzp'

if (-not (Test-Path -LiteralPath $sourceScript)) {
    throw "缺少主脚本：$sourceScript"
}
if (-not (Test-Path -LiteralPath $runControl)) {
    throw "缺少 mzp.run：$runControl"
}

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

if (Test-Path -LiteralPath $stageRoot) {
    $resolvedStage = (Resolve-Path -LiteralPath $stageRoot).Path
    $resolvedBuild = (Resolve-Path -LiteralPath $buildRoot).Path
    if (-not $resolvedStage.StartsWith($resolvedBuild, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "拒绝清理工作区外目录：$resolvedStage"
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}

New-Item -ItemType Directory -Path $stageRoot | Out-Null
Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $stageRoot 'XP_LightningGenerator.ms')
Copy-Item -LiteralPath $runControl -Destination (Join-Path $stageRoot 'mzp.run')

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $mzpPath) {
    Remove-Item -LiteralPath $mzpPath -Force
}

Compress-Archive -Path (Join-Path $stageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Move-Item -LiteralPath $zipPath -Destination $mzpPath

if (Test-Path -LiteralPath $legacyMzpPath) {
    Remove-Item -LiteralPath $legacyMzpPath -Force
}
if (Test-Path -LiteralPath $previousMzpPath) {
    Remove-Item -LiteralPath $previousMzpPath -Force
}

$hash = Get-FileHash -LiteralPath $mzpPath -Algorithm SHA256
[pscustomobject]@{
    Package = $mzpPath
    Bytes = (Get-Item -LiteralPath $mzpPath).Length
    SHA256 = $hash.Hash
}
