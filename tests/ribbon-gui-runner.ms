/* Only launched by tools/test-ribbon-widener.ps1 in its own empty Max 2023. */
(
    local token = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_RIBBON_TEST_OWNER"
    if token == undefined or not (matchPattern token pattern:"XP_RIBBON_TEST_*" ignoreCase:false) do throw "缺少隔离测试实例令牌，不运行或关闭 Max。"
    local root = "E:/CodeXProject/3dsmaxLightning/"
    local report = createFile (root + "artifacts/ribbon-gui-status.txt") encoding:#utf8
    format "RUNNING | Max=% | %\n" (maxVersion()) localTime to:report
    flush report
    try
    (
        fileIn (root + "tests/ribbon-widener-smoke.ms")
        fileIn (root + "tests/ribbon-gradient-smoke.ms")
        format "PASS | both suites completed | %\n" localTime to:report
    )
    catch
    (
        format "FAIL | % | source=% | line=%\n" (getCurrentException()) (getErrorSourceFileName()) (getErrorSourceFileLine()) to:report
    )
    close report
    if token == ((dotNetClass "System.Environment").GetEnvironmentVariable "XP_RIBBON_TEST_OWNER") do quitMAX #noPrompt
)
