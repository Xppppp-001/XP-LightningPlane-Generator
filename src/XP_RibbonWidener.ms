/* XP模型扩宽工具 V1.2.0 | Autodesk 3ds Max 2023
   R-044: Complete quad-grid rows; preserve their center vertices.
   Base-object coordinates make this independent of the active reference system.
*/
global XP_RW_Rollout
global XP_RW_NoUI

try (destroyDialog XP_RW_Rollout) catch ()

fn XP_RW_IsFinitePoint p =
(
    local singleType = dotNetClass "System.Single"
    not (singleType.IsNaN p.x or singleType.IsNaN p.y or singleType.IsNaN p.z or singleType.IsInfinity p.x or singleType.IsInfinity p.y or singleType.IsInfinity p.z)
)

fn XP_RW_QuadFaces ep edgeId =
(
    local faces = polyop.getFacesUsingEdge ep #{edgeId}
    if faces.numberSet < 1 or faces.numberSet > 2 do throw "横截面包含孤立边或非流形连接，请使用连续四边面网格。"
    for faceId in faces do
        if (polyop.getFaceVerts ep faceId).count != 4 do throw "横截面附近有三角面或多边面，无法可靠补齐。请使用规则四边面网格。"
    faces
)

-- Opposite edges at a regular quad-grid vertex do not share a face.
-- The same rule continues across the center vertex of a border row.
fn XP_RW_WalkSectionEnd ep vertexId incomingEdge visitedVerts sectionEdges borderVerts =
(
    local ordered = #(vertexId)
    local currentVertex = vertexId
    local currentEdge = incomingEdge
    local finished = false
    while not finished do
    (
        local incomingFaces = XP_RW_QuadFaces ep currentEdge
        local incidentEdges = polyop.getEdgesUsingVert ep #{currentVertex}
        local candidates = #()
        for edgeId in incidentEdges where edgeId != currentEdge do
        (
            local faces = XP_RW_QuadFaces ep edgeId
            if (faces * incomingFaces).numberSet == 0 do append candidates edgeId
        )
        if candidates.count > 1 do throw "横截面出现分叉，无法确定另一侧。请检查网格连接与横边选择。"
        if candidates.count == 0 then
        (
            if not borderVerts[currentVertex] do throw "横截面未能延伸到开放边界，请检查内部不规则顶点。"
            finished = true
        )
        else
        (
            local nextEdge = candidates[1]
            local pair = (polyop.getVertsUsingEdge ep #{nextEdge}) as array
            if pair.count != 2 do throw "横截面含无效边，请先修复模型。"
            local nextVertex = if pair[1] == currentVertex then pair[2] else pair[1]
            if visitedVerts[nextVertex] do throw "横截面形成闭环或重复经过顶点，不能作为开放带状截面。"
            visitedVerts[nextVertex] = true
            sectionEdges[nextEdge] = true
            append ordered nextVertex
            currentVertex = nextVertex
            currentEdge = nextEdge
        )
    )
    ordered
)

fn XP_RW_TraceSection ep seedEdge borderVerts =
(
    local pair = (polyop.getVertsUsingEdge ep #{seedEdge}) as array
    if pair.count != 2 do throw "选边包含无效边，请重新选择横向截面。"
    local vertices = #{pair[1],pair[2]}
    local sectionEdges = #{seedEdge}
    local left = XP_RW_WalkSectionEnd ep pair[1] seedEdge vertices sectionEdges borderVerts
    local right = XP_RW_WalkSectionEnd ep pair[2] seedEdge vertices sectionEdges borderVerts
    local ordered = for i = left.count to 1 by -1 collect left[i]
    join ordered right
    #(ordered, vertices, sectionEdges)
)

-- This function only reads the scene. No vertex is written until all checks pass.
fn XP_RW_Prepare nodes factor =
(
    if nodes.count != 1 do throw "请只选中一个需要扩宽的带状模型。"
    local obj = nodes[1]
    if not isValidNode obj do throw "选中的对象已失效，请重新选择。"
    if classOf obj.baseObject != Editable_Poly do throw "请先将模型转换为可编辑多边形（Editable Poly）。"
    if obj.modifiers.count != 0 do throw "模型仍有修改器。请使用已完成变形的可编辑多边形副本，再执行扩宽。"
    if not (isKindOf factor Number) do throw "宽度倍率必须是数值。"
    local singleType = dotNetClass "System.Single"
    if singleType.IsNaN factor or singleType.IsInfinity factor do throw "宽度倍率必须是有限数值。"
    if factor < 0.01 or factor > 100.0 do throw "宽度倍率范围为 0.01～100。"

    local instances = #()
    InstanceMgr.GetInstances obj &instances
    if instances.count > 1 do throw "模型与其他对象共享实例。请先制作独立副本，以免一起改变。"

    local ep = obj.baseObject
    local edges = polyop.getEdgeSelection ep
    if edges.numberSet == 0 do throw "尚未选择横向边。请进入边层级，选一条横边，再使用环形选择。"
    local usedVerts = #{}
    local completedEdges = #{}
    local borderVerts = polyop.getVertsUsingEdge ep (polyop.getOpenEdges ep)
    local oldById = #()
    local newById = #()
    local sectionCount = 0
    local sections = #()
    for edgeId in edges where not completedEdges[edgeId] do
    (
        local section = XP_RW_TraceSection ep edgeId borderVerts
        local row = section[1]
        if (usedVerts * section[2]).numberSet != 0 do throw "选边混入了相交的纵向边。请只选择横边，可选一侧或两侧，不要全选模型所有边。"
        local rowPoints = for vertexId in row collect (polyop.getVert ep vertexId)
        for p in rowPoints do if not (XP_RW_IsFinitePoint p) do throw "模型包含非法顶点坐标，无法扩宽。"
        local p1 = rowPoints[1]
        local p2 = rowPoints[row.count]
        local span = distance p1 p2
        if span <= 0.000001 do throw "横截面为零长度或过短，请先修复模型。"
        local axis = (p2 - p1) / span
        local tolerance = amax 0.000001 (span * 0.0001)
        local centerIndex = if (mod row.count 2) == 1 then ((row.count + 1) / 2) as integer else 0
        local center = if centerIndex > 0 then rowPoints[centerIndex] else (p1 + p2) / 2.0
        local previousAlong = -1.0
        local previousNew = undefined
        for i = 1 to row.count do
        (
            local p = rowPoints[i]
            local along = dot (p - p1) axis
            if distance p (p1 + axis * along) > tolerance do throw "识别出的整排边明显弯折，可能选到了纵边。请先撤销旧版扩宽，再选择规则横向截面。"
            if i > 1 and along - previousAlong <= 0.000001 do throw "横截面包含重合点或折返，请先修复模型。"
            local q = if i == centerIndex then p else center + (p - center) * factor
            if not (XP_RW_IsFinitePoint q) do throw "扩宽后坐标超出有效范围，请降低倍率。"
            if previousNew != undefined do
                if distance q previousNew <= 0.000001 do throw "调整后截面边过短，请提高倍率。"
            oldById[row[i]] = p
            newById[row[i]] = q
            previousAlong = along
            previousNew = q
        )
        usedVerts = usedVerts + section[2]
        completedEdges = completedEdges + section[3]
        sectionCount = sectionCount + 1
        append sections section
    )
    local ids = usedVerts as array
    local before = for vertexId in ids collect oldById[vertexId]
    local after = for vertexId in ids collect newById[vertexId]
    #(obj, usedVerts, before, after, sectionCount, (completedEdges - edges).numberSet, sections)
)

fn XP_RW_CheckFactor factor =
(
    if not (isKindOf factor Number) do throw "首尾倍率必须是数值。"
    local singleType = dotNetClass "System.Single"
    if singleType.IsNaN factor or singleType.IsInfinity factor do throw "首尾倍率必须是有限数值。"
    if factor < 0.01 or factor > 100.0 do throw "首尾倍率范围为 0.01～100。"
    true
)

fn XP_RW_TopologySignature ep =
(
    local output = stringStream ""
    format "%/%/%|" (polyop.getNumVerts ep) (polyop.getNumEdges ep) (polyop.getNumFaces ep) to:output
    for faceId = 1 to (polyop.getNumFaces ep) do format "%|" (polyop.getFaceVerts ep faceId) to:output
    local result = output as string
    close output
    result
)

fn XP_RW_CaptureStart nodes =
(
    local plan = XP_RW_Prepare nodes 1.0
    if plan[5] != 1 do throw "设置起点时，请只选择同一个端部截面的横边。"
    local section = plan[7][1]
    if (section[3] - (polyop.getOpenEdges plan[1].baseObject)).numberSet != 0 do throw "起点必须是条带端部的横截面，请勿选择中间排。"
    #(plan[1], plan[1].baseObject, copy section[2], XP_RW_TopologySignature plan[1].baseObject)
)

-- A full-strip chain is built from quad connectivity, never from IDs or UVs.
fn XP_RW_PrepareGradient nodes startFactor endFactor marker =
(
    XP_RW_CheckFactor startFactor
    XP_RW_CheckFactor endFactor
    local plan = XP_RW_Prepare nodes 1.0
    local obj = plan[1]
    local ep = obj.baseObject
    if marker == undefined do throw "请先选择端部横边并点击“设置起点”。"
    if not (isKindOf marker Array) do throw "起点标记无效，请重新设置起点。"
    if marker.count != 4 do throw "起点标记无效，请重新设置起点。"
    if not isValidNode marker[1] do throw "起点对象已失效，请重新设置起点。"
    if marker[1] != obj or marker[2] != ep do throw "当前对象不是已设置起点的模型，请重新设置起点。"
    if marker[4] != (XP_RW_TopologySignature ep) do throw "模型拓扑已改变，请重新设置起点。"
    local rows = plan[7]
    if rows.count < 2 or plan[2].numberSet != (polyop.getNumVerts ep) do throw "首尾渐变需要选齐整条模型的横截面，包括起点和终点。"
    local stride = rows[1][1].count
    if (polyop.getNumFaces ep) != (rows.count - 1) * (stride - 1) do throw "渐变需要完整、规则且无分叉的四边条带。"
    local rowByVertex = #()
    local columnByVertex = #()
    local neighbors = #()
    local neighborLinks = #()
    local links = #()
    local centers = #()
    for rowId = 1 to rows.count do
    (
        local ordered = rows[rowId][1]
        if ordered.count != stride do throw "各截面的宽度列数不一致，无法进行首尾渐变。"
        for columnId = 1 to stride do
        (
            rowByVertex[ordered[columnId]] = rowId
            columnByVertex[ordered[columnId]] = columnId
        )
        append neighbors #()
        append neighborLinks #()
        local middle = if (mod stride 2) == 1 then ((stride + 1) / 2) as integer else 0
        local center = if middle > 0 then polyop.getVert ep ordered[middle] else ((polyop.getVert ep ordered[1]) + (polyop.getVert ep ordered[stride])) / 2.0
        append centers center
    )
    for faceId = 1 to (polyop.getNumFaces ep) do
    (
        local faceVerts = polyop.getFaceVerts ep faceId
        if faceVerts.count != 4 do throw "渐变只支持规则四边条带。"
        local faceRows = #()
        for vertexId in faceVerts do appendIfUnique faceRows rowByVertex[vertexId]
        if faceRows.count != 2 do throw "横边选择或网格连接不规则，请重新选择完整横截面。"
        local a = faceRows[1]
        local b = faceRows[2]
        local neighborIndex = findItem neighbors[a] b
        local linkId = 0
        if neighborIndex == 0 then
        (
            linkId = links.count + 1
            append links #(a,b,true,true,#{})
            append neighbors[a] b
            append neighborLinks[a] linkId
            append neighbors[b] a
            append neighborLinks[b] linkId
            if neighbors[a].count > 2 or neighbors[b].count > 2 do throw "截面链存在分叉，无法确定首尾。"
        )
        else linkId = neighborLinks[a][neighborIndex]
        local link = links[linkId]
        local columnsA = #()
        local columnsB = #()
        for vertexId in faceVerts do
            if rowByVertex[vertexId] == link[1] then append columnsA columnByVertex[vertexId] else append columnsB columnByVertex[vertexId]
        if columnsA.count != 2 or columnsB.count != 2 do throw "四边面没有连接两排完整横截面。"
        local lowA = amin columnsA[1] columnsA[2]
        if abs (columnsA[1]-columnsA[2]) != 1 or abs (columnsB[1]-columnsB[2]) != 1 do throw "网格跨列连接，无法按完整条带渐变。"
        if link[5][lowA] do throw "同一截面区间包含重复连接，请先修复模型。"
        link[5][lowA] = true
        local crossCount = 0
        for corner = 1 to 4 do
        (
            local v1 = faceVerts[corner]
            local v2 = faceVerts[if corner == 4 then 1 else corner + 1]
            if rowByVertex[v1] != rowByVertex[v2] do
            (
                crossCount = crossCount + 1
                link[3] = link[3] and columnByVertex[v1] == columnByVertex[v2]
                link[4] = link[4] and columnByVertex[v1] + columnByVertex[v2] == stride + 1
            )
        )
        if crossCount != 2 or (not link[3] and not link[4]) do throw "相邻截面有交叉或不一致的列连接，请先修复模型。"
    )
    for link in links do if link[5].numberSet != stride-1 do throw "相邻截面缺少四边面，无法渐变。"
    local ends = for rowId = 1 to rows.count where neighbors[rowId].count == 1 collect rowId
    if ends.count != 2 do throw "截面链不是有两个端部的开放条带，可能存在闭环或断开。"
    local startRow = 0
    for rowId in ends do
        if (rows[rowId][2] - marker[3]).numberSet == 0 and (marker[3] - rows[rowId][2]).numberSet == 0 do startRow = rowId
    if startRow == 0 do throw "已标记起点不再是本条带端部，请重新设置起点。"
    local chain = #()
    local visited = #{}
    local current = startRow
    local previous = 0
    while current != 0 do
    (
        if visited[current] do throw "截面链存在闭环，无法渐变。"
        visited[current] = true
        append chain current
        local nextRow = 0
        for adjacent in neighbors[current] where adjacent != previous do
        (
            if nextRow != 0 do throw "截面链存在分叉。"
            nextRow = adjacent
        )
        previous = current
        current = nextRow
    )
    if chain.count != rows.count do throw "横截面没有组成同一条连续条带，请检查漏选或断开。"
    local cumulative = #(0.0)
    local total = 0.0
    local previousWorld = centers[chain[1]] * obj.objectTransform
    if not (XP_RW_IsFinitePoint previousWorld) do throw "模型世界坐标非法，无法计算渐变长度。"
    for i = 2 to chain.count do
    (
        local centerWorld = centers[chain[i]] * obj.objectTransform
        if not (XP_RW_IsFinitePoint centerWorld) do throw "模型世界坐标非法，无法计算渐变长度。"
        local segmentLength = distance previousWorld centerWorld
        if segmentLength <= 0.000001 do throw "相邻截面的中线重合或过短，无法计算渐变长度。"
        total = total + segmentLength
        append cumulative total
        previousWorld = centerWorld
    )
    local newByVertex = #()
    for i = 1 to chain.count do
    (
        local rowId = chain[i]
        local t = cumulative[i] / total
        local factor = if startFactor == endFactor then startFactor else if i == 1 then startFactor else if i == chain.count then endFactor else startFactor * (1.0-t) + endFactor * t
        local ordered = rows[rowId][1]
        local center = centers[rowId]
        local middle = if (mod stride 2) == 1 then ((stride + 1) / 2) as integer else 0
        local previousNew = undefined
        for columnId = 1 to stride do
        (
            local vertexId = ordered[columnId]
            local p = polyop.getVert ep vertexId
            local q = if columnId == middle or factor == 1.0 then p else center + (p-center) * factor
            if not (XP_RW_IsFinitePoint q) do throw "渐变坐标超出有效范围，请调整首尾倍率。"
            if previousNew != undefined do if distance previousNew q <= 0.000001 do throw "渐变后截面边过短，请调整首尾倍率。"
            newByVertex[vertexId] = q
            previousNew = q
        )
    )
    plan[4] = for vertexId in plan[2] collect newByVertex[vertexId]
    plan
)

-- Only geometry vertices are written. No UV/map mutation or topology API.
fn XP_RW_Commit plan status =
(
    local obj = plan[1]
    local problem = undefined
    undo "模型截面宽度调整" on
    (
        with animate off
        (
            try
            (
                polyop.setVert obj.baseObject plan[2] plan[4]
                update obj
            )
            catch
            (
                problem = "扩宽失败，已恢复本次操作前的顶点。"
                try
                (
                    polyop.setVert obj.baseObject plan[2] plan[3]
                    update obj
                )
                catch (problem = "扩宽失败，自动恢复也失败。请立即用 Ctrl+Z 撤销本次操作，并检查模型。")
            )
        )
    )
    redrawViews()
    if problem != undefined then #(false, problem)
    else #(true, status)
)

fn XP_RW_Apply factor =
(
    local plan = undefined
    try (plan = XP_RW_Prepare (selection as array) factor)
    catch (return #(false, (getCurrentException() as string)))
    if factor == 1.0 do return #(true, "倍率为 1，模型保持当前宽度。")
    XP_RW_Commit plan ("已调整 " + (plan[5] as string) + " 排截面，补齐 " + (plan[6] as string) + " 根横边，中线保持。倍率 " + (factor as string) + "；Ctrl+Z 可撤销。")
)

fn XP_RW_ApplyGradient startFactor endFactor marker =
(
    local plan = undefined
    try (plan = XP_RW_PrepareGradient (selection as array) startFactor endFactor marker)
    catch (return #(false, (getCurrentException() as string)))
    if startFactor == 1.0 and endFactor == 1.0 do return #(true, "首尾倍率均为 1，模型与原 UV 保持不变。")
    XP_RW_Commit plan ("已渐变 " + (plan[5] as string) + " 排截面：" + (startFactor as string) + " → " + (endFactor as string) + "。中线与原 UV 保持；Ctrl+Z 可撤销。")
)

rollout XP_RW_Rollout "XP模型扩宽工具 V1.2.0" width:440 height:466
(
    local startMarker = undefined
    label lblIntro "整排截面两侧均匀扩宽，已有中线顶点保持不动。" pos:[16,14] width:390 height:20
    label lblStep1 "① 只选一个可编辑多边形，进入边层级。" pos:[16,42] width:360 height:20
    label lblStep2 "② 选择横边（可选一侧或两侧）→ 应用倍率。" pos:[16,66] width:390 height:20
    spinner spnFactor "宽度倍率：" pos:[86,104] width:210 range:[0.01,100.0,1.5] type:#float scale:0.05
    button btnApply "应用宽度倍率" pos:[16,138] width:388 height:32
    label lblMeaning "1.5＝当前宽度的150%；0.5＝一半；1＝不变。" pos:[16,179] width:360 height:20
    label lblLimit "自动补齐整排横边；勿全选所有边；连续点击会累乘。" pos:[16,202] width:390 height:20
    groupBox grpGradient "首尾宽度渐变（保留中线、弯曲与扭转）" pos:[12,224] width:416 height:168
    button btnSetStart "设置起点：先选端部横边" pos:[24,248] width:390 height:26
    label lblStart "起点未设置；设置后再环选整条横截面。" pos:[24,278] width:390 height:20
    spinner spnStart "起点倍率：" pos:[24,304] width:166 range:[0.01,100.0,1.0] type:#float scale:0.05
    spinner spnEnd "终点倍率：" pos:[208,304] width:166 range:[0.01,100.0,1.0] type:#float scale:0.05
    button btnSwap "交换首尾" pos:[24,338] width:102 height:30
    button btnGradient "应用首尾渐变" pos:[136,338] width:278 height:30
    label lblUV "只移动几何顶点，不重展、不归一化原 UV。" pos:[16,398] width:410 height:20
    label lblStatus "就绪。统一倍率或首尾渐变均可 Ctrl+Z 撤销。" pos:[16,424] width:410 height:38
    on btnApply pressed do
    (
        local result = XP_RW_Apply spnFactor.value
        lblStatus.text = result[2]
        if not result[1] do messageBox result[2] title:"XP模型扩宽工具"
    )
    on btnSetStart pressed do
    (
        try
        (
            startMarker = XP_RW_CaptureStart (selection as array)
            lblStart.text = "起点已设置：" + startMarker[1].name + "；请环选全部横截面。"
            lblStatus.text = "已记录端部起点，模型和 UV 未修改。"
        )
        catch
        (
            startMarker = undefined
            lblStart.text = "起点未设置；请选择端部横边。"
            lblStatus.text = getCurrentException() as string
            messageBox lblStatus.text title:"XP模型扩宽工具"
        )
    )
    on btnSwap pressed do
    (
        local value = spnStart.value
        spnStart.value = spnEnd.value
        spnEnd.value = value
    )
    on btnGradient pressed do
    (
        local result = XP_RW_ApplyGradient spnStart.value spnEnd.value startMarker
        lblStatus.text = result[2]
        if not result[1] do messageBox result[2] title:"XP模型扩宽工具"
    )
)

fn XP_RW_OpenUI =
(
    try (destroyDialog XP_RW_Rollout) catch ()
    createDialog XP_RW_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
)

if XP_RW_NoUI != true do XP_RW_OpenUI()
