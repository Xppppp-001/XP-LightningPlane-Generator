/* Run manually in an isolated EMPTY 3ds Max 2023 scene.
   Never resets, opens or saves a scene. Uses Undo/Redo and deletes its own fixtures.
*/
global XP_RW_NoUI
global XP_RW_Rollout
global XP_RW_Apply
global XP_RW_Prepare
global XP_RW_TestReport
global XP_RW_TestCreated
global XP_RW_TestCount
global XP_RW_TestCheck
global XP_RW_TestPoints
global XP_RW_TestSamePoints
global XP_RW_TestEdgeBetween
global XP_RW_TestMakeRibbon
global XP_RW_TestReject
global XP_RW_TestCrossEdges
global XP_RW_TestSameBits
(
    if objects.count != 0 do throw "扩宽测试必须在隔离的空场景运行；当前场景未作修改。"
    local projectRoot = (dotNetClass "System.IO.Path").GetFullPath ((getFilenamePath (getSourceFileName())) + "../")
    XP_RW_TestReport = createFile (projectRoot + "artifacts/ribbon-widener-smoke.txt") encoding:#utf8
    XP_RW_TestCreated = #()
    XP_RW_TestCount = 0
    local failure = undefined
    local previousNoUI = XP_RW_NoUI

    fn XP_RW_TestCheck condition description =
    (
        if not condition do throw description
        XP_RW_TestCount = XP_RW_TestCount + 1
        format "OK %\n" description to:XP_RW_TestReport
    )
    fn XP_RW_TestPoints obj = for i = 1 to (polyop.getNumVerts obj.baseObject) collect (polyop.getVert obj.baseObject i)
    fn XP_RW_TestSameBits a b = (a-b).numberSet == 0 and (b-a).numberSet == 0
    fn XP_RW_TestSamePoints obj expected =
    (
        local current = XP_RW_TestPoints obj
        if current.count != expected.count do return false
        for i = 1 to current.count do if distance current[i] expected[i] > 0.00001 do return false
        true
    )
    fn XP_RW_TestEdgeBetween obj a b =
    (
        local edges = polyop.getEdgesUsingVert obj.baseObject #{a}
        for edgeId in edges do
        (
            local verts = polyop.getVertsUsingEdge obj.baseObject #{edgeId}
            if verts[b] do return edgeId
        )
        throw "测试模型缺少边。"
    )
    fn XP_RW_TestMakeRibbon columns:1 =
    (
        local obj = mesh name:"XP_RW_TestRibbon" numverts:0 numfaces:0
        append XP_RW_TestCreated obj
        convertToPoly obj
        local ep = obj.baseObject
        for row = 0 to 3 do
        (
            local center = [row * 10.0, row * row * 2.0, sin (row * 30.0) * 4.0]
            local side = [0, cos (row * 35.0), sin (row * 35.0)] * 2.0
            for column = 0 to columns do polyop.createVert ep (center + side * (2.0 * column / columns - 1.0))
        )
        local stride = columns + 1
        for row = 0 to 2 do for column = 0 to (columns - 1) do
        (
            local a = row * stride + column + 1
            polyop.createPolygon ep #(a, a+1, a+stride+1, a+stride)
        )
        polyop.setMapSupport ep 1 true
        polyop.setNumMapVerts ep 1 (4 * stride)
        polyop.setNumMapFaces ep 1 (3 * columns)
        for row = 0 to 3 do for column = 0 to columns do
            polyop.setMapVert ep 1 (row * stride + column + 1) [row/3.0,column as float / columns,0]
        for faceId = 1 to (3 * columns) do polyop.setMapFace ep 1 faceId (polyop.getFaceVerts ep faceId)
        update obj
        obj
    )
    fn XP_RW_TestCrossEdges obj columns side =
    (
        local edges = #{}
        for row = 0 to 3 do for column = 0 to (columns - 1) do
        (
            if side == #both or (side == #left and column == 0) or (side == #right and column == columns-1) do
            (
                local a = row * (columns+1) + column + 1
                edges[XP_RW_TestEdgeBetween obj a (a+1)] = true
            )
        )
        edges
    )
    fn XP_RW_TestReject factor obj description =
    (
        local before = XP_RW_TestPoints obj
        local result = XP_RW_Apply factor
        XP_RW_TestCheck (not result[1]) description
        XP_RW_TestCheck (XP_RW_TestSamePoints obj before) (description + "：顶点不变")
    )

    try
    (
        XP_RW_NoUI = true
        fileIn (projectRoot + "src/XP_RibbonWidener.ms")
        local obj = XP_RW_TestMakeRibbon()
        obj.rotation = eulerAngles 21 37 15
        obj.scale = [2.0,0.6,1.3]
        obj.pos = [120,-35,67]
        obj.material = standardMaterial name:"扩宽测试材质"
        local originalMaterial = obj.material
        local originalMatrix = copy obj.transform
        local originalPivot = copy obj.pivot
        local originalHandle = getHandleByAnim obj
        local original = XP_RW_TestPoints obj
        local originalUV = for i = 1 to 8 collect (polyop.getMapVert obj 1 i)
        local originalFaces = for i = 1 to 3 collect (polyop.getFaceVerts obj i)
        local originalMapFaces = for i = 1 to 3 collect (polyop.getMapFace obj 1 i)
        local crossEdges = #{}
        for row = 0 to 2 do crossEdges[XP_RW_TestEdgeBetween obj (row*2+1) (row*2+2)] = true
        polyop.setEdgeSelection obj crossEdges
        select obj

        for factor in #(0.5,1.0,1.5,2.0) do
        (
            local before = XP_RW_TestPoints obj
            local result = XP_RW_Apply factor
            XP_RW_TestCheck result[1] ("倍率应用成功：" + factor as string)
            local after = XP_RW_TestPoints obj
            for row = 0 to 2 do
            (
                local a = row*2+1
                local b = a+1
                local p = before[a] * obj.objectTransform
                local q = before[b] * obj.objectTransform
                local u = after[a] * obj.objectTransform
                local v = after[b] * obj.objectTransform
                XP_RW_TestCheck (distance ((p+q)/2) ((u+v)/2) < 0.0001) "世界截面中点不变"
                XP_RW_TestCheck (abs ((distance u v) - (distance p q)*factor) < 0.0001) "世界宽度符合倍率"
                XP_RW_TestCheck ((dot (normalize (q-p)) (normalize (v-u))) > 0.99999) "世界截面方向不变"
            )
            XP_RW_TestCheck (after[7] == before[7] and after[8] == before[8]) "未选横边顶点不变"
            XP_RW_TestCheck (obj.transform == originalMatrix and obj.pivot == originalPivot) "应用后变换和轴心不变"
            XP_RW_TestCheck (obj.material == originalMaterial) "应用后材质不变"
            XP_RW_TestCheck (XP_RW_TestSameBits (polyop.getEdgeSelection obj) crossEdges) "应用后边选择不变"
            for i = 1 to 8 do XP_RW_TestCheck ((polyop.getMapVert obj 1 i) == originalUV[i]) "应用后 UV 顶点不变"
            for i = 1 to 3 do
            (
                XP_RW_TestCheck (((polyop.getFaceVerts obj i) as string) == (originalFaces[i] as string)) "应用后几何索引不变"
                XP_RW_TestCheck (((polyop.getMapFace obj 1 i) as string) == (originalMapFaces[i] as string)) "应用后 UV 索引不变"
            )
            if factor != 1.0 do
            (
                max undo
                XP_RW_TestCheck (XP_RW_TestSamePoints obj before) "一次撤销恢复全部顶点"
                max redo
                XP_RW_TestCheck (XP_RW_TestSamePoints obj after) "重做恢复扩宽结果"
                max undo
            )
        )
        XP_RW_TestCheck ((getHandleByAnim obj) == originalHandle and obj.name == "XP_RW_TestRibbon") "节点身份和名称不变"
        XP_RW_TestCheck (obj.transform == originalMatrix and obj.pivot == originalPivot) "对象变换和轴心不变"
        XP_RW_TestCheck (obj.material == originalMaterial and selection.count == 1 and selection[1] == obj) "材质和对象选择不变"
        XP_RW_TestCheck (XP_RW_TestSameBits (polyop.getEdgeSelection obj) crossEdges) "边选择不变"
        XP_RW_TestCheck ((polyop.getNumVerts obj) == 8 and (polyop.getNumFaces obj) == 3) "拓扑数量不变"
        for i = 1 to 8 do XP_RW_TestCheck ((polyop.getMapVert obj 1 i) == originalUV[i]) "UV 顶点不变"
        for i = 1 to 3 do
        (
            XP_RW_TestCheck (((polyop.getFaceVerts obj i) as string) == (originalFaces[i] as string)) "几何面索引不变"
            XP_RW_TestCheck (((polyop.getMapFace obj 1 i) as string) == (originalMapFaces[i] as string)) "UV 面索引不变"
        )
        clearSelection()
        XP_RW_TestReject 1.5 obj "拒绝空选择"
        local boxNode = box name:"XP_RW_TestBox"
        append XP_RW_TestCreated boxNode
        select #(obj, boxNode)
        XP_RW_TestReject 1.5 obj "拒绝多对象"
        select boxNode
        XP_RW_TestCheck (not (XP_RW_Apply 1.5)[1]) "拒绝非可编辑多边形"
        select obj
        for factor in #(0,-1,101,"错误") do XP_RW_TestReject factor obj "拒绝非法倍率"
        polyop.setEdgeSelection obj #{}
        XP_RW_TestReject 1.5 obj "拒绝空选边"
        local adjacent = copy crossEdges
        adjacent[XP_RW_TestEdgeBetween obj 1 3] = true
        polyop.setEdgeSelection obj adjacent
        XP_RW_TestReject 1.5 obj "拒绝共享顶点选边"
        polyop.setEdgeSelection obj crossEdges
        local duplicate = instance obj
        append XP_RW_TestCreated duplicate
        XP_RW_TestReject 1.5 obj "拒绝共享实例"
        undo "清理测试实例" on (delete duplicate)
        addModifier obj (Bend())
        XP_RW_TestReject 1.5 obj "拒绝修改器堆栈"
        deleteModifier obj 1
        polyop.setVert obj.baseObject #{2} original[1]
        update obj
        XP_RW_TestReject 1.5 obj "拒绝零长度截面"

        -- R-044: actual quad meshes, including terminal rows and varied IDs.
        for columns in #(1,2,3,4) do
        (
            local grid = XP_RW_TestMakeRibbon columns:columns
            grid.rotation = eulerAngles -17 42 23
            grid.scale = [0.7,2.1,1.4]
            grid.pos = [-210,44,35]
            local basePoints = XP_RW_TestPoints grid
            local gridMatrix = copy grid.transform
            local gridPivot = copy grid.pivot
            local stride = columns + 1
            local gridUV = for i = 1 to basePoints.count collect (polyop.getMapVert grid 1 i)
            local gridFaces = for i = 1 to (3*columns) collect (polyop.getFaceVerts grid i)
            local gridMapFaces = for i = 1 to (3*columns) collect (polyop.getMapFace grid 1 i)
            select grid
            for factor in #(0.5,1.0,1.5,3.0) do
            (
                local leftResult = undefined
                for side in #(#left,#right,#both) do
                (
                    local picked = XP_RW_TestCrossEdges grid columns side
                    polyop.setEdgeSelection grid picked
                    local plan = XP_RW_Prepare #(grid) factor
                    XP_RW_TestCheck (plan[5] == 4) "整排去重：含首尾共四个截面"
                    XP_RW_TestCheck (plan[2].numberSet == basePoints.count) "补齐全部截面顶点且无重复"
                    XP_RW_TestCheck (plan[6] == (4*columns - picked.numberSet)) "自动补齐边数量正确"
                    XP_RW_TestCheck (XP_RW_TestSamePoints grid basePoints) "解析与校验阶段没有写入"
                    local result = XP_RW_Apply factor
                    XP_RW_TestCheck result[1] "多列横截面应用成功"
                    local actual = XP_RW_TestPoints grid
                    if side == #left then leftResult = actual
                    else XP_RW_TestCheck (XP_RW_TestSamePoints grid leftResult) "左侧、右侧、双侧选择结果等价"
                    for row = 0 to 3 do
                    (
                        local first = row*stride+1
                        local last = first+columns
                        local center = (basePoints[first]+basePoints[last])/2.0
                        local centerWorld = center * grid.objectTransform
                        if (mod columns 2) == 0 do
                        (
                            local middle = first + ((columns/2) as integer)
                            XP_RW_TestCheck (actual[middle] == basePoints[middle]) "真实中线顶点完全不动"
                        )
                        XP_RW_TestCheck (distance ((actual[first]+actual[last])/2.0) center < 0.00001) "整排左右边界中点不动"
                        for column = 0 to columns do
                        (
                            local id = first+column
                            local oldOffset = basePoints[id] * grid.objectTransform - centerWorld
                            local newOffset = actual[id] * grid.objectTransform - centerWorld
                            XP_RW_TestCheck (abs ((length newOffset) - (length oldOffset)*factor) < 0.0002) "左右及内部顶点按相同倍率扩宽"
                            if length oldOffset > 0.001 do
                                XP_RW_TestCheck ((dot (normalize newOffset) (normalize oldOffset)) > 0.99999) "扩宽方向保持"
                        )
                    )
                    XP_RW_TestCheck (grid.transform == gridMatrix and grid.pivot == gridPivot) "多列对象位置、旋转、缩放、轴心不动"
                    XP_RW_TestCheck (XP_RW_TestSameBits (polyop.getEdgeSelection grid) picked) "补齐不改用户边选择"
                    XP_RW_TestCheck ((polyop.getNumVerts grid) == basePoints.count and (polyop.getNumFaces grid) == 3*columns) "中线与网格拓扑数量保持"
                    for i = 1 to basePoints.count do XP_RW_TestCheck ((polyop.getMapVert grid 1 i) == gridUV[i]) "多列 UV 顶点不变"
                    for i = 1 to (3*columns) do
                    (
                        XP_RW_TestCheck (((polyop.getFaceVerts grid i) as string) == (gridFaces[i] as string)) "多列几何面索引不变"
                        XP_RW_TestCheck (((polyop.getMapFace grid 1 i) as string) == (gridMapFaces[i] as string)) "多列 UV 面索引不变"
                    )
                    if factor != 1.0 do
                    (
                        max undo
                        XP_RW_TestCheck (XP_RW_TestSamePoints grid basePoints) "多列一次撤销恢复"
                        max redo
                        XP_RW_TestCheck (XP_RW_TestSamePoints grid actual) "多列重做恢复"
                        max undo
                    )
                )
            )
            polyop.setEdgeSelection grid #{1..(polyop.getNumEdges grid)}
            XP_RW_TestReject 3.0 grid "拒绝全选纵横所有边，零写入"
            if columns > 1 do
            (
                local bentId = 3*stride+2
                polyop.setVert grid.baseObject #{bentId} (basePoints[bentId] + [1,0,0])
                update grid
                polyop.setEdgeSelection grid (XP_RW_TestCrossEdges grid columns #both)
                XP_RW_TestReject 3.0 grid "末排非法时前面合法截面也不写入"
            )
        )

        convertToPoly boxNode
        select boxNode
        polyop.setEdgeSelection boxNode #{1}
        XP_RW_TestReject 1.5 boxNode "拒绝不能到达边界的封闭网格"
        local triangle = mesh vertices:#([0,0,0],[4,0,0],[0,4,0]) faces:#([1,2,3])
        append XP_RW_TestCreated triangle
        convertToPoly triangle
        select triangle
        polyop.setEdgeSelection triangle #{1}
        XP_RW_TestReject 1.5 triangle "拒绝非四边面"

        XP_RW_NoUI = false
        fileIn (projectRoot + "dist/XP模型扩宽工具_V1.2.0.mzp")
        XP_RW_TestCheck (XP_RW_Rollout.hwnd != 0) "MZP run 打开窗口"
        XP_RW_TestCheck (XP_RW_Rollout.spnFactor.value == 1.5) "默认倍率 1.5"
        fileIn (projectRoot + "dist/XP模型扩宽工具_V1.2.0.mzp")
        XP_RW_TestCheck (XP_RW_Rollout.hwnd != 0) "重复加载可重新打开窗口"
        XP_RW_TestCheck (XP_RW_Rollout.btnApply.text == "应用宽度倍率") "中文应用按钮"
    )
    catch (failure = getCurrentException() as string)
    try (destroyDialog XP_RW_Rollout) catch ()
    XP_RW_NoUI = previousNoUI
    undo "清理扩宽测试对象" on
    (
        for obj in XP_RW_TestCreated where isValidNode obj do delete obj
    )
    if failure == undefined then format "PASS | assertions=% | %\n" XP_RW_TestCount localTime to:XP_RW_TestReport
    else format "FAIL | assertions=% | %\n" XP_RW_TestCount failure to:XP_RW_TestReport
    close XP_RW_TestReport
    if failure != undefined do throw failure
)
