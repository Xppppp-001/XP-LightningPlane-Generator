/*
    仅用于由全新的 3dsmax.exe 测试实例启动。
    无论测试通过或失败，都会写入项目内结果并关闭该测试实例。
*/

global XP_GUI_TEST_OwnerToken = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_GUI_TEST_OWNER_TOKEN"
global XP_TEST_LastPass

fn XP_GUI_IsOwnedTestInstance =
(
    XP_GUI_TEST_OwnerToken != undefined and (classOf XP_GUI_TEST_OwnerToken) == String and (matchPattern XP_GUI_TEST_OwnerToken pattern:"XP_GEOMETRY_SMOKE_*" ignoreCase:false)
)

fn XP_GUI_RunSmokeTest =
(
    if not XP_GUI_IsOwnedTestInstance() do
    (
        format "[XP_GUI_TEST_SKIP] 缺少独立测试实例所有权令牌；不会运行测试或退出 3ds Max。\n"
        return false
    )

    local resultPath = "E:/CodeXProject/3dsmaxLightning/artifacts/gui-smoke-result.txt"
    local resultText = ""

    try
    (
        fileIn "E:/CodeXProject/3dsmaxLightning/tests/smoke.ms" quiet:true
        resultText = "PASS"
    )
    catch
    (
        local exceptionText = getCurrentException()
        local errorSourceFile = ""
        local errorSourceLine = -1
        local exceptionStack = ""
        local lastPassedAssertion = if XP_TEST_LastPass != undefined then XP_TEST_LastPass as string else "<测试脚本尚未初始化>"
        try (errorSourceFile = getErrorSourceFileName()) catch (errorSourceFile = "<不可用>")
        try (errorSourceLine = getErrorSourceFileLine()) catch (errorSourceLine = -1)
        try (exceptionStack = getCurrentExceptionStack()) catch (exceptionStack = "<不可用>")
        local lightningError = ""
        try (lightningError = XP_LG_LastError as string) catch (lightningError = "<不可用>")
        resultText = "FAIL\nERROR=" + exceptionText + "\nSOURCE=" + errorSourceFile + "\nLINE=" + errorSourceLine as string + "\nLAST_PASS=" + lastPassedAssertion + "\nLIGHTNING_ERROR=" + lightningError + "\nSTACK=" + exceptionStack
    )

    local outputStream = createFile resultPath
    if outputStream != undefined do
    (
        format "%\n" resultText to:outputStream
        close outputStream
    )

    if XP_GUI_IsOwnedTestInstance() then
        quitMAX #noPrompt
    else
        format "[XP_GUI_TEST_SKIP] 退出前所有权复核失败；不会退出 3ds Max。\n"
)

if XP_GUI_IsOwnedTestInstance() do XP_GUI_RunSmokeTest()
