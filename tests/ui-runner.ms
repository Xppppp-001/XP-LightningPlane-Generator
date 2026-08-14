/*
    XP闪电面片生成器：GUI UI 冒烟测试

    安全约束：
    - 只能由单独启动的 3dsmax.exe 测试实例运行。
    - 启动器必须同时传入全局令牌 XP_UI_TEST_LaunchToken，
      并为新子进程设置同值的进程环境变量 XP_UI_TEST_CHILD_TOKEN。
    - 缺少令牌、令牌不匹配或结果路径不在项目 artifacts 目录时，
      本脚本不会加载插件，也绝不会调用 quitMAX。
    - 测试通过或失败后，仅由满足上述所有权条件的测试实例自行退出。

    本脚本不创建或修改场景对象，只验证中文 rollout 已实际显示，
    并验证关键 UI 控件具有真实 HWND、可见、预期启用状态且中文标题正确。
*/

global XP_UI_TEST_LaunchToken
global XP_UI_TEST_ResultPath
global XP_UI_TEST_LaunchValue
global XP_UI_TEST_ResultValue
global XP_LG_UpdateWholeTwistControlState
global XP_LG_UpdateWaypointSmoothingControlState
global XP_LG_UpdateNoiseAxisControlState
global XP_LG_RequestLiveUpdate
global XP_LG_FlushLiveUpdate
global XP_LG_Rollout
global XP_LG_LiveUpdateBusy
global XP_LG_LiveUpdatePending
global XP_LG_LiveUpdateCurrentDepth
global XP_LG_LiveUpdateAttemptCount
global XP_LG_LiveUpdateSuccessCount
global XP_LG_LiveUpdateMaxDepth
global XP_LG_LiveUpdateTimerLoopActive

if XP_UI_TEST_LaunchToken == undefined do
(
    XP_UI_TEST_LaunchValue = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_UI_TEST_LAUNCH_TOKEN"
    if XP_UI_TEST_LaunchValue != undefined do XP_UI_TEST_LaunchToken = XP_UI_TEST_LaunchValue as string
)
if XP_UI_TEST_ResultPath == undefined do
(
    XP_UI_TEST_ResultValue = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_UI_TEST_RESULT_PATH"
    if XP_UI_TEST_ResultValue != undefined do XP_UI_TEST_ResultPath = XP_UI_TEST_ResultValue as string
)

fn XP_UI_TEST_IsOwnedInstance =
(
    local environmentValue = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_UI_TEST_CHILD_TOKEN"
    local environmentToken = if environmentValue != undefined then environmentValue as string else undefined
    local tokenIsValid = false
    local resultPathIsValid = false

    if XP_UI_TEST_LaunchToken != undefined and environmentToken != undefined do
    (
        if (classOf XP_UI_TEST_LaunchToken) == String and (classOf environmentToken) == String do
        (
            tokenIsValid = (XP_UI_TEST_LaunchToken == environmentToken) and (matchPattern XP_UI_TEST_LaunchToken pattern:"XP_UI_SMOKE_*" ignoreCase:false)
        )
    )

    if XP_UI_TEST_ResultPath != undefined and (classOf XP_UI_TEST_ResultPath) == String do
    (
        local normalizedResultPath = toLower (substituteString XP_UI_TEST_ResultPath "\\" "/")
        resultPathIsValid = matchPattern normalizedResultPath pattern:"e:/codexproject/3dsmaxlightning/artifacts/ui-smoke-*.txt" ignoreCase:true
    )

    tokenIsValid and resultPathIsValid
)

fn XP_UI_TEST_Assert condition message =
(
    if not condition do throw ("[XP_UI_TEST_FAIL] " + message)
    format "[XP_UI_TEST_PASS] %\n" message
)

fn XP_UI_TEST_ControlHasWindow uiControl =
(
    local handles = #()
    local hasWindow = false

    try (handles = uiControl.hwnd) catch (handles = #())
    for windowHandle in handles do
    (
        if windowHandle != undefined and windowHandle != 0 do hasWindow = true
    )

    hasWindow
)

fn XP_UI_TEST_HasCaption uiControls expectedCaption =
(
    for uiControl in uiControls do
    (
        local currentCaption = ""
        try (currentCaption = uiControl.caption) catch (currentCaption = "")
        if currentCaption == expectedCaption do return true
    )
    false
)

fn XP_UI_TEST_FindControl rolloutInstance controlName =
(
    for candidateControl in rolloutInstance.controls do
    (
        if (candidateControl.name as string) == (controlName as string) do return candidateControl
    )
    undefined
)

fn XP_UI_TEST_CheckControl rolloutInstance controlName expectedCaption expectedEnabled:true =
(
    local uiControl = XP_UI_TEST_FindControl rolloutInstance controlName
    XP_UI_TEST_Assert (uiControl != undefined) ("控件实例有效：" + controlName as string)
    XP_UI_TEST_Assert (uiControl.visible == true) ("控件可见：" + controlName as string)
    XP_UI_TEST_Assert (uiControl.enabled == expectedEnabled) ("控件启用状态符合默认设计：" + controlName as string)
    XP_UI_TEST_Assert (XP_UI_TEST_ControlHasWindow uiControl) ("控件已创建原生窗口：" + controlName as string)
    XP_UI_TEST_Assert (uiControl.caption == expectedCaption) ("控件中文标题正确：" + controlName as string + "；actual=" + uiControl.caption + "；expected=" + expectedCaption)
    true
)

fn XP_UI_TEST_WriteResult resultText =
(
    local outputStream = createFile XP_UI_TEST_ResultPath
    if outputStream == undefined do return false

    format "%\n" resultText to:outputStream
    flush outputStream
    close outputStream
    true
)

fn XP_UI_TEST_WriteSkipDiagnostic =
(
    local childValue = (dotNetClass "System.Environment").GetEnvironmentVariable "XP_UI_TEST_CHILD_TOKEN"
    local childText = if childValue != undefined then childValue as string else "<undefined>"
    local launchText = if XP_UI_TEST_LaunchToken != undefined then XP_UI_TEST_LaunchToken as string else "<undefined>"
    local resultTextValue = if XP_UI_TEST_ResultPath != undefined then XP_UI_TEST_ResultPath as string else "<undefined>"
    local normalizedPath = substituteString resultTextValue "\\" "/"
    local safePath = matchPattern (toLower normalizedPath) pattern:"e:/codexproject/3dsmaxlightning/artifacts/ui-smoke-*.txt" ignoreCase:true

    if safePath do
    (
        XP_UI_TEST_WriteResult ("SKIP\nLAUNCH=" + launchText + "\nCHILD=" + childText + "\nLAUNCH_CLASS=" + (classOf XP_UI_TEST_LaunchToken) as string + "\nCHILD_CLASS=" + (classOf childText) as string + "\nRESULT=" + resultTextValue + "\nRESULT_CLASS=" + (classOf XP_UI_TEST_ResultPath) as string)
    )
)

fn XP_UI_TEST_RunOwnedInstance =
(
    if not XP_UI_TEST_IsOwnedInstance() do
    (
        format "[XP_UI_TEST_SKIP] 当前进程不具备测试实例所有权；不会加载插件或退出。\n"
        return false
    )

    local resultText = ""
    local processId = ((dotNetClass "System.Diagnostics.Process").GetCurrentProcess()).Id
    local testedRollout = undefined

    try
    (
        local versionInfo = maxVersion()
        XP_UI_TEST_Assert (versionInfo[1] >= 25000 and versionInfo[1] < 26000) "运行宿主为 3ds Max 2023"

        global XP_LG_SuppressUI = false
        global XP_LG_Rollout = undefined
        fileIn "E:/CodeXProject/3dsmaxLightning/dist/XP闪电面片生成器_V1.4.0.mzp" quiet:true
        testedRollout = XP_LG_Rollout

        XP_UI_TEST_Assert (testedRollout != undefined) "MZP 的 run 主脚本已定义 rollout"
        XP_UI_TEST_Assert (testedRollout.open == true) "主 rollout 处于打开状态"
        XP_UI_TEST_Assert (testedRollout.isDisplayed == true) "主 rollout 已显示"
        XP_UI_TEST_Assert (testedRollout.visible == true) "主 rollout 可见"
        XP_UI_TEST_Assert (testedRollout.hwnd != 0) "主 rollout 具有有效 HWND"
        XP_UI_TEST_Assert (testedRollout.title == "XP闪电面片生成器 V1.4.0") "主窗口中文标题正确"

        local requiredControls = #(
            #(#pbStart, "拾取起点", true),
            #(#btnClearStart, "清除起点", true),
            #(#pbAddEndpoint, "添加终点", true),
            #(#lbEndpoints, "终点列表：", true),
            #(#btnRemoveEndpoint, "移除所选终点", true),
            #(#btnClearEndpoints, "清空全部终点", true),
            #(#pbAddWaypoint, "添加途经点", false),
            #(#lbWaypoints, "途经点列表（起点 → 列表顺序 → 终点）：", true),
            #(#btnWaypointUp, "上移", false),
            #(#btnWaypointDown, "下移", false),
            #(#btnRemoveWaypoint, "移除所选", false),
            #(#btnClearWaypoints, "清空全部", false),
            #(#chkWaypointSmoothing, "启用途经点平滑过渡", true),
            #(#spWaypointSmoothingStrength, "途经点过渡强度：", false),
            #(#spFaces, "平面面数：", true),
            #(#spExtraFaces, "额外加面：", true),
            #(#spWidth, "闪电宽度：", true),
            #(#chkTaperEnds, "面片两端平滑收尖", true),
            #(#spTwist, "路径噪波强度：", true),
            #(#spNoiseSize, "噪波大小：", true),
            #(#spTiling, "噪波 Tiling：", true),
            #(#spNoisePhase, "噪波相位位移：", true),
            #(#chkNoiseSeparateAxes, "分开控制噪波轴向强度", true),
            #(#spNoiseUniformStrength, "统一轴向强度：", true),
            #(#spNoiseXStrength, "X 轴强度：", false),
            #(#spNoiseYStrength, "Y 轴强度：", false),
            #(#spNoiseZStrength, "Z 轴强度：", false),
            #(#spSeed, "随机种子：", true),
            #(#chkWholeTwist, "启用整段轴向扭转（Twist）", true),
            #(#spWholeTwistSegments, "轴向扭转分段：", false),
            #(#spWholeTwistAmount, "轴向扭转角度：", false),
            #(#spWholeOrientationAngle, "整段朝向旋转：", true),
            #(#chkLockStart, "锁定起点", true),
            #(#chkLockEnd, "锁定终点", true),
            #(#btnGenerate, "强制重新生成", true)
        )

        for controlDefinition in requiredControls do
        (
            local expectedEnabled = controlDefinition[3]
            XP_UI_TEST_CheckControl testedRollout controlDefinition[1] controlDefinition[2] expectedEnabled:expectedEnabled
        )

        XP_UI_TEST_Assert (XP_UI_TEST_HasCaption testedRollout.controls "起点与终点") "中文分组标题存在：起点与终点"
        XP_UI_TEST_Assert (XP_UI_TEST_HasCaption testedRollout.controls "所选面片途经点") "中文分组标题存在：所选面片途经点"
        XP_UI_TEST_Assert (XP_UI_TEST_HasCaption testedRollout.controls "模型参数") "中文分组标题存在：模型参数"
        XP_UI_TEST_Assert (XP_UI_TEST_HasCaption testedRollout.controls "扭曲与噪波") "中文分组标题存在：扭曲与噪波"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #lblPointHint).text == "位置取自所选对象的世界包围盒中心。") "中文位置说明正确"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #lblEndpointCount).text == "有效终点：0　预计四边面：0") "中文终点状态正确"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #lblWaypointHint).text == "先在场景层级中唯一选中一个 LightningPlane，再按列表顺序添加。") "中文途经点操作说明正确"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #lbWaypoints).items.count == 0) "未选中面片时途经点列表为空"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #chkWaypointSmoothing).checked == false) "途经点平滑过渡默认关闭"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spWaypointSmoothingStrength).value == 50.0) "途经点过渡强度默认值为 50"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #lblWaypointActualFaces).text == "实际面数将在生成或更新成功后显示。") "实际面数初始提示正确"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #lblStatus).text == "准备就绪；选中已有面片可编辑，强制重新生成才会新建。") "中文初始状态正确"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #lblVersion).text == "XP闪电面片生成器 V1.4.0｜3ds Max 2023") "中文版本信息正确"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #btnUnityAxis) == undefined) "面板已移除 Unity／Y-Up 轴向修改按钮"

        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spFaces).value == 24) "平面面数控件可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spExtraFaces).value == 0 and (XP_UI_TEST_FindControl testedRollout #spExtraFaces).range[1] == 0 and (XP_UI_TEST_FindControl testedRollout #spExtraFaces).range[2] == 1000) "额外加面滑条默认 0，范围 0 到 1000"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spWidth).value == 3.0) "闪电宽度控件可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #chkTaperEnds).checked == false) "面片两端平滑收尖默认关闭"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spTwist).value == 15.0) "路径噪波强度控件可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spNoiseSize).value == 1.0) "噪波大小控件可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spTiling).value == 1.0) "噪波 Tiling 控件可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spNoisePhase).value == 0.0) "噪波相位位移默认值为零"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #chkNoiseSeparateAxes).checked == false) "噪波轴向强度默认统一控制"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spNoiseUniformStrength).value == 1.0) "统一轴向强度默认值为一"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spNoiseXStrength).value == 1.0 and (XP_UI_TEST_FindControl testedRollout #spNoiseYStrength).value == 1.0 and (XP_UI_TEST_FindControl testedRollout #spNoiseZStrength).value == 1.0) "分轴强度默认值均为一"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spNoiseXStrength).range[1] == 0.0 and (XP_UI_TEST_FindControl testedRollout #spNoiseYStrength).range[1] == 0.0 and (XP_UI_TEST_FindControl testedRollout #spNoiseZStrength).range[1] == 0.0) "三个分轴强度下限均为零"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spSeed).value == 1) "随机种子控件可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #chkWholeTwist).checked == false) "轴向 Twist 默认关闭"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spWholeTwistSegments).value == 4) "轴向扭转分段默认值可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spWholeTwistAmount).value == 90.0) "轴向扭转角度安全默认值可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spWholeTwistSegments).range[1] >= 1) "轴向扭转分段下限不小于 1"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spWholeTwistAmount).range[1] < 0.0 and (XP_UI_TEST_FindControl testedRollout #spWholeTwistAmount).range[2] > 0.0) "轴向扭转角度支持正负两个方向"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spWholeOrientationAngle).value == 0.0) "整段朝向旋转默认值为零"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #spWholeOrientationAngle).range[1] == -180.0 and (XP_UI_TEST_FindControl testedRollout #spWholeOrientationAngle).range[2] == 180.0) "整段朝向旋转支持正负 180 度"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #chkLockStart).checked == true) "锁定起点控件可读取"
        XP_UI_TEST_Assert ((XP_UI_TEST_FindControl testedRollout #chkLockEnd).checked == true) "锁定终点控件可读取"

        local wholeTwistControl = XP_UI_TEST_FindControl testedRollout #chkWholeTwist
        local wholeSegmentsControl = XP_UI_TEST_FindControl testedRollout #spWholeTwistSegments
        local wholeAmountControl = XP_UI_TEST_FindControl testedRollout #spWholeTwistAmount
        global XP_LG_SuppressLiveUpdate = true
        wholeTwistControl.checked = true
        XP_LG_UpdateWholeTwistControlState()
        XP_UI_TEST_Assert (wholeSegmentsControl.enabled and wholeAmountControl.enabled) "启用轴向 Twist 后两个从属参数可用"
        wholeSegmentsControl.value = 7
        wholeAmountControl.value = -180.0
        XP_UI_TEST_Assert (wholeSegmentsControl.value == 7 and wholeAmountControl.value == -180.0) "轴向扭转分段和负角度可设置和读取"
        wholeTwistControl.checked = false

        local separateAxesControl = XP_UI_TEST_FindControl testedRollout #chkNoiseSeparateAxes
        local uniformStrengthControl = XP_UI_TEST_FindControl testedRollout #spNoiseUniformStrength
        local xStrengthControl = XP_UI_TEST_FindControl testedRollout #spNoiseXStrength
        local yStrengthControl = XP_UI_TEST_FindControl testedRollout #spNoiseYStrength
        local zStrengthControl = XP_UI_TEST_FindControl testedRollout #spNoiseZStrength
        separateAxesControl.checked = true
        XP_LG_UpdateNoiseAxisControlState()
        XP_UI_TEST_Assert (not uniformStrengthControl.enabled and xStrengthControl.enabled and yStrengthControl.enabled and zStrengthControl.enabled) "分开控制模式只启用 X/Y/Z 三个强度"
        xStrengthControl.value = 1.0
        yStrengthControl.value = 0.0
        zStrengthControl.value = 0.0
        XP_UI_TEST_Assert (xStrengthControl.value == 1.0 and yStrengthControl.value == 0.0 and zStrengthControl.value == 0.0) "分轴模式支持单轴噪波"
        separateAxesControl.checked = false
        XP_LG_UpdateNoiseAxisControlState()
        XP_UI_TEST_Assert (uniformStrengthControl.enabled and not xStrengthControl.enabled and not yStrengthControl.enabled and not zStrengthControl.enabled) "统一控制模式只启用统一轴向强度"
        XP_LG_UpdateWholeTwistControlState()
        XP_LG_SuppressLiveUpdate = false
        XP_UI_TEST_Assert ((not wholeSegmentsControl.enabled) and (not wholeAmountControl.enabled)) "关闭轴向 Twist 后两个从属参数恢复禁用"

        local waypointSmoothingControl = XP_UI_TEST_FindControl testedRollout #chkWaypointSmoothing
        local waypointSmoothingStrengthControl = XP_UI_TEST_FindControl testedRollout #spWaypointSmoothingStrength
        global XP_LG_SuppressLiveUpdate = true
        waypointSmoothingControl.checked = true
        XP_LG_UpdateWaypointSmoothingControlState()
        XP_UI_TEST_Assert waypointSmoothingStrengthControl.enabled "启用途经点平滑过渡后强度滑条可用"
        waypointSmoothingStrengthControl.value = 75.0
        XP_UI_TEST_Assert (waypointSmoothingStrengthControl.value == 75.0) "途经点过渡滑条可设置和读取"
        waypointSmoothingControl.checked = false
        XP_LG_UpdateWaypointSmoothingControlState()
        XP_LG_SuppressLiveUpdate = false
        XP_UI_TEST_Assert (not waypointSmoothingStrengthControl.enabled) "关闭途经点平滑过渡后强度滑条恢复禁用"

        local liveUpdateTimer = XP_UI_TEST_FindControl testedRollout #tmLiveUpdate
        XP_UI_TEST_Assert (liveUpdateTimer != undefined) "实时更新防抖计时器存在"
        XP_UI_TEST_Assert (liveUpdateTimer.interval == 200 and XP_LG_LiveUpdateTimerLoopActive == true) "实时更新常驻计时循环已启动且间隔为 200ms"
        XP_UI_TEST_Assert (XP_LG_RequestLiveUpdate != undefined and XP_LG_FlushLiveUpdate != undefined) "实时更新请求与刷新入口已定义"
        XP_UI_TEST_Assert (XP_LG_LiveUpdateBusy == false and XP_LG_LiveUpdatePending == false and XP_LG_LiveUpdateCurrentDepth == 0) "实时更新状态机初始为空闲"
        XP_UI_TEST_Assert (XP_LG_LiveUpdateAttemptCount == 0 and XP_LG_LiveUpdateSuccessCount == 0 and XP_LG_LiveUpdateMaxDepth == 0) "实时更新计数器初始为零"

        resultText = "PASS\nPID=" + processId as string + "\nTOKEN=" + XP_UI_TEST_LaunchToken + "\nROLLOUT_HWND=" + testedRollout.hwnd as string + "\nCONTROL_COUNT=" + testedRollout.controls.count as string
    )
    catch
    (
        resultText = "FAIL\nPID=" + processId as string + "\nTOKEN=" + XP_UI_TEST_LaunchToken + "\nERROR=" + getCurrentException()
    )

    if (XP_UI_TEST_WriteResult resultText) != true do format "[XP_UI_TEST_FAIL] 无法写入结果文件：%\n" XP_UI_TEST_ResultPath

    try (destroyDialog testedRollout) catch ()

    -- 在真正退出前再次验证进程级令牌，避免函数被现有会话手动调用。
    if XP_UI_TEST_IsOwnedInstance() then
        quitMAX #noPrompt
    else
        format "[XP_UI_TEST_SKIP] 退出前所有权复核失败；不会退出 3ds Max。\n"
)

if XP_UI_TEST_IsOwnedInstance() then
(
    XP_UI_TEST_RunOwnedInstance()
)
else
(
    format "[XP_UI_TEST_SKIP] 缺少独立测试实例所有权令牌；未加载插件，也不会退出 3ds Max。\n"
    XP_UI_TEST_WriteSkipDiagnostic()
)
