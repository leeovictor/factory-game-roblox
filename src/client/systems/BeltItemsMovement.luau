--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Gizmos = require(ReplicatedStorage.Shared.Gizmos)
local Types = require(ReplicatedStorage.Shared.Types)

local function findNodeByItemDistance(itemDistance: number, length: number)
	return math.floor((length - itemDistance) / BeltSettings.BeltSubdiv) + 1
end

local function BeltItemsMovementSystem(world: Types.World, gameState)
	local meshes = {}
	local cframes = {}

	local beltNodesView = world:query(Components.BeltNode):view()

	for _id, belt: Types.BeltPath, beltItems: Types.BeltItemComponent in
		world:query(Components.BeltPath, Components.BeltItems)
	do
		if #beltItems.items == 0 then
			continue
		end

		local distance = 0
		for _i, item in ipairs(beltItems.items) do
			distance += item.distFromNext

			local length = #belt.nodes * BeltSettings.BeltSubdiv
			local nodeIndex = findNodeByItemDistance(distance, length)
			local nodeProgress = (length - distance) - (BeltSettings.BeltSubdiv * (nodeIndex - 1))
			local node: Types.BeltNodeComponent = beltNodesView:get(belt.nodes[nodeIndex])

			local nodeStartPoint = node.pos - node.cframe.LookVector
			local nodeEndPoint = node.pos + node.cframe.LookVector
			local rightPoint = node.pos + node.cframe.RightVector
			local leftPoint = node.pos - node.cframe.RightVector

			local progress = nodeProgress / BeltSettings.BeltSubdiv -- 0 to 1

			if gameState.debug then
				Gizmos.setColor3(Color3.fromRGB(53, 255, 188))
				Gizmos.drawPoint(rightPoint)
				Gizmos.setColor3(Color3.fromRGB(71, 38, 255))
				Gizmos.drawPoint(leftPoint)
			end

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

			if gameState.debug then
				Gizmos.drawPoint(itemPos)
				Gizmos.setColor3(Color3.fromRGB(255, 0, 0))
			end

			table.insert(meshes, item.mesh)
			table.insert(cframes, CFrame.new(itemPos + Vector3.new(0, 0.8, 0)))
		end
	end

	workspace:BulkMoveTo(meshes, cframes)
end

return {
	system = BeltItemsMovementSystem,
	priority = math.huge,
}
