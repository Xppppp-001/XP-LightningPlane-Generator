$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'src\XP_LightningGenerator.ms'
$packagePath = Join-Path $projectRoot 'dist\XP闪电面片生成器_V1.2.0.mzp'

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "主脚本不存在：$sourcePath"
}
if (-not (Test-Path -LiteralPath $packagePath)) {
    throw "MZP 包不存在：$packagePath"
}

$source = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath
$sourceBytes = [System.IO.File]::ReadAllBytes($sourcePath)
$sourceHasUtf8Bom = $sourceBytes.Length -ge 3 -and $sourceBytes[0] -eq 0xEF -and $sourceBytes[1] -eq 0xBB -and $sourceBytes[2] -eq 0xBF
if (-not $sourceHasUtf8Bom) {
    throw '主脚本必须使用 UTF-8 BOM，以保证 3ds Max 2023 中文文本稳定解析。'
}
$requiredTokens = @(
    'XP_LG_CreateLightningNode',
    'XP闪电面片生成器 V1.2.0',
    '"1.2.0"',
    'XP_LG_ResolveOutput',
    'XP_LG_DeleteOutput',
    'XP_LG_RequestLiveUpdate',
    'XP_LG_FlushLiveUpdate',
    'XP_LG_LiveUpdateBusy',
    'XP_LG_LiveUpdatePending',
    'XP_LG_ComputeAxialTwistAngle',
    'XP_LG_BuildAxiallyTwistedSides',
    'XP_LG_BuildParallelTransportSides',
    'XP_LG_BuildAdaptiveCenterline',
    'XP_LG_BuildWaypointAdaptiveCenterline',
    'XP_LG_BuildWaypointRouteTangents',
    'XP_LG_BuildWaypointNoiseAxes',
    'XP_LG_BuildWaypointGuidePoints',
    'XP_LG_EvaluateWaypointBasePoint',
    'XP_LG_AllocateWaypointFaceCounts',
    'XP_LG_AddWaypointTransitionFaces',
    'XP_LG_BuildWaypointSpanTargetWeights',
    'XP_LG_GetWaypointNodesFromOutput',
    'XP_LG_BuildControlSnapshotSignature',
    'XP_LG_RequestSelectedControlPositionSync',
    'XP_LightningControlSnapshot',
    'XP_LightningWaypointSmoothingEnabled',
    'XP_LightningWaypointSmoothingStrength',
    'XP_LightningWaypointAutoAddFaces',
    'XP_LightningActualFaces',
    'XP_LG_BuildCurvatureWidthScales',
    'XP_LG_BuildRouteCurvatureWidthScales',
    'XP_LG_EndpointTaperScale',
    'XP_LG_ReplaceSelectedOutput',
    'instanceReplace selectedNode temporaryNode',
    'XP_LG_LoadSelectedOutputIntoUI',
    'XP_LightningRibbonWidth',
    'timer tmLiveUpdate interval:200 active:false',
    'polyop.createPolygon',
    'polyop.setMapSupport',
    'polyop.setMapFace',
    '锁定起点',
    '锁定终点',
    '平面面数',
    '噪波 Tiling',
    '噪波整体尺寸倍率',
    '路径噪波强度',
    '启用整段轴向扭转（Twist）',
    '轴向扭转分段',
    '轴向扭转角度',
    '面片两端平滑收尖',
    '所选面片途经点',
    '启用途经点平滑过渡',
    '途经点过渡强度',
    '平滑时允许额外加面',
    '基础预计四边面',
    '添加途经点',
    '上移',
    '下移',
    '移除所选',
    '清空全部',
    '强制重新生成',
    '写实闪电'
)

foreach ($token in $requiredTokens) {
    if (-not $source.Contains($token)) {
        throw "主脚本缺少必要内容：$token"
    }
}

$forbiddenTokens = @(
    'Rotation_list()',
    'XP_LG_FreezeRotationAtZero',
    'XP_LG_ApplyUnityAxisToNode',
    'XP_LG_ApplyUnityAxisToCurrentOutputs',
    'XP_LightningUnityAxis',
    'PivotYUpFrozenV4',
    'btnUnityAxis',
    '设置 Y 轴朝上（旋转归零）'
)

foreach ($token in $forbiddenTokens) {
    if ($source.Contains($token)) {
        throw "主脚本仍包含已撤销的轴向功能：$token"
    }
}

if ($source.Contains('quitMAX')) {
    throw '主脚本不得调用 quitMAX。'
}
if ($source -match '(?m)^local\s+') {
    throw '检测到顶层 local；请确认所有 local 均位于函数或 rollout 作用域。'
}
if ($source.Contains('+=' ) -or $source.Contains('-=')) {
    throw '检测到 MaxScript 不支持的复合赋值运算符。'
}

$sourceLines = Get-Content -Encoding UTF8 -LiteralPath $sourcePath
$functionDefinitions = @{}
for ($lineIndex = 0; $lineIndex -lt $sourceLines.Count; $lineIndex++) {
    if ($sourceLines[$lineIndex] -match '^fn\s+(XP_LG_[A-Za-z0-9_]+)') {
        $functionDefinitions[$matches[1]] = $lineIndex + 1
    }
}
foreach ($functionName in $functionDefinitions.Keys) {
    $definitionLine = $functionDefinitions[$functionName]
    for ($lineIndex = 0; $lineIndex -lt ($definitionLine - 1); $lineIndex++) {
        $lineText = $sourceLines[$lineIndex]
        if ($lineText -match ('\b' + [regex]::Escape($functionName) + '\b') -and $lineText -notmatch '^global\s+' -and $lineText -notmatch '^\s*--') {
            throw "内部函数 $functionName 在定义行 $definitionLine 之前已被第 $($lineIndex + 1) 行引用；干净 Max 会话可能得到 undefined。"
        }
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName })
    $expected = @('mzp.run', 'XP_LightningGenerator.ms')
    foreach ($entry in $expected) {
        if ($entries -notcontains $entry) {
            throw "MZP 根目录缺少：$entry"
        }
    }
    if ($entries.Count -ne $expected.Count) {
        throw "MZP 包含非预期文件：$($entries -join ', ')"
    }

    $sourceEntry = $archive.GetEntry('XP_LightningGenerator.ms')
    $entryStream = $sourceEntry.Open()
    try {
        $memoryStream = New-Object System.IO.MemoryStream
        try {
            $entryStream.CopyTo($memoryStream)
            $packagedSourceBytes = $memoryStream.ToArray()
        }
        finally {
            $memoryStream.Dispose()
        }
    }
    finally {
        $entryStream.Dispose()
    }

    $sourceBase64 = [System.Convert]::ToBase64String($sourceBytes)
    $packagedSourceBase64 = [System.Convert]::ToBase64String($packagedSourceBytes)
    if ($sourceBase64 -cne $packagedSourceBase64) {
        throw 'MZP 内主脚本与 src 目录当前源码不一致；请重新构建。'
    }
}
finally {
    $archive.Dispose()
}

$hash = Get-FileHash -LiteralPath $packagePath -Algorithm SHA256
[pscustomobject]@{
    SourceUTF8BOM = $sourceHasUtf8Bom
    ForwardFunctionReferences = 0
    PackagedSourceMatches = $true
    Entries = 'mzp.run, XP_LightningGenerator.ms'
    PackageBytes = (Get-Item -LiteralPath $packagePath).Length
    SHA256 = $hash.Hash
}
