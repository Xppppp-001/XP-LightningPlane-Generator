/* 3ds Max 2023 无界面实机测试 */

-- 几何测试后段会在独立测试进程中临时创建 rollout，以验证实时更新状态机。
global XP_LG_SuppressUI = true
global XP_LG_RequestLiveUpdate
global XP_LG_FlushLiveUpdate
global XP_LG_LiveUpdateTimerError
global XP_LG_GetPathTangent
global XP_LG_LiveUpdateTimerLoopActive
global XP_LG_LiveUpdateRequestTime
global XP_LG_LiveUpdateAttemptCount
global XP_LG_LiveUpdateSuccessCount
global XP_LG_LiveUpdatePending
global XP_LG_LiveUpdateBusy
global XP_LG_LiveUpdateCurrentDepth
global XP_LG_LiveUpdateMaxDepth
global XP_LG_Rollout
global XP_LG_OutputNodes
global XP_LG_EndNodes
global XP_TEST_LastPass = "<尚未通过断言>"

fn XP_TEST_Assert condition message =
(
    if not condition do throw ("[XP_TEST_FAIL] " + message)
    XP_TEST_LastPass = message
    format "[XP_TEST_PASS] %\n" message
)

fn XP_TEST_PointNear valueA valueB tolerance =
(
    (distance valueA valueB) <= tolerance
)

fn XP_TEST_GetWorldCenterFromPair editablePoly leftId rightId startWorld =
(
    ((polyop.getVert editablePoly leftId) + (polyop.getVert editablePoly rightId)) * 0.5 + startWorld
)

fn XP_TEST_CaptureVerts editablePoly =
(
    local values = #()
    for vertexIndex = 1 to (polyop.getNumVerts editablePoly) do append values (polyop.getVert editablePoly vertexIndex)
    values
)

fn XP_TEST_CaptureWorldVerts sceneNode =
(
    local values = #()
    local editablePoly = sceneNode.baseObject
    local objectTM = sceneNode.objectTransform
    for vertexIndex = 1 to (polyop.getNumVerts editablePoly) do append values ((polyop.getVert editablePoly vertexIndex) * objectTM)
    values
)

fn XP_TEST_CaptureMapVerts editablePoly =
(
    local values = #()
    for mapVertexIndex = 1 to (polyop.getNumMapVerts editablePoly 1) do append values (polyop.getMapVert editablePoly 1 mapVertexIndex)
    values
)

fn XP_TEST_VertArraysNear valuesA valuesB tolerance =
(
    if valuesA.count != valuesB.count do return false
    for valueIndex = 1 to valuesA.count do
    (
        if (distance valuesA[valueIndex] valuesB[valueIndex]) > tolerance do return false
    )
    true
)

fn XP_TEST_NumberArraysNear valuesA valuesB tolerance =
(
    if valuesA.count != valuesB.count do return false
    for valueIndex = 1 to valuesA.count do if (abs (valuesA[valueIndex] - valuesB[valueIndex])) > tolerance do return false
    true
)

fn XP_TEST_CaptureBranchCenters editablePoly branchIndex segmentCount startWorld =
(
    local values = #()
    local firstVertexId = (branchIndex - 1) * 2 * (segmentCount + 1) + 1
    for stationIndex = 0 to segmentCount do
    (
        local leftId = firstVertexId + stationIndex * 2
        append values (((polyop.getVert editablePoly leftId) + (polyop.getVert editablePoly (leftId + 1))) * 0.5 + startWorld)
    )
    values
)

fn XP_TEST_CaptureBranchSides editablePoly branchIndex segmentCount =
(
    local values = #()
    local firstVertexId = (branchIndex - 1) * 2 * (segmentCount + 1) + 1
    for stationIndex = 0 to segmentCount do
    (
        local leftId = firstVertexId + stationIndex * 2
        local side = (polyop.getVert editablePoly (leftId + 1)) - (polyop.getVert editablePoly leftId)
        if (length side) <= 0.000001 do return undefined
        append values (normalize side)
    )
    values
)

fn XP_TEST_AllSidesPerpendicular points sides tolerance =
(
    if points == undefined or sides == undefined or points.count != sides.count do return false
    for pointIndex = 1 to points.count do
    (
        local tangent = XP_LG_GetPathTangent points pointIndex
        if tangent == undefined or (abs (dot tangent sides[pointIndex])) > tolerance do return false
        if (abs ((length sides[pointIndex]) - 1.0)) > tolerance do return false
    )
    true
)

fn XP_TEST_AnyVectorDifference valuesA valuesB tolerance =
(
    if valuesA == undefined or valuesB == undefined or valuesA.count != valuesB.count do return false
    for valueIndex = 1 to valuesA.count do
    (
        if (distance valuesA[valueIndex] valuesB[valueIndex]) > tolerance do return true
    )
    false
)

fn XP_TEST_CaptureBranchVerts editablePoly branchIndex segmentCount =
(
    local values = #()
    local firstVertexId = (branchIndex - 1) * 2 * (segmentCount + 1) + 1
    local lastVertexId = firstVertexId + 2 * (segmentCount + 1) - 1
    for vertexId = firstVertexId to lastVertexId do append values (polyop.getVert editablePoly vertexId)
    values
)

fn XP_TEST_AllFacesAndMapFacesValid editablePoly =
(
    local faceCount = polyop.getNumFaces editablePoly
    local mapVertCount = polyop.getNumMapVerts editablePoly 1

    if faceCount < 1 or (polyop.getNumMapFaces editablePoly 1) != faceCount do return false

    for faceIndex = 1 to faceCount do
    (
        local faceVerts = polyop.getFaceVerts editablePoly faceIndex
        local mapFace = polyop.getMapFace editablePoly 1 faceIndex
        if faceVerts.count != 4 or mapFace.count != 4 do return false

        local p1 = polyop.getVert editablePoly faceVerts[1]
        local p2 = polyop.getVert editablePoly faceVerts[2]
        local p3 = polyop.getVert editablePoly faceVerts[3]
        local p4 = polyop.getVert editablePoly faceVerts[4]
        local normal1 = cross (p2 - p1) (p3 - p1)
        local normal2 = cross (p3 - p1) (p4 - p1)

        if (length normal1) <= 0.0000001 or (length normal2) <= 0.0000001 do return false
        if (dot normal1 normal2) <= 0.0 do return false

        for mapVertId in mapFace do
        (
            if mapVertId < 1 or mapVertId > mapVertCount do return false
        )
    )

    true
)

fn XP_TEST_AllMapVValues01 editablePoly =
(
    for mapVertIndex = 1 to (polyop.getNumMapVerts editablePoly 1) do
    (
        local mapPoint = polyop.getMapVert editablePoly 1 mapVertIndex
        if (abs mapPoint.y) > 0.000001 and (abs (mapPoint.y - 1.0)) > 0.000001 do return false
    )
    true
)

fn XP_TEST_MapFacesMatchBranchLayout editablePoly branchCount segmentCount =
(
    for branchIndex = 1 to branchCount do
    (
        local uvBase = (branchIndex - 1) * 2 * (segmentCount + 1)
        local faceBase = (branchIndex - 1) * segmentCount

        for segmentIndex = 1 to segmentCount do
        (
            local actual = polyop.getMapFace editablePoly 1 (faceBase + segmentIndex)
            local uvLeft0 = uvBase + (segmentIndex - 1) * 2 + 1
            local expected = #(uvLeft0, uvLeft0 + 1, uvLeft0 + 3, uvLeft0 + 2)
            if actual.count != 4 do return false
            for cornerIndex = 1 to 4 do
            (
                if actual[cornerIndex] != expected[cornerIndex] do return false
            )
        )
    )
    true
)

fn XP_TEST_BranchFacesAreContinuous editablePoly branchCount segmentCount =
(
    for branchIndex = 1 to branchCount do
    (
        local faceBase = (branchIndex - 1) * segmentCount
        for segmentIndex = 2 to segmentCount do
        (
            local previousFace = polyop.getFaceVerts editablePoly (faceBase + segmentIndex - 1)
            local currentFace = polyop.getFaceVerts editablePoly (faceBase + segmentIndex)
            local sharedCount = 0
            for vertexId in previousFace do
            (
                if (findItem currentFace vertexId) > 0 do sharedCount = sharedCount + 1
            )
            if sharedCount != 2 do return false
        )
    )
    true
)

fn XP_TEST_AllBranchUVsForward editablePoly branchCount segmentCount =
(
    for branchIndex = 1 to branchCount do
    (
        local uvBase = (branchIndex - 1) * 2 * (segmentCount + 1)
        local previousU = -1.0

        for stationIndex = 0 to segmentCount do
        (
            local leftUV = polyop.getMapVert editablePoly 1 (uvBase + stationIndex * 2 + 1)
            local rightUV = polyop.getMapVert editablePoly 1 (uvBase + stationIndex * 2 + 2)
            if (abs (leftUV.x - rightUV.x)) > 0.000001 do return false
            if leftUV.x <= previousU do return false
            if (abs leftUV.y) > 0.000001 or (abs (rightUV.y - 1.0)) > 0.000001 do return false
            previousU = leftUV.x
        )

        local firstU = (polyop.getMapVert editablePoly 1 (uvBase + 1)).x
        local lastU = (polyop.getMapVert editablePoly 1 (uvBase + segmentCount * 2 + 1)).x
        if (abs firstU) > 0.000001 or (abs (lastU - 1.0)) > 0.000001 do return false
    )
    true
)

fn XP_TEST_CountManagedOutputs =
(
    local managedCount = 0
    for sceneNode in objects do
    (
        local generatorMarker = undefined
        try (generatorMarker = getUserProp sceneNode "XP_LightningGenerator") catch (generatorMarker = undefined)
        if generatorMarker == "1.2.0" do managedCount = managedCount + 1
    )
    managedCount
)

fn XP_TEST_CountActiveOutputs =
(
    local activeCount = 0
    for sceneNode in objects do
    (
        local activeMarker = undefined
        try (activeMarker = getUserProp sceneNode "XP_LightningActiveSet") catch (activeMarker = undefined)
        if activeMarker == true or activeMarker == "true" do activeCount = activeCount + 1
    )
    activeCount
)

fn XP_TEST_CountTemporaryOutputs =
(
    local temporaryCount = 0
    for sceneNode in objects do
    (
        if matchPattern sceneNode.name pattern:"XP_Lightning_Temp*" ignoreCase:false do temporaryCount = temporaryCount + 1
    )
    temporaryCount
)

fn XP_TEST_FindOutputForEnd endNode =
(
    local endHandleText = (getHandleByAnim endNode) as string
    for outputNode in XP_LG_OutputNodes do
    (
        if isValidNode outputNode do
        (
            local storedEndHandle = getUserProp outputNode "XP_LightningEndHandle"
            if storedEndHandle != undefined and (storedEndHandle as string) == endHandleText do return outputNode
        )
    )
    undefined
)

fn XP_TEST_TotalOutputFaces =
(
    local totalFaces = 0
    for outputNode in XP_LG_OutputNodes do if isValidNode outputNode do totalFaces = totalFaces + polyop.getNumFaces outputNode.baseObject
    totalFaces
)

fn XP_TEST_AllIndependentOutputsValid expectedCount segmentCount =
(
    if XP_LG_OutputNodes.count != expectedCount do return false
    for outputNode in XP_LG_OutputNodes do
    (
        if not isValidNode outputNode do return false
        local editablePoly = outputNode.baseObject
        if (polyop.getNumFaces editablePoly) != segmentCount or (polyop.getNumVerts editablePoly) != 2 * (segmentCount + 1) do return false
        if not (XP_TEST_AllFacesAndMapFacesValid editablePoly) do return false
        if not (XP_TEST_MapFacesMatchBranchLayout editablePoly 1 segmentCount) do return false
        if not (XP_TEST_BranchFacesAreContinuous editablePoly 1 segmentCount) do return false
        if not (XP_TEST_AllBranchUVsForward editablePoly 1 segmentCount) do return false
    )
    true
)

fn XP_TEST_RequestAndFlush reasonText =
(
    local attemptBefore = XP_LG_LiveUpdateAttemptCount
    local successBefore = XP_LG_LiveUpdateSuccessCount
    local requestAccepted = XP_LG_RequestLiveUpdate reasonText
    local timerActive = false
    try (timerActive = XP_LG_Rollout.tmLiveUpdate.active) catch ()
    local timerDiagnostic = "；TimerError=" + XP_LG_LiveUpdateTimerError + "；Loop=" + XP_LG_LiveUpdateTimerLoopActive as string + "；ActiveRead=" + timerActive as string + "；RequestTime=" + XP_LG_LiveUpdateRequestTime as string + "；Now=" + timeStamp() as string + "；Attempt=" + XP_LG_LiveUpdateAttemptCount as string + "；Before=" + attemptBefore as string

    XP_TEST_Assert (requestAccepted == true) ("实时更新请求已排队：" + reasonText)
    XP_TEST_Assert (XP_LG_LiveUpdatePending == true) ("实时更新请求处于待处理状态：" + reasonText + timerDiagnostic)
    XP_TEST_Assert (XP_LG_LiveUpdateAttemptCount == attemptBefore) ("仅请求不会立即重建：" + reasonText)

    local flushResult = XP_LG_FlushLiveUpdate()
    XP_TEST_Assert (isValidNode flushResult) ("显式刷新成功：" + reasonText)
    XP_TEST_Assert (XP_LG_LiveUpdatePending == false) ("刷新后已消费待处理请求：" + reasonText)
    XP_TEST_Assert (XP_LG_LiveUpdateBusy == false and XP_LG_LiveUpdateCurrentDepth == 0) ("刷新后重入状态已复位：" + reasonText)
    XP_TEST_Assert (XP_LG_LiveUpdateAttemptCount == attemptBefore + 1) ("一次刷新只尝试一次替换：" + reasonText)
    XP_TEST_Assert (XP_LG_LiveUpdateSuccessCount == successBefore + 1) ("一次刷新只提交一个有效结果：" + reasonText)
    XP_TEST_Assert (XP_LG_LiveUpdateMaxDepth <= 1) ("实时更新最大生成深度不超过 1：" + reasonText)
    XP_TEST_Assert ((XP_TEST_CountActiveOutputs()) == XP_LG_EndNodes.count and (XP_TEST_CountTemporaryOutputs()) == 0) ("实时更新后每个终点只有一个活动模型且无半成品：" + reasonText)
    true
)

resetMaxFile #noPrompt
fileIn "E:/CodeXProject/3dsmaxLightning/src/XP_LightningGenerator.ms" quiet:true

XP_TEST_Assert (XP_LG_Rollout != undefined) "主脚本成功加载且未打开交互界面"

startNode = Point name:"测试起点" pos:[10.0, 20.0, 30.0] size:5.0
endNodeA = Point name:"测试终点A" pos:[130.0, 35.0, 55.0] size:5.0
endNodeB = Point name:"测试终点B" pos:[-20.0, 150.0, 85.0] size:5.0

XP_TEST_Assert (XP_LG_PickFilter startNode == true and XP_LG_PickFilter endNodeA == true) "干净会话首次加载后拾取过滤器可接受普通场景节点"

XP_LG_StartNode = startNode
XP_LG_EndNodes = #(endNodeA, endNodeB)

resultNode = XP_LG_ReplaceOutput XP_LG_StartNode XP_LG_EndNodes 8 4.0 18.0 1.0 1.5 42 true true
XP_TEST_Assert (isValidNode resultNode) "多终点闪电生成成功"

outputNodeA = XP_TEST_FindOutputForEnd endNodeA
outputNodeB = XP_TEST_FindOutputForEnd endNodeB
editablePoly = outputNodeA.baseObject
editablePolyB = outputNodeB.baseObject
startWorld = XP_LG_GetWorldCenter startNode
endWorldA = XP_LG_GetWorldCenter endNodeA
endWorldB = XP_LG_GetWorldCenter endNodeB

XP_TEST_Assert (isValidNode outputNodeA and isValidNode outputNodeB and outputNodeA != outputNodeB) "两个终点生成两个互不合并的独立对象"
XP_TEST_Assert (XP_LG_PickFilter outputNodeA == false and XP_LG_PickFilter outputNodeB == false) "拾取过滤器拒绝插件生成的闪电面片"
XP_TEST_Assert (outputNodeA.name == "LightningPlane001" and outputNodeB.name == "LightningPlane002") "空场景首次生成的独立面片依次使用 LightningPlane 三位序号命名"
XP_TEST_Assert ((classOf editablePoly) == Editable_Poly and (classOf editablePolyB) == Editable_Poly) "每个输出均为 Editable Poly"
XP_TEST_Assert (XP_TEST_AllIndependentOutputsValid 2 8 and (XP_TEST_TotalOutputFaces()) == 16) "两条独立分支各有 8 个真四边面且总面数为 16"
XP_TEST_Assert (XP_TEST_AllMapVValues01 editablePoly and XP_TEST_AllMapVValues01 editablePolyB) "每个独立对象的 UV V 值均覆盖 0 或 1"

for faceIndex = 1 to 8 do
(
    XP_TEST_Assert ((polyop.getFaceVerts editablePoly faceIndex).count == 4) ("几何面 " + faceIndex as string + " 为四边面")
    XP_TEST_Assert ((polyop.getMapFace editablePoly 1 faceIndex).count == 4) ("UV 面 " + faceIndex as string + " 为四边面")
)

XP_TEST_Assert (XP_TEST_PointNear outputNodeA.transform.row4 startWorld 0.00001 and XP_TEST_PointNear outputNodeB.transform.row4 startWorld 0.00001) "每个独立输出对象的轴心均位于公共起点中心"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair editablePoly 1 2 startWorld) startWorld 0.00001) "第一条分支锁定起点精确"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair editablePoly 17 18 startWorld) endWorldA 0.00001) "第一条分支锁定终点精确"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair editablePolyB 1 2 startWorld) startWorld 0.00001) "第二条分支锁定起点精确"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair editablePolyB 17 18 startWorld) endWorldB 0.00001) "第二条分支锁定终点精确"

XP_TEST_Assert ((polyop.getMapVert editablePoly 1 1).x == 0.0) "第一条分支 UV 从 U=0 开始"
XP_TEST_Assert ((polyop.getMapVert editablePoly 1 17).x == 1.0) "第一条分支 UV 在 U=1 结束"
XP_TEST_Assert ((polyop.getMapVert editablePolyB 1 1).x == 0.0) "第二条分支 UV 从 U=0 开始"
XP_TEST_Assert ((polyop.getMapVert editablePolyB 1 17).x == 1.0) "第二条分支 UV 在 U=1 结束"

previousU = -1.0
for uvIndex = 1 to 17 by 2 do
(
    currentU = (polyop.getMapVert editablePoly 1 uvIndex).x
    XP_TEST_Assert (currentU > previousU) "第一条分支 U 值严格递增"
    previousU = currentU
)

previousU = -1.0
for uvIndex = 1 to 17 by 2 do
(
    currentU = (polyop.getMapVert editablePolyB 1 uvIndex).x
    XP_TEST_Assert (currentU > previousU) "第二条分支 U 值严格递增"
    previousU = currentU
)

capturedA = XP_TEST_CaptureVerts editablePoly
initialOutputNameA = outputNodeA.name
initialOutputNameB = outputNodeB.name
repeatNode = XP_LG_ReplaceOutput XP_LG_StartNode XP_LG_EndNodes 8 4.0 18.0 1.0 1.5 42 true true
capturedB = XP_TEST_CaptureVerts repeatNode.baseObject
XP_TEST_Assert (XP_TEST_VertArraysNear capturedA capturedB 0.000001) "相同参数和随机种子可复现相同几何"
XP_TEST_Assert ((XP_TEST_FindOutputForEnd endNodeA).name == initialOutputNameA and (XP_TEST_FindOutputForEnd endNodeB).name == initialOutputNameB) "参数重建后同一终点继承原面片名称"
(XP_TEST_FindOutputForEnd endNodeA).name = "用户自定义闪电A"
customNamedNode = XP_LG_ReplaceOutput XP_LG_StartNode XP_LG_EndNodes 8 5.0 18.0 1.0 1.5 42 true true
XP_TEST_Assert ((XP_TEST_FindOutputForEnd endNodeA).name == "用户自定义闪电A" and (XP_TEST_FindOutputForEnd endNodeB).name == initialOutputNameB) "用户手动修改的分支名称在参数重建后保持不变"
(XP_TEST_FindOutputForEnd endNodeA).name = initialOutputNameA

originalEndAPosition = endNodeA.pos
endNodeA.pos = [170.0, 60.0, 75.0]
movedEndNode = XP_LG_ReplaceOutput startNode #(endNodeA) 8 4.0 18.0 1.0 1.5 42 true true
movedEndWorld = XP_LG_GetWorldCenter endNodeA
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair movedEndNode.baseObject 17 18 startWorld) movedEndWorld 0.00001) "移动终点后可正确重新生成"
endNodeA.pos = originalEndAPosition

originalStartPosition = startNode.pos
startNode.pos = [25.0, -15.0, 45.0]
movedStartWorld = XP_LG_GetWorldCenter startNode
movedStartNode = XP_LG_ReplaceOutput startNode #(endNodeA) 8 4.0 18.0 1.0 1.5 42 true true
XP_TEST_Assert (XP_TEST_PointNear movedStartNode.transform.row4 movedStartWorld 0.00001) "移动起点后轴心随新起点正确更新"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair movedStartNode.baseObject 1 2 movedStartWorld) movedStartWorld 0.00001) "移动起点后锁定位置正确"
startNode.pos = originalStartPosition
startWorld = XP_LG_GetWorldCenter startNode

deletedEndpoint = Point name:"待删除终点" pos:[50.0, 80.0, 120.0] size:5.0
XP_LG_EndNodes = #(endNodeA, deletedEndpoint)
delete deletedEndpoint
XP_LG_CleanEndNodes()
XP_TEST_Assert (XP_LG_EndNodes.count == 1 and XP_LG_EndNodes[1] == endNodeA) "已删除终点会被自动清理且不遗留无效引用"
cleanedNode = XP_LG_ReplaceOutput startNode XP_LG_EndNodes 8 4.0 18.0 1.0 1.5 42 true true
XP_TEST_Assert (isValidNode cleanedNode and (polyop.getNumFaces cleanedNode.baseObject) == 8) "清理失效终点后仍可用剩余终点重新生成"
XP_LG_EndNodes = #()
XP_LG_CleanEndNodes()
XP_TEST_Assert (XP_LG_EndNodes.count == 0) "清空终点后状态中不保留无效引用"
XP_LG_EndNodes = #(endNodeA, endNodeB)

clearTestNode = XP_LG_ReplaceOutput startNode XP_LG_EndNodes 8 4.0 18.0 1.0 1.5 42 true true
XP_TEST_Assert (isValidNode clearTestNode) "清空操作测试前已有当前闪电模型"
XP_LG_DeleteOutput()
XP_TEST_Assert (not isValidNode clearTestNode and XP_LG_OutputNode == undefined) "内部显式删除入口可清理当前活动模型"

singleNode = XP_LG_ReplaceOutput startNode #(endNodeA) 1 4.0 18.0 1.0 1.5 99 true true
singlePoly = singleNode.baseObject
XP_TEST_Assert ((polyop.getNumFaces singlePoly) == 1) "平面面数 1 时恰好生成一个四边面"
XP_TEST_Assert ((polyop.getNumVerts singlePoly) == 4) "平面面数 1 时恰好生成四个顶点"
XP_TEST_Assert ((polyop.getNumMapFaces singlePoly 1) == 1) "平面面数 1 时恰好生成一个 UV 面"
XP_TEST_Assert (XP_TEST_AllFacesAndMapFacesValid singlePoly) "最低面数下四边面和 UV 索引有效"
XP_TEST_Assert (XP_TEST_MapFacesMatchBranchLayout singlePoly 1 1) "最低面数下 UV 面索引正确"

endNodeC = Point name:"测试终点C" pos:[95.0, -110.0, 160.0] size:5.0
highNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB, endNodeC) 64 3.0 20.0 1.0 3.0 123 true true
highPoly = highNode.baseObject
XP_TEST_Assert (XP_TEST_AllIndependentOutputsValid 3 64) "较高面数下三个独立分支对象的拓扑和 UV 均有效"
XP_TEST_Assert ((XP_TEST_TotalOutputFaces()) == 192) "三条独立分支在较高面数下总面数等于 64 × 3"
XP_TEST_Assert ((XP_TEST_FindOutputForEnd endNodeA).name == "LightningPlane001" and (XP_TEST_FindOutputForEnd endNodeB).name == "LightningPlane002" and (XP_TEST_FindOutputForEnd endNodeC).name == "LightningPlane003") "首次加入第三终点后独立对象保持 LightningPlane001 至 003 顺序"
highNameA = (XP_TEST_FindOutputForEnd endNodeA).name
highNameB = (XP_TEST_FindOutputForEnd endNodeB).name
highNameC = (XP_TEST_FindOutputForEnd endNodeC).name
nameRemovalNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeC) 64 3.0 20.0 1.0 3.0 123 true true
XP_TEST_Assert ((XP_TEST_FindOutputForEnd endNodeA).name == highNameA and (XP_TEST_FindOutputForEnd endNodeC).name == highNameC) "移除终点后保留分支的名称不变"
nameReAddNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB, endNodeC) 64 3.0 20.0 1.0 3.0 123 true true
reAddedNameB = (XP_TEST_FindOutputForEnd endNodeB).name
XP_TEST_Assert ((XP_TEST_FindOutputForEnd endNodeA).name == highNameA and (XP_TEST_FindOutputForEnd endNodeC).name == highNameC and (matchPattern reAddedNameB pattern:"LightningPlane*" ignoreCase:false) and reAddedNameB != highNameA and reAddedNameB != highNameC) "重新添加终点只分配新的 LightningPlane 序号且不重排其他名称"

thinNode = XP_LG_ReplaceOutput startNode #(endNodeA) 12 2.0 15.0 1.0 2.0 77 true true
thinPoly = thinNode.baseObject
thinMidpoint = (polyop.getVert thinPoly 13 + polyop.getVert thinPoly 14) * 0.5
thinWidth = distance (polyop.getVert thinPoly 13) (polyop.getVert thinPoly 14)
wideNode = XP_LG_ReplaceOutput startNode #(endNodeA) 12 10.0 15.0 1.0 2.0 77 true true
widePoly = wideNode.baseObject
wideMidpoint = (polyop.getVert widePoly 13 + polyop.getVert widePoly 14) * 0.5
wideWidth = distance (polyop.getVert widePoly 13) (polyop.getVert widePoly 14)
XP_TEST_Assert ((abs (thinWidth - 2.0)) <= 0.00001 and (abs (wideWidth - 10.0)) <= 0.00001) "调整宽度后面片宽度与输入一致"
XP_TEST_Assert (XP_TEST_PointNear thinMidpoint wideMidpoint 0.00001) "调整宽度不会改变路径中心线"
XP_TEST_Assert (XP_TEST_AllFacesAndMapFacesValid widePoly) "调整宽度后拓扑与 UV 仍然有效"

baseParamNode = XP_LG_ReplaceOutput startNode #(endNodeA) 16 4.0 10.0 1.0 1.0 321 true true
baseParamVerts = XP_TEST_CaptureVerts baseParamNode.baseObject
twistParamNode = XP_LG_ReplaceOutput startNode #(endNodeA) 16 4.0 25.0 1.0 1.0 321 true true
twistParamVerts = XP_TEST_CaptureVerts twistParamNode.baseObject
noiseSizeNode = XP_LG_ReplaceOutput startNode #(endNodeA) 16 4.0 10.0 2.0 1.0 321 true true
noiseSizeVerts = XP_TEST_CaptureVerts noiseSizeNode.baseObject
tilingNode = XP_LG_ReplaceOutput startNode #(endNodeA) 16 4.0 10.0 1.0 4.0 321 true true
tilingVerts = XP_TEST_CaptureVerts tilingNode.baseObject
XP_TEST_Assert (not XP_TEST_VertArraysNear baseParamVerts twistParamVerts 0.0001) "路径噪波强度会改变中心线路径偏移幅度"
XP_TEST_Assert (not XP_TEST_VertArraysNear baseParamVerts noiseSizeVerts 0.0001) "噪波大小会改变路径偏移幅度和整体尺寸"
XP_TEST_Assert (not XP_TEST_VertArraysNear baseParamVerts tilingVerts 0.0001) "噪波 Tiling 会改变路径弯折密度"

wholeBranchKey = XP_LG_GetBranchKey endNodeA 1
wholeBranchKeyAfterReorder = XP_LG_GetBranchKey endNodeA 2
XP_TEST_Assert (wholeBranchKey == wholeBranchKeyAfterReorder) "细噪波中心线使用终点稳定标识而非分支顺序"

wholeFinePoints = XP_LG_BuildCenterline startWorld endWorldA 32 12.0 1.0 1.0 2026 wholeBranchKey true true
wholeAdaptiveData = XP_LG_BuildAdaptiveCenterline startWorld endWorldA 32 12.0 1.0 1.0 2026 wholeBranchKey true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:120.0
wholeAdaptivePoints = wholeAdaptiveData[1]
wholeAdaptiveParameters = wholeAdaptiveData[2]
wholeBaseSides = XP_LG_BuildRibbonSides wholeFinePoints
wholeTwistedSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 120.0 true true
XP_TEST_Assert (XP_TEST_AllSidesPerpendicular wholeFinePoints wholeBaseSides 0.00001 and XP_TEST_AllSidesPerpendicular wholeFinePoints wholeTwistedSides 0.00001) "轴向 Twist 前后宽度方向均垂直于中心线局部切线且保持单位长度"
XP_TEST_Assert (XP_TEST_AnyVectorDifference wholeBaseSides wholeTwistedSides 0.0001) "真正的轴向 Twist 会旋转面片宽度方向"

wholeDisabledMeshNode = XP_LG_ReplaceOutput startNode #(endNodeA) 32 4.0 12.0 1.0 1.0 2026 true true wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:120.0
wholeDisabledMeshVerts = XP_TEST_CaptureVerts wholeDisabledMeshNode.baseObject
wholeDisabledMapVerts = XP_TEST_CaptureMapVerts wholeDisabledMeshNode.baseObject
wholeZeroMeshNode = XP_LG_ReplaceOutput startNode #(endNodeA) 32 4.0 12.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:0.0
XP_TEST_Assert (XP_TEST_VertArraysNear wholeDisabledMeshVerts (XP_TEST_CaptureVerts wholeZeroMeshNode.baseObject) 0.000001) "轴向扭转角度为 0 时输出模型与关闭功能完全一致"
XP_TEST_Assert (XP_TEST_VertArraysNear wholeDisabledMapVerts (XP_TEST_CaptureMapVerts wholeZeroMeshNode.baseObject) 0.000001) "轴向扭转角度为 0 时 UV 与关闭功能完全一致"

wholeTwistedMeshNode = XP_LG_ReplaceOutput startNode #(endNodeA) 32 4.0 12.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:120.0
XP_TEST_Assert (isValidNode wholeTwistedMeshNode) ("120 度／32 面的正常轴向 Twist 通过抗折叠检查；" + XP_LG_LastError)
wholeTwistedMeshVerts = XP_TEST_CaptureVerts wholeTwistedMeshNode.baseObject
wholeTwistedCenters = XP_TEST_CaptureBranchCenters wholeTwistedMeshNode.baseObject 1 32 startWorld
wholeTwistedMapVerts = XP_TEST_CaptureMapVerts wholeTwistedMeshNode.baseObject
XP_TEST_Assert (not XP_TEST_VertArraysNear wholeDisabledMeshVerts wholeTwistedMeshVerts 0.0001) "启用轴向 Twist 后模型顶点朝向发生可见变化"
XP_TEST_Assert (XP_TEST_VertArraysNear wholeAdaptivePoints wholeTwistedCenters 0.00001) "轴向 Twist 只旋转面片截面，不改变自适应采样后的细噪波中心线"
XP_TEST_Assert (XP_TEST_AllBranchUVsForward wholeTwistedMeshNode.baseObject 1 32 and XP_TEST_AllMapVValues01 wholeTwistedMeshNode.baseObject) "轴向 Twist 自适应重排线环后仍保持从左到右的 0–1 UV 展开"
XP_TEST_Assert ((polyop.getNumFaces wholeTwistedMeshNode.baseObject) == 32 and (polyop.getNumVerts wholeTwistedMeshNode.baseObject) == 66) "轴向 Twist 不改变用户指定的平面面数和顶点数量"
XP_TEST_Assert ((getUserProp wholeTwistedMeshNode "XP_LightningTwistMode") == "Axial") "输出模型记录为真正的轴向 Twist 模式"
XP_TEST_Assert ((getUserProp wholeTwistedMeshNode "XP_LightningTwistMapping") == "FFDEqualSegmentsParallelTransport") "输出模型记录为等距逐段 FFD 与平行运输映射模式"

wholeOneSegmentSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 1 120.0 false false
wholeFourSegmentSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 120.0 false false
XP_TEST_Assert (XP_TEST_AnyVectorDifference wholeOneSegmentSides wholeFourSegmentSides 0.0001) "轴向扭转分段会改变旋转沿路径的缓入缓出分布"
XP_TEST_Assert (wholeOneSegmentSides.count == wholeFourSegmentSides.count and wholeOneSegmentSides.count == wholeFinePoints.count) "轴向扭转分段不会增加中心线采样点或平面面数"

wholePositiveSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 120.0 false false
wholeNegativeSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 (-120.0) false false
wholeZeroSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 0.0 false false
XP_TEST_Assert (XP_TEST_AnyVectorDifference wholePositiveSides wholeNegativeSides 0.0001) "轴向扭转角度正负值产生相反旋转方向"
XP_TEST_Assert (XP_TEST_VertArraysNear wholeBaseSides wholeZeroSides 0.000001) "轴向扭转角度为 0 时宽度方向与未启用完全一致"

wholeBothLockedSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 120.0 true true
wholeStartLockedSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 120.0 true false
wholeEndLockedSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 120.0 false true
wholeBothUnlockedSides = XP_LG_BuildAxiallyTwistedSides wholeFinePoints wholeBaseSides 4 120.0 false false
XP_TEST_Assert ((XP_LG_ComputeAxialTwistAngle 0.0 4 120.0 true true) == 0.0 and (XP_LG_ComputeAxialTwistAngle 1.0 4 120.0 true true) == 0.0) "两端锁定时起终点轴向扭转角精确为零"
XP_TEST_Assert ((abs ((XP_LG_ComputeAxialTwistAngle (1.0 / 3.0) 2 30.0 true false) - 30.0)) < 0.00001 and (abs ((XP_LG_ComputeAxialTwistAngle (2.0 / 3.0) 2 30.0 true false) - 60.0)) < 0.00001) "Twist 分段 2 将长度三等分且前两段各累计一次输入角度"
XP_TEST_Assert ((abs ((XP_LG_ComputeAxialTwistAngle 1.0 10 120.0 true false) - 1200.0)) < 0.00001) "未锁定终点时总累计角等于分段数乘以每段角度"
XP_TEST_Assert ((abs ((XP_LG_ComputeAxialTwistAngle (5.0 / 6.0) 2 30.0 true true) - 30.0)) < 0.00001 and (XP_LG_ComputeAxialTwistAngle 1.0 2 30.0 true true) == 0.0) "锁定终点时最后一个等长区间平滑回正"
XP_TEST_Assert ((abs (XP_LG_ShortestAngleDelta 1200.0 0.0)) == 120.0 and (abs (XP_LG_ShortestAngleDelta 359.0 1.0)) == 2.0) "Twist 布线安全检查使用跨整圈的最短等价角差"
XP_TEST_Assert (XP_TEST_PointNear wholeBothLockedSides[1] wholeBaseSides[1] 0.000001 and XP_TEST_PointNear wholeBothLockedSides[wholeBothLockedSides.count] wholeBaseSides[wholeBaseSides.count] 0.000001) "两端锁定时起终点面片朝向与未扭转一致"
XP_TEST_Assert (XP_TEST_PointNear wholeStartLockedSides[1] wholeBaseSides[1] 0.000001 and (distance wholeStartLockedSides[wholeStartLockedSides.count] wholeBaseSides[wholeBaseSides.count]) > 0.0001) "仅锁定起点时起点 Twist 为零且终点朝向可受影响"
XP_TEST_Assert ((distance wholeEndLockedSides[1] wholeBaseSides[1]) > 0.0001 and XP_TEST_PointNear wholeEndLockedSides[wholeEndLockedSides.count] wholeBaseSides[wholeBaseSides.count] 0.000001) "仅锁定终点时终点 Twist 为零且起点朝向可受影响"
XP_TEST_Assert ((distance wholeBothUnlockedSides[1] wholeBaseSides[1]) > 0.0001 and (distance wholeBothUnlockedSides[wholeBothUnlockedSides.count] wholeBaseSides[wholeBaseSides.count]) > 0.0001) "两端未锁定时 Twist 可影响两个端点的面片朝向"
XP_TEST_Assert ((XP_LG_ComputeAxialTwistAngle 0.01 4 120.0 true false) < (XP_LG_ComputeAxialTwistAngle 0.05 4 120.0 true false)) "锁定起点附近的轴向 Twist 平滑递增"
XP_TEST_Assert ((abs (XP_LG_ComputeAxialTwistAngle 0.99 4 120.0 false true)) < (abs (XP_LG_ComputeAxialTwistAngle 0.95 4 120.0 false true))) "锁定终点附近的轴向 Twist 平滑衰减"

wholeOtherSeedPoints = XP_LG_BuildCenterline startWorld endWorldA 32 12.0 1.0 1.0 2027 wholeBranchKey true true
XP_TEST_Assert (not XP_TEST_VertArraysNear wholeFinePoints wholeOtherSeedPoints 0.0001) "改变随机种子只会改变细噪波中心线"
XP_TEST_Assert ((XP_LG_ComputeAxialTwistAngle 0.37 4 120.0 false false) == (XP_LG_ComputeAxialTwistAngle 0.37 4 120.0 false false)) "轴向 Twist 角度规律不依赖随机噪波或随机种子"

ffdStraightPoints = #([0.0,0.0,0.0],[10.0,0.0,0.0],[20.0,0.0,0.0],[30.0,0.0,0.0],[40.0,0.0,0.0])
ffdCurvedPoints = #([0.0,0.0,0.0],[9.0,2.0,0.0],[17.0,7.0,2.0],[23.0,15.0,5.0],[28.0,24.0,9.0])
ffdStraightBase = XP_LG_BuildParallelTransportSides ffdStraightPoints
ffdCurvedBase = XP_LG_BuildParallelTransportSides ffdCurvedPoints
ffdStraightTwisted = XP_LG_BuildAxiallyTwistedSides ffdStraightPoints ffdStraightBase 3 75.0 true true
ffdCurvedTwisted = XP_LG_BuildAxiallyTwistedSides ffdCurvedPoints ffdCurvedBase 3 75.0 true true
ffdExpectedCosine = cos (XP_LG_ComputeAxialTwistAngle 0.5 3 75.0 true true)
XP_TEST_Assert ((abs ((dot ffdStraightBase[3] ffdStraightTwisted[3]) - ffdExpectedCosine)) < 0.00001 and (abs ((dot ffdCurvedBase[3] ffdCurvedTwisted[3]) - ffdExpectedCosine)) < 0.00001) "直线与弯曲路径在同一逻辑位置应用相同 FFD Twist 角，曲率不会放大角度"
ffdFrameContinuous = true
for pointIndex = 2 to ffdCurvedBase.count do if (dot ffdCurvedBase[pointIndex - 1] ffdCurvedBase[pointIndex]) <= 0.0 do ffdFrameContinuous = false
XP_TEST_Assert ffdFrameContinuous "最小旋转平行运输框架沿弯曲路径连续且不翻转"

wholeSingleDisabledNode = XP_LG_ReplaceOutput startNode #(endNodeA) 1 3.0 0.0 1.0 1.0 2026 true true wholeTwistEnabled:false wholeTwistSegments:4 wholeTwistAmount:120.0
wholeSingleDisabledVerts = XP_TEST_CaptureVerts wholeSingleDisabledNode.baseObject
wholeSingleEnabledNode = XP_LG_ReplaceOutput startNode #(endNodeA) 1 3.0 0.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:120.0
XP_TEST_Assert (XP_TEST_VertArraysNear wholeSingleDisabledVerts (XP_TEST_CaptureVerts wholeSingleEnabledNode.baseObject) 0.000001) "平面面数为 1 且两端锁定时轴向 Twist 不产生可见效果"

wholeLowMeshNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB, endNodeC) 1 3.0 0.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:120.0
XP_TEST_Assert (XP_TEST_AllIndependentOutputsValid 3 1 and (XP_TEST_TotalOutputFaces()) == 3) "轴向 Twist 下三终点最低面数分别生成有效独立对象"

wholeMediumMeshNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB, endNodeC) 8 3.0 0.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:2 wholeTwistAmount:20.0
XP_TEST_Assert (XP_TEST_AllIndependentOutputsValid 3 8 and (XP_TEST_TotalOutputFaces()) == 24) "轴向 Twist 下三终点中等面数分别生成拓扑连续且 UV 正确的独立对象"

wholeHighMeshNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB, endNodeC) 64 3.0 0.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:8 wholeTwistAmount:45.0
XP_TEST_Assert (XP_TEST_AllIndependentOutputsValid 3 64 and (XP_TEST_TotalOutputFaces()) == 192) "轴向 Twist 下三终点较高面数分别生成拓扑连续且 UV 正确的独立对象"

wholeOrderABNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB) 16 3.0 8.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:45.0
wholeBranchAFirst = XP_TEST_CaptureBranchVerts (XP_TEST_FindOutputForEnd endNodeA).baseObject 1 16
wholeOrderBANode = XP_LG_ReplaceOutput startNode #(endNodeB, endNodeA) 16 3.0 8.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:45.0
wholeBranchASecond = XP_TEST_CaptureBranchVerts (XP_TEST_FindOutputForEnd endNodeA).baseObject 1 16
XP_TEST_Assert (XP_TEST_VertArraysNear wholeBranchAFirst wholeBranchASecond 0.000001) "多终点重新排序不会改变同一终点的细噪波中心线和轴向 Twist"

-- R-009：两端平滑收尖只改变截面宽度，不改变中心线、面数或 UV。
taperOffNode = XP_LG_ReplaceOutput startNode #(endNodeA) 32 4.0 12.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:120.0 taperEnds:false
taperOffVerts = XP_TEST_CaptureVerts taperOffNode.baseObject
taperOffCenters = XP_TEST_CaptureBranchCenters taperOffNode.baseObject 1 32 startWorld
taperOffMapVerts = XP_TEST_CaptureMapVerts taperOffNode.baseObject
taperOnNode = XP_LG_ReplaceOutput startNode #(endNodeA) 32 4.0 12.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:120.0 taperEnds:true
taperOnPoly = taperOnNode.baseObject
taperOnCenters = XP_TEST_CaptureBranchCenters taperOnPoly 1 32 startWorld
taperStartWidth = distance (polyop.getVert taperOnPoly 1) (polyop.getVert taperOnPoly 2)
taperNearStartWidth1 = distance (polyop.getVert taperOnPoly 3) (polyop.getVert taperOnPoly 4)
taperNearStartWidth2 = distance (polyop.getVert taperOnPoly 5) (polyop.getVert taperOnPoly 6)
taperMidWidth = distance (polyop.getVert taperOnPoly 33) (polyop.getVert taperOnPoly 34)
taperEndWidth = distance (polyop.getVert taperOnPoly 65) (polyop.getVert taperOnPoly 66)
XP_TEST_Assert ((abs (taperStartWidth - 0.04)) < 0.00001 and (abs (taperEndWidth - 0.04)) < 0.00001) "开启收尖后起点和终点宽度为正常宽度的 1%"
XP_TEST_Assert (taperNearStartWidth1 > taperStartWidth and taperNearStartWidth2 > taperNearStartWidth1 and (abs (taperMidWidth - 4.0)) < 0.00001) "收尖宽度在端点附近平滑增大且中段保持用户宽度"
XP_TEST_Assert (XP_TEST_VertArraysNear taperOffCenters taperOnCenters 0.00001) "两端收尖不改变细噪波中心线"
XP_TEST_Assert (XP_TEST_VertArraysNear taperOffMapVerts (XP_TEST_CaptureMapVerts taperOnPoly) 0.000001) "两端收尖不改变从左到右的 UV 布局"
XP_TEST_Assert ((polyop.getNumFaces taperOnPoly) == 32 and (polyop.getNumVerts taperOnPoly) == 66 and XP_TEST_AllFacesAndMapFacesValid taperOnPoly) "两端收尖与轴向 Twist 同时启用时面数、顶点数和四边面均有效"
XP_TEST_Assert ((getUserProp taperOnNode "XP_LightningTaperEnds") == true) "输出模型记录两端收尖状态"

taperSingleNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB, endNodeC) 1 3.0 0.0 1.0 1.0 2026 true true taperEnds:true
XP_TEST_Assert (XP_TEST_AllIndependentOutputsValid 3 1) "三终点每支 1 面收尖时分别生成窄但不退化的有效四边面和 UV"
taperMediumNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB, endNodeC) 8 3.0 0.0 1.0 1.0 2026 true true taperEnds:true
XP_TEST_Assert (XP_TEST_AllIndependentOutputsValid 3 8) "三终点每支 8 面收尖时分别生成拓扑和 UV 有效的独立对象"
taperHighNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB, endNodeC) 64 3.0 0.0 1.0 1.0 2026 true true wholeTwistEnabled:true wholeTwistSegments:8 wholeTwistAmount:45.0 taperEnds:true
XP_TEST_Assert (XP_TEST_AllIndependentOutputsValid 3 64) "三终点每支 64 面同时收尖和轴向 Twist 时分别生成拓扑和 UV 有效的独立对象"

XP_TEST_Assert ((XP_LG_EndpointEnvelope 0.0 true false) == 0.0) "锁定起点时端点包络精确为零"
XP_TEST_Assert ((XP_LG_EndpointEnvelope 0.05 true false) < (XP_LG_EndpointEnvelope 0.1 true false)) "起点附近噪波包络平滑递增"
XP_TEST_Assert ((XP_LG_EndpointEnvelope 0.1 true false) < (XP_LG_EndpointEnvelope 0.2 true false)) "起点衰减区连续过渡到完整噪波"
XP_TEST_Assert ((XP_LG_EndpointEnvelope 1.0 false true) == 0.0) "锁定终点时端点包络精确为零"
XP_TEST_Assert ((XP_LG_EndpointEnvelope 0.95 false true) < (XP_LG_EndpointEnvelope 0.9 false true)) "终点附近噪波包络平滑衰减"

for updateIndex = 1 to 10 do
(
    updateNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB) 8 4.0 12.0 1.0 1.5 updateIndex true true
    XP_TEST_Assert (XP_TEST_PointNear updateNode.transform.row4 startWorld 0.00001) ("第 " + updateIndex as string + " 次更新后轴心未漂移")
)

staleReferenceNode = XP_LG_OutputNode
XP_LG_OutputNode = undefined
resolvedStaleReference = XP_LG_ResolveOutput startNode
XP_TEST_Assert (isValidNode resolvedStaleReference and resolvedStaleReference == staleReferenceNode) "全局引用失效后可从场景重新识别当前闪电模型"
recoveredUpdateNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB) 8 4.0 14.0 1.0 2.0 456 true true
XP_TEST_Assert (isValidNode recoveredUpdateNode and XP_LG_OutputNode == recoveredUpdateNode) "恢复引用后可继续正常更新"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == 2) "恢复引用并更新后每个终点只有一个独立受管模型"

unlockedNode = XP_LG_ReplaceOutput startNode #(endNodeA) 8 4.0 25.0 1.0 1.5 7 false false
unlockedPoly = unlockedNode.baseObject
unlockedStart = XP_TEST_GetWorldCenterFromPair unlockedPoly 1 2 startWorld
unlockedEnd = XP_TEST_GetWorldCenterFromPair unlockedPoly 17 18 startWorld
XP_TEST_Assert ((distance unlockedStart startWorld) > 0.0001) "关闭锁定后噪波可影响起点"
XP_TEST_Assert ((distance unlockedEnd endWorldA) > 0.0001) "关闭锁定后噪波可影响终点"

oldOutput = unlockedNode
missingStartResult = XP_LG_ReplaceOutput undefined #(endNodeA) 8 4.0 25.0 1.0 1.5 7 true true
XP_TEST_Assert (missingStartResult == undefined and isValidNode oldOutput) "未指定起点时中文校验拒绝生成且保留旧结果"
missingEndResult = XP_LG_ReplaceOutput startNode #() 8 4.0 25.0 1.0 1.5 7 true true
XP_TEST_Assert (missingEndResult == undefined and isValidNode oldOutput) "没有终点时中文校验拒绝生成且保留旧结果"
invalidFaceResult = XP_LG_ReplaceOutput startNode #(endNodeA) 0 4.0 25.0 1.0 1.5 7 true true
XP_TEST_Assert (invalidFaceResult == undefined and isValidNode oldOutput) "非法平面面数会被拒绝且不留下半成品"
invalidWidthResult = XP_LG_ReplaceOutput startNode #(endNodeA) 8 0.0 25.0 1.0 1.5 7 true true
XP_TEST_Assert (invalidWidthResult == undefined and isValidNode oldOutput) "非法宽度会被拒绝且不留下半成品"
invalidNoiseResult = XP_LG_ReplaceOutput startNode #(endNodeA) 8 4.0 25.0 0.0 1.5 7 true true
XP_TEST_Assert (invalidNoiseResult == undefined and isValidNode oldOutput) "非法噪波大小会被拒绝且不留下半成品"
invalidTilingResult = XP_LG_ReplaceOutput startNode #(endNodeA) 8 4.0 25.0 1.0 0.0 7 true true
XP_TEST_Assert (invalidTilingResult == undefined and isValidNode oldOutput) "非法 Tiling 会被拒绝且不留下半成品"
invalidWholeSegmentsResult = XP_LG_ReplaceOutput startNode #(endNodeA) 8 4.0 0.0 1.0 1.5 7 true true wholeTwistEnabled:true wholeTwistSegments:0 wholeTwistAmount:10.0
XP_TEST_Assert (invalidWholeSegmentsResult == undefined and isValidNode oldOutput and (findString XP_LG_LastError "轴向扭转分段") != undefined) "非法轴向扭转分段会被中文校验拒绝且保留旧结果"
XP_TEST_Assert (XP_LG_IsTwistSamplingSafe 33 4 120.0 true true) "足够面数下的轴向 Twist 通过单步旋转安全阈值"
XP_TEST_Assert (not (XP_LG_IsTwistSamplingSafe 5 4 720.0 true true)) "低面数高角度轴向 Twist 被单步旋转安全阈值识别"
safePlanePoints = #([0.0,0.0,0.0], [10.0,0.0,0.0])
safePlaneSides = #([0.0,1.0,0.0], [0.0,1.0,0.0])
foldedPlaneSides = #([0.0,1.0,0.0], [0.0,0.0,1.0])
XP_TEST_Assert (XP_LG_IsRibbonTwistSafe safePlanePoints safePlaneSides 5.0) "共面四边面通过 Twist 法线一致性检查"
XP_TEST_Assert (not (XP_LG_IsRibbonTwistSafe safePlanePoints foldedPlaneSides 5.0)) "严重非共面四边面被 Twist 法线一致性检查拒绝"
safeGroupNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB) 16 4.0 0.0 1.0 1.0 7 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:20.0
XP_TEST_Assert (isValidNode safeGroupNode and XP_TEST_AllIndependentOutputsValid 2 16) "原子失败测试前的安全分支组生成成功"
safeGroupNodes = for outputNode in XP_LG_OutputNodes collect outputNode
unsafeGroupResult = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB) 4 20.0 0.0 1.0 1.0 7 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:720.0
XP_TEST_Assert (unsafeGroupResult == undefined and XP_LG_OutputNodes.count == 2 and XP_LG_OutputNodes[1] == safeGroupNodes[1] and XP_LG_OutputNodes[2] == safeGroupNodes[2]) "任一不安全分支会拒绝整组替换并保留全部旧对象"
XP_TEST_Assert (isValidNode safeGroupNodes[1] and isValidNode safeGroupNodes[2] and (XP_TEST_CountTemporaryOutputs()) == 0 and (findString XP_LG_LastError "增加平面面数") != undefined) "抗折叠拒绝使用中文调参提示且不留下半成品"

-- R-011：曲率／Twist 自适应布线保持精确面数，并在急弯处动态加密和收窄。
adaptiveScreenshotKey = XP_LG_GetBranchKey endNodeA 1
adaptiveScreenshotData = XP_LG_BuildAdaptiveCenterline startWorld endWorldA 100 15.0 0.5 1.0 1 adaptiveScreenshotKey true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:75.0
adaptiveScreenshotPoints = adaptiveScreenshotData[1]
adaptiveScreenshotParameters = adaptiveScreenshotData[2]
adaptiveMinStep = 1.0
adaptiveMaxStep = 0.0
for sampleIndex = 2 to adaptiveScreenshotParameters.count do
(
    adaptiveStep = adaptiveScreenshotParameters[sampleIndex] - adaptiveScreenshotParameters[sampleIndex - 1]
    if adaptiveStep < adaptiveMinStep do adaptiveMinStep = adaptiveStep
    if adaptiveStep > adaptiveMaxStep do adaptiveMaxStep = adaptiveStep
)
XP_TEST_Assert (adaptiveScreenshotPoints.count == 101 and adaptiveScreenshotParameters.count == 101 and adaptiveScreenshotParameters[1] == 0.0 and adaptiveScreenshotParameters[101] == 1.0) "自适应布线精确保持 100 面所需的 101 组截面与锁定端点"
XP_TEST_Assert (adaptiveMaxStep > adaptiveMinStep * 1.05) "自适应布线按曲率和 Twist 变化重新分配线环而非均匀采样"
adaptiveRepeatData = XP_LG_BuildAdaptiveCenterline startWorld endWorldA 100 15.0 0.5 1.0 1 adaptiveScreenshotKey true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:75.0
XP_TEST_Assert (XP_TEST_VertArraysNear adaptiveScreenshotPoints adaptiveRepeatData[1] 0.000001 and XP_TEST_NumberArraysNear adaptiveScreenshotParameters adaptiveRepeatData[2] 0.000001) "自适应布线对相同输入可确定复现"
straightCurvatureScales = XP_LG_BuildCurvatureWidthScales #([0.0,0.0,0.0],[10.0,0.0,0.0],[20.0,0.0,0.0],[30.0,0.0,0.0]) 2.0
sharpCurvatureScales = XP_LG_BuildCurvatureWidthScales #([0.0,0.0,0.0],[1.0,0.0,0.0],[1.0,1.0,0.0],[2.0,1.0,0.0]) 2.0
XP_TEST_Assert (straightCurvatureScales[2] == 1.0 and straightCurvatureScales[3] == 1.0) "直线路径保持用户设置宽度"
XP_TEST_Assert (sharpCurvatureScales[2] < 1.0 or sharpCurvatureScales[3] < 1.0) "曲率半径不足时急弯截面会自动收窄"
uniformCircleScales = XP_LG_BuildCurvatureWidthScales #([9.84808,-1.73648,0.0],[10.0,0.0,0.0],[9.84808,1.73648,0.0]) 10.0
asymmetricCircleScales = XP_LG_BuildCurvatureWidthScales #([9.96195,-0.87156,0.0],[10.0,0.0,0.0],[9.39693,3.42020,0.0]) 10.0
XP_TEST_Assert ((abs (uniformCircleScales[2] - asymmetricCircleScales[2])) < 0.001 and (abs (uniformCircleScales[2] - 0.65)) < 0.01) "三点外接圆曲率宽度对均匀和非均匀采样保持稳定"
visualFloorScales = XP_LG_BuildCurvatureWidthScales #([0.0,0.0,0.0],[1.0,0.0,0.0],[1.0,1.0,0.0]) 10.0 minimumScale:0.35
XP_TEST_Assert (visualFloorScales[2] >= 0.34999) "通用曲率宽度缩放遵守显式安全下限"
preservedWaypointScales = XP_LG_BuildRouteCurvatureWidthScales #([0.0,0.0,0.0],[1.0,0.0,0.0],[1.0,1.0,0.0]) 10.0 true
XP_TEST_Assert (preservedWaypointScales.count == 3 and preservedWaypointScales[1] == 1.0 and preservedWaypointScales[2] == 1.0 and preservedWaypointScales[3] == 1.0) "途经点平滑路径不再通过缩窄截面掩盖急弯"
nonuniformTangentPoints = #([0.0,0.0,0.0],[0.01,0.0001,0.0],[1.0,1.0,0.0])
nonuniformTangentParameters = #(0.0,0.01,1.0)
nonuniformExpectedTangent = normalize ((normalize (nonuniformTangentPoints[2] - nonuniformTangentPoints[1])) + (normalize (nonuniformTangentPoints[3] - nonuniformTangentPoints[2])))
nonuniformLegacyTangent = normalize (nonuniformTangentPoints[3] - nonuniformTangentPoints[1])
nonuniformStableTangent = XP_LG_GetPathTangent nonuniformTangentPoints 2 sampleParameters:nonuniformTangentParameters
XP_TEST_Assert ((dot nonuniformStableTangent nonuniformExpectedTangent) > 0.999999 and (dot nonuniformStableTangent nonuniformExpectedTangent) > ((dot nonuniformLegacyTangent nonuniformExpectedTangent) + 0.05)) "非均匀采样切线保持相邻边公平角平分且不再被较长一侧拉偏"
adaptiveScreenshotNode = XP_LG_ReplaceOutput startNode #(endNodeA) 100 3.0 15.0 0.5 1.0 1 true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:75.0
XP_TEST_Assert (isValidNode adaptiveScreenshotNode and (polyop.getNumFaces adaptiveScreenshotNode.baseObject) == 100 and (polyop.getNumVerts adaptiveScreenshotNode.baseObject) == 202) "用户截图参数经动态布线后成功生成且精确保持 100 面"
XP_TEST_Assert (XP_TEST_AllFacesAndMapFacesValid adaptiveScreenshotNode.baseObject and XP_TEST_AllBranchUVsForward adaptiveScreenshotNode.baseObject 1 100 and (getUserProp adaptiveScreenshotNode "XP_LightningAdaptiveTopology") == "CurvatureTwistWidth") "用户截图参数生成结果通过四边面、UV 与自适应拓扑标记检查"
segmentedTwistScreenshotNode = XP_LG_ReplaceOutput startNode #(endNodeA, endNodeB) 50 5.0 15.0 1.0 1.0 1 true true wholeTwistEnabled:true wholeTwistSegments:10 wholeTwistAmount:120.0
XP_TEST_Assert (isValidNode segmentedTwistScreenshotNode and XP_TEST_AllIndependentOutputsValid 2 50 and (XP_TEST_TotalOutputFaces()) == 100) ("10 段每段 120 度的用户截图参数生成两个独立有效面片；" + XP_LG_LastError)
XP_TEST_Assert (XP_TEST_AllBranchUVsForward (XP_TEST_FindOutputForEnd endNodeA).baseObject 1 50 and XP_TEST_AllBranchUVsForward (XP_TEST_FindOutputForEnd endNodeB).baseObject 1 50) "高累计逐段 Twist 经动态布线后仍保持每支从左到右的 UV"
negativeTwistNode = XP_LG_ReplaceOutput startNode #(endNodeA) 32 4.0 0.0 1.0 1.5 7 false false wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:(-90.0)
XP_TEST_Assert (isValidNode negativeTwistNode and XP_TEST_AllFacesAndMapFacesValid negativeTwistNode.baseObject) "负轴向扭转角度可生成相反方向的有效面片"
oldOutput = negativeTwistNode
samePositionEnd = Point name:"重合终点" pos:startWorld size:5.0
invalidResult = XP_LG_ReplaceOutput startNode #(samePositionEnd) 8 4.0 25.0 1.0 1.5 7 true true
XP_TEST_Assert (invalidResult == undefined) "起终点重合时拒绝生成"
XP_TEST_Assert (isValidNode oldOutput) "非法输入不会删除旧结果"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == 1 and (XP_TEST_CountTemporaryOutputs()) == 0) "全部非法输入后仍只有旧模型且无临时半成品"

-- R-007：显式 request/flush 测试，不依赖程序设置控件值时是否触发 changed 事件。
try (destroyDialog XP_LG_Rollout) catch ()
createDialog XP_LG_Rollout pos:[20,20]
XP_TEST_Assert (XP_LG_Rollout.open == true) "实时更新测试所需 rollout 已创建"
XP_TEST_Assert (XP_LG_RequestLiveUpdate != undefined and XP_LG_FlushLiveUpdate != undefined) "实时更新请求和显式刷新入口已定义"

XP_LG_DeleteOutput()
XP_LG_SuppressLiveUpdate = true
XP_LG_StartNode = startNode
XP_LG_EndNodes = #(endNodeA)
XP_LG_Rollout.spFaces.value = 8
XP_LG_Rollout.spWidth.value = 4.0
XP_LG_Rollout.chkTaperEnds.checked = false
XP_LG_Rollout.spTwist.value = 12.0
XP_LG_Rollout.spNoiseSize.value = 1.0
XP_LG_Rollout.spTiling.value = 1.5
XP_LG_Rollout.spSeed.value = 700
XP_LG_Rollout.chkWholeTwist.checked = false
XP_LG_Rollout.spWholeTwistSegments.value = 4
XP_LG_Rollout.spWholeTwistAmount.value = 20.0
XP_LG_Rollout.chkLockStart.checked = true
XP_LG_Rollout.chkLockEnd.checked = true
XP_LG_RefreshUI()
XP_LG_SuppressLiveUpdate = false
XP_LG_CancelLiveUpdate()
XP_LG_LiveUpdateBusy = false
XP_LG_LiveUpdatePending = false
XP_LG_LiveUpdateAttemptCount = 0
XP_LG_LiveUpdateSuccessCount = 0
XP_LG_LiveUpdateCurrentDepth = 0
XP_LG_LiveUpdateMaxDepth = 0

XP_TEST_Assert (not (XP_LG_RequestLiveUpdate "未选择面片参数变化")) "未选择插件面片时普通参数变化不会自动创建模型"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == 0) "未选择面片时场景对象数量保持不变"
XP_TEST_Assert (XP_LG_RequestLiveUpdate "首次强制重新生成" showErrors:true immediate:true) "点击强制重新生成后创建首个模型"
XP_TEST_Assert (isValidNode XP_LG_OutputNode and (polyop.getNumFaces XP_LG_OutputNode.baseObject) == 8) "强制重新生成按当前参数创建模型"
select XP_LG_OutputNode

liveOldNode = XP_LG_OutputNode
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spFaces.value = 12
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "平面面数"
XP_TEST_Assert (isValidNode liveOldNode and XP_LG_OutputNode == liveOldNode) "实时更新在原节点提交，不删除或新建节点"
XP_TEST_Assert ((polyop.getNumFaces XP_LG_OutputNode.baseObject) == 12 and (polyop.getNumVerts XP_LG_OutputNode.baseObject) == 26 and (polyop.getNumMapFaces XP_LG_OutputNode.baseObject 1) == 12 and (polyop.getNumMapVerts XP_LG_OutputNode.baseObject 1) == 26) "平面面数实时更新后几何和 UV 数量同步重建"
XP_TEST_Assert (XP_TEST_AllFacesAndMapFacesValid XP_LG_OutputNode.baseObject and XP_TEST_AllBranchUVsForward XP_LG_OutputNode.baseObject 1 12) "面数实时更新后拓扑与从左到右 UV 仍有效"

XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spWidth.value = 6.0
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "闪电宽度"
liveWidth = distance (polyop.getVert XP_LG_OutputNode.baseObject 1) (polyop.getVert XP_LG_OutputNode.baseObject 2)
XP_TEST_Assert ((abs (liveWidth - 6.0)) <= 0.00001) "闪电宽度实时更新到最终控件值"

liveTaperCentersBefore = XP_TEST_CaptureBranchCenters XP_LG_OutputNode.baseObject 1 12 startWorld
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.chkTaperEnds.checked = true
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "面片两端平滑收尖"
liveTaperPoly = XP_LG_OutputNode.baseObject
XP_TEST_Assert ((abs ((distance (polyop.getVert liveTaperPoly 1) (polyop.getVert liveTaperPoly 2)) - 0.06)) < 0.00001) "两端收尖选项实时缩小端点宽度"
XP_TEST_Assert (XP_TEST_VertArraysNear liveTaperCentersBefore (XP_TEST_CaptureBranchCenters liveTaperPoly 1 12 startWorld) 0.00001) "两端收尖实时更新不改变中心线"

liveVertsBefore = XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spTwist.value = 25.0
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "路径噪波强度"
XP_TEST_Assert (not XP_TEST_VertArraysNear liveVertsBefore (XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject) 0.0001) "路径噪波强度实时更新中心线几何"

liveVertsBefore = XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spNoiseSize.value = 1.8
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "噪波大小"
XP_TEST_Assert (not XP_TEST_VertArraysNear liveVertsBefore (XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject) 0.0001) "噪波大小实时更新几何"

liveVertsBefore = XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spTiling.value = 3.0
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "噪波 Tiling"
XP_TEST_Assert (not XP_TEST_VertArraysNear liveVertsBefore (XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject) 0.0001) "噪波 Tiling 实时更新几何"

liveVertsBefore = XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spSeed.value = 701
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "随机种子"
XP_TEST_Assert (not XP_TEST_VertArraysNear liveVertsBefore (XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject) 0.0001) "随机种子实时更新几何"

liveVertsBefore = XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject
liveCentersBefore = XP_TEST_CaptureBranchCenters XP_LG_OutputNode.baseObject 1 12 startWorld
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.chkWholeTwist.checked = true
XP_LG_UpdateWholeTwistControlState()
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "轴向扭转开关"
XP_TEST_Assert (not XP_TEST_VertArraysNear liveVertsBefore (XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject) 0.0001) "启用轴向 Twist 会实时旋转面片截面"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 1 2 startWorld) startWorld 0.00001 and XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 25 26 startWorld) endWorldA 0.00001) "实时启用轴向 Twist 仅重排中心线采样且保持锁定起终点"

liveVertsBefore = XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject
liveCentersBefore = XP_TEST_CaptureBranchCenters XP_LG_OutputNode.baseObject 1 12 startWorld
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spWholeTwistSegments.value = 3
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "轴向扭转分段"
XP_TEST_Assert (not XP_TEST_VertArraysNear liveVertsBefore (XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject) 0.0001) "轴向扭转分段实时更新截面旋转分布"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 1 2 startWorld) startWorld 0.00001 and XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 25 26 startWorld) endWorldA 0.00001) "实时调整轴向扭转分段仅重排采样且保持锁定起终点"

liveVertsBefore = XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject
liveCentersBefore = XP_TEST_CaptureBranchCenters XP_LG_OutputNode.baseObject 1 12 startWorld
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spWholeTwistAmount.value = 30.0
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "轴向扭转角度"
XP_TEST_Assert (not XP_TEST_VertArraysNear liveVertsBefore (XP_TEST_CaptureVerts XP_LG_OutputNode.baseObject) 0.0001) "轴向扭转角度实时更新截面旋转量"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 1 2 startWorld) startWorld 0.00001 and XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 25 26 startWorld) endWorldA 0.00001) "实时调整轴向扭转角度仅重排采样且保持锁定起终点"

XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.chkLockStart.checked = false
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "锁定起点"
liveStartCenter = XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 1 2 startWorld
XP_TEST_Assert ((distance liveStartCenter startWorld) > 0.0001) "关闭起点锁定后实时结果允许起点偏移"

XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.chkLockEnd.checked = false
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "锁定终点"
liveEndCenter = XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 25 26 startWorld
XP_TEST_Assert ((distance liveEndCenter endWorldA) > 0.0001) "关闭终点锁定后实时结果允许终点偏移"

XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.chkLockStart.checked = true
XP_LG_Rollout.chkLockEnd.checked = true
XP_LG_SuppressLiveUpdate = false
XP_TEST_RequestAndFlush "恢复端点锁定"
XP_TEST_Assert (XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 1 2 startWorld) startWorld 0.00001 and XP_TEST_PointNear (XP_TEST_GetWorldCenterFromPair XP_LG_OutputNode.baseObject 25 26 startWorld) endWorldA 0.00001) "恢复锁定后两个端点实时回到控制点中心"

XP_LG_EndNodes = #(endNodeA, endNodeB)
XP_LG_RefreshUI()
XP_TEST_RequestAndFlush "添加终点"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == 1 and XP_LG_OutputNode == liveOldNode) "普通更新只修改所选面片，不因终点列表变化生成其他分支"
XP_LG_EndNodes = #(endNodeA)
XP_LG_RefreshUI()
XP_TEST_RequestAndFlush "移除终点"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == 1 and XP_LG_OutputNode == liveOldNode) "普通更新不删除所选面片以外的对象"

liveAlternateStart = Point name:"实时更新替代起点" pos:[-35.0, 10.0, 50.0] size:5.0
XP_LG_StartNode = liveAlternateStart
XP_LG_RefreshUI()
XP_TEST_RequestAndFlush "更换起点"
liveAlternateStartWorld = XP_LG_GetWorldCenter liveAlternateStart
XP_TEST_Assert (XP_TEST_PointNear XP_LG_OutputNode.transform.row4 startWorld 0.00001) "所选面片继续使用自身保存的起点引用，不被面板临时控制点覆盖"
XP_LG_StartNode = startNode
XP_LG_RefreshUI()
XP_TEST_RequestAndFlush "恢复起点"

liveAtomicOldNode = XP_LG_OutputNode
liveAttemptBeforeFailure = XP_LG_LiveUpdateAttemptCount
liveSuccessBeforeFailure = XP_LG_LiveUpdateSuccessCount
liveEndOriginalPosition = endNodeA.pos
endNodeA.pos = startNode.pos
XP_TEST_Assert (XP_LG_RequestLiveUpdate "原子失败测试") "非法几何实时更新请求仍由状态机接收"
XP_TEST_Assert (XP_LG_LiveUpdatePending and XP_LG_LiveUpdateAttemptCount == liveAttemptBeforeFailure) "非法几何请求在显式刷新前不会进入生成器"
liveFailureResult = XP_LG_FlushLiveUpdate()
XP_TEST_Assert (liveFailureResult == undefined) "非法几何实时刷新明确失败"
XP_TEST_Assert (XP_LG_OutputNode == liveAtomicOldNode and isValidNode liveAtomicOldNode) "实时更新失败时保留上一个有效模型"
XP_TEST_Assert (XP_LG_LiveUpdateAttemptCount == liveAttemptBeforeFailure + 1 and XP_LG_LiveUpdateSuccessCount == liveSuccessBeforeFailure) "失败刷新只增加尝试次数而不增加成功次数"
XP_TEST_Assert (XP_LG_LiveUpdateBusy == false and XP_LG_LiveUpdatePending == false and XP_LG_LiveUpdateCurrentDepth == 0) "失败路径完整复位实时更新状态"
XP_TEST_Assert ((findString XP_LG_Rollout.lblStatus.text "失败") != undefined and (findString XP_LG_Rollout.lblStatus.text "保留") != undefined) "实时更新失败在窗口显示中文保留状态"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == XP_LG_EndNodes.count and (XP_TEST_CountTemporaryOutputs()) == 0) "实时更新失败不产生重复模型或半成品"
endNodeA.pos = liveEndOriginalPosition
XP_TEST_RequestAndFlush "失败后恢复"

liveAttemptBeforeBusy = XP_LG_LiveUpdateAttemptCount
XP_LG_LiveUpdateBusy = true
liveBusyRequestAccepted = XP_LG_RequestLiveUpdate "生成期间合并请求"
XP_TEST_Assert (liveBusyRequestAccepted and XP_LG_LiveUpdatePending) "生成忙碌期间的新请求不会丢失"
liveBusyFlushResult = XP_LG_FlushLiveUpdate()
XP_TEST_Assert (liveBusyFlushResult == undefined and XP_LG_LiveUpdatePending and XP_LG_LiveUpdateAttemptCount == liveAttemptBeforeBusy) "忙碌期间拒绝重入且不增加生成尝试"
XP_LG_LiveUpdateBusy = false
liveBusyRecoveredNode = XP_LG_FlushLiveUpdate()
XP_TEST_Assert (isValidNode liveBusyRecoveredNode and XP_LG_LiveUpdatePending == false and XP_LG_LiveUpdateAttemptCount == liveAttemptBeforeBusy + 1) "解除忙碌后只消费一次合并请求"

liveAttemptBeforeRapid = XP_LG_LiveUpdateAttemptCount
liveSuccessBeforeRapid = XP_LG_LiveUpdateSuccessCount
for rapidIndex = 1 to 50 do
(
    XP_LG_SuppressLiveUpdate = true
    XP_LG_Rollout.spSeed.value = 3000 + rapidIndex
    XP_LG_SuppressLiveUpdate = false
    XP_TEST_Assert (XP_LG_RequestLiveUpdate ("快速参数 " + rapidIndex as string)) ("第 " + rapidIndex as string + " 个快速请求已合并排队")
)
XP_TEST_Assert (XP_LG_LiveUpdatePending and XP_LG_LiveUpdateAttemptCount == liveAttemptBeforeRapid) "50 次快速请求在刷新前不会重复生成"
liveRapidNode = XP_LG_FlushLiveUpdate()
XP_TEST_Assert (isValidNode liveRapidNode) "50 次快速请求可显式刷新最终状态"
XP_TEST_Assert (XP_LG_LiveUpdateAttemptCount == liveAttemptBeforeRapid + 1 and XP_LG_LiveUpdateSuccessCount == liveSuccessBeforeRapid + 1) "50 次快速请求只执行一次原子替换"
liveRapidVerts = XP_TEST_CaptureVerts liveRapidNode.baseObject
liveExpectedNode = XP_LG_CreateLightningNode XP_LG_StartNode XP_LG_EndNodes XP_LG_Rollout.spFaces.value XP_LG_Rollout.spWidth.value XP_LG_Rollout.spTwist.value XP_LG_Rollout.spNoiseSize.value XP_LG_Rollout.spTiling.value XP_LG_Rollout.spSeed.value XP_LG_Rollout.chkLockStart.checked XP_LG_Rollout.chkLockEnd.checked wholeTwistEnabled:XP_LG_Rollout.chkWholeTwist.checked wholeTwistSegments:XP_LG_Rollout.spWholeTwistSegments.value wholeTwistAmount:XP_LG_Rollout.spWholeTwistAmount.value taperEnds:XP_LG_Rollout.chkTaperEnds.checked
liveExpectedVerts = XP_TEST_CaptureVerts liveExpectedNode.baseObject
XP_TEST_Assert (XP_TEST_VertArraysNear liveRapidVerts liveExpectedVerts 0.000001) "快速请求最终模型使用最后一次控件参数"
delete liveExpectedNode
XP_TEST_Assert (XP_LG_LiveUpdateMaxDepth == 1 and XP_LG_LiveUpdateCurrentDepth == 0 and XP_LG_LiveUpdateBusy == false and XP_LG_LiveUpdatePending == false) "完整实时更新期间最大生成深度始终为 1"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == XP_LG_EndNodes.count and (XP_TEST_CountTemporaryOutputs()) == 0) "快速连续调整后每个终点只有一个最终模型且无半成品"

-- 在隔离测试实例中实测一次 200ms debounce tick；轮询有明确上限，不会无界等待。
liveTimerAttemptBefore = XP_LG_LiveUpdateAttemptCount
liveTimerSuccessBefore = XP_LG_LiveUpdateSuccessCount
XP_LG_SuppressLiveUpdate = true
XP_LG_Rollout.spSeed.value = 4096
XP_LG_SuppressLiveUpdate = false
liveTimerStart = timeStamp()
XP_TEST_Assert (XP_LG_RequestLiveUpdate "计时器防抖实测") "计时器防抖请求已排队"
XP_TEST_Assert (XP_LG_LiveUpdatePending and XP_LG_LiveUpdateAttemptCount == liveTimerAttemptBefore) "计时器触发前不会同步生成"
liveTimerWaitIterations = 0
while XP_LG_LiveUpdatePending and liveTimerWaitIterations < 40 do
(
    sleep 0.05
    windows.processPostedMessages()
    liveTimerWaitIterations = liveTimerWaitIterations + 1
)
liveTimerElapsed = timeStamp() - liveTimerStart
XP_TEST_Assert (XP_LG_LiveUpdatePending == false) "防抖计时器在限定时间内自动消费请求"
XP_TEST_Assert (liveTimerElapsed >= 150 and liveTimerElapsed < 3000) "防抖更新在约 200ms 后且超时上限前执行"
XP_TEST_Assert (XP_LG_LiveUpdateAttemptCount == liveTimerAttemptBefore + 1 and XP_LG_LiveUpdateSuccessCount == liveTimerSuccessBefore + 1) "一次防抖 Tick 只尝试并成功提交一次"
XP_TEST_Assert (XP_LG_LiveUpdateBusy == false and XP_LG_LiveUpdateCurrentDepth == 0 and XP_LG_LiveUpdateMaxDepth == 1) "计时器更新后状态机保持非重入"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == XP_LG_EndNodes.count and (XP_TEST_CountTemporaryOutputs()) == 0) "计时器更新后每个终点仍只有一个最终模型且无半成品"

liveForceAttemptBefore = XP_LG_LiveUpdateAttemptCount
liveForceSuccessBefore = XP_LG_LiveUpdateSuccessCount
liveHistoricalNodes = for outputNode in XP_LG_OutputNodes collect outputNode
liveHistoricalNames = for outputNode in liveHistoricalNodes collect outputNode.name
liveHistoricalWorldVerts = for outputNode in liveHistoricalNodes collect (XP_TEST_CaptureWorldVerts outputNode)
liveManagedBeforeForce = XP_TEST_CountManagedOutputs()
liveForceResult = XP_LG_RequestLiveUpdate "强制重新生成" showErrors:true immediate:true
XP_TEST_Assert (liveForceResult and XP_LG_LiveUpdateAttemptCount == liveForceAttemptBefore + 1 and XP_LG_LiveUpdateSuccessCount == liveForceSuccessBefore + 1) "强制重新生成复用同一状态机并立即成功一次"
XP_TEST_Assert ((findString XP_LG_Rollout.lblStatus.text "已保留旧面片并新建一组") != undefined) "强制重新生成显示保留旧面片并新建一组的中文状态"
XP_TEST_Assert ((XP_TEST_CountManagedOutputs()) == liveManagedBeforeForce + XP_LG_EndNodes.count and (XP_TEST_CountActiveOutputs()) == XP_LG_EndNodes.count) "强制重新生成保留旧组并新增一套活动分支"
for branchIndex = 1 to liveHistoricalNodes.count do
(
    XP_TEST_Assert (isValidNode liveHistoricalNodes[branchIndex] and liveHistoricalNodes[branchIndex].name == liveHistoricalNames[branchIndex]) ("强制新建后历史分支名称保持不变：" + branchIndex as string)
    XP_TEST_Assert (XP_TEST_VertArraysNear liveHistoricalWorldVerts[branchIndex] (XP_TEST_CaptureWorldVerts liveHistoricalNodes[branchIndex]) 0.000001) ("强制新建后历史分支世界几何保持不变：" + branchIndex as string)
)
for activeNode in XP_LG_OutputNodes do
(
    XP_TEST_Assert ((findItem liveHistoricalNodes activeNode) == 0 and (matchPattern activeNode.name pattern:"LightningPlane*" ignoreCase:false)) "强制新建的活动分支是新对象并获得新 LightningPlane 名称"
    XP_TEST_Assert ((XP_LG_GetWaypointNodesFromOutput activeNode).count == 0) "强制重新生成的新面片不会复制其他面片的途经点"
)

firstForcedNodes = for outputNode in XP_LG_OutputNodes collect outputNode
firstForcedNames = for outputNode in firstForcedNodes collect outputNode.name
firstForcedWorldVerts = for outputNode in firstForcedNodes collect (XP_TEST_CaptureWorldVerts outputNode)
secondForcedNode = XP_LG_CreateNewOutputSet XP_LG_StartNode XP_LG_EndNodes 12 6.0 25.0 1.8 3.0 701 true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 taperEnds:true
XP_TEST_Assert (isValidNode secondForcedNode and (XP_TEST_CountManagedOutputs()) == liveManagedBeforeForce + XP_LG_EndNodes.count * 2 and (XP_TEST_CountActiveOutputs()) == XP_LG_EndNodes.count) "连续强制重新生成再次保留旧组并累加一套新对象"
for branchIndex = 1 to firstForcedNodes.count do
(
    append liveHistoricalNodes firstForcedNodes[branchIndex]
    append liveHistoricalNames firstForcedNames[branchIndex]
    append liveHistoricalWorldVerts firstForcedWorldVerts[branchIndex]
)
expectedManagedWithHistory = liveManagedBeforeForce + XP_LG_EndNodes.count * 2

for outputNode in XP_LG_OutputNodes do
(
    XP_TEST_Assert ((classOf outputNode.rotation.controller) != Rotation_List) "新生成面片不包含插件创建的 Rotation List"
    XP_TEST_Assert ((getUserProp outputNode "XP_LightningUnityAxis") == undefined) "新生成面片不包含已撤销的 Unity 轴向标记"
)

preLiveReplaceActiveNodes = for outputNode in XP_LG_OutputNodes collect outputNode
selectedEditNode = preLiveReplaceActiveNodes[1]
selectedEditHandle = getHandleByAnim selectedEditNode
selectedEditName = selectedEditNode.name
selectedEditTransform = selectedEditNode.transform
selectedEditMaterial = selectedEditNode.material
postForceLiveNode = XP_LG_ReplaceSelectedOutput selectedEditNode (XP_LG_FindNodeByStoredHandle selectedEditNode "XP_LightningStartHandle") (XP_LG_FindNodeByStoredHandle selectedEditNode "XP_LightningEndHandle") 12 7.0 25.0 1.8 3.0 701 true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 taperEnds:true
XP_TEST_Assert (postForceLiveNode == selectedEditNode and (getHandleByAnim postForceLiveNode) == selectedEditHandle and postForceLiveNode.name == selectedEditName and postForceLiveNode.transform == selectedEditTransform and postForceLiveNode.material == selectedEditMaterial and (XP_TEST_CountManagedOutputs()) == expectedManagedWithHistory) ("强制新建后的普通参数更新原位修改所选节点；Error=" + XP_LG_LastError)
for branchIndex = 1 to liveHistoricalNodes.count do XP_TEST_Assert (isValidNode liveHistoricalNodes[branchIndex] and liveHistoricalNodes[branchIndex].name == liveHistoricalNames[branchIndex] and XP_TEST_VertArraysNear liveHistoricalWorldVerts[branchIndex] (XP_TEST_CaptureWorldVerts liveHistoricalNodes[branchIndex]) 0.000001) ("普通参数更新不修改历史组：" + branchIndex as string)
for oldActiveNode in preLiveReplaceActiveNodes do XP_TEST_Assert (isValidNode oldActiveNode) "普通参数更新不删除同组任何节点"
XP_TEST_Assert ((classOf postForceLiveNode.rotation.controller) != Rotation_List and (getUserProp postForceLiveNode "XP_LightningUnityAxis") == undefined) "普通参数原位更新不会新增轴向适配控制器或标记"

savedActiveOutputs = for outputNode in XP_LG_OutputNodes collect outputNode
savedActiveOutputNode = XP_LG_OutputNode
selectionPairNode = XP_LG_CreateNewOutputSet startNode #(endNodeA, endNodeB) 16 4.0 10.0 1.0 1.5 808 true true
XP_TEST_Assert (isValidNode selectionPairNode and XP_LG_OutputNodes.count == 2) "选择编辑测试已创建两个独立面片"
selectionTarget = XP_LG_OutputNodes[1]
selectionOther = XP_LG_OutputNodes[2]
setUserProp selectionTarget "XP_LightningGenerator" "1.1.0"
setUserProp selectionOther "XP_LightningGenerator" "1.0.0"
XP_TEST_Assert (XP_LG_IsManagedOutput selectionTarget and XP_LG_IsManagedOutput selectionOther) "V1.2.0 继续识别 1.0.0 与 1.1.0 历史面片标记"
legacy11Result = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 16 4.0 10.0 1.0 1.5 808 true true
legacy10Result = XP_LG_ReplaceSelectedOutput selectionOther startNode endNodeB 16 4.0 10.0 1.0 1.5 808 true true
XP_TEST_Assert (legacy11Result == selectionTarget and legacy10Result == selectionOther and (getUserProp selectionTarget "XP_LightningGenerator") == "1.2.0" and (getUserProp selectionOther "XP_LightningGenerator") == "1.2.0") "1.0.0 与 1.1.0 历史面片可原位编辑并迁移为 1.2.0 标记"
selectionParent = Point name:"选择编辑层级父节点" pos:[0.0,0.0,0.0] size:2.0
selectionTarget.parent = selectionParent
selectionTargetHandle = getHandleByAnim selectionTarget
selectionTargetName = selectionTarget.name
selectionTargetTM = selectionTarget.transform
selectionOtherWorldBefore = XP_TEST_CaptureWorldVerts selectionOther
selectionOtherNameBefore = selectionOther.name
selectionCountBefore = XP_TEST_CountManagedOutputs()
select selectionTarget
XP_LG_LoadSelectedOutputIntoUI()
XP_TEST_Assert ((abs (XP_LG_Rollout.spWidth.value - 4.0)) < 0.000001 and XP_LG_EndNodes.count == 1 and XP_LG_EndNodes[1] == endNodeA) "选中面片后载入该对象自己的参数与终点"
selectionEditResult = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 20 9.0 18.0 1.2 2.0 909 true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 taperEnds:true
XP_TEST_Assert (selectionEditResult == selectionTarget and (getHandleByAnim selectionTarget) == selectionTargetHandle and selectionTarget.name == selectionTargetName and selectionTarget.parent == selectionParent and selectionTarget.transform == selectionTargetTM and (polyop.getNumFaces selectionTarget.baseObject) == 20 and (XP_TEST_CountManagedOutputs()) == selectionCountBefore) "修改参数只原位更新所选面片并保持节点句柄、名称、层级、变换和对象数量"
XP_TEST_Assert (selectionOther.name == selectionOtherNameBefore and XP_TEST_VertArraysNear selectionOtherWorldBefore (XP_TEST_CaptureWorldVerts selectionOther) 0.000001 and (polyop.getNumFaces selectionOther.baseObject) == 16) "同组未选面片的名称、参数和几何完全不变"

-- R-022：途经点属于所选面片，按顺序精确穿过中心，并保持总面数与原位更新语义。
waypointA = Point name:"测试途经点A" pos:[70.0, 0.0, 45.0] size:4.0
waypointB = Point name:"测试途经点B" pos:[70.0, 55.0, 45.0] size:4.0
waypointRoute = #(XP_LG_GetWorldCenter startNode, XP_LG_GetWorldCenter waypointA, XP_LG_GetWorldCenter waypointB, XP_LG_GetWorldCenter endNodeA)
waypointAllocations = XP_LG_AllocateWaypointFaceCounts waypointRoute 24
waypointResult = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 24 5.0 18.0 1.2 2.0 909 true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 taperEnds:true waypointNodes:#(waypointA, waypointB)
XP_TEST_Assert (waypointResult == selectionTarget and (getHandleByAnim selectionTarget) == selectionTargetHandle and selectionTarget.name == selectionTargetName and selectionTarget.parent == selectionParent and selectionTarget.transform == selectionTargetTM and (polyop.getNumFaces selectionTarget.baseObject) == 24) ("途经点更新只原位修改所选面片并保持节点、名称、层级、Transform 与总面数；Error=" + XP_LG_LastError)
storedWaypointNodes = XP_LG_GetWaypointNodesFromOutput selectionTarget
XP_TEST_Assert (storedWaypointNodes.count == 2 and storedWaypointNodes[1] == waypointA and storedWaypointNodes[2] == waypointB) "所选面片按顺序保存自己的途经点对象句柄"
waypointWorldVerts = XP_TEST_CaptureWorldVerts selectionTarget
waypointAStation = waypointAllocations[1]
waypointBStation = waypointAllocations[1] + waypointAllocations[2]
waypointACenter = (waypointWorldVerts[waypointAStation * 2 + 1] + waypointWorldVerts[waypointAStation * 2 + 2]) * 0.5
waypointBCenter = (waypointWorldVerts[waypointBStation * 2 + 1] + waypointWorldVerts[waypointBStation * 2 + 2]) * 0.5
XP_TEST_Assert (XP_TEST_PointNear waypointACenter (XP_LG_GetWorldCenter waypointA) 0.00001 and XP_TEST_PointNear waypointBCenter (XP_LG_GetWorldCenter waypointB) 0.00001) "最终中心线按列表顺序精确经过两个途经点的世界中心"
XP_TEST_Assert (XP_TEST_AllFacesAndMapFacesValid selectionTarget.baseObject and XP_TEST_BranchFacesAreContinuous selectionTarget.baseObject 1 24 and XP_TEST_AllBranchUVsForward selectionTarget.baseObject 1 24) "途经点面片保持连续有效四边面与从左到右的 0–1 UV"
XP_TEST_Assert (selectionOther.name == selectionOtherNameBefore and XP_TEST_VertArraysNear selectionOtherWorldBefore (XP_TEST_CaptureWorldVerts selectionOther) 0.000001 and (XP_LG_GetWaypointNodesFromOutput selectionOther).count == 0) "给一个面片添加途经点不会修改另一面片的几何或途经点列表"

-- R-025：共享切线的途经点平滑只改变整体基础走向，仍精确经过控制点。
smoothingTestRoute = #([0.0,0.0,0.0], [50.0,0.0,0.0], [50.0,50.0,0.0])
smoothingTestParameters = XP_LG_BuildRouteParameters smoothingTestRoute
smoothingTestTangents = XP_LG_BuildWaypointRouteTangents smoothingTestRoute smoothingTestParameters 100.0
smoothingLinearMid = XP_LG_EvaluateWaypointBasePoint smoothingTestRoute smoothingTestParameters smoothingTestTangents 1 0.5 false 100.0
smoothingZeroMid = XP_LG_EvaluateWaypointBasePoint smoothingTestRoute smoothingTestParameters smoothingTestTangents 1 0.5 true 0.0
smoothingHalfTangents = XP_LG_BuildWaypointRouteTangents smoothingTestRoute smoothingTestParameters 50.0
smoothingHalfMid = XP_LG_EvaluateWaypointBasePoint smoothingTestRoute smoothingTestParameters smoothingHalfTangents 1 0.5 true 50.0
smoothingFullMid = XP_LG_EvaluateWaypointBasePoint smoothingTestRoute smoothingTestParameters smoothingTestTangents 1 0.5 true 100.0
smoothingKnot = XP_LG_EvaluateWaypointBasePoint smoothingTestRoute smoothingTestParameters smoothingTestTangents 1 1.0 true 100.0
smoothingLeft = XP_LG_EvaluateWaypointBasePoint smoothingTestRoute smoothingTestParameters smoothingTestTangents 1 0.999 true 100.0
smoothingRight = XP_LG_EvaluateWaypointBasePoint smoothingTestRoute smoothingTestParameters smoothingTestTangents 2 0.001 true 100.0
smoothingIncoming = normalize (smoothingKnot - smoothingLeft)
smoothingOutgoing = normalize (smoothingRight - smoothingKnot)
XP_TEST_Assert (XP_TEST_PointNear smoothingLinearMid [25.0,0.0,0.0] 0.00001 and XP_TEST_PointNear smoothingZeroMid smoothingLinearMid 0.00001) "平滑关闭或强度为 0 时严格保持原直线路段"
XP_TEST_Assert (XP_TEST_PointNear smoothingKnot [50.0,0.0,0.0] 0.00001 and (dot smoothingIncoming smoothingOutgoing) > 0.999) "相邻曲线段共享途经点切线并精确穿过途经点中心"
XP_TEST_Assert ((distance smoothingFullMid smoothingLinearMid) > 0.1) "途经点过渡强度可产生可见且受控的圆滑走向"
XP_TEST_Assert ((distance smoothingHalfMid smoothingLinearMid) < (distance smoothingFullMid smoothingLinearMid)) "50% 到 100% 过渡强度逐渐增强且结果可确定复现"
reverseSmoothingRoute = #([0.0,0.0,0.0], [10.0,0.0,0.0], [0.1,0.1,0.0])
reverseSmoothingParameters = XP_LG_BuildRouteParameters reverseSmoothingRoute
reverseSmoothingTangents = XP_LG_BuildWaypointRouteTangents reverseSmoothingRoute reverseSmoothingParameters 100.0
shortSmoothingRoute = #([0.0,0.0,0.0], [100.0,0.0,0.0], [100.0,1.0,0.0])
shortSmoothingParameters = XP_LG_BuildRouteParameters shortSmoothingRoute
shortSmoothingTangents = XP_LG_BuildWaypointRouteTangents shortSmoothingRoute shortSmoothingParameters 100.0
XP_TEST_Assert ((length reverseSmoothingTangents[2]) < 1.0) "接近 180 度掉头时共享切线会按夹角自动衰减"
XP_TEST_Assert (((length shortSmoothingTangents[2]) * (shortSmoothingParameters[3] - shortSmoothingParameters[2])) <= 1.00001) "短路径段的局部切线长度受该段长度自动限制"

waypointGeometryBeforeSmoothing = XP_TEST_CaptureWorldVerts selectionTarget
waypointSmoothResult = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 24 5.0 18.0 1.2 2.0 909 true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 taperEnds:true waypointNodes:#(waypointA, waypointB) waypointSmoothingEnabled:true waypointSmoothingStrength:100.0
XP_TEST_Assert (waypointSmoothResult == selectionTarget) ("多途经点恒宽安全补面应成功；Error=" + XP_LG_LastError)
waypointSmoothWorldVerts = XP_TEST_CaptureWorldVerts selectionTarget
waypointSafetyProbeKey = XP_LG_GetBranchKey endNodeA 1
waypointSafetyInitialProbeData = XP_LG_BuildWaypointAdaptiveCenterline waypointRoute 24 18.0 1.2 2.0 909 waypointSafetyProbeKey true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 waypointAutoAddFaces:true
XP_TEST_Assert (waypointSafetyInitialProbeData != undefined and waypointSafetyInitialProbeData.count >= 4 and waypointSafetyInitialProbeData[4].count == 2) ("多途经点安全采样必须返回两个精确站位；route=" + waypointRoute.count as string + "；data=" + waypointSafetyInitialProbeData as string)
waypointSafetyAStation = waypointSafetyInitialProbeData[4][1] - 1
waypointSafetyBStation = waypointSafetyInitialProbeData[4][2] - 1
waypointSmoothACenter = (waypointSmoothWorldVerts[waypointSafetyAStation * 2 + 1] + waypointSmoothWorldVerts[waypointSafetyAStation * 2 + 2]) * 0.5
waypointSmoothBCenter = (waypointSmoothWorldVerts[waypointSafetyBStation * 2 + 1] + waypointSmoothWorldVerts[waypointSafetyBStation * 2 + 2]) * 0.5
XP_TEST_Assert (waypointSmoothResult == selectionTarget and not (XP_TEST_VertArraysNear waypointGeometryBeforeSmoothing waypointSmoothWorldVerts 0.0001)) "启用途经点平滑后原位更新同一面片并改变拐点附近走向"
XP_TEST_Assert (XP_TEST_PointNear waypointSmoothACenter (XP_LG_GetWorldCenter waypointA) 0.00001 and XP_TEST_PointNear waypointSmoothBCenter (XP_LG_GetWorldCenter waypointB) 0.00001) "平滑后的中心线仍精确经过所有途经点中心"
XP_TEST_Assert ((getUserProp selectionTarget "XP_LightningWaypointSmoothingEnabled") == true and (abs (((getUserProp selectionTarget "XP_LightningWaypointSmoothingStrength") as float) - 100.0)) < 0.00001) "面片独立保存途经点平滑开关和强度"
XP_TEST_Assert (XP_TEST_AllFacesAndMapFacesValid selectionTarget.baseObject and XP_TEST_AllBranchUVsForward selectionTarget.baseObject 1 waypointSafetyInitialProbeData[3] and (polyop.getNumFaces selectionTarget.baseObject) == waypointSafetyInitialProbeData[3]) "多途经点平滑安全补面后保持有效四边面和从左到右 UV"

-- R-026／R-031：过渡强度滑条；用户可显式增加细节，多途经点另有强制恒宽安全补面。
autoFaceCornerRoute = #([0.0,0.0,0.0], [50.0,0.0,0.0], [50.0,50.0,0.0])
autoFaceStraightRoute = #([0.0,0.0,0.0], [50.0,0.0,0.0], [100.0,0.0,0.0])
autoFaceBaseAllocations = #(10,10)
autoFaceOffData = XP_LG_AddWaypointTransitionFaces autoFaceCornerRoute autoFaceBaseAllocations true 100.0 false
autoFaceHalfData = XP_LG_AddWaypointTransitionFaces autoFaceCornerRoute autoFaceBaseAllocations true 50.0 true
autoFaceFullData = XP_LG_AddWaypointTransitionFaces autoFaceCornerRoute autoFaceBaseAllocations true 100.0 true
autoFaceStraightData = XP_LG_AddWaypointTransitionFaces autoFaceStraightRoute autoFaceBaseAllocations true 100.0 true
XP_TEST_Assert (autoFaceOffData[2] == 20 and autoFaceOffData[1][1] == 10 and autoFaceOffData[1][2] == 10) "关闭自动加面时严格保持基础面数和原分配"
XP_TEST_Assert (autoFaceHalfData[2] > 20 and autoFaceFullData[2] > autoFaceHalfData[2] and autoFaceFullData[1][1] > 10 and autoFaceFullData[1][2] > 10) "自动加面随滑条强度增加，并同时加密途经点前后过渡段"
XP_TEST_Assert (autoFaceStraightData[2] == 20) "共线途经点在 100 强度下也不会无意义增加面数"
XP_TEST_Assert (autoFaceFullData[4][1] > 0 and autoFaceFullData[3][2] > 0) "90 度途经点明确记录进入侧末端和离开侧起始的局部新增线环"
incomingTargetWeights = XP_LG_BuildWaypointSpanTargetWeights 10 0 autoFaceFullData[4][1] 100.0
outgoingTargetWeights = XP_LG_BuildWaypointSpanTargetWeights 10 autoFaceFullData[3][2] 0 100.0
incomingLocalExtraCount = 0
outgoingLocalExtraCount = 0
incomingMinimumGap = 1.0
outgoingMinimumGap = 1.0
for targetValue in incomingTargetWeights where targetValue > 0.6 and targetValue < 1.0 do incomingLocalExtraCount = incomingLocalExtraCount + 1
for targetValue in outgoingTargetWeights where targetValue > 0.0 and targetValue < 0.4 do outgoingLocalExtraCount = outgoingLocalExtraCount + 1
for targetIndex = 2 to incomingTargetWeights.count do if (incomingTargetWeights[targetIndex] - incomingTargetWeights[targetIndex - 1]) < incomingMinimumGap do incomingMinimumGap = incomingTargetWeights[targetIndex] - incomingTargetWeights[targetIndex - 1]
for targetIndex = 2 to outgoingTargetWeights.count do if (outgoingTargetWeights[targetIndex] - outgoingTargetWeights[targetIndex - 1]) < outgoingMinimumGap do outgoingMinimumGap = outgoingTargetWeights[targetIndex] - outgoingTargetWeights[targetIndex - 1]
XP_TEST_Assert (incomingTargetWeights.count == autoFaceFullData[1][1] + 1 and outgoingTargetWeights.count == autoFaceFullData[1][2] + 1 and incomingLocalExtraCount >= autoFaceFullData[4][1] and outgoingLocalExtraCount >= autoFaceFullData[3][2]) "自动新增采样集中在途经点两侧 40% 局部窗口而不是分散到整段"
XP_TEST_Assert (incomingMinimumGap > 0.001 and outgoingMinimumGap > 0.001) "途经点窗口内基础线环与新增线环统一重排且不存在近零间距"

waypointAutoAllocationData = XP_LG_AddWaypointTransitionFaces waypointRoute waypointAllocations true 100.0 true safetyMultiplier:4.0
waypointAutoAllocations = waypointAutoAllocationData[1]
waypointAutoActualFaces = waypointAutoAllocationData[2]
waypointAutoProbeKey = XP_LG_GetBranchKey endNodeA 1
waypointAutoProbeData = XP_LG_BuildWaypointAdaptiveCenterline waypointRoute 24 18.0 1.2 2.0 909 waypointAutoProbeKey true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 waypointAutoAddFaces:true
waypointAutoProbePoints = waypointAutoProbeData[1]
waypointAutoProbeParameters = waypointAutoProbeData[2]
waypointAutoProbeStations = waypointAutoProbeData[4]
waypointAutoProbeScales = XP_LG_BuildWidthScales waypointAutoProbePoints.count true sampleParameters:waypointAutoProbeParameters
waypointAutoProbeSides = XP_LG_BuildRibbonSides waypointAutoProbePoints sampleParameters:waypointAutoProbeParameters
waypointAutoProbeTwistedSides = XP_LG_BuildAxiallyTwistedSides waypointAutoProbePoints waypointAutoProbeSides 3 30.0 true true sampleParameters:waypointAutoProbeParameters
waypointAutoProbeOptimizedScales = XP_LG_BuildTwistSafeWidthScales waypointAutoProbePoints waypointAutoProbeTwistedSides 2.5 waypointAutoProbeScales
waypointAutoProbeScaleA = if waypointAutoProbeOptimizedScales != undefined then waypointAutoProbeOptimizedScales[waypointAutoProbeStations[1]] else -1.0
waypointAutoProbeScaleB = if waypointAutoProbeOptimizedScales != undefined then waypointAutoProbeOptimizedScales[waypointAutoProbeStations[2]] else -1.0
waypointAutoMinimumBaseSideDot = 1.0
for waypointAutoSideIndex = 2 to waypointAutoProbeSides.count do
(
    waypointAutoSideDot = dot waypointAutoProbeSides[waypointAutoSideIndex - 1] waypointAutoProbeSides[waypointAutoSideIndex]
    if waypointAutoSideDot < waypointAutoMinimumBaseSideDot do waypointAutoMinimumBaseSideDot = waypointAutoSideDot
)
waypointAutoResult = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 24 5.0 18.0 1.2 2.0 909 true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 taperEnds:true waypointNodes:#(waypointA, waypointB) waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 waypointAutoAddFaces:true
XP_TEST_Assert (waypointAutoResult == selectionTarget) ("100 强度局部自动加面应成功生成；Error=" + XP_LG_LastError)
XP_TEST_Assert (waypointAutoMinimumBaseSideDot > 0.0 and waypointAutoProbeOptimizedScales != undefined and waypointAutoProbeScaleA == 1.0 and waypointAutoProbeScaleB == 1.0) "双途经点局部加密后的平行运输截面连续且途经点宽度无需收窄"
waypointAutoWorldVerts = XP_TEST_CaptureWorldVerts selectionTarget
waypointAutoAStation = waypointAutoAllocations[1]
waypointAutoBStation = waypointAutoAllocations[1] + waypointAutoAllocations[2]
waypointAutoACenter = (waypointAutoWorldVerts[waypointAutoAStation * 2 + 1] + waypointAutoWorldVerts[waypointAutoAStation * 2 + 2]) * 0.5
waypointAutoBCenter = (waypointAutoWorldVerts[waypointAutoBStation * 2 + 1] + waypointAutoWorldVerts[waypointAutoBStation * 2 + 2]) * 0.5
waypointAutoAWidth = distance waypointAutoWorldVerts[waypointAutoAStation * 2 + 1] waypointAutoWorldVerts[waypointAutoAStation * 2 + 2]
waypointAutoBWidth = distance waypointAutoWorldVerts[waypointAutoBStation * 2 + 1] waypointAutoWorldVerts[waypointAutoBStation * 2 + 2]
XP_TEST_Assert (waypointAutoResult == selectionTarget and waypointAutoActualFaces > 24 and (polyop.getNumFaces selectionTarget.baseObject) == waypointAutoActualFaces and (polyop.getNumVerts selectionTarget.baseObject) == 2 * (waypointAutoActualFaces + 1)) "100 强度允许自动加面时按实际面数生成有效拓扑"
XP_TEST_Assert (XP_TEST_PointNear waypointAutoACenter (XP_LG_GetWorldCenter waypointA) 0.00001 and XP_TEST_PointNear waypointAutoBCenter (XP_LG_GetWorldCenter waypointB) 0.00001) "自动加面后仍精确穿过每个途经点中心"
XP_TEST_Assert ((abs (waypointAutoAWidth - 5.0)) < 0.0001 and (abs (waypointAutoBWidth - 5.0)) < 0.0001) "双途经点与 Twist 同时启用时两个途经点截面保持用户宽度而不缩成尖口"
XP_TEST_Assert (XP_TEST_AllFacesAndMapFacesValid selectionTarget.baseObject and XP_TEST_AllBranchUVsForward selectionTarget.baseObject 1 waypointAutoActualFaces) "自动加面后的所有几何面与从左到右 UV 保持有效"
XP_TEST_Assert ((getUserProp selectionTarget "XP_LightningWaypointAutoAddFaces") == true and ((getUserProp selectionTarget "XP_LightningFacesPerBranch") as integer) == 24 and ((getUserProp selectionTarget "XP_LightningActualFaces") as integer) == waypointAutoActualFaces) "面片分别保存基础面数、实际面数和自动加面开关"
select selectionTarget
XP_LG_LoadSelectedOutputIntoUI()
XP_TEST_Assert (XP_LG_Rollout.chkWaypointAutoAddFaces.checked and XP_LG_Rollout.spWaypointSmoothingStrength.value == 100) "重新选择面片会载入其自动加面开关和滑条强度"

waypointSmoothResult = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 24 5.0 18.0 1.2 2.0 909 true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 taperEnds:true waypointNodes:#(waypointA, waypointB) waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 waypointAutoAddFaces:false
waypointSafetyActualFaces = waypointSafetyInitialProbeData[3]
XP_TEST_Assert (waypointSmoothResult == selectionTarget and (polyop.getNumFaces selectionTarget.baseObject) == waypointSafetyActualFaces and waypointSafetyActualFaces > 24 and (getUserProp selectionTarget "XP_LightningWaypointAutoAddFaces") == false and (getUserProp selectionTarget "XP_LightningWaypointSafetyAutoFaces") == true) ("多途经点关闭主动自动加面时仍按需执行恒宽安全补面且保留用户开关；result=" + waypointSmoothResult as string + "；faces=" + (polyop.getNumFaces selectionTarget.baseObject) as string + "/" + waypointSafetyActualFaces as string + "；user=" + (getUserProp selectionTarget "XP_LightningWaypointAutoAddFaces") as string + "；safety=" + (getUserProp selectionTarget "XP_LightningWaypointSafetyAutoFaces") as string + "；Error=" + XP_LG_LastError)
waypointSafetyProbeData = XP_LG_BuildWaypointAdaptiveCenterline waypointRoute 24 18.0 1.2 2.0 909 waypointAutoProbeKey true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 waypointAutoAddFaces:true
waypointSafetyProbeParameters = waypointSafetyProbeData[2]
waypointSafetyWorldVerts = XP_TEST_CaptureWorldVerts selectionTarget
waypointSafetyWidthsMatch = true
waypointSafetyProtectionRadius = (ceil (waypointSafetyProbeData[1].count * 0.06)) as integer
if waypointSafetyProtectionRadius < 4 do waypointSafetyProtectionRadius = 4
waypointSafetyFirstProtected = waypointSafetyProbeData[4][1] - waypointSafetyProtectionRadius
waypointSafetyLastProtected = waypointSafetyProbeData[4][waypointSafetyProbeData[4].count] + waypointSafetyProtectionRadius
if waypointSafetyFirstProtected < 2 do waypointSafetyFirstProtected = 2
if waypointSafetyLastProtected > (waypointSafetyProbeData[1].count - 1) do waypointSafetyLastProtected = waypointSafetyProbeData[1].count - 1
for waypointSafetyPointIndex = waypointSafetyFirstProtected to waypointSafetyLastProtected do
(
    waypointSafetyActualWidth = distance waypointSafetyWorldVerts[(waypointSafetyPointIndex - 1) * 2 + 1] waypointSafetyWorldVerts[(waypointSafetyPointIndex - 1) * 2 + 2]
    waypointSafetyExpectedWidth = 5.0 * XP_LG_EndpointTaperScale waypointSafetyProbeParameters[waypointSafetyPointIndex] true
    if (abs (waypointSafetyActualWidth - waypointSafetyExpectedWidth)) > 0.0001 do waypointSafetyWidthsMatch = false
)
XP_TEST_Assert waypointSafetyWidthsMatch "从首个途经点前过渡区到末个途经点后过渡区保持既有宽度倍率，不再被 Twist 安全优化局部缩窄"

-- R-027／R-028：途经点只修正基础导向曲线，最终噪波连续但不会在途经点被归零或重建。
continuousNoiseRoute = #([0.0,0.0,0.0], [50.0,0.0,0.0], [50.0,50.0,0.0])
continuousNoiseParameters = XP_LG_BuildRouteParameters continuousNoiseRoute
continuousNoiseAxes = XP_LG_BuildWaypointNoiseAxes continuousNoiseRoute
continuousNoiseGuides = XP_LG_BuildWaypointGuidePoints continuousNoiseRoute continuousNoiseParameters continuousNoiseAxes 15.0 1.0 1.0 73 1 true true
continuousNoiseTangents = XP_LG_BuildWaypointRouteTangents continuousNoiseGuides continuousNoiseParameters 100.0
continuousNoiseAtKnot = XP_LG_EvaluateWaypointRawNoiseOffset continuousNoiseParameters[2] continuousNoiseAxes 15.0 1.0 1.0 73 1 true true
continuousNoiseKnot = (XP_LG_EvaluateWaypointSpanPoint continuousNoiseGuides continuousNoiseParameters 1 1.0 15.0 1.0 1.0 73 1 true true routeTangents:continuousNoiseTangents waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 noiseAxes:continuousNoiseAxes)[1]
continuousNoiseLeft = (XP_LG_EvaluateWaypointSpanPoint continuousNoiseGuides continuousNoiseParameters 1 0.999 15.0 1.0 1.0 73 1 true true routeTangents:continuousNoiseTangents waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 noiseAxes:continuousNoiseAxes)[1]
continuousNoiseRight = (XP_LG_EvaluateWaypointSpanPoint continuousNoiseGuides continuousNoiseParameters 2 0.001 15.0 1.0 1.0 73 1 true true routeTangents:continuousNoiseTangents waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 noiseAxes:continuousNoiseAxes)[1]
continuousNoiseIncoming = normalize (continuousNoiseKnot - continuousNoiseLeft)
continuousNoiseOutgoing = normalize (continuousNoiseRight - continuousNoiseKnot)
XP_TEST_Assert (XP_TEST_PointNear continuousNoiseKnot continuousNoiseRoute[2] 0.00001) "带噪波的最终中心线仍精确经过途经点中心"
XP_TEST_Assert ((dot continuousNoiseIncoming continuousNoiseOutgoing) > 0.995) "带噪波的最终中心线在途经点进入与离开切线连续"
XP_TEST_Assert ((length continuousNoiseAtKnot) > 0.0001 and XP_TEST_PointNear (continuousNoiseGuides[2] + continuousNoiseAtKnot) continuousNoiseRoute[2] 0.00001) "途经点通过导向控制点预补偿命中中心，不会把噪波强制归零"
continuousNoiseSampleT = continuousNoiseParameters[2] + (continuousNoiseParameters[3] - continuousNoiseParameters[2]) * 0.271
continuousNoiseBase = XP_LG_EvaluateWaypointBasePoint continuousNoiseGuides continuousNoiseParameters continuousNoiseTangents 2 0.271 true 100.0
continuousNoiseExpectedOffset = XP_LG_EvaluateWaypointRawNoiseOffset continuousNoiseSampleT continuousNoiseAxes 15.0 1.0 1.0 73 1 true true
continuousNoiseRepeat = (XP_LG_EvaluateWaypointSpanPoint continuousNoiseGuides continuousNoiseParameters 2 0.271 15.0 1.0 1.0 73 1 true true routeTangents:continuousNoiseTangents waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 noiseAxes:continuousNoiseAxes)[1]
continuousNoiseRepeatAgain = (XP_LG_EvaluateWaypointSpanPoint continuousNoiseGuides continuousNoiseParameters 2 0.271 15.0 1.0 1.0 73 1 true true routeTangents:continuousNoiseTangents waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 noiseAxes:continuousNoiseAxes)[1]
XP_TEST_Assert (XP_TEST_PointNear continuousNoiseRepeat continuousNoiseRepeatAgain 0.000001) "连续全局噪波场对相同参数和种子确定复现"
XP_TEST_Assert (XP_TEST_PointNear (continuousNoiseRepeat - continuousNoiseBase) continuousNoiseExpectedOffset 0.000001) "途经点平滑只改变基础导向曲线，不缩放或旋转全局噪波偏移"
continuousNoiseMovedRoute = #([0.0,0.0,0.0], [35.0,30.0,20.0], [50.0,50.0,0.0])
continuousNoiseMovedAxes = XP_LG_BuildWaypointNoiseAxes continuousNoiseMovedRoute
continuousNoiseMovedOffset = XP_LG_EvaluateWaypointRawNoiseOffset continuousNoiseSampleT continuousNoiseMovedAxes 15.0 1.0 1.0 73 1 true true
XP_TEST_Assert (XP_TEST_PointNear continuousNoiseMovedOffset continuousNoiseExpectedOffset 0.000001) "移动途经点不改变同一全局参数位置的噪波场"
continuousTwistBefore = XP_LG_ComputeAxialTwistAngle continuousNoiseSampleT 4 45.0 true true
continuousTwistAfter = XP_LG_ComputeAxialTwistAngle continuousNoiseSampleT 4 45.0 true true
XP_TEST_Assert ((abs (continuousTwistBefore - continuousTwistAfter)) < 0.000001) "途经点不会重置或改变同一全局参数位置的 Twist 累计角"
foldbackPoints = #([0.0,0.0,0.0], [10.0,0.0,0.0], [5.0,0.0,0.0])
foldbackSides = #([0.0,1.0,0.0], [0.0,1.0,0.0], [0.0,-1.0,0.0])
XP_TEST_Assert (not (XP_LG_IsRibbonTwistSafe foldbackPoints foldbackSides 1.0)) "相邻截面反转造成的边界折返会被安全检查拒绝"

waypointGeometryBeforeFailure = XP_TEST_CaptureWorldVerts selectionTarget
waypointHandlesBeforeFailure = getUserProp selectionTarget "XP_LightningWaypointHandles"
insufficientWaypointResult = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 2 5.0 18.0 1.2 2.0 909 true true waypointNodes:#(waypointA, waypointB)
XP_TEST_Assert (insufficientWaypointResult == undefined and XP_TEST_VertArraysNear waypointGeometryBeforeFailure (XP_TEST_CaptureWorldVerts selectionTarget) 0.000001 and (getUserProp selectionTarget "XP_LightningWaypointHandles") == waypointHandlesBeforeFailure) "总面数不足时原子拒绝并保留原几何与原途经点列表"
duplicateWaypointResult = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 24 5.0 18.0 1.2 2.0 909 true true waypointNodes:#(waypointA, waypointA)
XP_TEST_Assert (duplicateWaypointResult == undefined and XP_TEST_VertArraysNear waypointGeometryBeforeFailure (XP_TEST_CaptureWorldVerts selectionTarget) 0.000001 and (getUserProp selectionTarget "XP_LightningWaypointHandles") == waypointHandlesBeforeFailure) "相邻重复途经点原子拒绝并保留原几何与原列表"
deletedWaypoint = Point name:"待删除途经点" pos:[80.0, 20.0, 90.0] size:3.0
delete deletedWaypoint
invalidWaypointResult = XP_LG_ReplaceSelectedOutput selectionTarget startNode endNodeA 24 5.0 18.0 1.2 2.0 909 true true waypointNodes:#(deletedWaypoint)
XP_TEST_Assert (invalidWaypointResult == undefined and XP_TEST_VertArraysNear waypointGeometryBeforeFailure (XP_TEST_CaptureWorldVerts selectionTarget) 0.000001 and (getUserProp selectionTarget "XP_LightningWaypointHandles") == waypointHandlesBeforeFailure) "已删除途经点原子拒绝并保留原几何与原列表"

select selectionTarget
XP_LG_LoadSelectedOutputIntoUI()
XP_TEST_Assert (XP_LG_WaypointOwnerNode == selectionTarget and XP_LG_WaypointNodes.count == 2 and XP_LG_WaypointNodes[1] == waypointA) "选中第一个面片时面板载入它自己的有序途经点列表"
XP_TEST_Assert (XP_LG_Rollout.chkWaypointSmoothing.checked and (abs (XP_LG_Rollout.spWaypointSmoothingStrength.value - 100.0)) < 0.00001) "重新选中面片时载入它独立保存的途经点平滑参数"
XP_TEST_Assert (XP_LG_CommitWaypointChange selectionTarget #(waypointB, waypointA) "测试下移途经点") "途经点排序操作可原位提交"
reorderedWaypointNodes = XP_LG_GetWaypointNodesFromOutput selectionTarget
XP_TEST_Assert (reorderedWaypointNodes.count == 2 and reorderedWaypointNodes[1] == waypointB and reorderedWaypointNodes[2] == waypointA) "途经点上移／下移后的对象顺序独立保存"
XP_TEST_Assert (XP_LG_CommitWaypointChange selectionTarget #() "测试清空途经点") "清空途经点可原位提交"
XP_TEST_Assert ((XP_LG_GetWaypointNodesFromOutput selectionTarget).count == 0) "清空后所选面片途经点列表为空"
XP_TEST_Assert (XP_LG_CommitWaypointChange selectionTarget #(waypointA, waypointB) "测试恢复途经点") "添加／恢复途经点列表可原位提交"

-- R-024：移动途经点后，重新选择所属面片时按坐标快照自动同步；未变化不重建，失败不递归重试。
controlSnapshotBeforeMove = getUserProp selectionTarget "XP_LightningControlSnapshot"
selectionTargetGeometryBeforeMove = XP_TEST_CaptureWorldVerts selectionTarget
selectionOtherGeometryBeforeControlSync = XP_TEST_CaptureWorldVerts selectionOther
selectionTargetSuccessCountBeforeMove = XP_LG_LiveUpdateSuccessCount
select selectionOther
XP_LG_HandleSelectionChanged()
waypointA.pos = waypointA.pos + [18.0, 12.0, 9.0]
select selectionTarget
XP_LG_HandleSelectionChanged()
XP_TEST_Assert (XP_LG_LiveUpdatePending and XP_LG_LiveUpdateTargetNode == selectionTarget) "重新选中面片时检测到途经点坐标变化并排队防抖更新"
controlSyncResult = XP_LG_FlushLiveUpdate()
controlSnapshotAfterMove = getUserProp selectionTarget "XP_LightningControlSnapshot"
movedWaypointRoute = #(XP_LG_GetWorldCenter startNode, XP_LG_GetWorldCenter waypointA, XP_LG_GetWorldCenter waypointB, XP_LG_GetWorldCenter endNodeA)
movedWaypointProbeData = XP_LG_BuildWaypointAdaptiveCenterline movedWaypointRoute 24 18.0 1.2 2.0 909 waypointSafetyProbeKey true true wholeTwistEnabled:true wholeTwistSegments:3 wholeTwistAmount:30.0 waypointSmoothingEnabled:true waypointSmoothingStrength:100.0 waypointAutoAddFaces:true
movedWaypointWorldVerts = XP_TEST_CaptureWorldVerts selectionTarget
movedWaypointAStation = movedWaypointProbeData[4][1] - 1
movedWaypointACenter = (movedWaypointWorldVerts[movedWaypointAStation * 2 + 1] + movedWaypointWorldVerts[movedWaypointAStation * 2 + 2]) * 0.5
XP_TEST_Assert (controlSyncResult == selectionTarget and controlSnapshotAfterMove != controlSnapshotBeforeMove and XP_LG_LiveUpdateSuccessCount == selectionTargetSuccessCountBeforeMove + 1 and XP_TEST_PointNear movedWaypointACenter (XP_LG_GetWorldCenter waypointA) 0.00001) ("途经点移动后所选面片原位同步并精确经过新中心；Error=" + XP_LG_LastError)
XP_TEST_Assert ((getHandleByAnim selectionTarget) == selectionTargetHandle and selectionTarget.name == selectionTargetName and selectionTarget.parent == selectionParent and selectionTarget.transform == selectionTargetTM and (polyop.getNumFaces selectionTarget.baseObject) == movedWaypointProbeData[3] and XP_TEST_VertArraysNear selectionOtherGeometryBeforeControlSync (XP_TEST_CaptureWorldVerts selectionOther) 0.000001) "坐标同步保持节点、名称、层级、Transform、安全实际面数并且不修改其他面片"

successfulGeometryBeforeFailure = XP_TEST_CaptureWorldVerts selectionTarget
successfulSnapshotBeforeFailure = getUserProp selectionTarget "XP_LightningControlSnapshot"
waypointAValidPosition = waypointA.pos
waypointA.pos = XP_LG_GetWorldCenter startNode
select selectionOther
XP_LG_HandleSelectionChanged()
select selectionTarget
XP_LG_HandleSelectionChanged()
XP_TEST_Assert XP_LG_LiveUpdatePending "无效的新途经点坐标仍会发起一次自动同步尝试"
failedControlSyncResult = XP_LG_FlushLiveUpdate()
XP_TEST_Assert (failedControlSyncResult == undefined and XP_TEST_VertArraysNear successfulGeometryBeforeFailure (XP_TEST_CaptureWorldVerts selectionTarget) 0.000001 and (getUserProp selectionTarget "XP_LightningControlSnapshot") == successfulSnapshotBeforeFailure) "坐标同步失败时保留旧几何与旧成功快照"
XP_LG_HandleSelectionChanged()
XP_TEST_Assert (not XP_LG_LiveUpdatePending) "相同失败坐标不会被选择回调连续重复提交"

waypointA.pos = waypointAValidPosition + [0.1, -0.1, 0.1]
select selectionOther
XP_LG_HandleSelectionChanged()
select selectionTarget
XP_LG_HandleSelectionChanged()
XP_TEST_Assert XP_LG_LiveUpdatePending "失败后再次移动途经点会解除失败签名并允许重新同步"
recoveredControlSyncResult = XP_LG_FlushLiveUpdate()
XP_TEST_Assert (recoveredControlSyncResult == selectionTarget and XP_LG_LastFailedControlSyncNode == undefined) ("有效新坐标可以成功恢复自动同步状态；Error=" + XP_LG_LastError)

successCountBeforeUnchangedSelection = XP_LG_LiveUpdateSuccessCount
unchangedGeometryBeforeSelection = XP_TEST_CaptureWorldVerts selectionTarget
select selectionOther
XP_LG_HandleSelectionChanged()
select selectionTarget
XP_LG_HandleSelectionChanged()
XP_TEST_Assert (not XP_LG_LiveUpdatePending and XP_LG_LiveUpdateSuccessCount == successCountBeforeUnchangedSelection and XP_TEST_VertArraysNear unchangedGeometryBeforeSelection (XP_TEST_CaptureWorldVerts selectionTarget) 0.000001) "控制点坐标未变化时反复选择不会重建面片"

deleteUserProp selectionTarget "XP_LightningControlSnapshot"
waypointB.pos = waypointB.pos + [-2.0, 3.0, 1.0]
select selectionOther
XP_LG_HandleSelectionChanged()
select selectionTarget
XP_LG_HandleSelectionChanged()
XP_TEST_Assert XP_LG_LiveUpdatePending "旧版有途经点但无坐标快照的面片首次选择会执行兼容同步"
legacySnapshotSyncResult = XP_LG_FlushLiveUpdate()
XP_TEST_Assert (legacySnapshotSyncResult == selectionTarget and (getUserProp selectionTarget "XP_LightningControlSnapshot") != undefined) ("兼容同步成功后为旧面片补写控制点快照；Error=" + XP_LG_LastError)

select selectionOther
XP_LG_LoadSelectedOutputIntoUI()
XP_TEST_Assert ((abs (XP_LG_Rollout.spWidth.value - 4.0)) < 0.000001 and XP_LG_EndNodes.count == 1 and XP_LG_EndNodes[1] == endNodeB and XP_LG_WaypointOwnerNode == selectionOther and XP_LG_WaypointNodes.count == 0) "切换选择后面板载入另一个面片自己的参数与空途经点列表"
deleteUserProp selectionOther "XP_LightningWaypointHandles"
XP_TEST_Assert ((XP_LG_GetWaypointNodesFromOutput selectionOther).count == 0) "旧版无途经点属性的面片按空列表兼容"
delete selectionTarget
delete selectionOther
delete selectionParent
delete waypointA
delete waypointB
XP_LG_OutputNodes = savedActiveOutputs
XP_LG_OutputNode = savedActiveOutputNode
XP_LG_SetOutputSetActive savedActiveOutputs true

protectedActiveNodes = for outputNode in XP_LG_OutputNodes collect outputNode
failedForcedNode = XP_LG_CreateNewOutputSet XP_LG_StartNode XP_LG_EndNodes 4 20.0 0.0 1.0 1.0 7 true true wholeTwistEnabled:true wholeTwistSegments:4 wholeTwistAmount:720.0
XP_TEST_Assert (failedForcedNode == undefined and XP_LG_OutputNodes.count == protectedActiveNodes.count and (XP_TEST_CountManagedOutputs()) == expectedManagedWithHistory and (XP_TEST_CountTemporaryOutputs()) == 0) "强制新建失败时活动组、历史组和场景对象数量保持不变"
for branchIndex = 1 to protectedActiveNodes.count do XP_TEST_Assert (XP_LG_OutputNodes[branchIndex] == protectedActiveNodes[branchIndex] and isValidNode protectedActiveNodes[branchIndex]) ("强制新建失败保留活动分支：" + branchIndex as string)

XP_LG_DeleteOutput()
XP_TEST_Assert ((XP_TEST_CountActiveOutputs()) == 0 and (XP_TEST_CountManagedOutputs()) == liveHistoricalNodes.count) "清除当前输出只删除活动组并保留全部强制生成历史组"
for branchIndex = 1 to liveHistoricalNodes.count do XP_TEST_Assert (isValidNode liveHistoricalNodes[branchIndex]) ("清除当前输出后历史分支仍有效：" + branchIndex as string)
XP_LG_CancelLiveUpdate()
try (destroyDialog XP_LG_Rollout) catch ()

packageRunExtractDir = ""
XP_LG_Rollout = undefined
packageRunResult = msZip.fileInPackage "E:/CodeXProject/3dsmaxLightning/dist/XP闪电面片生成器_V1.2.0.mzp" &packageRunExtractDir
XP_TEST_Assert packageRunResult "MZP 的 run 命令可由 3ds Max 2023 执行"
XP_TEST_Assert (XP_LG_Rollout != undefined) "MZP 的 run 主脚本成功定义中文插件窗口"

packageExtractDir = ""
packageDropFile = ""
packageUnloaded = msZip.unloadPackage "E:/CodeXProject/3dsmaxLightning/dist/XP闪电面片生成器_V1.2.0.mzp" &packageExtractDir &packageDropFile
XP_TEST_Assert packageUnloaded "MZP 可由 3ds Max 2023 正确解析和提取"
XP_TEST_Assert (packageDropFile != "") "MZP 的 drop 命令返回主脚本"
XP_TEST_Assert (doesFileExist packageDropFile) "MZP 提取后的 drop 主脚本存在"
fileIn packageDropFile quiet:true
XP_TEST_Assert (XP_LG_Rollout != undefined) "MZP 的 drop 主脚本可在 3ds Max 2023 中加载"

format "[XP_TEST_COMPLETE] 全部实机测试通过。\n"
