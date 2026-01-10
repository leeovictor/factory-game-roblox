local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TouchInputService = game:GetService("TouchInputService")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Gizmos = require(ReplicatedStorage.Shared.Gizmos)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local Types = require(ReplicatedStorage.Shared.Types)
local MinerSystem = require(script.Parent.MinerSystem)

type BeltItem = {
	distFromNext: number,
	item: string,
}

local function ConveyorBeltSystem(world: Types.World)
	-- local function tryInsertItemIntoNodeBelt(nodeId: Types.EntityId, item: string): boolean
	-- 	-- 1. verify is there space on the node belt to insert the item
	-- 	-- 2. insert the item on the center of the belt node and update dists
	-- 	-- 3. the min space required to add a item is 1, soo we need to compress
	-- 	-- the items behind the new item, substracting the space ocupied by the new item until and each distFromNext until no more space is needed

	-- 	-- check if there space in the node
	-- 	local beltNode: Types.BeltNodeComponent = world:get(nodeId, Components.BeltNode)
	-- 	local beltPath: Types.BeltPath = world:get(beltNode.beltPath, Components.BeltPath)
	-- 	local beltItems: Types.BeltItemComponent = world:get(beltNode.beltPath, Components.BeltItems)

	-- 	local nodeDistFromEnd = (#beltPath.nodes - beltNode.index) * BeltSettings.BeltSubdiv

	-- 	local dropDistance = nodeDistFromEnd + BeltSettings.BeltSubdiv / 2

	-- 	-- no items in the source belt, simply insert
	-- 	if #beltItems.items == 0 then
	-- 		table.insert(
	-- 			beltItems.items,
	-- 			{
	-- 				item = item,
	-- 				distFromNext = dropDistance,
	-- 				mesh = Helpers.createItemMesh(item),
	-- 			} :: Types.BeltItem
	-- 		)
	-- 		beltPath.distToInsertAtStart = (#beltPath.nodes * BeltSettings.BeltSubdiv) - nodeDistFromEnd
	-- 		return true
	-- 	end

	-- 	-- item is to far behind. insert item
	-- 	if beltItems.items[1].distFromNext > dropDistance + 1 then
	-- 		table.insert(
	-- 			beltItems.items,
	-- 			1,
	-- 			{
	-- 				item = item,
	-- 				distFromNext = dropDistance,
	-- 				mesh = Helpers.createItemMesh(item),
	-- 			} :: Types.BeltItem
	-- 		)
	-- 		beltItems.items[2].distFromNext -= dropDistance
	-- 		return true
	-- 	end

	-- 	local distance = 0
	-- 	for i = 1, #beltItems.items do
	-- 		distance += beltItems.items[i].distFromNext

	-- 		if distance < dropDistance - BeltSettings.ItemOcupancy then
	-- 			continue
	-- 		end

	-- 		if distance <= dropDistance + 1 and distance >= dropDistance - BeltSettings.ItemOcupancy then
	-- 			-- no space to insert item here
	-- 			return false
	-- 		else
	-- 			-- can insert item here
	-- 			-- TODO cases
	-- 			-- a. will be be inserted as last item
	-- 			--    i. calculate distFromNext to the next item
	-- 			--    i. update distToInsertAtStart of the beltPath
	-- 			-- b. will be inserted in the middle of other items
	-- 			--    i. calculate distFromNext to the next item
	-- 			--	  ii. update the distFromNext of the previous items to compress the items behind the new item if have space

	-- 			return false
	-- 		end
	-- 	end

	-- 	return false
	-- end

	-- filter last belt paths
	local lastBeltPaths: { Types.EntityId } = {}
	for id, belt: Types.BeltPath in world:query(Components.BeltPath) do
		if belt.nextBelt == nil then
			table.insert(lastBeltPaths, id)
		end
	end

	local function insertItemIntoNextBelt(beltId: Types.EntityId, item: Types.BeltItem)
		if item.distFromNext > 0 then
			return false
		end

		local beltPath: Types.BeltPath = world:get(beltId, Components.BeltPath)
		local beltItems: Types.BeltItemComponent = world:get(beltId, Components.BeltItems)

		table.insert(
			beltItems.items,
			{
				item = item.item,
				distFromNext = beltPath.distToInsertAtStart,
				mesh = Helpers.createItemMesh(item.item),
			} :: Types.BeltItem
		)
		beltPath.distToInsertAtStart = 0
		return true
	end

	for _, beltId in ipairs(lastBeltPaths) do
		local currentBelt = beltId

		local iter = 0
		repeat
			if iter > 100000 then
				error("Possible infinite loop detected in belt traversal")
			end

			local beltPath: Types.BeltPath = world:get(currentBelt, Components.BeltPath)
			local beltItems: Types.BeltItemComponent = world:get(currentBelt, Components.BeltItems)

			for i = 1, #beltItems.items do
				if beltItems.items[i].distFromNext > BeltSettings.ItemOcupancy then
					beltItems.items[i].distFromNext -= beltPath.speed
					beltPath.distToInsertAtStart += beltPath.speed
					break
				end

				if beltPath.nextBelt == nil then
					continue
				end

				if i == 1 then
					local nextBeltPath: Types.BeltPath = world:get(beltPath.nextBelt, Components.BeltPath)
					if
						beltItems.items[i].distFromNext - beltPath.speed + nextBeltPath.distToInsertAtStart
						>= BeltSettings.ItemOcupancy
					then
						if beltItems.items[i].distFromNext > 0 then
							beltItems.items[i].distFromNext -= beltPath.speed
							beltPath.distToInsertAtStart += beltPath.speed
						elseif insertItemIntoNextBelt(beltPath.nextBelt, beltItems.items[i]) then
							beltItems.items[i].mesh:Destroy()
							table.remove(beltItems.items, i)
						end
						break
					end
				end
			end

			currentBelt = beltPath.prevBelt
			iter += 1
		until currentBelt == nil
	end
end

return {
	system = ConveyorBeltSystem,
	event = "FixedUpdate",
	after = { MinerSystem },
}
