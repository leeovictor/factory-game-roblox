--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Types = require(ReplicatedStorage.Shared.Types)

local function findNodeByItemDistance(itemDistance: number, nodesNum: number)
	return nodesNum - math.floor(itemDistance * BeltSettings.BeltSubdivInv)
end

local function calculateItemPositionInNode(node: Types.BeltNodeComponent, progress: number): Vector3
	local doubleProgress = progress * 2

	if node.direction == "top" then
		return node.cframe:PointToWorldSpace(Vector3.new(0, 0, 1 - doubleProgress))
	elseif progress < 0.5 then
		-- Primeira metade da curva (comum para left e right)
		return node.cframe:PointToWorldSpace(Vector3.new(0, 0, 1 - doubleProgress))
	elseif node.direction == "left" then
		return node.cframe:PointToWorldSpace(Vector3.new(-(progress - 0.5) * 2, 0, 0))
	else -- right
		return node.cframe:PointToWorldSpace(Vector3.new((progress - 0.5) * 2, 0, 0))
	end
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

		local beltLength = #belt.nodes * BeltSettings.BeltSubdiv
		local dist = 0
		for _i, item in ipairs(beltItems.items) do
			dist += item.distFromNext
			local nodeIndex = findNodeByItemDistance(dist - 1, #belt.nodes)

			if nodeIndex == 0 or nodeIndex > #belt.nodes then
				-- FIXME: handle items that go out of bounds
				continue
			end

			local nodeProgress = (beltLength - dist) - (BeltSettings.BeltSubdiv * (nodeIndex - 1))
			local node: Types.BeltNodeComponent = world:get(belt.nodes[nodeIndex], Components.BeltNode)

			local progress = nodeProgress * BeltSettings.BeltSubdivInv
			local itemPos = calculateItemPositionInNode(node, progress)

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
