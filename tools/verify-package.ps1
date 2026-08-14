$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'src\XP_LightningGenerator.ms'
$packagePath = Join-Path $projectRoot 'dist\XP闪电面片生成器_V1.4.0.mzp'

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
    'XP闪电面片生成器 V1.4.0',
    '"1.4.0"',
    'XP_LightningWholeOrientationAngle',
    'XP_LightningNoisePhase',
    'XP_LightningNoiseSeparateAxes',
    'XP_LightningNoiseUniformStrength',
    'XP_LightningNoiseXStrength',
    'XP_LightningNoiseYStrength',
    'XP_LightningNoiseZStrength',
    'XP_LG_ResolveNoiseAxisScales',
    'XP_LG_ApplyNoiseAxisScales',
    'FFDUserControlledPlane',
    'XP_LightningExtraFaces',
    'XP_LG_ResolveFFDSegmentCount',
    'XP_LG_GetGridDiagonalMinimumQuality',
    'XP_LG_GetGridDiagonalMaximumExcessAngle',
    'XP_LG_ResolveOutput',
    'XP_LG_DeleteOutput',
    'XP_LG_RequestLiveUpdate',
    'XP_LG_FlushLiveUpdate',
    'XP_LG_LiveUpdateBusy',
    'XP_LG_LiveUpdatePending',
    'XP_LG_ComputeAxialTwistAngle',
    'XP_LG_BuildAxiallyTwistedSides',
    'XP_LG_BuildParallelTransportSides',
    'XP_LG_GetQuadDiagonalQuality',
    'XP_LG_BuildArcLengthU',
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
    'XP_LightningActualLongitudinalFaces',
    'XP_LightningWidthSegments',
    'XP_LightningStableDiagonalMode',
    'XP_LightningMinimumGridNormalDot',
    'XP_LightningMaximumGridExcessAngle',
    'XP_LG_EndpointTaperScale',
    'XP_LG_ReplaceSelectedOutput',
    'instanceReplace selectedNode temporaryNode',
    'XP_LG_LoadSelectedOutputIntoUI',
    'XP_LightningRibbonWidth',
    'timer tmLiveUpdate interval:200 active:false',
    'polyop.createPolygon',
    'polyop.setMapSupport',
    'polyop.setMapFace',
    'polyop.setDiagonal editablePoly faceId 1 3',
    'polyop.setDiagonal editablePoly faceId 2 4',
    'polyop.setFaceSmoothGroup',
    '锁定起点',
    '锁定终点',
    '平面面数',
    '噪波 Tiling',
    '噪波相位位移',
    '分开控制噪波轴向强度',
    '统一轴向强度',
    'X 轴强度',
    'Y 轴强度',
    'Z 轴强度',
    '噪波整体尺寸倍率',
    '路径噪波强度',
    '启用整段轴向扭转（Twist）',
    '轴向扭转分段',
    '轴向扭转角度',
    '面片两端平滑收尖',
    '所选面片途经点',
    '启用途经点平滑过渡',
    '途经点过渡强度',
    '额外加面',
    '预计四边面',
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
    '设置 Y 轴朝上（旋转归零）',
    'while not ribbonIsSafe',
    'sides = XP_LG_BuildTextureStableSides',
    '"FullWidthAdaptiveFaces"',
    '视觉优化未收敛',
    'checkbox chkWaypointAutoAddFaces'
)

foreach ($token in $forbiddenTokens) {
    if ($source.Contains($token)) {
        throw "主脚本仍包含禁止进入当前版本的功能或旧生成链路：$token"
    }
}

$branchStart = $source.IndexOf('fn XP_LG_CreateLightningBranchNode')
$branchEnd = $source.IndexOf('fn XP_LG_CreateLightningNodes', $branchStart + 1)
if ($branchStart -lt 0 -or $branchEnd -le $branchStart) {
    throw '无法定位单分支生成主链。'
}
$branchSource = $source.Substring($branchStart, $branchEnd - $branchStart)
$forbiddenGenerationTokens = @(
    'while ',
    'XP_LG_GetRibbonSafetyReport',
    'XP_LG_BuildTextureStableSides',
    'XP_LG_BuildTwistSafeWidthScales',
    'XP_LG_BuildCurvatureWidthScales',
    'XP_LG_BuildRouteCurvatureWidthScales',
    'XP_LG_ResolveFFDSegmentCount',
    'XP_LG_ResolveRibbonGridLayout'
)
foreach ($token in $forbiddenGenerationTokens) {
    if ($branchSource.Contains($token)) {
        throw "FFD 单次生成主链仍调用旧循环／视觉／缩宽逻辑：$token"
    }
}
if ([regex]::Matches($branchSource, 'mesh\s+name:').Count -ne 1) {
    throw '单分支生成主链必须只创建一次最终临时网格。'
}
if (-not $branchSource.Contains('local resolvedFFDSegmentCount = segmentCount + extraFaceCount')) {
    throw '单分支生成主链必须只使用平面面数加用户额外加面。'
}
if (-not $branchSource.Contains('local widthSegmentCount = 1')) {
    throw '单分支生成主链必须保持标准单列 Plane。'
}
if ($branchSource.Contains('diagonalModes')) {
    throw '单分支生成主链不得恢复逐面独立对角线模式。'
}
if ([regex]::Matches($branchSource, 'polyop\.setDiagonal editablePoly faceId 1 3').Count -ne 1 -or [regex]::Matches($branchSource, 'polyop\.setDiagonal editablePoly faceId 2 4').Count -ne 1) {
    throw '单分支生成主链必须只按整段统一模式设置两种候选对角线。'
}

$centerlineStart = $source.IndexOf('fn XP_LG_BuildAdaptiveCenterline')
$centerlineEnd = $source.IndexOf('fn XP_LG_AllocateWaypointFaceCounts', $centerlineStart + 1)
if ($centerlineStart -lt 0 -or $centerlineEnd -le $centerlineStart) {
    throw '无法定位规则 Plane 的普通路径 FFD 映射。'
}
$centerlineSource = $source.Substring($centerlineStart, $centerlineEnd - $centerlineStart)
if (-not $centerlineSource.Contains('local t = (sampleIndex as float) / (segmentCount as float)')) {
    throw '普通路径必须使用规则 Plane 的等距逻辑长度参数。'
}
foreach ($token in @('denseSegmentCount', 'curvatureFactor', 'twistFactor', 'cumulativeWeights')) {
    if ($centerlineSource.Contains($token)) {
        throw "普通路径仍按曲率或 Twist 重新分配固定 Plane 线环：$token"
    }
}

$waypointCenterlineStart = $source.IndexOf('fn XP_LG_BuildWaypointAdaptiveCenterline')
$waypointCenterlineEnd = $source.IndexOf('fn XP_LG_BuildParallelTransportSides', $waypointCenterlineStart + 1)
if ($waypointCenterlineStart -lt 0 -or $waypointCenterlineEnd -le $waypointCenterlineStart) {
    throw '无法定位途经点路径 FFD 映射。'
}
$waypointCenterlineSource = $source.Substring($waypointCenterlineStart, $waypointCenterlineEnd - $waypointCenterlineStart)
if (-not $waypointCenterlineSource.Contains('XP_LG_AddWaypointTransitionFaces routePoints baseAllocations waypointSmoothingEnabled waypointSmoothingStrength false')) {
    throw '途经点主路径仍可能通过旧自动开关增加面数。'
}
foreach ($token in @('denseSegmentCount', 'curvatureFactor', 'twistFactor', 'cumulativeWeights')) {
    if ($waypointCenterlineSource.Contains($token)) {
        throw "途经点路径仍按曲率或 Twist 重新分配固定 Plane 线环：$token"
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
