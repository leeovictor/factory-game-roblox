local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Types = require(ReplicatedStorage.Shared.Types)
local CalculateItemPosition = {}

local function findNodeBySegment(nodesNumber: number, segmentsPerNodes: number, distance: number)
    local totalSegments = nodesNumber * segmentsPerNodes
    if distance >= totalSegments then
        return nodesNumber
    end

    local segmentIndex = math.floor((totalSegments - distance) / segmentsPerNodes) + 1
    return segmentIndex
end

function CalculateItemPosition:Execute(belt, distance, meshPart)
    local beltLength = #belt.nodes * BeltSettings.BeltSubdiv * 2
    local nodeIndex = findNodeBySegment(#belt.nodes, BeltSettings.BeltSubdiv * 2, distance)
    local node: Types.Beltnode = belt.nodes[nodeIndex]
    local prevNode = belt.nodes[nodeIndex - 1]

    local startSeg = (nodeIndex - 1) * (BeltSettings.BeltSubdiv * 2)
    local currentSegInNode = beltLength - distance - startSeg
    local startPosNode = node.pos - node.outDir

    local itemPos
    if prevNode and prevNode.outDir ~= node.outDir then
        local startPosNodeInCurve = node.pos - prevNode.outDir
        
        if currentSegInNode <= 10 then
            itemPos = startPosNodeInCurve + prevNode.outDir * ((beltLength - distance - startSeg) / BeltSettings.BeltSubdiv)
        else
            itemPos = startPosNode + node.outDir * ((beltLength - distance - startSeg) / BeltSettings.BeltSubdiv)
        end
    else
        itemPos = startPosNode + node.outDir * ((beltLength - distance - startSeg) / BeltSettings.BeltSubdiv)
    end
    
    task.synchronize()
    meshPart.CFrame = CFrame.new(itemPos + Vector3.yAxis)
end

return CalculateItemPosition