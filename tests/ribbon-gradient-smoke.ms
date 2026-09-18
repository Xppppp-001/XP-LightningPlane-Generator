/* Isolated empty-scene test, after ribbon-widener-smoke.ms. No scene reset/save. */
global XP_RW_GReport
global XP_RW_GCount
global XP_RW_GCreated
global XP_RW_GCheck
global XP_RW_GMaps
global XP_RW_GSameMaps
global XP_RW_GMakeMaps
global XP_RW_GReject
(
    if objects.count != 0 do throw "渐变测试必须使用隔离空场景。"
    local root = (dotNetClass "System.IO.Path").GetFullPath ((getFilenamePath (getSourceFileName())) + "../")
    XP_RW_GReport = createFile (root + "artifacts/ribbon-gradient-smoke.txt") encoding:#utf8
    XP_RW_GCount = 0
    XP_RW_GCreated = #()
    local failure = undefined
    fn XP_RW_GCheck condition description =
    (
        if not condition do throw description
        XP_RW_GCount = XP_RW_GCount + 1
        format "OK %\n" description to:XP_RW_GReport
    )
    -- Includes disabled support flags, unused map vertices, seams and hidden channels.
    fn XP_RW_GMaps obj =
    (
        local ep = obj.baseObject
        local result = #(polyop.getNumMaps ep)
        for channel = -2 to ((polyop.getNumMaps ep)-1) do
        (
            local supported = polyop.getMapSupport ep channel
            local data = #(channel, supported)
            if supported do
            (
                append data (polyop.getNumMapVerts ep channel)
                append data (polyop.getNumMapFaces ep channel)
                append data (for i = 1 to data[3] collect (polyop.getMapVert ep channel i))
                append data (for i = 1 to data[4] collect (polyop.getMapFace ep channel i))
            )
            append result data
        )
        result
    )
    fn XP_RW_GSameMaps obj original =
    (
        local actual = XP_RW_GMaps obj
        if actual.count != original.count or actual[1] != original[1] do return false
        for i = 2 to original.count do
        (
            local a = actual[i]
            local b = original[i]
            if a.count != b.count or a[1] != b[1] or a[2] != b[2] do return false
            if b[2] do
            (
                if a[3] != b[3] or a[4] != b[4] do return false
                for v = 1 to b[3] do if a[5][v] != b[5][v] do return false
                for f = 1 to b[4] do if a[6][f].count != b[6][f].count do return false
                for f = 1 to b[4] do for corner = 1 to b[6][f].count do
                    if a[6][f][corner] != b[6][f][corner] do return false
            )
        )
        true
    )
    fn XP_RW_GMakeMaps obj =
    (
        local ep = obj.baseObject
        local faces = polyop.getNumFaces ep
        polyop.setNumMaps ep 8 keep:true
        for channel in #(-2,-1,0,1,3,7) do
        (
            polyop.setMapSupport ep channel true
            polyop.setNumMapVerts ep channel (faces*4+1) keep:false
            polyop.setNumMapFaces ep channel faces keep:false
            for i = 1 to (faces*4+1) do polyop.setMapVert ep channel i [i*0.17-3.0,channel*0.2+i*0.071,sin (i*17.0)]
            for f = 1 to faces do polyop.setMapFace ep channel f #(f*4-3,f*4-2,f*4-1,f*4)
        )
        update obj
    )
    fn XP_RW_GReject obj marker startFactor endFactor description =
    (
        local points = XP_RW_TestPoints obj
        local maps = XP_RW_GMaps obj
        local result = XP_RW_ApplyGradient startFactor endFactor marker
        XP_RW_GCheck (not result[1]) (description + "：拒绝")
        XP_RW_GCheck (XP_RW_TestSamePoints obj points) (description + "：几何不变")
        XP_RW_GCheck (XP_RW_GSameMaps obj maps) (description + "：全部 UV 精确不变")
    )
    try
    (
        XP_RW_NoUI = true
        fileIn (root + "src/XP_RibbonWidener.ms")
        for fixtureMode in #(#curved,#straight) do for columns in #(1,2,3,4) do
        (
            local obj = XP_RW_TestMakeRibbon columns:columns
            append XP_RW_GCreated obj
            local stride = columns+1
            -- Unequal world-space centerline segments and pre-existing varying widths.
            local centers = #([0,0,0],[2,1,0],[9,4,2],[30,12,7])
            if fixtureMode == #straight do centers = #([0,0,0],[2,0,0],[9,0,0],[30,0,0])
            for row = 0 to 3 do
            (
                local side = [0,cos (row*35.0),sin (row*35.0)] * (2.0+row*0.7)
                if fixtureMode == #straight do side = [0,2.0+row*0.7,0]
                for column = 0 to columns do polyop.setVert obj.baseObject (row*stride+column+1) (centers[row+1]+side*(2.0*column/columns-1.0))
            )
            obj.rotation = eulerAngles 27 -35 11
            obj.scale = [0.6,2.3,1.7]
            obj.pos = [-97,62,33]
            obj.baseObject.preserveUVs = (mod columns 2)==0
            local preserveUVs = obj.baseObject.preserveUVs
            XP_RW_GMakeMaps obj
            format "FIXTURE mode=% columns=% PreserveUVs=% channels=-2,-1,0,1,3,7\n" fixtureMode columns preserveUVs to:XP_RW_GReport
            local original = XP_RW_TestPoints obj
            local maps = XP_RW_GMaps obj
            local topology = XP_RW_TopologySignature obj.baseObject
            local transform = copy obj.transform
            local pivot = copy obj.pivot
            local handle = getHandleByAnim obj
            obj.material = standardMaterial name:"渐变测试材质"
            local material = obj.material
            local lengths = #(0.0)
            for row = 2 to 4 do append lengths (lengths[row-1] + distance (centers[row-1]*obj.objectTransform) (centers[row]*obj.objectTransform))
            select obj
            for startRow in #(0,3) do
            (
                local a = startRow*stride+1
                polyop.setEdgeSelection obj #{XP_RW_TestEdgeBetween obj a (a+1)}
                local marker = XP_RW_CaptureStart #(obj)
                XP_RW_GCheck (XP_RW_TestSamePoints obj original and XP_RW_GSameMaps obj maps) "记录起点零写入"
                for factors in #(#(2.0,0.5),#(0.5,2.0),#(1.0,1.0),#(1.5,1.5)) do
                (
                    local expected = #()
                    for row = 0 to 3 do
                    (
                        local t = lengths[row+1]/lengths[4]
                        if startRow == 3 do t = 1.0-t
                        local factor = factors[1]*(1.0-t)+factors[2]*t
                        for column = 0 to columns do
                        (
                            local id = row*stride+column+1
                            append expected (if factor == 1.0 or ((mod columns 2)==0 and column==columns/2) then original[id] else centers[row+1]+(original[id]-centers[row+1])*factor)
                        )
                    )
                    for side in #(#left,#right,#both) do
                    (
                        local edges = XP_RW_TestCrossEdges obj columns side
                        polyop.setEdgeSelection obj edges
                        local plan = XP_RW_PrepareGradient #(obj) factors[1] factors[2] marker
                        XP_RW_GCheck (plan[5]==4 and XP_RW_TestSamePoints obj original and XP_RW_GSameMaps obj maps) "渐变预计算零写入、截面去重"
                        local result = XP_RW_ApplyGradient factors[1] factors[2] marker
                        XP_RW_GCheck result[1] ("渐变成功：" + result[2])
                        XP_RW_GCheck (XP_RW_TestSamePoints obj expected) "首尾方向、相对倍率、世界弧长插值符合独立预期"
                        local actual = XP_RW_TestPoints obj
                        for row = 0 to 3 do
                        (
                            local first = row*stride+1
                            local last = first+columns
                            XP_RW_GCheck (distance ((actual[first]+actual[last])/2) centers[row+1] < 0.00001) "渐变中线中心不动"
                            XP_RW_GCheck ((dot (normalize (actual[last]-actual[first])) (normalize (original[last]-original[first]))) > 0.99999) "渐变截面方向与扭转不变"
                            if (mod columns 2)==0 do XP_RW_GCheck (actual[first+(columns/2) as integer]==original[first+(columns/2) as integer]) "真实中线顶点精确不动"
                        )
                        XP_RW_GCheck (obj.transform==transform and obj.pivot==pivot and XP_RW_TestSameBits (polyop.getEdgeSelection obj) edges) "渐变不改变位置、轴心或选边"
                        XP_RW_GCheck ((XP_RW_TopologySignature obj.baseObject)==topology) "渐变拓扑索引不变"
                        XP_RW_GCheck ((getHandleByAnim obj)==handle and obj.material==material) "渐变节点身份与材质保持"
                        XP_RW_GCheck (XP_RW_GSameMaps obj maps) "应用／无操作：所有通道、接缝、未引用 UVW、面索引精确不变"
                        XP_RW_GCheck (obj.baseObject.preserveUVs==preserveUVs) "不修改 Preserve UVs 开关"
                        if factors[1]!=1.0 or factors[2]!=1.0 do
                        (
                            max undo
                            XP_RW_GCheck (XP_RW_TestSamePoints obj original and XP_RW_GSameMaps obj maps) "渐变一次撤销：几何恢复、全部 UV 不变"
                            max redo
                            XP_RW_GCheck (XP_RW_TestSamePoints obj actual and XP_RW_GSameMaps obj maps) "渐变重做：几何恢复、全部 UV 不变"
                            max undo
                        )
                    )
                )
                polyop.setEdgeSelection obj (XP_RW_TestCrossEdges obj columns #both)
                XP_RW_GReject obj undefined 2 0.5 "未设置起点"
                XP_RW_GReject obj marker 0 0.5 "非法首端倍率"
                XP_RW_GReject obj marker 2 101 "非法末端倍率"
                local stale = #(obj,obj.baseObject,copy marker[3],"失效拓扑")
                XP_RW_GReject obj stale 2 0.5 "已改变拓扑的起点标记"
                local partial = XP_RW_TestCrossEdges obj columns #both
                for column = 0 to columns-1 do partial[XP_RW_TestEdgeBetween obj (3*stride+column+1) (3*stride+column+2)] = false
                polyop.setEdgeSelection obj partial
                XP_RW_GReject obj marker 2 0.5 "漏选末端"
                polyop.setEdgeSelection obj #{1..(polyop.getNumEdges obj)}
                XP_RW_GReject obj marker 2 0.5 "全选纵横所有边"
            )
            local a = stride+1
            polyop.setEdgeSelection obj #{XP_RW_TestEdgeBetween obj a (a+1)}
            local rejected = false
            try (XP_RW_CaptureStart #(obj)) catch (rejected=true)
            XP_RW_GCheck (rejected and XP_RW_TestSamePoints obj original and XP_RW_GSameMaps obj maps) "拒绝中间排作为起点且零写入"
            -- Uniform operation also preserves every map channel.
            polyop.setEdgeSelection obj (XP_RW_TestCrossEdges obj columns #both)
            XP_RW_GCheck (XP_RW_Apply 1.5)[1] "多通道模型统一扩宽成功"
            XP_RW_GCheck (XP_RW_GSameMaps obj maps) "统一扩宽全部 UV 精确不变"
            max undo
            XP_RW_GCheck (XP_RW_TestSamePoints obj original and XP_RW_GSameMaps obj maps) "统一扩宽撤销全部 UV 精确不变"
            max redo
            XP_RW_GCheck (XP_RW_GSameMaps obj maps) "统一扩宽重做全部 UV 精确不变"
            max undo
            -- Marker from another node, and 1->1 must not consume an Undo item.
            polyop.setEdgeSelection obj #{XP_RW_TestEdgeBetween obj 1 2}
            local marker = XP_RW_CaptureStart #(obj)
            local other = XP_RW_TestMakeRibbon columns:columns
            append XP_RW_GCreated other
            select other
            polyop.setEdgeSelection other (XP_RW_TestCrossEdges other columns #both)
            XP_RW_GReject other marker 2 0.5 "其他对象的起点标记"
            local untouched = XP_RW_TestPoints other
            select obj
            polyop.setEdgeSelection obj (XP_RW_TestCrossEdges obj columns #both)
            XP_RW_GCheck (XP_RW_ApplyGradient 2 0.5 marker)[1] "无操作撤销测试：先渐变"
            local current = XP_RW_TestPoints obj
            XP_RW_GCheck (XP_RW_ApplyGradient 1 1 marker)[1] "无操作撤销测试：1→1 成功"
            XP_RW_GCheck (XP_RW_TestSamePoints obj current and XP_RW_GSameMaps obj maps) "1→1 几何与全部 UV 精确不变"
            max undo
            XP_RW_GCheck (XP_RW_TestSamePoints obj original and XP_RW_GSameMaps obj maps) "1→1 不占用撤销项"
            XP_RW_GCheck (XP_RW_TestSamePoints other untouched) "其他对象不受渐变影响"
        )
        -- Invoke real rollout event handlers from the packaged entry point.
        local uiObj = XP_RW_TestMakeRibbon columns:2
        append XP_RW_GCreated uiObj
        XP_RW_GMakeMaps uiObj
        local uiPoints = XP_RW_TestPoints uiObj
        local uiMaps = XP_RW_GMaps uiObj
        select uiObj
        XP_RW_NoUI = false
        fileIn (root + "dist/XP模型扩宽工具_V1.2.0.mzp")
        XP_RW_GCheck (XP_RW_Rollout.hwnd!=0 and XP_RW_Rollout.spnStart.value==1 and XP_RW_Rollout.spnEnd.value==1) "MZP 渐变中文窗口与默认值"
        XP_RW_Rollout.spnStart.value = 2
        XP_RW_Rollout.spnEnd.value = 0.5
        XP_RW_Rollout.btnSwap.pressed()
        XP_RW_GCheck (XP_RW_Rollout.spnStart.value==0.5 and XP_RW_Rollout.spnEnd.value==2 and XP_RW_Rollout.spnFactor.value==1.5) "交换首尾按钮真实事件，不叠乘统一倍率"
        XP_RW_GCheck (XP_RW_TestSamePoints uiObj uiPoints and XP_RW_GSameMaps uiObj uiMaps) "交换首尾零写入"
        polyop.setEdgeSelection uiObj #{XP_RW_TestEdgeBetween uiObj 1 2}
        XP_RW_Rollout.btnSetStart.pressed()
        XP_RW_GCheck (matchPattern XP_RW_Rollout.lblStart.text pattern:"起点已设置*") "设置起点按钮真实事件与中文状态"
        XP_RW_GCheck (XP_RW_TestSamePoints uiObj uiPoints and XP_RW_GSameMaps uiObj uiMaps) "设置起点按钮零写入"
        local uiMarker = XP_RW_CaptureStart #(uiObj)
        polyop.setEdgeSelection uiObj (XP_RW_TestCrossEdges uiObj 2 #both)
        local uiPlan = XP_RW_PrepareGradient #(uiObj) 0.5 2 uiMarker
        XP_RW_Rollout.btnGradient.pressed()
        XP_RW_GCheck (XP_RW_TestSamePoints uiObj uiPlan[4] and XP_RW_GSameMaps uiObj uiMaps) "应用渐变按钮真实事件与 UV 保持"
        max undo
        XP_RW_GCheck (XP_RW_TestSamePoints uiObj uiPoints and XP_RW_GSameMaps uiObj uiMaps) "UI 应用一次撤销"
        local previousRollout = XP_RW_Rollout
        fileIn (root + "dist/XP模型扩宽工具_V1.2.0.mzp")
        XP_RW_GCheck (previousRollout.hwnd==0 and XP_RW_Rollout.hwnd!=0) "MZP 重复加载关闭旧窗口，只开新窗口"
        XP_RW_GCheck (XP_RW_Rollout.lblStart.text=="起点未设置；设置后再环选整条横截面。") "重新加载清空起点状态"
        destroyDialog XP_RW_Rollout
    )
    catch (failure=getCurrentException() as string)
    try (destroyDialog XP_RW_Rollout) catch ()
    undo "清理渐变测试" on (for obj in XP_RW_GCreated where isValidNode obj do delete obj)
    if failure==undefined then format "PASS | assertions=% | %\n" XP_RW_GCount localTime to:XP_RW_GReport
    else format "FAIL | assertions=% | %\n" XP_RW_GCount failure to:XP_RW_GReport
    close XP_RW_GReport
    if failure!=undefined do throw failure
)
