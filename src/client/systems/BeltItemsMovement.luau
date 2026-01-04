--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Types = require(ReplicatedStorage.Shared.Types)

local function findNodeBySegment(nodesNumber: number, segmentsPerNodes: number, distance: number)
	local totalSegments = nodesNumber * segmentsPerNodes
	if distance >= totalSegments then
		return nodesNumber
	end

	local segmentIndex = math.floor((totalSegments - distance) / segmentsPerNodes) + 1
	return segmentIndex
end

local function BeltItemsMovementSystem(world, _state)
	local meshes = {}
	local cframes = {}
	for _id, belt: Types.BeltPath, beltItems: Types.BeltItemComponent in
		world:query(Components.BeltPath, Components.BeltItems)
	do
		if #beltItems.items == 0 then
			continue
		end

		local distance = 0
		local beltNodesView = world:query(Components.BeltNode):view()
		for _i, item in ipairs(beltItems.items) do
			distance += item.distFromNext

			local beltLength = #belt.nodes * BeltSettings.BeltSubdiv * 2
			local nodeIndex = findNodeBySegment(#belt.nodes, BeltSettings.BeltSubdiv * 2, distance)
			local node: Types.BeltNodeComponent = beltNodesView:get(belt.nodes[nodeIndex])
			local prevNode: Types.BeltNodeComponent = beltNodesView:get(belt.nodes[nodeIndex - 1])

			local startSeg = (nodeIndex - 1) * (BeltSettings.BeltSubdiv * 2)
			local currentSegInNode = beltLength - distance - startSeg
			local startPosNode = node.pos - node.outDir

			local itemPos
			if prevNode and prevNode.outDir ~= node.outDir then
				local startPosNodeInCurve = node.pos - prevNode.outDir
				if currentSegInNode <= 10 then
					itemPos = startPosNodeInCurve
						+ prevNode.outDir * ((beltLength - distance - startSeg) / BeltSettings.BeltSubdiv)
				else
					itemPos = startPosNode
						+ node.outDir * ((beltLength - distance - startSeg) / BeltSettings.BeltSubdiv)
				end
			else
				itemPos = startPosNode + node.outDir * ((beltLength - distance - startSeg) / BeltSettings.BeltSubdiv)
			end

			table.insert(meshes, item.mesh)
			table.insert(cframes, CFrame.new(itemPos + Vector3.new(0, 0.8, 0)))
		end
	end

	workspace:BulkMoveTo(meshes, cframes)
end

return {
	system = BeltItemsMovementSystem,
	event = "FixedUpdate",
	priority = math.huge,
}
