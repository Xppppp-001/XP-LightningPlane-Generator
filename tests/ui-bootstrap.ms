/*
    UI 测试的安全引导器。
    只在进程环境变量带有专属令牌和工作区内结果路径时运行、写结果或退出。
*/

global XP_UI_BOOTSTRAP_LaunchValue = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_UI_TEST_LAUNCH_TOKEN"
global XP_UI_BOOTSTRAP_ResultValue = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_UI_TEST_RESULT_PATH"
global XP_UI_TEST_LaunchToken = if XP_UI_BOOTSTRAP_LaunchValue != undefined then XP_UI_BOOTSTRAP_LaunchValue as string else undefined
global XP_UI_TEST_ResultPath = if XP_UI_BOOTSTRAP_ResultValue != undefined then XP_UI_BOOTSTRAP_ResultValue as string else undefined

fn XP_UI_BOOTSTRAP_IsOwned =
(
    local childToken = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_UI_TEST_CHILD_TOKEN"
    local normalizedPath = if XP_UI_TEST_ResultPath != undefined then substituteString (XP_UI_TEST_ResultPath as string) "\\" "/" else ""
    local tokenText = if XP_UI_TEST_LaunchToken != undefined then XP_UI_TEST_LaunchToken as string else ""
    local childText = if childToken != undefined then childToken as string else ""

    tokenText == childText and (matchPattern tokenText pattern:"XP_UI_SMOKE_*" ignoreCase:false) and (matchPattern (toLower normalizedPath) pattern:"e:/codexproject/3dsmaxlightning/artifacts/ui-smoke-*.txt" ignoreCase:true)
)

fn XP_UI_BOOTSTRAP_WriteFailure message =
(
    local outputStream = createFile (XP_UI_TEST_ResultPath as string)
    if outputStream != undefined do
    (
        format "FAIL\nBOOTSTRAP_ERROR=%\n" message to:outputStream
        close outputStream
    )
)

if XP_UI_BOOTSTRAP_IsOwned() then
(
    try
    (
        fileIn "E:/CodeXProject/3dsmaxLightning/tests/ui-runner.ms" quiet:true
        if not doesFileExist (XP_UI_TEST_ResultPath as string) do XP_UI_BOOTSTRAP_WriteFailure "UI runner 返回但没有写入结果。"
    )
    catch
    (
        XP_UI_BOOTSTRAP_WriteFailure (getCurrentException())
    )

    if XP_UI_BOOTSTRAP_IsOwned() do quitMAX #noPrompt
)
else
(
    format "[XP_UI_BOOTSTRAP_SKIP] 缺少独立测试实例所有权；不会运行或退出。\n"
)
