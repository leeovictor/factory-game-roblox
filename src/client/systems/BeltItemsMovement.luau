--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Types = require(ReplicatedStorage.Shared.Types)

local function findNodeByItemDistance(itemDistance: number, nodesNum: number)
	return nodesNum - math.floor(itemDistance / BeltSettings.BeltSubdiv)
end

local function BeltItemsMovementSystem(world: Types.World)
	local renderedMeshes = {}
	local cframes = {}

	for _id, belt: Types.BeltSegment, beltItems: Types.BeltItemsV2, meshes: Types.ItemsMeshes in
		world:query(Components.BeltSegment, Components.BeltItemsV2, Components.ItemsMeshes)
	do
		if #beltItems.items == 0 then
			continue
		end

		local pos = 0
		for _i, item in ipairs(beltItems.items) do
			pos += item.distFromNext
			local length = #belt.nodes * BeltSettings.BeltSubdiv
			local nodeIndex = findNodeByItemDistance(pos - 1, #belt.nodes)

			if nodeIndex == 0 or nodeIndex > #belt.nodes then
				-- FIXME: handle items that go out of bounds
				-- warn("Belt item out of bounds:", _id, item)
				continue
			end
			-- assert(nodeIndex ~= 0, "NodeIndex is zero")
			-- assert(nodeIndex <= #belt.nodes, "NodeIndex exceeds belt nodes count")

			local nodeProgress = (length - pos) - (BeltSettings.BeltSubdiv * (nodeIndex - 1))
			local node: Types.BeltNodeComponent = world:get(belt.nodes[nodeIndex], Components.BeltNode)

			local nodeStartPoint = node.pos - node.cframe.LookVector
			local nodeEndPoint = node.pos + node.cframe.LookVector
			local rightPoint = node.pos + node.cframe.RightVector
			local leftPoint = node.pos - node.cframe.RightVector

			local progress = nodeProgress / BeltSettings.BeltSubdiv -- 0 to 1

			local itemPos = nil
			if node.direction == "top" then
				itemPos = nodeStartPoint:Lerp(nodeEndPoint, progress)
			elseif node.direction == "left" then
				itemPos = progress < 0.5 and nodeStartPoint:Lerp(node.pos, progress * 2)
					or node.pos:Lerp(leftPoint, (progress - 0.5) * 2)
			elseif node.direction == "right" then
				itemPos = progress < 0.5 and nodeStartPoint:Lerp(node.pos, progress * 2)
					or node.pos:Lerp(rightPoint, (progress - 0.5) * 2)
			else
				error("Invalid belt node direction: " .. tostring(node.direction))
			end

			if not meshes[item] then
				error("Mesh not found for belt item: " .. tostring(item))
			end

			table.insert(renderedMeshes, meshes[item])
			table.insert(
				cframes,
				CFrame.new(itemPos + Vector3.new(0, 0.8, 0), itemPos + Vector3.new(0, 0.8, 0) + node.dirVector)
			)
		end
	end

	workspace:BulkMoveTo(renderedMeshes, cframes)
end

return {
	system = BeltItemsMovementSystem,
	event = "FixedUpdate",
	priority = 1001,
}
