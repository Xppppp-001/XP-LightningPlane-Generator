$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'src\XP_RibbonWidener.ms'
$controlPath = Join-Path $projectRoot 'package\ribbon-widener\mzp.run'
$packagePath = Join-Path $projectRoot 'dist\XP模型扩宽工具_V1.2.0.mzp'
$reportPath = Join-Path $projectRoot 'artifacts\ribbon-widener-static.txt'
$testPath = Join-Path $projectRoot 'tests\ribbon-widener-smoke.ms'

# Reject encoding mistakes instead of silently changing source files while building.
foreach ($path in @($sourcePath, $controlPath, $testPath, (Join-Path $projectRoot 'tests\ribbon-gradient-smoke.ms'))) {
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191) {
        throw "文件须为 UTF-8 BOM：$path"
    }
    $scriptText = [IO.File]::ReadAllText($path)
    if ($path.EndsWith('.ms')) {
        # Lexical checks only: not a substitute for the MaxScript compiler/runtime.
        $code = [regex]::Replace($scriptText, '(?s)/\*.*?\*/|"(?:\\.|[^"\\])*"|--[^\r\n]*', '')
        $stack = [Collections.Generic.Stack[char]]::new()
        $pairs = @{ ')' = '('; ']' = '['; '}' = '{' }
        foreach ($ch in $code.ToCharArray()) {
            if ('([{'.Contains([string]$ch)) { $stack.Push($ch) }
            elseif (')]}'.Contains([string]$ch)) {
                if ($stack.Count -eq 0 -or $stack.Pop() -ne $pairs[[string]$ch]) { throw "括号不配对：$path" }
            }
        }
        if ($stack.Count -ne 0) { throw "括号未闭合：$path" }
        if ($code -match '(?m)^\s*\+' -or $code -match 'Editable\\_Poly' -or $code.Contains('```')) { throw "含粘贴或续行错误：$path" }
    }
}

$source = [IO.File]::ReadAllText($sourcePath)
$definitions = [regex]::Matches($source, '(?m)^fn\s+(XP_RW_\w+)\b')
foreach ($definition in $definitions) {
    $name = $definition.Groups[1].Value
    $prefix = $source.Substring(0, $definition.Index)
    if ($prefix -match ('\b' + $name + '\b')) { throw "函数前向引用：$name" }
}
$control = [IO.File]::ReadAllText($controlPath)
if (-not $source.Contains('XP模型扩宽工具 V1.2.0') -or -not $control.Contains('XP模型扩宽工具 V1.2.0')) {
    throw '源码窗口和入口版本必须统一为 V1.2.0。'
}
foreach ($requiredFunction in @('XP_RW_QuadFaces', 'XP_RW_WalkSectionEnd', 'XP_RW_TraceSection', 'XP_RW_CaptureStart', 'XP_RW_PrepareGradient', 'XP_RW_ApplyGradient')) {
    if (-not $source.Contains($requiredFunction)) { throw "缺少完整横截面处理：$requiredFunction" }
}
foreach ($entryKind in @('run', 'drop')) {
    if ($control -notmatch ('(?m)^' + $entryKind + ' "XP_RibbonWidener.ms"\s*$')) { throw "缺少 $entryKind 入口" }
}
if ($source -match 'polyop\.setVert[^\r\n]*useSoftSel:') { throw 'setVert 不支持 useSoftSel 关键字。' }
if ($source -match '(?i)polyop\.(set\w*Map\w*|setMap\w*|defaultMapFaces|applyUVWMap)|Unwrap_UVW|UVWMap') { throw '扩宽源码不得写入或重建原 UV。' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Path (Split-Path $packagePath), (Split-Path $reportPath) -Force | Out-Null
# Build entirely in memory; write only the companion package, preserving generator releases.
$memory = [IO.MemoryStream]::new()
$archive = [IO.Compression.ZipArchive]::new($memory, [IO.Compression.ZipArchiveMode]::Create, $true)
$files = [ordered]@{ 'mzp.run' = $controlPath; 'XP_RibbonWidener.ms' = $sourcePath }
try {
    foreach ($entryName in $files.Keys) {
        $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [DateTimeOffset]::new(2026, 9, 7, 0, 0, 0, [TimeSpan]::Zero)
        $stream = $entry.Open()
        try { $content = [IO.File]::ReadAllBytes($files[$entryName]); $stream.Write($content, 0, $content.Length) }
        finally { $stream.Dispose() }
    }
}
finally { $archive.Dispose() }
try { [IO.File]::WriteAllBytes($packagePath, $memory.ToArray()) }
finally { $memory.Dispose() }

$archive = [IO.Compression.ZipFile]::OpenRead($packagePath)
try {
    if ($archive.Entries.Count -ne 2) { throw '包内文件数量错误。' }
    foreach ($entryName in $files.Keys) {
        $entry = $archive.GetEntry($entryName)
        if ($null -eq $entry) { throw "包内缺少 $entryName" }
        $stream = $entry.Open()
        $buffer = [IO.MemoryStream]::new()
        try {
            $stream.CopyTo($buffer)
            if ([Convert]::ToBase64String($buffer.ToArray()) -cne [Convert]::ToBase64String([IO.File]::ReadAllBytes($files[$entryName]))) { throw "包内内容不一致：$entryName" }
        }
        finally { $stream.Dispose(); $buffer.Dispose() }
    }
}
finally { $archive.Dispose() }

$report = @(
    'PASS - static packaging checks; runtime evidence is reported separately',
    ('Timestamp: ' + (Get-Date -Format o)),
    'UTF-8 BOM: source, control, regression script',
    'Balanced lexical delimiters: source and regression script',
    'Forward internal function references: 0',
    'Version: V1.2.0; full-section and gradient functions present; no UV mutation APIs',
    'MZP entries: mzp.run, XP_RibbonWidener.ms; run/drop paths verified',
    'Both archived files match workspace bytes',
    ('Source SHA256: ' + (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash),
    ('Package SHA256: ' + (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash),
    'Runtime evidence: artifacts/ribbon-gui-status.txt, ribbon-widener-smoke.txt, ribbon-gradient-smoke.txt',
    'PENDING manual validation: Windows physical drag/drop and original user model/texture'
)
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8
$report
