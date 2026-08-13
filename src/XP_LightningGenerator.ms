/*
    XP闪电面片生成器 V1.2.0
    目标版本：Autodesk 3ds Max 2023 中文版
    编码：UTF-8

    功能：
    - 一个起点到多个终点
    - 确定性分形噪波与独立端点锁定
    - 真正的 Editable Poly 四边面带状模型
    - 贴图通道 1，沿实际弧长从 U=0 展开到 U=1
    - 输出对象局部原点固定在起点中心
    - 参数变化后实时重建
    - 可调分段与角度的整段轴向扭转（Twist）
    - 可选的面片两端平滑收尖，保持有效四边面与原 UV
*/

global XP_LG_StartNode
global XP_LG_EndNodes
global XP_LG_OutputNode
global XP_LG_OutputNodes
global XP_LG_Rollout
global XP_LG_SuppressUI
global XP_LG_LastError
global XP_LG_LiveUpdateBusy
global XP_LG_LiveUpdatePending
global XP_LG_LiveUpdatePendingReason
global XP_LG_LiveUpdatePendingShowErrors
global XP_LG_LiveUpdateTimerError
global XP_LG_LiveUpdateRequestTime
global XP_LG_LiveUpdateTimerLoopActive
global XP_LG_SuppressLiveUpdate
global XP_LG_LiveUpdateAttemptCount
global XP_LG_LiveUpdateSuccessCount
global XP_LG_LiveUpdateCurrentDepth
global XP_LG_LiveUpdateMaxDepth
global XP_LG_LiveUpdateTargetNode
global XP_LG_SelectionSyncBusy
global XP_LG_HandleSelectionChanged
global XP_LG_WaypointNodes
global XP_LG_WaypointOwnerNode
global XP_LG_LastFailedControlSyncNode
global XP_LG_LastFailedControlSyncSignature

if XP_LG_EndNodes == undefined do XP_LG_EndNodes = #()
if XP_LG_OutputNodes == undefined do XP_LG_OutputNodes = #()
if XP_LG_LastError == undefined do XP_LG_LastError = ""
XP_LG_LiveUpdateBusy = false
XP_LG_LiveUpdatePending = false
XP_LG_LiveUpdatePendingReason = ""
XP_LG_LiveUpdatePendingShowErrors = false
XP_LG_LiveUpdateTimerError = ""
XP_LG_LiveUpdateRequestTime = 0
XP_LG_LiveUpdateTimerLoopActive = false
XP_LG_SuppressLiveUpdate = false
XP_LG_LiveUpdateAttemptCount = 0
XP_LG_LiveUpdateSuccessCount = 0
XP_LG_LiveUpdateCurrentDepth = 0
XP_LG_LiveUpdateTargetNode = undefined
XP_LG_SelectionSyncBusy = false
XP_LG_LiveUpdateMaxDepth = 0
XP_LG_WaypointNodes = #()
XP_LG_WaypointOwnerNode = undefined
XP_LG_LastFailedControlSyncNode = undefined
XP_LG_LastFailedControlSyncSignature = ""

fn XP_LG_SetError message =
(
    XP_LG_LastError = message
    undefined
)

fn XP_LG_Clamp value minValue maxValue =
(
    if value < minValue then minValue else if value > maxValue then maxValue else value
)

fn XP_LG_SmootherStep01 value =
(
    local x = XP_LG_Clamp value 0.0 1.0
    x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
)

fn XP_LG_GetWorldCenter sceneNode =
(
    local worldCenter = [0.0, 0.0, 0.0]
    in coordsys world worldCenter = sceneNode.center
    worldCenter
)

fn XP_LG_IsManagedOutput sceneNode =
(
    if not isValidNode sceneNode do return false

    local generatorMarker = undefined
    try (generatorMarker = getUserProp sceneNode "XP_LightningGenerator") catch (generatorMarker = undefined)
    generatorMarker == "1.0.0" or generatorMarker == "1.1.0" or generatorMarker == "1.2.0"
)

fn XP_LG_PickFilter sceneNode =
(
    isValidNode sceneNode and not (XP_LG_IsManagedOutput sceneNode)
)

fn XP_LG_IsActiveOutput sceneNode =
(
    if not (XP_LG_IsManagedOutput sceneNode) do return false
    local activeMarker = undefined
    try (activeMarker = getUserProp sceneNode "XP_LightningActiveSet") catch (activeMarker = undefined)
    activeMarker == true or activeMarker == "true"
)

fn XP_LG_GetSelectedManagedOutput =
(
    local selectedOutput = undefined
    local selectedOutputCount = 0
    for sceneNode in selection do if XP_LG_IsManagedOutput sceneNode do
    (
        selectedOutput = sceneNode
        selectedOutputCount = selectedOutputCount + 1
    )
    if selectedOutputCount == 1 then selectedOutput else undefined
)

fn XP_LG_FindNodeByStoredHandle outputNode propertyName =
(
    if not isValidNode outputNode do return undefined
    local storedHandle = undefined
    try (storedHandle = getUserProp outputNode propertyName) catch (storedHandle = undefined)
    if storedHandle == undefined do return undefined
    local handleText = storedHandle as string
    for sceneNode in objects do if isValidNode sceneNode and ((getHandleByAnim sceneNode) as string) == handleText do return sceneNode
    undefined
)

fn XP_LG_FindNodeByHandleText handleText =
(
    if handleText == undefined or handleText == "" do return undefined
    for sceneNode in objects do if isValidNode sceneNode and ((getHandleByAnim sceneNode) as string) == handleText do return sceneNode
    undefined
)

fn XP_LG_SerializeWaypointHandles waypointNodes =
(
    if waypointNodes == undefined or waypointNodes.count == 0 do return ""
    local handleText = ""
    for waypointIndex = 1 to waypointNodes.count do
    (
        if not isValidNode waypointNodes[waypointIndex] do return undefined
        if waypointIndex > 1 do handleText = handleText + "|"
        handleText = handleText + ((getHandleByAnim waypointNodes[waypointIndex]) as string)
    )
    handleText
)

fn XP_LG_GetWaypointNodesFromOutput outputNode =
(
    if not isValidNode outputNode do return undefined
    local storedHandles = undefined
    try (storedHandles = getUserProp outputNode "XP_LightningWaypointHandles") catch (storedHandles = undefined)
    if storedHandles == undefined or (storedHandles as string) == "" do return #()

    local waypointNodes = #()
    local handleParts = filterString (storedHandles as string) "|"
    for handlePart in handleParts do
    (
        local waypointNode = XP_LG_FindNodeByHandleText handlePart
        if not isValidNode waypointNode do
        (
            XP_LG_SetError "所选面片保存的途经点对象已被删除或失效；原模型未被修改。"
            return undefined
        )
        append waypointNodes waypointNode
    )
    waypointNodes
)

fn XP_LG_GetWaypointNames waypointNodes =
(
    if waypointNodes == undefined do return #()
    for waypointNode in waypointNodes collect (if isValidNode waypointNode then waypointNode.name else "<已失效>")
)

fn XP_LG_GetControlPointSignature sceneNode =
(
    if not isValidNode sceneNode do return undefined
    local worldCenter = XP_LG_GetWorldCenter sceneNode
    ((getHandleByAnim sceneNode) as string) + "@" + (worldCenter.x as string) + "," + (worldCenter.y as string) + "," + (worldCenter.z as string)
)

fn XP_LG_BuildControlSnapshotSignature startNode waypointNodes endNode =
(
    if not isValidNode startNode or not isValidNode endNode or waypointNodes == undefined do return undefined
    local snapshotText = XP_LG_GetControlPointSignature startNode
    if snapshotText == undefined do return undefined
    for waypointNode in waypointNodes do
    (
        local waypointSignature = XP_LG_GetControlPointSignature waypointNode
        if waypointSignature == undefined do return undefined
        snapshotText = snapshotText + "|" + waypointSignature
    )
    local endSignature = XP_LG_GetControlPointSignature endNode
    if endSignature == undefined do return undefined
    snapshotText + "|" + endSignature
)

fn XP_LG_GetStoredControlSnapshotSignature outputNode =
(
    if not isValidNode outputNode do return ""
    local storedSnapshot = undefined
    try (storedSnapshot = getUserProp outputNode "XP_LightningControlSnapshot") catch (storedSnapshot = undefined)
    if storedSnapshot == undefined then "" else storedSnapshot as string
)

fn XP_LG_SetOutputSetActive outputNodes isActive =
(
    if outputNodes == undefined do return false
    for outputNode in outputNodes do if isValidNode outputNode do setUserProp outputNode "XP_LightningActiveSet" (isActive as string)
    true
)

fn XP_LG_ResolveOutputs startNode =
(
    local currentOutputs = #()
    if XP_LG_OutputNodes != undefined do
    (
        for sceneNode in XP_LG_OutputNodes do
        (
            if isValidNode sceneNode and XP_LG_IsManagedOutput sceneNode and (findItem currentOutputs sceneNode) == 0 do append currentOutputs sceneNode
        )
    )
    if isValidNode XP_LG_OutputNode and XP_LG_IsManagedOutput XP_LG_OutputNode and (findItem currentOutputs XP_LG_OutputNode) == 0 do append currentOutputs XP_LG_OutputNode
    if currentOutputs.count > 0 do
    (
        XP_LG_OutputNodes = currentOutputs
        XP_LG_OutputNode = currentOutputs[1]
        return currentOutputs
    )

    local allManaged = #()
    local activeManaged = #()
    local legacyMatchingStart = #()
    local activeMatchingStart = #()
    local startHandleText = if isValidNode startNode then (getHandleByAnim startNode) as string else undefined

    for sceneNode in objects do
    (
        if XP_LG_IsManagedOutput sceneNode do
        (
            append allManaged sceneNode
            if XP_LG_IsActiveOutput sceneNode do append activeManaged sceneNode
            if startHandleText != undefined do
            (
                local storedStartHandle = undefined
                local activeMarker = undefined
                try (storedStartHandle = getUserProp sceneNode "XP_LightningStartHandle") catch (storedStartHandle = undefined)
                try (activeMarker = getUserProp sceneNode "XP_LightningActiveSet") catch (activeMarker = undefined)
                if storedStartHandle == startHandleText do
                (
                    if XP_LG_IsActiveOutput sceneNode do append activeMatchingStart sceneNode
                    if activeMarker == undefined do append legacyMatchingStart sceneNode
                )
            )
        )
    )

    local resolvedNodes = if activeMatchingStart.count > 0 then activeMatchingStart else if legacyMatchingStart.count > 0 then legacyMatchingStart else if activeManaged.count > 0 then activeManaged else #()
    XP_LG_OutputNodes = resolvedNodes
    XP_LG_OutputNode = if resolvedNodes.count > 0 then resolvedNodes[1] else undefined
    resolvedNodes
)

fn XP_LG_ResolveOutput startNode =
(
    local resolvedNodes = XP_LG_ResolveOutputs startNode
    if resolvedNodes.count > 0 then resolvedNodes[1] else undefined
)

fn XP_LG_DeleteOutput =
(
    local outputsToDelete = XP_LG_ResolveOutputs XP_LG_StartNode
    for outputToDelete in outputsToDelete do if isValidNode outputToDelete do delete outputToDelete
    XP_LG_OutputNodes = #()
    XP_LG_OutputNode = undefined
    true
)

fn XP_LG_CleanEndNodes =
(
    local cleanedNodes = #()

    for sceneNode in XP_LG_EndNodes do
    (
        if isValidNode sceneNode and sceneNode != XP_LG_StartNode and not (XP_LG_IsManagedOutput sceneNode) do
        (
            if (findItem cleanedNodes sceneNode) == 0 do append cleanedNodes sceneNode
        )
    )

    XP_LG_EndNodes = cleanedNodes
    cleanedNodes
)

fn XP_LG_GetEndNodeNames =
(
    local names = #()
    XP_LG_CleanEndNodes()

    for sceneNode in XP_LG_EndNodes do append names sceneNode.name
    names
)

fn XP_LG_HashSigned lattice seedValue branchKey axisKey =
(
    local angle = (lattice as float) * 127.1 + (seedValue as float) * 0.013 + (branchKey as float) * 0.00173 + (axisKey as float) * 74.7
    local rawValue = (sin angle) * 43758.5453
    local fraction = rawValue - floor rawValue
    fraction * 2.0 - 1.0
)

fn XP_LG_ValueNoise x seedValue branchKey axisKey =
(
    local x0 = floor x
    local x1 = x0 + 1.0
    local fraction = x - x0
    local blend = XP_LG_SmootherStep01 fraction
    local value0 = XP_LG_HashSigned x0 seedValue branchKey axisKey
    local value1 = XP_LG_HashSigned x1 seedValue branchKey axisKey
    value0 + (value1 - value0) * blend
)

fn XP_LG_FractalNoise x seedValue branchKey axisKey =
(
    local octave1 = XP_LG_ValueNoise x seedValue branchKey axisKey
    local octave2 = XP_LG_ValueNoise (x * 2.03 + 17.13) seedValue branchKey (axisKey + 11)
    local octave3 = XP_LG_ValueNoise (x * 4.09 + 41.71) seedValue branchKey (axisKey + 23)
    local octave4 = XP_LG_ValueNoise (x * 8.17 + 89.27) seedValue branchKey (axisKey + 47)
    (octave1 + octave2 * 0.5 + octave3 * 0.25 + octave4 * 0.125) / 1.875
)

fn XP_LG_StablePerpendicular direction =
(
    local normalizedDirection = normalize direction
    local referenceAxis = if (abs (dot normalizedDirection [0.0, 0.0, 1.0])) < 0.85 then [0.0, 0.0, 1.0] else [0.0, 1.0, 0.0]
    local side = cross normalizedDirection referenceAxis

    if (length side) < 0.000001 do side = cross normalizedDirection [1.0, 0.0, 0.0]
    normalize side
)

fn XP_LG_GetBranchKey endNode fallbackIndex =
(
    local branchKey = fallbackIndex as float
    try
    (
        branchKey = (getHandleByAnim endNode) as float
    )
    catch
    (
        branchKey = fallbackIndex as float
    )
    branchKey
)

fn XP_LG_EndpointEnvelope t lockStart lockEnd =
(
    local envelope = 1.0
    local fadeSpan = 0.2

    if lockStart do envelope = envelope * XP_LG_SmootherStep01 (t / fadeSpan)
    if lockEnd do envelope = envelope * XP_LG_SmootherStep01 ((1.0 - t) / fadeSpan)
    envelope
)

fn XP_LG_EndpointTaperScale t taperEnds =
(
    if not taperEnds do return 1.0

    local minimumScale = 0.01
    local fadeSpan = 0.2
    local startScale = XP_LG_SmootherStep01 (t / fadeSpan)
    local endScale = XP_LG_SmootherStep01 ((1.0 - t) / fadeSpan)
    local transitionScale = if startScale < endScale then startScale else endScale
    minimumScale + (1.0 - minimumScale) * transitionScale
)

fn XP_LG_BuildWidthScales pointCount taperEnds sampleParameters:undefined =
(
    if pointCount < 2 do return undefined
    local widthScales = #()
    for pointIndex = 1 to pointCount do
    (
        local t = if sampleParameters == undefined then ((pointIndex - 1) as float) / ((pointCount - 1) as float) else sampleParameters[pointIndex]
        append widthScales (XP_LG_EndpointTaperScale t taperEnds)
    )
    widthScales
)

fn XP_LG_BuildCurvatureWidthScales points halfWidth safetyRatio:0.65 minimumScale:0.05 =
(
    if points == undefined or points.count < 2 or halfWidth <= 0.000001 do return undefined
    local widthScales = for pointIndex = 1 to points.count collect 1.0

    for pointIndex = 2 to (points.count - 1) do
    (
        local incoming = points[pointIndex] - points[pointIndex - 1]
        local outgoing = points[pointIndex + 1] - points[pointIndex]
        local incomingLength = length incoming
        local outgoingLength = length outgoing
        if incomingLength > 0.000001 and outgoingLength > 0.000001 do
        (
            local turnAngle = acos (XP_LG_Clamp (dot (normalize incoming) (normalize outgoing)) -1.0 1.0)
            if turnAngle > 0.001 do
            (
                local crossLength = length (cross incoming outgoing)
                if crossLength > 0.000001 do
                (
                    local oppositeLength = distance points[pointIndex - 1] points[pointIndex + 1]
                    local localRadius = (incomingLength * outgoingLength * oppositeLength) / (2.0 * crossLength)
                    local safeScale = (localRadius * safetyRatio) / halfWidth
                    widthScales[pointIndex] = XP_LG_Clamp safeScale minimumScale 1.0
                )
            )
        )
    )

    -- 限制相邻截面的宽度恢复速度，把急弯处的缩窄平滑传播到周围线环。
    local maximumScaleStep = 0.12
    for passIndex = 1 to 3 do
    (
        for pointIndex = 2 to points.count do
        (
            local allowedScale = widthScales[pointIndex - 1] + maximumScaleStep
            if widthScales[pointIndex] > allowedScale do widthScales[pointIndex] = allowedScale
        )
        for pointIndex = (points.count - 1) to 1 by -1 do
        (
            local allowedScale = widthScales[pointIndex + 1] + maximumScaleStep
            if widthScales[pointIndex] > allowedScale do widthScales[pointIndex] = allowedScale
        )
    )
    widthScales
)

fn XP_LG_BuildRouteCurvatureWidthScales points halfWidth preserveWaypointWidth =
(
    if points == undefined or points.count < 2 do return undefined
    if preserveWaypointWidth then
        (for pointIndex = 1 to points.count collect 1.0)
    else
        (XP_LG_BuildCurvatureWidthScales points halfWidth)
)

fn XP_LG_CombineWidthScales taperScales curvatureScales =
(
    if taperScales == undefined or curvatureScales == undefined or taperScales.count != curvatureScales.count do return undefined
    local combinedScales = #()
    for pointIndex = 1 to taperScales.count do append combinedScales (if taperScales[pointIndex] < curvatureScales[pointIndex] then taperScales[pointIndex] else curvatureScales[pointIndex])
    combinedScales
)

fn XP_LG_GetPathTangent points pointIndex sampleParameters:undefined =
(
    if points == undefined or points.count < 2 do return undefined
    if pointIndex < 1 or pointIndex > points.count do return undefined

    local tangent = [0.0, 0.0, 0.0]
    if pointIndex == 1 then
        tangent = points[2] - points[1]
    else if pointIndex == points.count then
        tangent = points[points.count] - points[points.count - 1]
    else
    (
        -- 截面跟随最终折线，而不是跟随不均匀参数速度。两侧先单位化再公平分角，
        -- 避免双途经点局部加密时较长一侧把切线拉偏并触发截面翻转。
        local incoming = points[pointIndex] - points[pointIndex - 1]
        local outgoing = points[pointIndex + 1] - points[pointIndex]
        if (length incoming) > 0.000001 and (length outgoing) > 0.000001 do tangent = normalize incoming + normalize outgoing
        if (length tangent) <= 0.000001 do
        (
            if (length outgoing) > 0.000001 then tangent = outgoing else tangent = incoming
            if (length tangent) <= 0.000001 do tangent = points[pointIndex + 1] - points[pointIndex - 1]
        )
    )

    if (length tangent) <= 0.000001 do return undefined
    normalize tangent
)

fn XP_LG_SegmentedTwistProgress t wholeTwistSegments =
(
    if t <= 0.0 do return 0.0
    local segmentCount = if wholeTwistSegments < 1 then 1 else wholeTwistSegments
    if t >= 1.0 do return segmentCount as float

    -- K 个有效扭转段把逻辑长度等分为 K+1 份；最后一份专用于终点保持／回正。
    local scaledT = t * ((segmentCount + 1) as float)
    local segmentIndex = floor scaledT
    if segmentIndex >= segmentCount do return segmentCount as float
    local fraction = scaledT - segmentIndex
    (segmentIndex as float) + fraction
)

fn XP_LG_WrapAngle180 angleValue =
(
    local wrappedAngle = mod (angleValue + 180.0) 360.0
    if wrappedAngle < 0.0 do wrappedAngle = wrappedAngle + 360.0
    wrappedAngle - 180.0
)

fn XP_LG_ShortestAngleDelta angleA angleB =
(
    XP_LG_WrapAngle180 (angleB - angleA)
)

fn XP_LG_ComputeAxialTwistAngle t wholeTwistSegments wholeTwistAmount lockStart lockEnd =
(
    if (abs wholeTwistAmount) <= 0.000001 do return 0.0

    local segmentCount = if wholeTwistSegments < 1 then 1 else wholeTwistSegments
    local startAngle = if lockStart then 0.0 else (-0.5 * wholeTwistAmount)
    local accumulatedAngle = startAngle + (segmentCount as float) * wholeTwistAmount

    if t <= 0.0 do return startAngle
    if t >= 1.0 do
    (
        if lockEnd then return 0.0 else return accumulatedAngle
    )

    local intervalCount = segmentCount + 1
    local scaledT = t * (intervalCount as float)
    local intervalIndex = floor scaledT
    local intervalFraction = scaledT - intervalIndex

    if intervalIndex < segmentCount then
    (
        startAngle + ((intervalIndex as float) + intervalFraction) * wholeTwistAmount
    )
    else if lockEnd then
    (
        -- 只回正累计角的最短 360° 等价余量，避免末段倒转多个整圈。
        local shortestRemainder = XP_LG_WrapAngle180 accumulatedAngle
        local equivalentStraightAngle = accumulatedAngle - shortestRemainder
        accumulatedAngle + (equivalentStraightAngle - accumulatedAngle) * intervalFraction
    )
    else
        accumulatedAngle
)

fn XP_LG_RotateVectorAroundAxis value axis angleValue =
(
    local normalizedAxis = normalize axis
    local cosineValue = cos angleValue
    local sineValue = sin angleValue
    value * cosineValue + (cross normalizedAxis value) * sineValue + normalizedAxis * (dot normalizedAxis value) * (1.0 - cosineValue)
)

fn XP_LG_BuildCenterline startWorld endWorld segmentCount twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd =
(
    local baseVector = endWorld - startWorld
    local branchLength = length baseVector

    if branchLength <= 0.000001 do return XP_LG_SetError "起点与终点中心重合，无法生成有效闪电。"

    local baseDirection = normalize baseVector
    local axisA = XP_LG_StablePerpendicular baseDirection
    local axisB = normalize (cross baseDirection axisA)
    -- “噪波大小”是整体尺寸倍率：同时放大位移，并让弯折更宽缓。
    -- “噪波 Tiling”独立控制沿每条分支的弯折密度。
    local cycles = tiling / noiseSize
    local noiseAmplitude = twistStrength * noiseSize
    local points = #()

    if cycles < 0.000001 do cycles = 0.000001

    for sampleIndex = 0 to segmentCount do
    (
        local t = (sampleIndex as float) / (segmentCount as float)
        local noiseCoordinate = t * cycles
        local noiseA = XP_LG_FractalNoise noiseCoordinate seedValue branchKey 1
        local noiseB = XP_LG_FractalNoise (noiseCoordinate + 103.19) seedValue branchKey 2
        local envelope = XP_LG_EndpointEnvelope t lockStart lockEnd
        local noiseOffset = (axisA * noiseA + axisB * noiseB) * noiseAmplitude
        local point = startWorld + baseVector * t + noiseOffset * envelope

        if sampleIndex == 0 and lockStart do point = startWorld
        if sampleIndex == segmentCount and lockEnd do point = endWorld
        append points point
    )

    points
)

fn XP_LG_EvaluateCenterlinePoint startWorld endWorld t twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd =
(
    local baseVector = endWorld - startWorld
    if (length baseVector) <= 0.000001 do return undefined
    local baseDirection = normalize baseVector
    local axisA = XP_LG_StablePerpendicular baseDirection
    local axisB = normalize (cross baseDirection axisA)
    local cycles = tiling / noiseSize
    if cycles < 0.000001 do cycles = 0.000001
    local noiseCoordinate = t * cycles
    local noiseA = XP_LG_FractalNoise noiseCoordinate seedValue branchKey 1
    local noiseB = XP_LG_FractalNoise (noiseCoordinate + 103.19) seedValue branchKey 2
    local envelope = XP_LG_EndpointEnvelope t lockStart lockEnd
    local point = startWorld + baseVector * t + (axisA * noiseA + axisB * noiseB) * (twistStrength * noiseSize) * envelope
    if t <= 0.0000001 and lockStart do point = startWorld
    if t >= 0.9999999 and lockEnd do point = endWorld
    point
)

fn XP_LG_BuildAdaptiveCenterline startWorld endWorld segmentCount twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 =
(
    if segmentCount < 1 do return undefined
    if segmentCount == 1 do return #(#(XP_LG_EvaluateCenterlinePoint startWorld endWorld 0.0 twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd, XP_LG_EvaluateCenterlinePoint startWorld endWorld 1.0 twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd), #(0.0, 1.0))

    local denseSegmentCount = if (segmentCount * 4) > 64 then (segmentCount * 4) else 64
    if denseSegmentCount > 4000 do denseSegmentCount = 4000
    local densePoints = #()
    local denseParameters = #()
    local denseWeights = #()
    local cumulativeWeights = #(0.0)
    local totalWeight = 0.0

    for sampleIndex = 0 to denseSegmentCount do
    (
        local t = (sampleIndex as float) / (denseSegmentCount as float)
        append denseParameters t
        append densePoints (XP_LG_EvaluateCenterlinePoint startWorld endWorld t twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd)
    )

    for segmentIndex = 1 to denseSegmentCount do
    (
        local segmentLength = distance densePoints[segmentIndex] densePoints[segmentIndex + 1]
        local curvatureFactor = 0.0
        if segmentIndex > 1 and segmentIndex < denseSegmentCount do
        (
            local incoming = densePoints[segmentIndex] - densePoints[segmentIndex - 1]
            local outgoing = densePoints[segmentIndex + 1] - densePoints[segmentIndex]
            if (length incoming) > 0.000001 and (length outgoing) > 0.000001 do curvatureFactor = (acos (XP_LG_Clamp (dot (normalize incoming) (normalize outgoing)) -1.0 1.0)) / 30.0
        )

        local twistFactor = 0.0
        if wholeTwistEnabled and (abs wholeTwistAmount) > 0.000001 do
        (
            local angle0 = XP_LG_ComputeAxialTwistAngle denseParameters[segmentIndex] wholeTwistSegments wholeTwistAmount lockStart lockEnd
            local angle1 = XP_LG_ComputeAxialTwistAngle denseParameters[segmentIndex + 1] wholeTwistSegments wholeTwistAmount lockStart lockEnd
            local twistDelta = angle1 - angle0
            if lockEnd and denseParameters[segmentIndex + 1] >= 0.9999999 do twistDelta = XP_LG_ShortestAngleDelta angle0 angle1
            twistFactor = (abs twistDelta) / 15.0
        )

        local rawWeight = segmentLength * (1.0 + curvatureFactor * 4.0 + twistFactor * 2.0)
        local weight = if rawWeight > 0.000001 then rawWeight else 0.000001
        append denseWeights weight
        totalWeight = totalWeight + weight
        append cumulativeWeights totalWeight
    )

    if totalWeight <= 0.000001 do return undefined
    local points = #()
    local sampleValues = #()
    local denseIndex = 1
    for sampleIndex = 0 to segmentCount do
    (
        local targetWeight = totalWeight * ((sampleIndex as float) / (segmentCount as float))
        while denseIndex < denseSegmentCount and cumulativeWeights[denseIndex + 1] < targetWeight do denseIndex = denseIndex + 1
        local weight0 = cumulativeWeights[denseIndex]
        local weight1 = cumulativeWeights[denseIndex + 1]
        local fraction = if (weight1 - weight0) <= 0.000001 then 0.0 else (targetWeight - weight0) / (weight1 - weight0)
        local t = denseParameters[denseIndex] + (denseParameters[denseIndex + 1] - denseParameters[denseIndex]) * fraction
        if sampleIndex == 0 do t = 0.0
        if sampleIndex == segmentCount do t = 1.0
        append sampleValues t
        append points (XP_LG_EvaluateCenterlinePoint startWorld endWorld t twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd)
    )
    #(points, sampleValues)
)

fn XP_LG_AllocateWaypointFaceCounts routePoints segmentCount =
(
    local spanCount = routePoints.count - 1
    if spanCount < 1 or segmentCount < spanCount do return undefined

    local spanLengths = #()
    local allocations = #()
    local fractions = #()
    local totalLength = 0.0
    for spanIndex = 1 to spanCount do
    (
        local spanLength = distance routePoints[spanIndex] routePoints[spanIndex + 1]
        if spanLength <= 0.000001 do return undefined
        append spanLengths spanLength
        totalLength = totalLength + spanLength
        append allocations 1
        append fractions 0.0
    )

    local remainingFaces = segmentCount - spanCount
    local assignedExtra = 0
    for spanIndex = 1 to spanCount do
    (
        local exactExtra = remainingFaces * spanLengths[spanIndex] / totalLength
        local wholeExtra = (floor exactExtra) as integer
        allocations[spanIndex] = allocations[spanIndex] + wholeExtra
        fractions[spanIndex] = exactExtra - wholeExtra
        assignedExtra = assignedExtra + wholeExtra
    )

    local leftover = remainingFaces - assignedExtra
    for extraIndex = 1 to leftover do
    (
        local bestIndex = 1
        local bestFraction = fractions[1]
        for spanIndex = 2 to spanCount do if fractions[spanIndex] > bestFraction do
        (
            bestIndex = spanIndex
            bestFraction = fractions[spanIndex]
        )
        allocations[bestIndex] = allocations[bestIndex] + 1
        fractions[bestIndex] = -1.0
    )
    allocations
)

fn XP_LG_AddWaypointTransitionFaces routePoints baseAllocations smoothingEnabled smoothingStrength autoAddFaces safetyMultiplier:1.0 =
(
    local allocations = for faceCount in baseAllocations collect faceCount
    local startExtras = for faceCount in baseAllocations collect 0
    local endExtras = for faceCount in baseAllocations collect 0
    local actualFaceCount = 0
    for faceCount in allocations do actualFaceCount = actualFaceCount + faceCount
    if not autoAddFaces or not smoothingEnabled or smoothingStrength <= 0.000001 or routePoints.count < 3 do return #(allocations, actualFaceCount, startExtras, endExtras)

    local strengthFactor = XP_LG_Clamp (smoothingStrength / 100.0) 0.0 1.0
    local maximumActualFaces = 4000
    for pointIndex = 2 to (routePoints.count - 1) do
    (
        if actualFaceCount < maximumActualFaces do
        (
            local incoming = routePoints[pointIndex] - routePoints[pointIndex - 1]
            local outgoing = routePoints[pointIndex + 1] - routePoints[pointIndex]
            if (length incoming) > 0.000001 and (length outgoing) > 0.000001 do
            (
                local turnAngle = acos (XP_LG_Clamp (dot (normalize incoming) (normalize outgoing)) -1.0 1.0)
                if turnAngle > 1.0 do
                (
                    local cornerFactor = sqrt (XP_LG_Clamp (turnAngle / 180.0) 0.0 1.0)
                    local resolvedSafetyMultiplier = if safetyMultiplier < 1.0 then 1.0 else safetyMultiplier
                    local requestedExtra = (ceil (strengthFactor * (4.0 + 12.0 * cornerFactor) * resolvedSafetyMultiplier)) as integer
                    local availableExtra = maximumActualFaces - actualFaceCount
                    local extraFaceCount = if requestedExtra < availableExtra then requestedExtra else availableExtra
                    local incomingExtra = (floor ((extraFaceCount + 1) / 2.0)) as integer
                    local outgoingExtra = extraFaceCount - incomingExtra
                    allocations[pointIndex - 1] = allocations[pointIndex - 1] + incomingExtra
                    allocations[pointIndex] = allocations[pointIndex] + outgoingExtra
                    endExtras[pointIndex - 1] = endExtras[pointIndex - 1] + incomingExtra
                    startExtras[pointIndex] = startExtras[pointIndex] + outgoingExtra
                    actualFaceCount = actualFaceCount + extraFaceCount
                )
            )
        )
    )
    #(allocations, actualFaceCount, startExtras, endExtras)
)

fn XP_LG_BuildWaypointSpanTargetWeights baseFaceCount startExtraCount endExtraCount smoothingStrength =
(
    if baseFaceCount < 1 or startExtraCount < 0 or endExtraCount < 0 do return undefined
    local targets = #()
    local strengthFactor = XP_LG_Clamp (smoothingStrength / 100.0) 0.0 1.0
    local transitionWindow = 0.18 + 0.22 * strengthFactor
    local startBaseCount = 0
    local endBaseCount = 0

    -- 窗口内的基础采样与新增采样一起重新均分，避免近零长度面和扇形挤压。
    for sampleIndex = 0 to baseFaceCount do
    (
        local targetValue = (sampleIndex as float) / (baseFaceCount as float)
        if sampleIndex == 0 or sampleIndex == baseFaceCount then
            append targets targetValue
        else if startExtraCount > 0 and targetValue <= transitionWindow then
            startBaseCount = startBaseCount + 1
        else if endExtraCount > 0 and targetValue >= (1.0 - transitionWindow) then
            endBaseCount = endBaseCount + 1
        else
            append targets targetValue
    )

    local startLocalCount = startBaseCount + startExtraCount
    local endLocalCount = endBaseCount + endExtraCount
    for localIndex = 1 to startLocalCount do append targets (transitionWindow * (localIndex as float) / ((startLocalCount + 1) as float))
    for localIndex = 1 to endLocalCount do append targets (1.0 - transitionWindow * (localIndex as float) / ((endLocalCount + 1) as float))
    sort targets
    targets
)

fn XP_LG_BuildRouteParameters routePoints =
(
    local cumulativeLengths = #(0.0)
    local totalLength = 0.0
    for pointIndex = 2 to routePoints.count do
    (
        totalLength = totalLength + distance routePoints[pointIndex - 1] routePoints[pointIndex]
        append cumulativeLengths totalLength
    )
    if totalLength <= 0.000001 do return undefined
    for pointIndex = 1 to cumulativeLengths.count do cumulativeLengths[pointIndex] = cumulativeLengths[pointIndex] / totalLength
    cumulativeLengths[cumulativeLengths.count] = 1.0
    cumulativeLengths
)

fn XP_LG_BuildWaypointRouteTangents routePoints routeParameters smoothingStrength =
(
    if routePoints == undefined or routeParameters == undefined or routePoints.count != routeParameters.count or routePoints.count < 2 do return undefined
    local strength = XP_LG_Clamp (smoothingStrength / 100.0) 0.0 1.0
    local tangents = #()
    for pointIndex = 1 to routePoints.count do
    (
        local tangent = [0.0, 0.0, 0.0]
        if pointIndex == 1 then
        (
            local parameterSpan = routeParameters[2] - routeParameters[1]
            if parameterSpan > 0.000001 do tangent = (routePoints[2] - routePoints[1]) / parameterSpan
        )
        else if pointIndex == routePoints.count then
        (
            local parameterSpan = routeParameters[pointIndex] - routeParameters[pointIndex - 1]
            if parameterSpan > 0.000001 do tangent = (routePoints[pointIndex] - routePoints[pointIndex - 1]) / parameterSpan
        )
        else
        (
            local incoming = routePoints[pointIndex] - routePoints[pointIndex - 1]
            local outgoing = routePoints[pointIndex + 1] - routePoints[pointIndex]
            local incomingLength = length incoming
            local outgoingLength = length outgoing
            local incomingParameterSpan = routeParameters[pointIndex] - routeParameters[pointIndex - 1]
            local outgoingParameterSpan = routeParameters[pointIndex + 1] - routeParameters[pointIndex]
            if incomingLength > 0.000001 and outgoingLength > 0.000001 and incomingParameterSpan > 0.000001 and outgoingParameterSpan > 0.000001 do
            (
                local incomingDirection = normalize incoming
                local outgoingDirection = normalize outgoing
                local directionSum = incomingDirection + outgoingDirection
                local directionDot = XP_LG_Clamp (dot incomingDirection outgoingDirection) -1.0 1.0
                if (length directionSum) > 0.000001 and directionDot > -0.999999 do
                (
                    -- 100% 平滑使用相邻短段允许的完整导数长度，扩大途经点圆角半径；
                    -- 强度仍在函数末尾线性缩放，短段与接近掉头继续由段长和 angleFactor 限制。
                    local incomingDerivativeLimit = incomingLength / incomingParameterSpan
                    local outgoingDerivativeLimit = outgoingLength / outgoingParameterSpan
                    local derivativeLimit = if incomingDerivativeLimit < outgoingDerivativeLimit then incomingDerivativeLimit else outgoingDerivativeLimit
                    local angleFactor = sqrt (XP_LG_Clamp ((1.0 + directionDot) * 0.5) 0.0 1.0)
                    tangent = (normalize directionSum) * derivativeLimit * angleFactor
                )
            )
        )
        append tangents (tangent * strength)
    )
    tangents
)

fn XP_LG_EvaluateWaypointBasePoint routePoints routeParameters routeTangents spanIndex localT smoothingEnabled smoothingStrength =
(
    local spanStart = routePoints[spanIndex]
    local spanEnd = routePoints[spanIndex + 1]
    if not smoothingEnabled or smoothingStrength <= 0.000001 or routeTangents == undefined do return (spanStart + (spanEnd - spanStart) * localT)

    local parameterSpan = routeParameters[spanIndex + 1] - routeParameters[spanIndex]
    local t2 = localT * localT
    local t3 = t2 * localT
    local h00 = 2.0 * t3 - 3.0 * t2 + 1.0
    local h10 = t3 - 2.0 * t2 + localT
    local h01 = -2.0 * t3 + 3.0 * t2
    local h11 = t3 - t2
    spanStart * h00 + (routeTangents[spanIndex] * parameterSpan) * h10 + spanEnd * h01 + (routeTangents[spanIndex + 1] * parameterSpan) * h11
)

fn XP_LG_BuildWaypointNoiseAxes routePoints =
(
    if routePoints == undefined or routePoints.count < 2 do return undefined
    local routeDirection = routePoints[routePoints.count] - routePoints[1]
    if (length routeDirection) <= 0.000001 do
    (
        for pointIndex = 2 to routePoints.count do
        (
            if (length routeDirection) <= 0.000001 do routeDirection = routePoints[pointIndex] - routePoints[pointIndex - 1]
        )
    )
    if (length routeDirection) <= 0.000001 do return undefined
    routeDirection = normalize routeDirection
    local axisA = XP_LG_StablePerpendicular routeDirection
    local axisB = normalize (cross routeDirection axisA)
    #(axisA, axisB)
)

fn XP_LG_EvaluateWaypointRawNoiseOffset globalT noiseAxes twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd =
(
    if noiseAxes == undefined or noiseAxes.count != 2 do return [0.0, 0.0, 0.0]
    local cycles = tiling / noiseSize
    if cycles < 0.000001 do cycles = 0.000001
    local noiseCoordinate = globalT * cycles
    local noiseA = XP_LG_FractalNoise noiseCoordinate seedValue branchKey 1
    local noiseB = XP_LG_FractalNoise (noiseCoordinate + 103.19) seedValue branchKey 2
    local envelope = XP_LG_EndpointEnvelope globalT lockStart lockEnd
    (noiseAxes[1] * noiseA + noiseAxes[2] * noiseB) * (twistStrength * noiseSize) * envelope
)

fn XP_LG_BuildWaypointGuidePoints routePoints routeParameters noiseAxes twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd =
(
    if routePoints == undefined or routeParameters == undefined or noiseAxes == undefined do return undefined
    if routePoints.count != routeParameters.count or routePoints.count < 2 do return undefined
    local guidePoints = #()
    for pointIndex = 1 to routePoints.count do
    (
        local constrainPoint = (pointIndex > 1 and pointIndex < routePoints.count) or (pointIndex == 1 and lockStart) or (pointIndex == routePoints.count and lockEnd)
        local guidePoint = routePoints[pointIndex]
        if constrainPoint do
        (
            local noiseOffset = XP_LG_EvaluateWaypointRawNoiseOffset routeParameters[pointIndex] noiseAxes twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd
            guidePoint = guidePoint - noiseOffset
        )
        append guidePoints guidePoint
    )
    guidePoints
)

fn XP_LG_EvaluateWaypointSpanPoint guidePoints routeParameters spanIndex localT twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd routeTangents:undefined waypointSmoothingEnabled:false waypointSmoothingStrength:50.0 noiseAxes:undefined =
(
    local globalStartT = routeParameters[spanIndex]
    local globalEndT = routeParameters[spanIndex + 1]
    local globalT = globalStartT + (globalEndT - globalStartT) * localT
    local basePoint = XP_LG_EvaluateWaypointBasePoint guidePoints routeParameters routeTangents spanIndex localT waypointSmoothingEnabled waypointSmoothingStrength
    local resolvedNoiseAxes = if noiseAxes != undefined then noiseAxes else XP_LG_BuildWaypointNoiseAxes guidePoints
    local noiseOffset = XP_LG_EvaluateWaypointRawNoiseOffset globalT resolvedNoiseAxes twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd
    #(basePoint + noiseOffset, globalT)
)

fn XP_LG_BuildWaypointAdaptiveCenterline routePoints segmentCount twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 waypointSmoothingEnabled:false waypointSmoothingStrength:50.0 waypointAutoAddFaces:false =
(
    local baseAllocations = XP_LG_AllocateWaypointFaceCounts routePoints segmentCount
    local routeParameters = XP_LG_BuildRouteParameters routePoints
    if baseAllocations == undefined or routeParameters == undefined do return undefined
    -- 多途经点安全补面使用更高的局部密度预算，以恒宽线环表达连续转向；
    -- 单途经点和用户主动额外加面的既有密度保持不变。
    local waypointSafetyMultiplier = if routePoints.count > 3 and waypointSmoothingEnabled and waypointSmoothingStrength > 0.000001 then 4.0 else 1.0
    local allocationData = XP_LG_AddWaypointTransitionFaces routePoints baseAllocations waypointSmoothingEnabled waypointSmoothingStrength waypointAutoAddFaces safetyMultiplier:waypointSafetyMultiplier
    local allocations = allocationData[1]
    local actualSegmentCount = allocationData[2]
    local startExtras = allocationData[3]
    local endExtras = allocationData[4]
    local noiseAxes = XP_LG_BuildWaypointNoiseAxes routePoints
    if noiseAxes == undefined do return undefined
    local guidePoints = XP_LG_BuildWaypointGuidePoints routePoints routeParameters noiseAxes twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd
    local routeTangents = XP_LG_BuildWaypointRouteTangents guidePoints routeParameters waypointSmoothingStrength
    if guidePoints == undefined or routeTangents == undefined do return undefined
    local finalPoints = #()
    local finalParameters = #()
    local waypointStationIndices = #()
    for spanIndex = 1 to allocations.count do
    (
        local spanFaces = allocations[spanIndex]
        local targetWeights = XP_LG_BuildWaypointSpanTargetWeights baseAllocations[spanIndex] startExtras[spanIndex] endExtras[spanIndex] waypointSmoothingStrength
        if targetWeights == undefined or targetWeights.count != (spanFaces + 1) do return undefined
        local denseSegmentCount = if (spanFaces * 4) > 32 then (spanFaces * 4) else 32
        if denseSegmentCount > 4000 do denseSegmentCount = 4000
        local densePoints = #()
        local denseParameters = #()
        local cumulativeWeights = #(0.0)
        local totalWeight = 0.0

        for denseIndex = 0 to denseSegmentCount do
        (
            local localT = (denseIndex as float) / (denseSegmentCount as float)
            local evaluated = XP_LG_EvaluateWaypointSpanPoint guidePoints routeParameters spanIndex localT twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd routeTangents:routeTangents waypointSmoothingEnabled:waypointSmoothingEnabled waypointSmoothingStrength:waypointSmoothingStrength noiseAxes:noiseAxes
            append densePoints evaluated[1]
            append denseParameters evaluated[2]
        )

        for denseIndex = 1 to denseSegmentCount do
        (
            local segmentLength = distance densePoints[denseIndex] densePoints[denseIndex + 1]
            local curvatureFactor = 0.0
            if denseIndex > 1 and denseIndex < denseSegmentCount do
            (
                local incoming = densePoints[denseIndex] - densePoints[denseIndex - 1]
                local outgoing = densePoints[denseIndex + 1] - densePoints[denseIndex]
                if (length incoming) > 0.000001 and (length outgoing) > 0.000001 do curvatureFactor = (acos (XP_LG_Clamp (dot (normalize incoming) (normalize outgoing)) -1.0 1.0)) / 30.0
            )
            local twistFactor = 0.0
            if wholeTwistEnabled and (abs wholeTwistAmount) > 0.000001 do
            (
                local angle0 = XP_LG_ComputeAxialTwistAngle denseParameters[denseIndex] wholeTwistSegments wholeTwistAmount lockStart lockEnd
                local angle1 = XP_LG_ComputeAxialTwistAngle denseParameters[denseIndex + 1] wholeTwistSegments wholeTwistAmount lockStart lockEnd
                twistFactor = (abs (angle1 - angle0)) / 15.0
            )
            local rawWeight = segmentLength * (1.0 + curvatureFactor * 4.0 + twistFactor * 2.0)
            totalWeight = totalWeight + (if rawWeight > 0.000001 then rawWeight else 0.000001)
            append cumulativeWeights totalWeight
        )

        local searchIndex = 1
        for sampleIndex = 0 to spanFaces do
        (
            if spanIndex > 1 and sampleIndex == 0 then
            (
                -- 前一段已经加入同一个途经点截面。
            )
            else
            (
                local targetWeight = totalWeight * targetWeights[sampleIndex + 1]
                while searchIndex < denseSegmentCount and cumulativeWeights[searchIndex + 1] < targetWeight do searchIndex = searchIndex + 1
                local weight0 = cumulativeWeights[searchIndex]
                local weight1 = cumulativeWeights[searchIndex + 1]
                local fraction = if (weight1 - weight0) <= 0.000001 then 0.0 else (targetWeight - weight0) / (weight1 - weight0)
                local localT = (((searchIndex - 1) as float) + fraction) / (denseSegmentCount as float)
                if targetWeights[sampleIndex + 1] <= 0.0000001 do localT = 0.0
                if targetWeights[sampleIndex + 1] >= 0.9999999 do localT = 1.0
                local evaluated = XP_LG_EvaluateWaypointSpanPoint guidePoints routeParameters spanIndex localT twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd routeTangents:routeTangents waypointSmoothingEnabled:waypointSmoothingEnabled waypointSmoothingStrength:waypointSmoothingStrength noiseAxes:noiseAxes
                append finalPoints evaluated[1]
                append finalParameters evaluated[2]
            )
        )
        if spanIndex < allocations.count do append waypointStationIndices finalPoints.count
    )
    if finalPoints.count != (actualSegmentCount + 1) do return undefined
    #(finalPoints, finalParameters, actualSegmentCount, waypointStationIndices)
)

fn XP_LG_BuildParallelTransportSides points sampleParameters:undefined =
(
    local sides = #()
    local previousSide = [0.0, 0.0, 0.0]
    local previousTangent = [0.0, 0.0, 0.0]

    for pointIndex = 1 to points.count do
    (
        local tangent = XP_LG_GetPathTangent points pointIndex sampleParameters:sampleParameters
        if tangent == undefined do return undefined

        local side = [0.0, 0.0, 0.0]
        if pointIndex == 1 then
        (
            side = XP_LG_StablePerpendicular tangent
        )
        else
        (
            local tangentDot = XP_LG_Clamp (dot previousTangent tangent) -1.0 1.0
            local rotationAxis = cross previousTangent tangent
            local rotationAxisLength = length rotationAxis

            if rotationAxisLength > 0.000001 then
            (
                side = XP_LG_RotateVectorAroundAxis previousSide (rotationAxis / rotationAxisLength) (acos tangentDot)
            )
            else if tangentDot < -0.999999 then
            (
                side = XP_LG_RotateVectorAroundAxis previousSide (XP_LG_StablePerpendicular previousTangent) 180.0
            )
            else
            (
                side = previousSide
            )

            -- 浮点误差只做一次正交投影；主方向来自最小旋转平行运输。
            side = side - tangent * (dot side tangent)
            if (length side) <= 0.000001 then
                side = XP_LG_StablePerpendicular tangent
            else
                side = normalize side
        )

        append sides side
        previousSide = side
        previousTangent = tangent
    )

    sides
)

fn XP_LG_BuildRibbonSides points sampleParameters:undefined =
(
    XP_LG_BuildParallelTransportSides points sampleParameters:sampleParameters
)

fn XP_LG_BuildAxiallyTwistedSides points baseSides wholeTwistSegments wholeTwistAmount lockStart lockEnd sampleParameters:undefined =
(
    if points == undefined or baseSides == undefined do return undefined
    if points.count != baseSides.count or points.count < 2 do return undefined

    local twistedSides = #()
    for pointIndex = 1 to points.count do
    (
        local tangent = XP_LG_GetPathTangent points pointIndex sampleParameters:sampleParameters
        if tangent == undefined do return undefined

        local t = if sampleParameters == undefined then ((pointIndex - 1) as float) / ((points.count - 1) as float) else sampleParameters[pointIndex]
        local angleValue = XP_LG_ComputeAxialTwistAngle t wholeTwistSegments wholeTwistAmount lockStart lockEnd
        local rotatedSide = XP_LG_RotateVectorAroundAxis baseSides[pointIndex] tangent angleValue
        rotatedSide = rotatedSide - tangent * (dot rotatedSide tangent)
        if (length rotatedSide) <= 0.000001 do return undefined
        append twistedSides (normalize rotatedSide)
    )

    twistedSides
)

fn XP_LG_BuildFixedSides points baseDirection:undefined =
(
    local resolvedDirection = baseDirection
    if resolvedDirection == undefined then
        resolvedDirection = points[points.count] - points[1]
    else if (length resolvedDirection) <= 0.000001 do
        resolvedDirection = points[points.count] - points[1]
    resolvedDirection = normalize resolvedDirection

    local fixedSide = XP_LG_StablePerpendicular resolvedDirection
    local sides = #()

    for pointIndex = 1 to points.count do append sides fixedSide
    sides
)

fn XP_LG_IsRibbonValid points sides halfWidth widthScales:undefined =
(
    if points == undefined or sides == undefined do return false
    if points.count != sides.count or points.count < 2 do return false

    for segmentIndex = 1 to (points.count - 1) do
    (
        local scale0 = if widthScales == undefined then 1.0 else widthScales[segmentIndex]
        local scale1 = if widthScales == undefined then 1.0 else widthScales[segmentIndex + 1]
        local left0 = points[segmentIndex] - sides[segmentIndex] * halfWidth * scale0
        local right0 = points[segmentIndex] + sides[segmentIndex] * halfWidth * scale0
        local left1 = points[segmentIndex + 1] - sides[segmentIndex + 1] * halfWidth * scale1
        local right1 = points[segmentIndex + 1] + sides[segmentIndex + 1] * halfWidth * scale1
        local normal1 = cross (right0 - left0) (right1 - left0)
        local normal2 = cross (right1 - left0) (left1 - left0)

        if (length normal1) <= 0.0000001 or (length normal2) <= 0.0000001 do return false
        if (dot normal1 normal2) <= 0.0 do return false
    )

    true
)

fn XP_LG_IsTwistSamplingSafe pointCount wholeTwistSegments wholeTwistAmount lockStart lockEnd sampleParameters:undefined maxStepAngle:45.0 =
(
    if pointCount < 2 do return false

    local firstT = if sampleParameters == undefined then 0.0 else sampleParameters[1]
    local previousAngle = XP_LG_ComputeAxialTwistAngle firstT wholeTwistSegments wholeTwistAmount lockStart lockEnd
    for pointIndex = 2 to pointCount do
    (
        local t = if sampleParameters == undefined then ((pointIndex - 1) as float) / ((pointCount - 1) as float) else sampleParameters[pointIndex]
        local currentAngle = XP_LG_ComputeAxialTwistAngle t wholeTwistSegments wholeTwistAmount lockStart lockEnd
        local angleDelta = currentAngle - previousAngle
        if lockEnd and t >= 0.9999999 do angleDelta = XP_LG_ShortestAngleDelta previousAngle currentAngle
        if (abs angleDelta) > maxStepAngle do return false
        previousAngle = currentAngle
    )
    true
)

fn XP_LG_IsRibbonTwistSafe points sides halfWidth widthScales:undefined minimumNormalDot:0.70 =
(
    if not (XP_LG_IsRibbonValid points sides halfWidth widthScales:widthScales) do return false

    for segmentIndex = 1 to (points.count - 1) do
    (
        local scale0 = if widthScales == undefined then 1.0 else widthScales[segmentIndex]
        local scale1 = if widthScales == undefined then 1.0 else widthScales[segmentIndex + 1]
        local left0 = points[segmentIndex] - sides[segmentIndex] * halfWidth * scale0
        local right0 = points[segmentIndex] + sides[segmentIndex] * halfWidth * scale0
        local left1 = points[segmentIndex + 1] - sides[segmentIndex + 1] * halfWidth * scale1
        local right1 = points[segmentIndex + 1] + sides[segmentIndex + 1] * halfWidth * scale1
        local normal1 = cross (right0 - left0) (right1 - left0)
        local normal2 = cross (right1 - left0) (left1 - left0)
        local centerDelta = points[segmentIndex + 1] - points[segmentIndex]
        local leftDelta = left1 - left0
        local rightDelta = right1 - right0

        if (length normal1) <= 0.0000001 or (length normal2) <= 0.0000001 do return false
        if (dot leftDelta centerDelta) <= 0.0000001 or (dot rightDelta centerDelta) <= 0.0000001 do return false
        normal1 = normalize normal1
        normal2 = normalize normal2
        if (dot normal1 normal2) < minimumNormalDot do return false
    )
    true
)

fn XP_LG_BuildTwistSafeWidthScales points sides halfWidth sourceScales minimumNormalDot:0.70 minimumScale:0.01 protectedIndices:#() =
(
    if points == undefined or sides == undefined or sourceScales == undefined do return undefined
    if points.count != sides.count or points.count != sourceScales.count or points.count < 2 do return undefined

    local widthScales = for scaleValue in sourceScales collect scaleValue
    local maximumScaleStep = 0.12

    for passIndex = 1 to 28 do
    (
        if XP_LG_IsRibbonTwistSafe points sides halfWidth widthScales:widthScales minimumNormalDot:minimumNormalDot do return widthScales

        local changed = false
        for segmentIndex = 1 to (points.count - 1) do
        (
            local scale0 = widthScales[segmentIndex]
            local scale1 = widthScales[segmentIndex + 1]
            local left0 = points[segmentIndex] - sides[segmentIndex] * halfWidth * scale0
            local right0 = points[segmentIndex] + sides[segmentIndex] * halfWidth * scale0
            local left1 = points[segmentIndex + 1] - sides[segmentIndex + 1] * halfWidth * scale1
            local right1 = points[segmentIndex + 1] + sides[segmentIndex + 1] * halfWidth * scale1
            local normal1 = cross (right0 - left0) (right1 - left0)
            local normal2 = cross (right1 - left0) (left1 - left0)
            local centerDelta = points[segmentIndex + 1] - points[segmentIndex]
            local leftDelta = left1 - left0
            local rightDelta = right1 - right0
            local segmentIsSafe = true

            if (length normal1) <= 0.0000001 or (length normal2) <= 0.0000001 then
                segmentIsSafe = false
            else
            (
                normal1 = normalize normal1
                normal2 = normalize normal2
                if (dot leftDelta centerDelta) <= 0.0000001 or (dot rightDelta centerDelta) <= 0.0000001 or (dot normal1 normal2) < minimumNormalDot do segmentIsSafe = false
            )

            if not segmentIsSafe do
            (
                local reduced0 = if (scale0 * 0.82) > minimumScale then (scale0 * 0.82) else minimumScale
                local reduced1 = if (scale1 * 0.82) > minimumScale then (scale1 * 0.82) else minimumScale
                if (findItem protectedIndices segmentIndex) == 0 and reduced0 < widthScales[segmentIndex] do
                (
                    widthScales[segmentIndex] = reduced0
                    changed = true
                )
                if (findItem protectedIndices (segmentIndex + 1)) == 0 and reduced1 < widthScales[segmentIndex + 1] do
                (
                    widthScales[segmentIndex + 1] = reduced1
                    changed = true
                )
            )
        )

        if not changed do return undefined

        -- 将局部收窄平滑传播到相邻截面，避免新的宽度折线。
        for smoothPass = 1 to 2 do
        (
            for pointIndex = 2 to points.count do
            (
                local allowedScale = widthScales[pointIndex - 1] + maximumScaleStep
                if (findItem protectedIndices pointIndex) == 0 and widthScales[pointIndex] > allowedScale do widthScales[pointIndex] = allowedScale
            )
            for pointIndex = (points.count - 1) to 1 by -1 do
            (
                local allowedScale = widthScales[pointIndex + 1] + maximumScaleStep
                if (findItem protectedIndices pointIndex) == 0 and widthScales[pointIndex] > allowedScale do widthScales[pointIndex] = allowedScale
            )
        )
    )

    if XP_LG_IsRibbonTwistSafe points sides halfWidth widthScales:widthScales minimumNormalDot:minimumNormalDot then widthScales else undefined
)

fn XP_LG_BuildArcLengthU points =
(
    local cumulative = #(0.0)
    local totalLength = 0.0

    for pointIndex = 2 to points.count do
    (
        totalLength = totalLength + distance points[pointIndex - 1] points[pointIndex]
        append cumulative totalLength
    )

    if totalLength <= 0.000001 do return undefined
    for pointIndex = 1 to cumulative.count do cumulative[pointIndex] = cumulative[pointIndex] / totalLength
    cumulative[1] = 0.0
    cumulative[cumulative.count] = 1.0
    cumulative
)

fn XP_LG_ValidateInputs startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 waypointNodes:#() waypointSmoothingStrength:50.0 =
(
    XP_LG_LastError = ""

    if not isValidNode startNode do return XP_LG_SetError "请先拾取一个有效的起点对象。"
    if endNodes == undefined or endNodes.count == 0 do return XP_LG_SetError "请至少添加一个有效的终点对象。"
    if segmentCount < 1 do return XP_LG_SetError "平面面数必须大于或等于 1。"
    if ribbonWidth <= 0.000001 do return XP_LG_SetError "闪电宽度必须大于 0。"
    if twistStrength < 0.0 do return XP_LG_SetError "路径噪波强度不能小于 0。"
    if noiseSize <= 0.000001 do return XP_LG_SetError "噪波大小必须大于 0。"
    if tiling <= 0.0 do return XP_LG_SetError "噪波 Tiling 必须大于 0。"
    if wholeTwistSegments < 1 or (floor wholeTwistSegments) != wholeTwistSegments do return XP_LG_SetError "轴向扭转分段必须为大于或等于 1 的整数。"
    if waypointSmoothingStrength < 0.0 or waypointSmoothingStrength > 100.0 do return XP_LG_SetError "途经点过渡强度必须在 0 到 100 之间。"

    local startWorld = XP_LG_GetWorldCenter startNode
    local acceptedPositions = #()

    if waypointNodes == undefined do return XP_LG_SetError "途经点列表无效；原模型未被修改。"
    if waypointNodes.count > 0 and segmentCount < (waypointNodes.count + 1) do return XP_LG_SetError ("当前路径含 " + (waypointNodes.count as string) + " 个途经点，平面面数至少需要 " + ((waypointNodes.count + 1) as string) + "；原模型未被修改。")

    local previousControlNode = startNode
    local previousControlWorld = startWorld
    for waypointNode in waypointNodes do
    (
        if not isValidNode waypointNode do return XP_LG_SetError "途经点列表中存在已删除或无效的对象；原模型未被修改。"
        if XP_LG_IsManagedOutput waypointNode do return XP_LG_SetError "闪电面片不能作为途经点；原模型未被修改。"
        local waypointWorld = XP_LG_GetWorldCenter waypointNode
        if waypointNode == previousControlNode or (distance waypointWorld previousControlWorld) <= 0.000001 do return XP_LG_SetError ("途经点“" + waypointNode.name + "”与前一个控制点中心重合；原模型未被修改。")
        previousControlNode = waypointNode
        previousControlWorld = waypointWorld
    )

    for endNode in endNodes do
    (
        if not isValidNode endNode do return XP_LG_SetError "终点列表中存在已删除或无效的对象。"
        if endNode == startNode do return XP_LG_SetError "起点对象不能同时作为终点。"

        local endWorld = XP_LG_GetWorldCenter endNode
        if (distance startWorld endWorld) <= 0.000001 do return XP_LG_SetError ("终点“" + endNode.name + "”与起点中心重合。")
        if waypointNodes.count > 0 and (distance previousControlWorld endWorld) <= 0.000001 do return XP_LG_SetError ("终点“" + endNode.name + "”与最后一个途经点中心重合；原模型未被修改。")

        for existingPosition in acceptedPositions do
        (
            if (distance existingPosition endWorld) <= 0.000001 do return XP_LG_SetError ("终点“" + endNode.name + "”与另一个终点中心重合。")
        )
        append acceptedPositions endWorld
    )

    true
)

fn XP_LG_CreateLightningBranchNode startNode endNode branchIndex branchCount segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 taperEnds:false waypointNodes:#() waypointSmoothingEnabled:false waypointSmoothingStrength:50.0 waypointAutoAddFaces:false =
(
    local startWorld = XP_LG_GetWorldCenter startNode
    local endWorld = XP_LG_GetWorldCenter endNode
    local halfWidth = ribbonWidth * 0.5
    local branchKey = XP_LG_GetBranchKey endNode branchIndex
    local routePoints = #(startWorld)
    for waypointNode in waypointNodes do append routePoints (XP_LG_GetWorldCenter waypointNode)
    append routePoints endWorld
    -- 两个或更多途经点的中间段会同时承受两侧转向。为保持用户宽度，
    -- 这类路径始终启用局部安全补面；面板复选框仍控制单途经点／主动额外平滑加面。
    local waypointSafetyAutoFaces = waypointNodes.count > 1 and waypointSmoothingEnabled and waypointSmoothingStrength > 0.000001
    local effectiveWaypointAutoAddFaces = waypointAutoAddFaces or waypointSafetyAutoFaces
    local smoothingSafetyHint = if waypointNodes.count > 0 and waypointSmoothingEnabled and waypointSmoothingStrength > 0.000001 then "；可尝试增加平面面数、降低途经点过渡强度或调整控制点位置" else ""
    local adaptiveData = if waypointNodes.count > 0 then (XP_LG_BuildWaypointAdaptiveCenterline routePoints segmentCount twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd wholeTwistEnabled:wholeTwistEnabled wholeTwistSegments:wholeTwistSegments wholeTwistAmount:wholeTwistAmount waypointSmoothingEnabled:waypointSmoothingEnabled waypointSmoothingStrength:waypointSmoothingStrength waypointAutoAddFaces:effectiveWaypointAutoAddFaces) else (XP_LG_BuildAdaptiveCenterline startWorld endWorld segmentCount twistStrength noiseSize tiling seedValue branchKey lockStart lockEnd wholeTwistEnabled:wholeTwistEnabled wholeTwistSegments:wholeTwistSegments wholeTwistAmount:wholeTwistAmount)
    if adaptiveData == undefined do return XP_LG_SetError ("终点“" + endNode.name + "”的路径采样失败" + smoothingSafetyHint + "；原模型未被修改。")
    local points = adaptiveData[1]
    local sampleParameters = adaptiveData[2]
    local actualSegmentCount = points.count - 1
    local waypointStationIndices = if adaptiveData.count >= 4 then adaptiveData[4] else #()
    local taperScales = XP_LG_BuildWidthScales points.count taperEnds sampleParameters:sampleParameters
    -- 途经点只负责改变中心路径和局部采样，不允许曲率保护把路径站位压成 V 形尖口。
    -- 等宽结果若不安全，会由后续几何检查原子拒绝并保留旧模型。
    local curvatureScales = XP_LG_BuildRouteCurvatureWidthScales points halfWidth (waypointNodes.count > 0 and waypointSmoothingEnabled)
    local widthScales = XP_LG_CombineWidthScales taperScales curvatureScales
    if widthScales == undefined do return XP_LG_SetError ("终点“" + endNode.name + "”的收尖宽度数据无效；原模型未被修改。")

    local preserveWaypointWidth = waypointNodes.count > 0 and waypointSmoothingEnabled
    -- 途经点只负责中心线转向。从第一个途经点前的局部窗口到最后一个
    -- 途经点后的局部窗口全部保护现有宽度倍率；真实起终点区域仍保留其收尖／Twist 安全职责。
    local protectedWidthIndices = #()
    if preserveWaypointWidth and waypointStationIndices.count > 0 do
    (
        local protectionRadius = (ceil (points.count * 0.06)) as integer
        if protectionRadius < 4 do protectionRadius = 4
        local firstProtectedIndex = waypointStationIndices[1] - protectionRadius
        local lastProtectedIndex = waypointStationIndices[waypointStationIndices.count] + protectionRadius
        if firstProtectedIndex < 2 do firstProtectedIndex = 2
        if lastProtectedIndex > (points.count - 1) do lastProtectedIndex = points.count - 1
        for pointIndex = firstProtectedIndex to lastProtectedIndex do append protectedWidthIndices pointIndex
    )
    local baseSides = XP_LG_BuildRibbonSides points sampleParameters:sampleParameters
    local baseRibbonIsValid = XP_LG_IsRibbonValid points baseSides halfWidth widthScales:widthScales
    if not baseRibbonIsValid and not preserveWaypointWidth do
    (
        baseSides = XP_LG_BuildFixedSides points baseDirection:(endWorld - startWorld)
        baseRibbonIsValid = XP_LG_IsRibbonValid points baseSides halfWidth widthScales:widthScales
    )
    if not baseRibbonIsValid and not (wholeTwistEnabled and (abs wholeTwistAmount) > 0.000001) do return XP_LG_SetError ("终点“" + endNode.name + "”的路径参数产生了无效面片" + smoothingSafetyHint + "；原模型未被修改。")

    local sides = baseSides
    if wholeTwistEnabled and (abs wholeTwistAmount) > 0.000001 do
    (
        if not (XP_LG_IsTwistSamplingSafe points.count wholeTwistSegments wholeTwistAmount lockStart lockEnd sampleParameters:sampleParameters) do return XP_LG_SetError ("终点“" + endNode.name + "”的轴向扭转在当前面数下变化过快；请增加平面面数，或降低轴向扭转角度／分段。原模型未被修改。")
        sides = XP_LG_BuildAxiallyTwistedSides points baseSides wholeTwistSegments wholeTwistAmount lockStart lockEnd sampleParameters:sampleParameters
        widthScales = XP_LG_BuildTwistSafeWidthScales points sides halfWidth widthScales protectedIndices:protectedWidthIndices
        if widthScales == undefined do
        (
            local twistWidthError = if preserveWaypointWidth then "的面片无法在保持途经点截面宽度的前提下安全表达当前 Twist" else "的面片无法通过局部宽度优化安全表达当前 Twist"
            return XP_LG_SetError ("终点“" + endNode.name + "”" + twistWidthError + "；请增加平面面数，或降低轴向扭转角度、分段或闪电宽度。原模型未被修改。")
        )
        if not (XP_LG_IsRibbonTwistSafe points sides halfWidth widthScales:widthScales) do return XP_LG_SetError ("终点“" + endNode.name + "”的面片会发生明显折叠或非共面变形；请增加平面面数，或降低轴向扭转角度、分段、闪电宽度或路径噪波强度。原模型未被修改。")
    )
    if not (XP_LG_IsRibbonTwistSafe points sides halfWidth widthScales:widthScales) do return XP_LG_SetError ("终点“" + endNode.name + "”的急弯仍无法安全布线；请增加平面面数，或降低闪电宽度、路径噪波强度或噪波 Tiling" + smoothingSafetyHint + "；原模型未被修改。")

    local uValues = XP_LG_BuildArcLengthU points
    if uValues == undefined do return XP_LG_SetError ("终点“" + endNode.name + "”的路径长度无效；原模型未被修改。")

    local polyNode = undefined

    try
    (
        with redraw off
        (
            polyNode = mesh name:"XP_Lightning_Temp" numverts:0 numfaces:0
            convertToPoly polyNode
            polyNode.transform = transMatrix startWorld
            polyNode.isHidden = true

            local editablePoly = polyNode.baseObject
            local geometryFaceIds = #()
            local uvCoordinates = #()
            local uvFaceDefinitions = #()
            local rowVertexIds = #()

            for pointIndex = 1 to points.count do
            (
                local stationHalfWidth = halfWidth * widthScales[pointIndex]
                local leftWorld = points[pointIndex] - sides[pointIndex] * stationHalfWidth
                local rightWorld = points[pointIndex] + sides[pointIndex] * stationHalfWidth
                local leftId = polyop.createVert editablePoly (leftWorld - startWorld)
                local rightId = polyop.createVert editablePoly (rightWorld - startWorld)

                if leftId == undefined or rightId == undefined do
                (
                    XP_LG_LastError = "创建闪电顶点失败；原模型未被修改。"
                    delete polyNode
                    return undefined
                )

                append rowVertexIds #(leftId, rightId)
                append uvCoordinates [uValues[pointIndex], 0.0, 0.0]
                append uvCoordinates [uValues[pointIndex], 1.0, 0.0]
            )

            for segmentIndex = 1 to actualSegmentCount do
            (
                local row0 = rowVertexIds[segmentIndex]
                local row1 = rowVertexIds[segmentIndex + 1]
                local faceId = polyop.createPolygon editablePoly #(row0[1], row0[2], row1[2], row1[1])

                if faceId == undefined do
                (
                    XP_LG_LastError = "创建闪电四边面失败；请降低宽度或扭曲参数。原模型未被修改。"
                    delete polyNode
                    return undefined
                )

                append geometryFaceIds faceId
                local uvLeft0 = (segmentIndex - 1) * 2 + 1
                local uvRight0 = uvLeft0 + 1
                local uvLeft1 = uvLeft0 + 2
                local uvRight1 = uvLeft0 + 3
                append uvFaceDefinitions #(uvLeft0, uvRight0, uvRight1, uvLeft1)
            )

            polyop.setMapSupport editablePoly 1 false
            polyop.setMapSupport editablePoly 1 true
            polyop.setNumMapVerts editablePoly 1 uvCoordinates.count keep:false

            for uvIndex = 1 to uvCoordinates.count do polyop.setMapVert editablePoly 1 uvIndex uvCoordinates[uvIndex]

            if (polyop.getNumMapFaces editablePoly 1) != geometryFaceIds.count do
            (
                XP_LG_LastError = "UV 面数量与几何面数量不一致；原模型未被修改。"
                delete polyNode
                return undefined
            )

            for faceListIndex = 1 to geometryFaceIds.count do
            (
                polyop.setMapFace editablePoly 1 geometryFaceIds[faceListIndex] uvFaceDefinitions[faceListIndex]
            )

            local expectedFaceCount = actualSegmentCount
            local expectedVertexCount = 2 * (actualSegmentCount + 1)
            if (polyop.getNumFaces editablePoly) != expectedFaceCount or (polyop.getNumVerts editablePoly) != expectedVertexCount do
            (
                XP_LG_LastError = "生成后的顶点或四边面数量校验失败；原模型未被修改。"
                delete polyNode
                return undefined
            )

            if (polyop.getNumMapVerts editablePoly 1) != expectedVertexCount or (polyop.getNumMapFaces editablePoly 1) != expectedFaceCount do
            (
                XP_LG_LastError = "生成后的 UV 数量校验失败；原模型未被修改。"
                delete polyNode
                return undefined
            )

            for faceId in geometryFaceIds do
            (
                if (polyop.getFaceVerts editablePoly faceId).count != 4 or (polyop.getMapFace editablePoly 1 faceId).count != 4 do
                (
                    XP_LG_LastError = "生成结果中存在非四边面或错误的 UV 面；原模型未被修改。"
                    delete polyNode
                    return undefined
                )
            )

            update polyNode
            polyNode.wirecolor = color 120 190 255
            polyNode.backFaceCull = false
            setUserProp polyNode "XP_LightningGenerator" "1.2.0"
            setUserProp polyNode "XP_LightningStartHandle" ((getHandleByAnim startNode) as string)
            setUserProp polyNode "XP_LightningEndHandle" ((getHandleByAnim endNode) as string)
            setUserProp polyNode "XP_LightningBranchIndex" (branchIndex as string)
            setUserProp polyNode "XP_LightningBranchCount" (branchCount as string)
            setUserProp polyNode "XP_LightningFacesPerBranch" (segmentCount as string)
            setUserProp polyNode "XP_LightningActualFaces" (actualSegmentCount as string)
            setUserProp polyNode "XP_LightningRibbonWidth" (ribbonWidth as string)
            setUserProp polyNode "XP_LightningPathNoiseStrength" (twistStrength as string)
            setUserProp polyNode "XP_LightningNoiseSize" (noiseSize as string)
            setUserProp polyNode "XP_LightningTiling" (tiling as string)
            setUserProp polyNode "XP_LightningSeed" (seedValue as string)
            setUserProp polyNode "XP_LightningLockStart" (lockStart as string)
            setUserProp polyNode "XP_LightningLockEnd" (lockEnd as string)
            setUserProp polyNode "XP_LightningWholeTwistEnabled" (wholeTwistEnabled as string)
            setUserProp polyNode "XP_LightningWholeTwistSegments" (wholeTwistSegments as string)
            setUserProp polyNode "XP_LightningWholeTwistAmount" (wholeTwistAmount as string)
            setUserProp polyNode "XP_LightningTwistMode" "Axial"
            setUserProp polyNode "XP_LightningTwistMapping" "FFDEqualSegmentsParallelTransport"
            setUserProp polyNode "XP_LightningTaperEnds" (taperEnds as string)
            setUserProp polyNode "XP_LightningAdaptiveTopology" "CurvatureTwistWidth"
            setUserProp polyNode "XP_LightningWaypointHandles" (XP_LG_SerializeWaypointHandles waypointNodes)
            setUserProp polyNode "XP_LightningWaypointSmoothingEnabled" (waypointSmoothingEnabled as string)
            setUserProp polyNode "XP_LightningWaypointSmoothingStrength" (waypointSmoothingStrength as string)
            setUserProp polyNode "XP_LightningWaypointAutoAddFaces" (waypointAutoAddFaces as string)
            setUserProp polyNode "XP_LightningWaypointSafetyAutoFaces" (waypointSafetyAutoFaces as string)
            local controlSnapshotSignature = XP_LG_BuildControlSnapshotSignature startNode waypointNodes endNode
            if controlSnapshotSignature != undefined do setUserProp polyNode "XP_LightningControlSnapshot" controlSnapshotSignature
            setUserProp polyNode "XP_LightningActiveSet" "false"
        )
    )
    catch
    (
        local exceptionText = getCurrentException()
        if isValidNode polyNode do delete polyNode
        XP_LG_LastError = "生成闪电时发生错误：" + exceptionText
        polyNode = undefined
    )

    polyNode
)

fn XP_LG_CreateLightningNodes startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 taperEnds:false waypointNodes:#() waypointSmoothingEnabled:false waypointSmoothingStrength:50.0 waypointAutoAddFaces:false =
(
    XP_LG_LastError = ""
    if (XP_LG_ValidateInputs startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling wholeTwistEnabled:wholeTwistEnabled wholeTwistSegments:wholeTwistSegments wholeTwistAmount:wholeTwistAmount waypointNodes:waypointNodes waypointSmoothingStrength:waypointSmoothingStrength) != true do return undefined

    local newNodes = #()
    for branchIndex = 1 to endNodes.count do
    (
        local newNode = XP_LG_CreateLightningBranchNode startNode endNodes[branchIndex] branchIndex endNodes.count segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:wholeTwistEnabled wholeTwistSegments:wholeTwistSegments wholeTwistAmount:wholeTwistAmount taperEnds:taperEnds waypointNodes:waypointNodes waypointSmoothingEnabled:waypointSmoothingEnabled waypointSmoothingStrength:waypointSmoothingStrength waypointAutoAddFaces:waypointAutoAddFaces
        if not isValidNode newNode do
        (
            for createdNode in newNodes do if isValidNode createdNode do delete createdNode
            return undefined
        )
        append newNodes newNode
    )
    newNodes
)

fn XP_LG_CreateLightningNode startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 taperEnds:false waypointNodes:#() waypointSmoothingEnabled:false waypointSmoothingStrength:50.0 waypointAutoAddFaces:false =
(
    local newNodes = XP_LG_CreateLightningNodes startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:wholeTwistEnabled wholeTwistSegments:wholeTwistSegments wholeTwistAmount:wholeTwistAmount taperEnds:taperEnds waypointNodes:waypointNodes waypointSmoothingEnabled:waypointSmoothingEnabled waypointSmoothingStrength:waypointSmoothingStrength waypointAutoAddFaces:waypointAutoAddFaces
    if newNodes == undefined or newNodes.count == 0 do return undefined
    for newNode in newNodes do if isValidNode newNode do
    (
        newNode.name = uniqueName "LightningPlane"
        newNode.isHidden = false
    )
    newNodes[1]
)

fn XP_LG_FindOutputByEndHandle outputNodes endHandleText =
(
    for outputNode in outputNodes do
    (
        if isValidNode outputNode do
        (
            local storedEndHandle = undefined
            try (storedEndHandle = getUserProp outputNode "XP_LightningEndHandle") catch (storedEndHandle = undefined)
            if storedEndHandle != undefined and (storedEndHandle as string) == endHandleText do return outputNode
        )
    )
    undefined
)

fn XP_LG_CopyGenerationProperties sourceNode targetNode =
(
    if not isValidNode sourceNode or not isValidNode targetNode do return false
    local propertyNames = #("XP_LightningGenerator", "XP_LightningStartHandle", "XP_LightningEndHandle", "XP_LightningFacesPerBranch", "XP_LightningActualFaces", "XP_LightningRibbonWidth", "XP_LightningPathNoiseStrength", "XP_LightningNoiseSize", "XP_LightningTiling", "XP_LightningSeed", "XP_LightningLockStart", "XP_LightningLockEnd", "XP_LightningWholeTwistEnabled", "XP_LightningWholeTwistSegments", "XP_LightningWholeTwistAmount", "XP_LightningTwistMode", "XP_LightningTwistMapping", "XP_LightningTaperEnds", "XP_LightningAdaptiveTopology", "XP_LightningWaypointHandles", "XP_LightningWaypointSmoothingEnabled", "XP_LightningWaypointSmoothingStrength", "XP_LightningWaypointAutoAddFaces", "XP_LightningWaypointSafetyAutoFaces", "XP_LightningControlSnapshot")
    for propertyName in propertyNames do
    (
        local propertyValue = undefined
        try (propertyValue = getUserProp sourceNode propertyName) catch (propertyValue = undefined)
        if propertyValue != undefined do setUserProp targetNode propertyName propertyValue
    )
    true
)

fn XP_LG_CaptureNodeWorldVertices sceneNode =
(
    if not isValidNode sceneNode do return undefined
    local editablePoly = sceneNode.baseObject
    local objectTM = sceneNode.objectTransform
    for vertexIndex = 1 to (polyop.getNumVerts editablePoly) collect ((polyop.getVert editablePoly vertexIndex) * objectTM)
)

fn XP_LG_ReplaceSelectedOutput selectedNode startNode endNode segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 taperEnds:false waypointNodes:#() waypointSmoothingEnabled:false waypointSmoothingStrength:50.0 waypointAutoAddFaces:false =
(
    if not isValidNode selectedNode or not (XP_LG_IsManagedOutput selectedNode) do return undefined
    local temporaryNodes = XP_LG_CreateLightningNodes startNode #(endNode) segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:wholeTwistEnabled wholeTwistSegments:wholeTwistSegments wholeTwistAmount:wholeTwistAmount taperEnds:taperEnds waypointNodes:waypointNodes waypointSmoothingEnabled:waypointSmoothingEnabled waypointSmoothingStrength:waypointSmoothingStrength waypointAutoAddFaces:waypointAutoAddFaces
    if temporaryNodes == undefined or temporaryNodes.count != 1 do return undefined

    local temporaryNode = temporaryNodes[1]
    local backupNode = undefined
    local oldUserProperties = ""
    local committed = false

    try
    (
        backupNode = copy selectedNode
        backupNode.name = uniqueName "XP_Lightning_BackupTemp"
        backupNode.isHidden = true
        setUserProp backupNode "XP_LightningGenerator" "BackupTemp"
        setUserProp backupNode "XP_LightningActiveSet" "false"
        oldUserProperties = getUserPropBuffer selectedNode
        local temporaryWorldVertices = XP_LG_CaptureNodeWorldVertices temporaryNode
        local inverseTargetObjectTM = inverse selectedNode.objectTransform
        for vertexIndex = 1 to temporaryWorldVertices.count do polyop.setVert temporaryNode.baseObject vertexIndex (temporaryWorldVertices[vertexIndex] * inverseTargetObjectTM)
        update temporaryNode
        instanceReplace selectedNode temporaryNode
        XP_LG_CopyGenerationProperties temporaryNode selectedNode
        update selectedNode
        committed = true
    )
    catch
    (
        XP_LG_LastError = "更新所选闪电面片时发生错误：" + getCurrentException() + "；原对象已保留。"
        if isValidNode backupNode do try (instanceReplace selectedNode backupNode) catch ()
        if oldUserProperties != "" do try (setUserPropBuffer selectedNode oldUserProperties) catch ()
        try (update selectedNode) catch ()
    )

    if isValidNode temporaryNode do delete temporaryNode
    if isValidNode backupNode do delete backupNode
    if committed then
    (
        XP_LG_OutputNode = selectedNode
        if (findItem XP_LG_OutputNodes selectedNode) == 0 do append XP_LG_OutputNodes selectedNode
        try (select selectedNode) catch ()
        try (redrawViews()) catch ()
        selectedNode
    )
    else
    (
        undefined
    )
)

fn XP_LG_ReplaceOutput startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 taperEnds:false =
(
    local oldNodes = XP_LG_ResolveOutputs startNode
    local newNodes = XP_LG_CreateLightningNodes startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:wholeTwistEnabled wholeTwistSegments:wholeTwistSegments wholeTwistAmount:wholeTwistAmount taperEnds:taperEnds
    local renamedOldNodes = #()

    if newNodes == undefined or newNodes.count != endNodes.count do return undefined

    try
    (
        with redraw off
        (
            for branchIndex = 1 to newNodes.count do
            (
                local newNode = newNodes[branchIndex]
                local endHandleText = (getHandleByAnim endNodes[branchIndex]) as string
                local matchingOldNode = XP_LG_FindOutputByEndHandle oldNodes endHandleText
                if isValidNode matchingOldNode do
                (
                    if matchingOldNode.material != undefined do newNode.material = matchingOldNode.material
                    newNode.wirecolor = matchingOldNode.wirecolor
                    local inheritedName = matchingOldNode.name
                    append renamedOldNodes #(matchingOldNode, inheritedName)
                    matchingOldNode.name = uniqueName "XP_Lightning_OldTemp"
                    newNode.name = inheritedName
                )
                if not isValidNode matchingOldNode do newNode.name = uniqueName "LightningPlane"
                newNode.isHidden = false
            )

            for oldNode in oldNodes do if isValidNode oldNode do delete oldNode
            XP_LG_SetOutputSetActive newNodes true
            XP_LG_OutputNodes = newNodes
            XP_LG_OutputNode = newNodes[1]
        )
    )
    catch
    (
        local exceptionText = getCurrentException()
        for newNode in newNodes do if isValidNode newNode do delete newNode
        for renamedRecord in renamedOldNodes do
        (
            try
            (
                if isValidNode renamedRecord[1] do renamedRecord[1].name = renamedRecord[2]
            )
            catch ()
        )
        XP_LG_OutputNodes = for oldNode in oldNodes where isValidNode oldNode collect oldNode
        XP_LG_OutputNode = if XP_LG_OutputNodes.count > 0 then XP_LG_OutputNodes[1] else undefined
        XP_LG_LastError = "替换旧闪电分支对象时发生错误：" + exceptionText + "；原模型未被修改。"
        return undefined
    )

    try (select newNodes) catch ()
    try (redrawViews()) catch ()
    newNodes[1]
)

fn XP_LG_CreateNewOutputSet startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:0.0 taperEnds:false waypointSmoothingEnabled:false waypointSmoothingStrength:50.0 waypointAutoAddFaces:false =
(
    local oldActiveNodes = XP_LG_ResolveOutputs startNode
    local newNodes = XP_LG_CreateLightningNodes startNode endNodes segmentCount ribbonWidth twistStrength noiseSize tiling seedValue lockStart lockEnd wholeTwistEnabled:wholeTwistEnabled wholeTwistSegments:wholeTwistSegments wholeTwistAmount:wholeTwistAmount taperEnds:taperEnds waypointSmoothingEnabled:waypointSmoothingEnabled waypointSmoothingStrength:waypointSmoothingStrength waypointAutoAddFaces:waypointAutoAddFaces
    if newNodes == undefined or newNodes.count != endNodes.count do return undefined

    try
    (
        with redraw off
        (
            for newNode in newNodes do if isValidNode newNode do
            (
                newNode.name = uniqueName "LightningPlane"
                newNode.isHidden = false
            )
            XP_LG_SetOutputSetActive oldActiveNodes false
            XP_LG_SetOutputSetActive newNodes true
            XP_LG_OutputNodes = newNodes
            XP_LG_OutputNode = newNodes[1]
        )
    )
    catch
    (
        local exceptionText = getCurrentException()
        for newNode in newNodes do if isValidNode newNode do delete newNode
        XP_LG_SetOutputSetActive oldActiveNodes true
        XP_LG_OutputNodes = for oldNode in oldActiveNodes where isValidNode oldNode collect oldNode
        XP_LG_OutputNode = if XP_LG_OutputNodes.count > 0 then XP_LG_OutputNodes[1] else undefined
        XP_LG_LastError = "新建闪电面片组时发生错误：" + exceptionText + "；已有面片未被修改。"
        return undefined
    )

    try (select newNodes) catch ()
    try (redrawViews()) catch ()
    newNodes[1]
)

fn XP_LG_UpdateWholeTwistControlState =
(
    if XP_LG_Rollout == undefined do return false

    local wholeTwistIsEnabled = XP_LG_Rollout.chkWholeTwist.checked
    XP_LG_Rollout.spWholeTwistSegments.enabled = wholeTwistIsEnabled
    XP_LG_Rollout.spWholeTwistAmount.enabled = wholeTwistIsEnabled
    true
)

fn XP_LG_UpdateWaypointSmoothingControlState =
(
    if XP_LG_Rollout == undefined do return false
    local smoothingIsEnabled = XP_LG_Rollout.chkWaypointSmoothing.checked
    XP_LG_Rollout.spWaypointSmoothingStrength.enabled = smoothingIsEnabled
    XP_LG_Rollout.chkWaypointAutoAddFaces.enabled = smoothingIsEnabled
    true
)

fn XP_LG_StopLiveUpdateTimer =
(
    if XP_LG_Rollout != undefined do
    (
        try (XP_LG_Rollout.tmLiveUpdate.active = false) catch ()
    )
    XP_LG_LiveUpdateTimerLoopActive = false
    true
)

fn XP_LG_StartLiveUpdateTimerLoop =
(
    if XP_LG_Rollout == undefined do return false
    if XP_LG_LiveUpdateTimerLoopActive do return true
    XP_LG_LiveUpdateTimerError = ""
    local timerStarted = false

    try
    (
        XP_LG_Rollout.tmLiveUpdate.active = true
        XP_LG_LiveUpdateTimerLoopActive = true
        timerStarted = true
    )
    catch
    (
        XP_LG_LiveUpdateTimerError = getCurrentException()
    )
    timerStarted
)

fn XP_LG_RestartLiveUpdateTimer =
(
    XP_LG_LiveUpdateRequestTime = timeStamp()
    XP_LG_StartLiveUpdateTimerLoop()
)

fn XP_LG_CancelLiveUpdate =
(
    XP_LG_LiveUpdatePending = false
    XP_LG_LiveUpdatePendingReason = ""
    XP_LG_LiveUpdatePendingShowErrors = false
    XP_LG_LiveUpdateRequestTime = 0
    XP_LG_LiveUpdateTargetNode = undefined
    true
)

fn XP_LG_CanGenerateFromUI =
(
    XP_LG_CleanEndNodes()
    isValidNode XP_LG_StartNode and XP_LG_EndNodes.count > 0
)

fn XP_LG_FlushLiveUpdate =
(
    if XP_LG_Rollout == undefined do return undefined

    if XP_LG_LiveUpdateBusy do return undefined

    if not XP_LG_LiveUpdatePending do return undefined

    local reasonSnapshot = XP_LG_LiveUpdatePendingReason
    local showErrorsSnapshot = XP_LG_LiveUpdatePendingShowErrors
    local targetNodeSnapshot = XP_LG_LiveUpdateTargetNode
    local isControlPositionSync = not showErrorsSnapshot and reasonSnapshot == "途经点坐标变化"
    local canGenerate = false
    local preflightError = ""

    try
    (
        if showErrorsSnapshot then
        (
            canGenerate = XP_LG_CanGenerateFromUI()
        )
        else
        (
            canGenerate = isValidNode targetNodeSnapshot and XP_LG_IsManagedOutput targetNodeSnapshot and isValidNode (XP_LG_FindNodeByStoredHandle targetNodeSnapshot "XP_LightningStartHandle") and isValidNode (XP_LG_FindNodeByStoredHandle targetNodeSnapshot "XP_LightningEndHandle")
        )
    )
    catch
    (
        preflightError = getCurrentException()
    )

    if not canGenerate do
    (
        XP_LG_CancelLiveUpdate()
        local missingControlMessage = if preflightError != "" then ("读取控制点时发生错误：" + preflightError) else if not showErrorsSnapshot then "请选择一个有效的 LightningPlane 面片后再调整参数。" else if not isValidNode XP_LG_StartNode then "请先拾取一个有效的起点对象。" else "请至少添加一个有效的终点对象。"
        try (XP_LG_Rollout.lblStatus.text = if showErrorsSnapshot then "无法生成；请检查提示。" else "等待有效的起点和终点。") catch ()
        if showErrorsSnapshot do try (messageBox missingControlMessage title:"XP闪电面片生成器") catch ()
        return undefined
    )

    -- 在进入生成器前冻结本次参数，避免一个模型混用两次 UI 状态。
    local startSnapshot = undefined
    local endSnapshot = #()
    local faceCountSnapshot = 1
    local widthSnapshot = 1.0
    local twistSnapshot = 0.0
    local noiseSizeSnapshot = 1.0
    local tilingSnapshot = 1.0
    local seedSnapshot = 1
    local lockStartSnapshot = true
    local lockEndSnapshot = true
    local wholeTwistEnabledSnapshot = false
    local wholeTwistSegmentsSnapshot = 1
    local wholeTwistAmountSnapshot = 0.0
    local taperEndsSnapshot = false
    local waypointSnapshot = #()
    local waypointSmoothingEnabledSnapshot = false
    local waypointSmoothingStrengthSnapshot = 50.0
    local waypointAutoAddFacesSnapshot = false
    local snapshotReady = false
    local snapshotError = ""
    local generatedNode = undefined
    local unexpectedError = ""

    try
    (
        if showErrorsSnapshot then
        (
            startSnapshot = XP_LG_StartNode
            for sceneNode in XP_LG_EndNodes do append endSnapshot sceneNode
            waypointSnapshot = #()
        )
        else
        (
            startSnapshot = XP_LG_FindNodeByStoredHandle targetNodeSnapshot "XP_LightningStartHandle"
            append endSnapshot (XP_LG_FindNodeByStoredHandle targetNodeSnapshot "XP_LightningEndHandle")
            if isValidNode XP_LG_WaypointOwnerNode and XP_LG_WaypointOwnerNode == targetNodeSnapshot then
                waypointSnapshot = for waypointNode in XP_LG_WaypointNodes collect waypointNode
            else
                waypointSnapshot = XP_LG_GetWaypointNodesFromOutput targetNodeSnapshot
            if waypointSnapshot == undefined do snapshotError = XP_LG_LastError
        )
        faceCountSnapshot = XP_LG_Rollout.spFaces.value as integer
        widthSnapshot = XP_LG_Rollout.spWidth.value
        twistSnapshot = XP_LG_Rollout.spTwist.value
        noiseSizeSnapshot = XP_LG_Rollout.spNoiseSize.value
        tilingSnapshot = XP_LG_Rollout.spTiling.value
        seedSnapshot = XP_LG_Rollout.spSeed.value as integer
        lockStartSnapshot = XP_LG_Rollout.chkLockStart.checked
        lockEndSnapshot = XP_LG_Rollout.chkLockEnd.checked
        wholeTwistEnabledSnapshot = XP_LG_Rollout.chkWholeTwist.checked
        wholeTwistSegmentsSnapshot = XP_LG_Rollout.spWholeTwistSegments.value as integer
        wholeTwistAmountSnapshot = XP_LG_Rollout.spWholeTwistAmount.value
        taperEndsSnapshot = XP_LG_Rollout.chkTaperEnds.checked
        waypointSmoothingEnabledSnapshot = XP_LG_Rollout.chkWaypointSmoothing.checked
        waypointSmoothingStrengthSnapshot = XP_LG_Rollout.spWaypointSmoothingStrength.value
        waypointAutoAddFacesSnapshot = XP_LG_Rollout.chkWaypointAutoAddFaces.checked
        snapshotReady = waypointSnapshot != undefined
    )
    catch
    (
        snapshotError = getCurrentException()
    )

    if not snapshotReady do
    (
        XP_LG_CancelLiveUpdate()
        try (XP_LG_Rollout.lblStatus.text = "实时更新失败；无法读取当前界面参数，上一个有效模型已保留。") catch ()
        if showErrorsSnapshot do try (messageBox ("无法读取当前界面参数：" + snapshotError) title:"XP闪电面片生成器") catch ()
        return undefined
    )

    XP_LG_LiveUpdatePending = false
    XP_LG_LiveUpdatePendingReason = ""
    XP_LG_LiveUpdatePendingShowErrors = false
    XP_LG_LiveUpdateTargetNode = undefined
    XP_LG_LastError = ""
    XP_LG_LiveUpdateCurrentDepth = 1
    if XP_LG_LiveUpdateMaxDepth < 1 do XP_LG_LiveUpdateMaxDepth = 1
    XP_LG_LiveUpdateBusy = true

    try
    (
        XP_LG_LiveUpdateAttemptCount = XP_LG_LiveUpdateAttemptCount + 1
        try
        (
            XP_LG_Rollout.lblStatus.text = if showErrorsSnapshot then "正在强制重新生成，请稍候……" else ("正在实时更新：「" + reasonSnapshot + "」……")
        )
        catch ()

        if showErrorsSnapshot then
        (
            undo "新建一组写实闪电" on
            (
                generatedNode = XP_LG_CreateNewOutputSet startSnapshot endSnapshot faceCountSnapshot widthSnapshot twistSnapshot noiseSizeSnapshot tilingSnapshot seedSnapshot lockStartSnapshot lockEndSnapshot wholeTwistEnabled:wholeTwistEnabledSnapshot wholeTwistSegments:wholeTwistSegmentsSnapshot wholeTwistAmount:wholeTwistAmountSnapshot taperEnds:taperEndsSnapshot waypointSmoothingEnabled:waypointSmoothingEnabledSnapshot waypointSmoothingStrength:waypointSmoothingStrengthSnapshot waypointAutoAddFaces:waypointAutoAddFacesSnapshot
            )
        )
        else
        (
            undo "实时更新写实闪电" on
            (
                generatedNode = XP_LG_ReplaceSelectedOutput targetNodeSnapshot startSnapshot endSnapshot[1] faceCountSnapshot widthSnapshot twistSnapshot noiseSizeSnapshot tilingSnapshot seedSnapshot lockStartSnapshot lockEndSnapshot wholeTwistEnabled:wholeTwistEnabledSnapshot wholeTwistSegments:wholeTwistSegmentsSnapshot wholeTwistAmount:wholeTwistAmountSnapshot taperEnds:taperEndsSnapshot waypointNodes:waypointSnapshot waypointSmoothingEnabled:waypointSmoothingEnabledSnapshot waypointSmoothingStrength:waypointSmoothingStrengthSnapshot waypointAutoAddFaces:waypointAutoAddFacesSnapshot
            )
        )
    )
    catch
    (
        unexpectedError = getCurrentException()
    )

    XP_LG_LiveUpdateBusy = false
    XP_LG_LiveUpdateCurrentDepth = 0
    if unexpectedError != "" and XP_LG_LastError == "" do XP_LG_LastError = "实时更新闪电时发生错误：" + unexpectedError

    if isValidNode generatedNode then
    (
        XP_LG_LiveUpdateSuccessCount = XP_LG_LiveUpdateSuccessCount + 1
        if XP_LG_LastFailedControlSyncNode == generatedNode do
        (
            XP_LG_LastFailedControlSyncNode = undefined
            XP_LG_LastFailedControlSyncSignature = ""
        )
        local actualFaceCount = faceCountSnapshot
        try
        (
            local storedActualFaceCount = getUserProp generatedNode "XP_LightningActualFaces"
            if storedActualFaceCount != undefined do actualFaceCount = storedActualFaceCount as integer
        )
        catch ()
        local resultSummary = if showErrorsSnapshot then ((endSnapshot.count as string) + " 条分支；首条实际 " + (actualFaceCount as string) + " 个四边面") else ("已原位更新「" + generatedNode.name + "」，实际 " + (actualFaceCount as string) + " 个四边面")
        try (XP_LG_Rollout.lblWaypointActualFaces.text = if showErrorsSnapshot then ("新组首条：基础 " + (faceCountSnapshot as string) + " 面，实际 " + (actualFaceCount as string) + " 面。") else ("当前面片：基础 " + (faceCountSnapshot as string) + " 面，实际 " + (actualFaceCount as string) + " 面。")) catch ()
        local samplingWarning = ""
        if wholeTwistEnabledSnapshot and wholeTwistSegmentsSnapshot > faceCountSnapshot do samplingWarning = samplingWarning + "；提示：平面面数低于轴向扭转分段，部分旋转变化可能无法完整表现"
        if faceCountSnapshot <= 5 and (lockStartSnapshot or lockEndSnapshot) do samplingWarning = samplingWarning + "；提示：平面面数较低，端点平滑衰减细节可能无法完整表现"
        if samplingWarning == "" then samplingWarning = "。" else samplingWarning = samplingWarning + "。"
        if showErrorsSnapshot then
            try (XP_LG_Rollout.lblStatus.text = "已保留旧面片并新建一组：" + resultSummary + samplingWarning) catch ()
        else
            try (XP_LG_Rollout.lblStatus.text = "已更新所选面片：「" + reasonSnapshot + "」；" + resultSummary + samplingWarning) catch ()
    )
    else
    (
        if isControlPositionSync and isValidNode targetNodeSnapshot do
        (
            local failedControlSignature = undefined
            try (failedControlSignature = XP_LG_BuildControlSnapshotSignature startSnapshot waypointSnapshot endSnapshot[1]) catch (failedControlSignature = undefined)
            if failedControlSignature != undefined do
            (
                XP_LG_LastFailedControlSyncNode = targetNodeSnapshot
                XP_LG_LastFailedControlSyncSignature = failedControlSignature
            )
        )
        local errorMessage = if XP_LG_LastError == "" then "生成失败；上一个有效模型已保留。" else XP_LG_LastError
        try (XP_LG_Rollout.lblStatus.text = if showErrorsSnapshot then ("强制重新生成失败；原模型已保留。" + errorMessage) else ("实时更新失败；上一个有效模型已保留。" + errorMessage)) catch ()
        if showErrorsSnapshot do try (messageBox errorMessage title:"XP闪电面片生成器") catch ()
    )

    if XP_LG_LiveUpdatePending do XP_LG_RestartLiveUpdateTimer()
    generatedNode
)

fn XP_LG_HandleLiveUpdateTimerTick =
(
    if not XP_LG_LiveUpdatePending do
    (
        return false
    )

    local elapsedMilliseconds = timeStamp() - XP_LG_LiveUpdateRequestTime
    if elapsedMilliseconds < 0 do elapsedMilliseconds = 200
    if elapsedMilliseconds < 200 do return false

    isValidNode (XP_LG_FlushLiveUpdate())
)

fn XP_LG_RequestLiveUpdate reasonText showErrors:false immediate:false =
(
    if XP_LG_Rollout == undefined or XP_LG_SuppressLiveUpdate do return false

    if not showErrors do
    (
        local selectedTarget = XP_LG_GetSelectedManagedOutput()
        if not isValidNode selectedTarget do
        (
            try (XP_LG_Rollout.lblStatus.text = "参数已保留；请选择一个 LightningPlane 面片后再编辑，只有强制重新生成会新建对象。") catch ()
            return false
        )
        XP_LG_LiveUpdateTargetNode = selectedTarget
    )
    if showErrors do XP_LG_LiveUpdateTargetNode = undefined

    -- 常驻 Timer 可能在任意 UI 消息边界触发；先更新时间戳，再公开 Pending，
    -- 避免 Tick 看到新请求却读取到旧时间戳而提前提交。
    XP_LG_LiveUpdateRequestTime = timeStamp()
    XP_LG_LiveUpdatePending = true
    XP_LG_LiveUpdatePendingReason = reasonText
    if showErrors do XP_LG_LiveUpdatePendingShowErrors = true

    if XP_LG_LiveUpdateBusy do return true

    if immediate then
    (
        isValidNode (XP_LG_FlushLiveUpdate())
    )
    else
    (
        local timerStarted = XP_LG_RestartLiveUpdateTimer()
        if timerStarted then
        (
            true
        )
        else
        (
            local rolloutIsOpen = false
            try (rolloutIsOpen = XP_LG_Rollout.isDisplayed) catch (rolloutIsOpen = false)
            if rolloutIsOpen then isValidNode (XP_LG_FlushLiveUpdate()) else true
        )
    )
)

fn XP_LG_GenerateFromUI showErrors reasonText =
(
    XP_LG_RequestLiveUpdate reasonText showErrors:showErrors immediate:true
)

fn XP_LG_RequestSelectedControlPositionSync selectedOutput startNode waypointNodes endNode =
(
    if not isValidNode selectedOutput or not (XP_LG_IsManagedOutput selectedOutput) do return false
    if waypointNodes == undefined or waypointNodes.count == 0 do return false
    local currentSignature = XP_LG_BuildControlSnapshotSignature startNode waypointNodes endNode
    if currentSignature == undefined do return false
    local storedSignature = XP_LG_GetStoredControlSnapshotSignature selectedOutput
    if storedSignature == currentSignature do return false
    if isValidNode XP_LG_LastFailedControlSyncNode and XP_LG_LastFailedControlSyncNode == selectedOutput and XP_LG_LastFailedControlSyncSignature == currentSignature do
    (
        try (XP_LG_Rollout.lblStatus.text = "途经点坐标仍与上次成功模型不同；上次自动同步失败，请调整控制点或参数后重试。") catch ()
        return false
    )
    try (XP_LG_Rollout.lblStatus.text = "检测到途经点坐标变化，正在准备自动同步所选面片……") catch ()
    XP_LG_RequestLiveUpdate "途经点坐标变化"
)

fn XP_LG_RefreshUI =
(
    if XP_LG_Rollout == undefined do return false

    local endpointNames = XP_LG_GetEndNodeNames()
    XP_LG_Rollout.lbEndpoints.items = endpointNames
    XP_LG_Rollout.lbEndpoints.selection = if endpointNames.count > 0 then 1 else 0

    if isValidNode XP_LG_StartNode then
    (
        XP_LG_Rollout.pbStart.text = "起点：" + XP_LG_StartNode.name
        XP_LG_Rollout.pbStart.object = XP_LG_StartNode
    )
    else
    (
        XP_LG_StartNode = undefined
        XP_LG_Rollout.pbStart.text = "拾取起点"
        XP_LG_Rollout.pbStart.object = undefined
    )

    XP_LG_Rollout.lblEndpointCount.text = "有效终点：" + endpointNames.count as string + "　基础预计四边面：" + (endpointNames.count * XP_LG_Rollout.spFaces.value) as string
    local selectedOutput = XP_LG_GetSelectedManagedOutput()
    local waypointNames = if isValidNode selectedOutput and isValidNode XP_LG_WaypointOwnerNode and selectedOutput == XP_LG_WaypointOwnerNode then XP_LG_GetWaypointNames XP_LG_WaypointNodes else #()
    XP_LG_Rollout.lbWaypoints.items = waypointNames
    XP_LG_Rollout.lbWaypoints.selection = if waypointNames.count > 0 then 1 else 0
    local canEditWaypoints = isValidNode selectedOutput
    XP_LG_Rollout.pbAddWaypoint.enabled = canEditWaypoints
    XP_LG_Rollout.btnWaypointUp.enabled = canEditWaypoints and waypointNames.count > 1
    XP_LG_Rollout.btnWaypointDown.enabled = canEditWaypoints and waypointNames.count > 1
    XP_LG_Rollout.btnRemoveWaypoint.enabled = canEditWaypoints and waypointNames.count > 0
    XP_LG_Rollout.btnClearWaypoints.enabled = canEditWaypoints and waypointNames.count > 0
    local storedActualFaces = undefined
    if isValidNode selectedOutput do
    (
        try (storedActualFaces = getUserProp selectedOutput "XP_LightningActualFaces") catch (storedActualFaces = undefined)
        if storedActualFaces == undefined do storedActualFaces = XP_LG_Rollout.spFaces.value
    )
    XP_LG_Rollout.lblWaypointActualFaces.text = if storedActualFaces != undefined then ("当前面片：基础 " + (XP_LG_Rollout.spFaces.value as string) + " 面，实际 " + ((storedActualFaces as integer) as string) + " 面。") else "实际面数将在生成或更新成功后显示。"
    XP_LG_UpdateWholeTwistControlState()
    XP_LG_UpdateWaypointSmoothingControlState()
    true
)

fn XP_LG_ReadOutputNumber outputNode propertyName fallbackValue =
(
    local propertyValue = undefined
    try (propertyValue = getUserProp outputNode propertyName) catch (propertyValue = undefined)
    if propertyValue == undefined then fallbackValue else propertyValue as float
)

fn XP_LG_ReadOutputBoolean outputNode propertyName fallbackValue =
(
    local propertyValue = undefined
    try (propertyValue = getUserProp outputNode propertyName) catch (propertyValue = undefined)
    if propertyValue == undefined then fallbackValue else (propertyValue == true or (toLower (propertyValue as string)) == "true")
)

fn XP_LG_LoadSelectedOutputIntoUI =
(
    if XP_LG_Rollout == undefined or XP_LG_SelectionSyncBusy do return false
    local selectedOutput = XP_LG_GetSelectedManagedOutput()
    if not isValidNode selectedOutput do
    (
        XP_LG_WaypointOwnerNode = undefined
        XP_LG_WaypointNodes = #()
        try (XP_LG_RefreshUI()) catch ()
        return false
    )

    local storedStartNode = XP_LG_FindNodeByStoredHandle selectedOutput "XP_LightningStartHandle"
    local storedEndNode = XP_LG_FindNodeByStoredHandle selectedOutput "XP_LightningEndHandle"
    local storedWaypointNodes = XP_LG_GetWaypointNodesFromOutput selectedOutput
    local previousSuppressState = XP_LG_SuppressLiveUpdate
    XP_LG_SelectionSyncBusy = true
    XP_LG_SuppressLiveUpdate = true
    try
    (
        if isValidNode storedStartNode do XP_LG_StartNode = storedStartNode
        if isValidNode storedEndNode do XP_LG_EndNodes = #(storedEndNode)
        XP_LG_OutputNode = selectedOutput
        if storedWaypointNodes == undefined then
        (
            XP_LG_WaypointOwnerNode = undefined
            XP_LG_WaypointNodes = #()
        )
        else
        (
            XP_LG_WaypointOwnerNode = selectedOutput
            XP_LG_WaypointNodes = storedWaypointNodes
        )
        XP_LG_Rollout.spFaces.value = (XP_LG_ReadOutputNumber selectedOutput "XP_LightningFacesPerBranch" XP_LG_Rollout.spFaces.value) as integer
        XP_LG_Rollout.spWidth.value = XP_LG_ReadOutputNumber selectedOutput "XP_LightningRibbonWidth" XP_LG_Rollout.spWidth.value
        XP_LG_Rollout.spTwist.value = XP_LG_ReadOutputNumber selectedOutput "XP_LightningPathNoiseStrength" XP_LG_Rollout.spTwist.value
        XP_LG_Rollout.spNoiseSize.value = XP_LG_ReadOutputNumber selectedOutput "XP_LightningNoiseSize" XP_LG_Rollout.spNoiseSize.value
        XP_LG_Rollout.spTiling.value = XP_LG_ReadOutputNumber selectedOutput "XP_LightningTiling" XP_LG_Rollout.spTiling.value
        XP_LG_Rollout.spSeed.value = (XP_LG_ReadOutputNumber selectedOutput "XP_LightningSeed" XP_LG_Rollout.spSeed.value) as integer
        XP_LG_Rollout.chkLockStart.checked = XP_LG_ReadOutputBoolean selectedOutput "XP_LightningLockStart" XP_LG_Rollout.chkLockStart.checked
        XP_LG_Rollout.chkLockEnd.checked = XP_LG_ReadOutputBoolean selectedOutput "XP_LightningLockEnd" XP_LG_Rollout.chkLockEnd.checked
        XP_LG_Rollout.chkWholeTwist.checked = XP_LG_ReadOutputBoolean selectedOutput "XP_LightningWholeTwistEnabled" XP_LG_Rollout.chkWholeTwist.checked
        XP_LG_Rollout.spWholeTwistSegments.value = (XP_LG_ReadOutputNumber selectedOutput "XP_LightningWholeTwistSegments" XP_LG_Rollout.spWholeTwistSegments.value) as integer
        XP_LG_Rollout.spWholeTwistAmount.value = XP_LG_ReadOutputNumber selectedOutput "XP_LightningWholeTwistAmount" XP_LG_Rollout.spWholeTwistAmount.value
        XP_LG_Rollout.chkTaperEnds.checked = XP_LG_ReadOutputBoolean selectedOutput "XP_LightningTaperEnds" XP_LG_Rollout.chkTaperEnds.checked
        XP_LG_Rollout.chkWaypointSmoothing.checked = XP_LG_ReadOutputBoolean selectedOutput "XP_LightningWaypointSmoothingEnabled" false
        XP_LG_Rollout.spWaypointSmoothingStrength.value = XP_LG_ReadOutputNumber selectedOutput "XP_LightningWaypointSmoothingStrength" 50.0
        XP_LG_Rollout.chkWaypointAutoAddFaces.checked = XP_LG_ReadOutputBoolean selectedOutput "XP_LightningWaypointAutoAddFaces" false
        XP_LG_RefreshUI()
        if storedWaypointNodes == undefined then
            XP_LG_Rollout.lblStatus.text = if XP_LG_LastError == "" then "所选面片的途经点引用无效；旧模型已保留。" else XP_LG_LastError
        else
            XP_LG_Rollout.lblStatus.text = "当前编辑面片：「" + selectedOutput.name + "」；参数修改只作用于该对象。"
    )
    catch
    (
        try (XP_LG_Rollout.lblStatus.text = "读取所选面片参数失败；场景对象未修改。") catch ()
    )
    XP_LG_SuppressLiveUpdate = previousSuppressState
    XP_LG_SelectionSyncBusy = false
    if storedWaypointNodes != undefined and storedWaypointNodes.count > 0 do XP_LG_RequestSelectedControlPositionSync selectedOutput storedStartNode storedWaypointNodes storedEndNode
    true
)

fn XP_LG_CommitWaypointChange selectedOutput candidateNodes reasonText =
(
    if not isValidNode selectedOutput or not (XP_LG_IsManagedOutput selectedOutput) do return false
    local oldNodes = if isValidNode XP_LG_WaypointOwnerNode and XP_LG_WaypointOwnerNode == selectedOutput then (for waypointNode in XP_LG_WaypointNodes collect waypointNode) else XP_LG_GetWaypointNodesFromOutput selectedOutput
    if oldNodes == undefined do oldNodes = #()
    XP_LG_WaypointOwnerNode = selectedOutput
    XP_LG_WaypointNodes = for waypointNode in candidateNodes collect waypointNode
    XP_LG_RefreshUI()
    local updateSucceeded = XP_LG_RequestLiveUpdate reasonText immediate:true
    if updateSucceeded then
    (
        XP_LG_LoadSelectedOutputIntoUI()
        true
    )
    else
    (
        XP_LG_WaypointOwnerNode = selectedOutput
        XP_LG_WaypointNodes = oldNodes
        XP_LG_RefreshUI()
        false
    )
)

fn XP_LG_HandleSelectionChanged =
(
    if XP_LG_LiveUpdatePending and XP_LG_LiveUpdatePendingReason == "途经点坐标变化" do XP_LG_CancelLiveUpdate()
    try (XP_LG_LoadSelectedOutputIntoUI()) catch ()
)

try (destroyDialog XP_LG_Rollout) catch ()
XP_LG_SuppressLiveUpdate = false

rollout XP_LG_Rollout "XP闪电面片生成器 V1.2.0" width:390 height:1045
(
    group "起点与终点"
    (
        label lblPointHint "位置取自所选对象的世界包围盒中心。" align:#left
        pickbutton pbStart "拾取起点" width:342 filter:XP_LG_PickFilter autoDisplay:false message:"请选择闪电起点对象" toolTip:"使用所选对象的中心作为闪电起点"
        button btnClearStart "清除起点" width:342
        pickbutton pbAddEndpoint "添加终点" width:342 filter:XP_LG_PickFilter autoDisplay:false message:"请选择要添加的闪电终点对象" toolTip:"每次拾取一个终点，可重复添加多个"
        listbox lbEndpoints "终点列表：" items:#() selection:0 height:5 width:342
        button btnRemoveEndpoint "移除所选终点" width:166 across:2
        button btnClearEndpoints "清空全部终点" width:166
        label lblEndpointCount "有效终点：0　基础预计四边面：0" align:#left
    )

    group "所选面片途经点"
    (
        label lblWaypointHint "先在场景层级中唯一选中一个 LightningPlane，再按列表顺序添加。" width:342 align:#left
        pickbutton pbAddWaypoint "添加途经点" width:342 enabled:false filter:XP_LG_PickFilter autoDisplay:false message:"请选择途经点对象" toolTip:"只修改当前选中面片；路径精确经过对象的世界包围盒中心"
        listbox lbWaypoints "途经点列表（起点 → 列表顺序 → 终点）：" items:#() selection:0 height:4 width:342
        button btnWaypointUp "上移" width:80 across:4 enabled:false
        button btnWaypointDown "下移" width:80 enabled:false
        button btnRemoveWaypoint "移除所选" width:80 enabled:false
        button btnClearWaypoints "清空全部" width:80 enabled:false
        checkbox chkWaypointSmoothing "启用途经点平滑过渡" checked:false toolTip:"只平滑起点、途经点和终点构成的整体走向；路径仍精确经过每个控制点中心"
        slider spWaypointSmoothingStrength "途经点过渡强度：" range:[0,100,50] type:#integer width:342 enabled:false toolTip:"拖动 0～100；0 保持原折线路径，数值越高转折越圆滑"
        checkbox chkWaypointAutoAddFaces "平滑时允许额外加面" checked:false enabled:false toolTip:"主动增加途经点局部平滑密度；两个以上途经点会另外自动安全补面以保持恒宽，关闭本项也不会禁用安全补面"
        label lblWaypointActualFaces "实际面数将在生成或更新成功后显示。" width:342 align:#left
    )

    group "模型参数"
    (
        spinner spFaces "平面面数：" range:[1,1000,24] type:#integer fieldWidth:75 toolTip:"每条闪电分支沿长度方向的基础四边面数量；自动加面关闭时即为实际面数，设为 1 时是一张四边面"
        spinner spWidth "闪电宽度：" range:[0.001,1000000.0,3.0] type:#worldunits scale:0.1 fieldWidth:75 toolTip:"带状面片的总宽度"
        checkbox chkTaperEnds "面片两端平滑收尖" checked:false toolTip:"起点和每个终点平滑缩小到正常宽度的 1%，保持有效四边面和原 UV"
    )

    group "扭曲与噪波"
    (
        spinner spTwist "路径噪波强度：" range:[0.0,1000000.0,15.0] type:#worldunits scale:0.1 fieldWidth:75 toolTip:"细噪波使中心线偏离起终点直线的最大幅度；它不是轴向 Twist"
        spinner spNoiseSize "噪波大小：" range:[0.01,100.0,1.0] type:#float scale:0.01 fieldWidth:75 toolTip:"噪波整体尺寸倍率；数值越大，位移更明显且弯折更宽缓"
        spinner spTiling "噪波 Tiling：" range:[0.01,1000.0,1.0] type:#float scale:0.01 fieldWidth:75 toolTip:"控制噪波重复频率；数值越大，弯折越密集"
        spinner spSeed "随机种子：" range:[-1000000,1000000,1] type:#integer fieldWidth:75 toolTip:"相同控制点、参数和种子会生成相同闪电"
        checkbox chkWholeTwist "启用整段轴向扭转（Twist）" checked:false toolTip:"围绕闪电中心线切线轴旋转带状面片，不增加中心线 Noise"
        spinner spWholeTwistSegments "轴向扭转分段：" range:[1,100,4] type:#integer fieldWidth:75 enabled:false toolTip:"K 段会把全长等分为 K+1 份；前 K 份各累计一次所设角度，最后一份处理终点"
        spinner spWholeTwistAmount "轴向扭转角度：" range:[-36000.0,36000.0,90.0] type:#float scale:1.0 fieldWidth:75 enabled:false toolTip:"每个有效扭转分段的旋转增量；总累计约为分段数乘以角度，正负值控制方向，0 等同关闭"
        checkbox chkLockStart "锁定起点" checked:true across:2 toolTip:"锁定后，起点处路径噪波位移与轴向扭转角均精确为零并平滑衰减"
        checkbox chkLockEnd "锁定终点" checked:true toolTip:"锁定后，每个终点处路径噪波位移与轴向扭转角均精确为零并平滑衰减"
    )

    button btnGenerate "强制重新生成" width:342 height:36 toolTip:"保留已有面片，并按当前参数另外创建一套新的 LightningPlane 对象"
    label lblStatus "准备就绪；选中已有面片可编辑，强制重新生成才会新建。" width:342 align:#left
    label lblVersion "XP闪电面片生成器 V1.2.0｜3ds Max 2023" width:342 align:#center
    timer tmLiveUpdate interval:200 active:false

    on pbStart picked sceneNode do
    (
        if isValidNode sceneNode do
        (
            XP_LG_StartNode = sceneNode
            XP_LG_CleanEndNodes()
            lblStatus.text = "已设置起点：「" + sceneNode.name + "」。"
            XP_LG_RefreshUI()
        )
    )

    on btnClearStart pressed do
    (
        XP_LG_CancelLiveUpdate()
        XP_LG_StartNode = undefined
        lblStatus.text = "已清除起点；已有闪电面片保持不变。"
        XP_LG_RefreshUI()
    )

    on pbAddEndpoint picked sceneNode do
    (
        if isValidNode sceneNode do
        (
            if sceneNode == XP_LG_StartNode then
            (
                messageBox "起点对象不能同时作为终点。" title:"XP闪电面片生成器"
            )
            else if (findItem XP_LG_EndNodes sceneNode) > 0 then
            (
                messageBox "该对象已经在终点列表中。" title:"XP闪电面片生成器"
            )
            else
            (
                append XP_LG_EndNodes sceneNode
                lblStatus.text = "已添加终点：「" + sceneNode.name + "」。"
                XP_LG_RefreshUI()
            )
        )
    )

    on btnRemoveEndpoint pressed do
    (
        XP_LG_CleanEndNodes()
        local selectedIndex = lbEndpoints.selection
        if selectedIndex > 0 and selectedIndex <= XP_LG_EndNodes.count then
        (
            local removedName = XP_LG_EndNodes[selectedIndex].name
            deleteItem XP_LG_EndNodes selectedIndex
            if XP_LG_EndNodes.count == 0 then
            (
                XP_LG_CancelLiveUpdate()
                lblStatus.text = "已移除最后一个终点：「" + removedName + "」；已有闪电面片保持不变。"
            )
            else
            (
                lblStatus.text = "已移除终点：「" + removedName + "」；已有闪电面片保持不变。"
            )
            XP_LG_RefreshUI()
        )
        else
        (
            messageBox "请先在终点列表中选择要移除的对象。" title:"XP闪电面片生成器"
        )
    )

    on btnClearEndpoints pressed do
    (
        XP_LG_CancelLiveUpdate()
        XP_LG_EndNodes = #()
        lblStatus.text = "已清空全部终点；已有闪电面片保持不变。"
        XP_LG_RefreshUI()
    )

    on pbAddWaypoint picked sceneNode do
    (
        local selectedOutput = XP_LG_GetSelectedManagedOutput()
        if not isValidNode selectedOutput then
        (
            messageBox "请先在场景层级中唯一选中一个 LightningPlane 面片，再添加途经点。" title:"XP闪电面片生成器"
        )
        else if isValidNode sceneNode then
        (
            local candidateNodes = if isValidNode XP_LG_WaypointOwnerNode and XP_LG_WaypointOwnerNode == selectedOutput then (for waypointNode in XP_LG_WaypointNodes collect waypointNode) else XP_LG_GetWaypointNodesFromOutput selectedOutput
            if candidateNodes == undefined then
            (
                messageBox XP_LG_LastError title:"XP闪电面片生成器"
            )
            else
            (
                append candidateNodes sceneNode
                XP_LG_CommitWaypointChange selectedOutput candidateNodes ("添加途经点“" + sceneNode.name + "”")
            )
        )
    )

    on btnWaypointUp pressed do
    (
        local selectedOutput = XP_LG_GetSelectedManagedOutput()
        local selectedIndex = lbWaypoints.selection
        if isValidNode selectedOutput and selectedIndex > 1 and selectedIndex <= XP_LG_WaypointNodes.count then
        (
            local candidateNodes = for waypointNode in XP_LG_WaypointNodes collect waypointNode
            local swapNode = candidateNodes[selectedIndex - 1]
            candidateNodes[selectedIndex - 1] = candidateNodes[selectedIndex]
            candidateNodes[selectedIndex] = swapNode
            XP_LG_CommitWaypointChange selectedOutput candidateNodes "上移途经点"
        )
    )

    on btnWaypointDown pressed do
    (
        local selectedOutput = XP_LG_GetSelectedManagedOutput()
        local selectedIndex = lbWaypoints.selection
        if isValidNode selectedOutput and selectedIndex > 0 and selectedIndex < XP_LG_WaypointNodes.count then
        (
            local candidateNodes = for waypointNode in XP_LG_WaypointNodes collect waypointNode
            local swapNode = candidateNodes[selectedIndex + 1]
            candidateNodes[selectedIndex + 1] = candidateNodes[selectedIndex]
            candidateNodes[selectedIndex] = swapNode
            XP_LG_CommitWaypointChange selectedOutput candidateNodes "下移途经点"
        )
    )

    on btnRemoveWaypoint pressed do
    (
        local selectedOutput = XP_LG_GetSelectedManagedOutput()
        local selectedIndex = lbWaypoints.selection
        if isValidNode selectedOutput and selectedIndex > 0 and selectedIndex <= XP_LG_WaypointNodes.count then
        (
            local candidateNodes = for waypointNode in XP_LG_WaypointNodes collect waypointNode
            deleteItem candidateNodes selectedIndex
            XP_LG_CommitWaypointChange selectedOutput candidateNodes "移除途经点"
        )
    )

    on btnClearWaypoints pressed do
    (
        local selectedOutput = XP_LG_GetSelectedManagedOutput()
        if isValidNode selectedOutput and XP_LG_WaypointNodes.count > 0 do XP_LG_CommitWaypointChange selectedOutput #() "清空全部途经点"
    )

    on chkWaypointSmoothing changed state do
    (
        XP_LG_UpdateWaypointSmoothingControlState()
        XP_LG_RequestLiveUpdate "途经点平滑过渡开关"
    )

    on spWaypointSmoothingStrength changed value do XP_LG_RequestLiveUpdate "途经点过渡强度"
    on chkWaypointAutoAddFaces changed state do XP_LG_RequestLiveUpdate "途经点自动加面"

    on spFaces changed value do
    (
        XP_LG_RefreshUI()
        XP_LG_RequestLiveUpdate "平面面数"
    )

    on spWidth changed value do XP_LG_RequestLiveUpdate "闪电宽度"
    on chkTaperEnds changed state do XP_LG_RequestLiveUpdate "面片两端平滑收尖"
    on spTwist changed value do XP_LG_RequestLiveUpdate "路径噪波强度"
    on spNoiseSize changed value do XP_LG_RequestLiveUpdate "噪波大小"
    on spTiling changed value do XP_LG_RequestLiveUpdate "噪波 Tiling"
    on spSeed changed value do XP_LG_RequestLiveUpdate "随机种子"

    on chkWholeTwist changed state do
    (
        XP_LG_UpdateWholeTwistControlState()
        XP_LG_RequestLiveUpdate "轴向扭转开关"
    )

    on spWholeTwistSegments changed value do XP_LG_RequestLiveUpdate "轴向扭转分段"
    on spWholeTwistAmount changed value do XP_LG_RequestLiveUpdate "轴向扭转角度"
    on chkLockStart changed state do XP_LG_RequestLiveUpdate "锁定起点"
    on chkLockEnd changed state do XP_LG_RequestLiveUpdate "锁定终点"

    on btnGenerate pressed do
    (
        XP_LG_RequestLiveUpdate "强制重新生成" showErrors:true immediate:true
    )

    on tmLiveUpdate tick do XP_LG_HandleLiveUpdateTimerTick()

    on XP_LG_Rollout open do
    (
        XP_LG_LiveUpdateBusy = false
        XP_LG_LiveUpdateCurrentDepth = 0
        XP_LG_SuppressLiveUpdate = false
        XP_LG_StopLiveUpdateTimer()
        XP_LG_CancelLiveUpdate()
        XP_LG_StartLiveUpdateTimerLoop()
        XP_LG_RefreshUI()
        callbacks.removeScripts id:#XP_LightningSelectionChanged
        callbacks.addScript #selectionSetChanged "XP_LG_HandleSelectionChanged()" id:#XP_LightningSelectionChanged persistent:false
        XP_LG_HandleSelectionChanged()
    )

    on XP_LG_Rollout close do
    (
        XP_LG_CancelLiveUpdate()
        XP_LG_StopLiveUpdateTimer()
        XP_LG_SuppressLiveUpdate = true
        callbacks.removeScripts id:#XP_LightningSelectionChanged
    )
)

fn XP_LG_ShowUI =
(
    try (destroyDialog XP_LG_Rollout) catch ()
    createDialog XP_LG_Rollout
)

if XP_LG_SuppressUI != true do XP_LG_ShowUI()
