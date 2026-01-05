local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	local function tryInsertItemIntoNodeBelt(nodeId: Types.EntityId, item: string): boolean
		-- 1. verify is there space on the node belt to insert the item
		-- 2. insert the item on the center of the belt node and update dists
		-- 3. the min space required to add a item is 1, soo we need to compress
		-- the items behind the new item, substracting the space ocupied by the new item until and each distFromNext until no more space is needed

		-- check if there space in the node
		local beltNode: Types.BeltNodeComponent = world:get(nodeId, Components.BeltNode)
		local beltPath: Types.BeltPath = world:get(beltNode.beltPath, Components.BeltPath)
		local beltItems: Types.BeltItemComponent = world:get(beltNode.beltPath, Components.BeltItems)

		local nodeDistFromEnd = (#beltPath.nodes - beltNode.index) * BeltSettings.BeltSubdiv

		local dropDistance = nodeDistFromEnd + BeltSettings.BeltSubdiv / 2

		-- no items in the source belt, simply insert
		if #beltItems.items == 0 then
			table.insert(
				beltItems.items,
				{
					item = item,
					distFromNext = dropDistance,
					mesh = Helpers.createItemMesh(item),
				} :: Types.BeltItem
			)
			beltPath.distToInsertAtStart = (#beltPath.nodes * BeltSettings.BeltSubdiv) - nodeDistFromEnd
			return true
		end

		-- item is to far behind. insert item
		if beltItems.items[1].distFromNext > dropDistance + 1 then
			table.insert(
				beltItems.items,
				1,
				{
					item = item,
					distFromNext = dropDistance,
					mesh = Helpers.createItemMesh(item),
				} :: Types.BeltItem
			)
			beltItems.items[2].distFromNext -= dropDistance
			return true
		end

		local distance = 0
		for i = 1, #beltItems.items do
			distance += beltItems.items[i].distFromNext

			if distance < dropDistance - BeltSettings.ItemOcupancy then
				continue
			end

			if distance <= dropDistance + 1 and distance >= dropDistance - BeltSettings.ItemOcupancy then
				-- no space to insert item here
				return false
			else
				-- can insert item here
				-- TODO cases
				-- a. will be be inserted as last item
				--    i. calculate distFromNext to the next item
				--    i. update distToInsertAtStart of the beltPath
				-- b. will be inserted in the middle of other items
				--    i. calculate distFromNext to the next item
				--	  ii. update the distFromNext of the previous items to compress the items behind the new item if have space

				return false
			end
		end

		return false
	end

	for _id, belt: Types.BeltPath, beltItems: Types.BeltItemComponent in
		world:query(Components.BeltPath, Components.BeltItems)
	do
		if #beltItems.items == 0 then
			continue
		end

		debug.profilebegin("ConveyorBeltSystem")

		for i = 1, #beltItems.items do
			if i == 1 and belt.beltNodeOutput ~= nil and beltItems.items[i].distFromNext > 4 then
				beltItems.items[i].distFromNext -= belt.speed
				belt.distToInsertAtStart += belt.speed
				break
			end

			if beltItems.items[i].distFromNext > BeltSettings.ItemOcupancy then
				beltItems.items[i].distFromNext -= belt.speed
				belt.distToInsertAtStart += belt.speed
				break
			end

			if belt.beltNodeOutput == nil then
				continue
			end

			if tryInsertItemIntoNodeBelt(belt.beltNodeOutput, beltItems.items[i].item) then
				beltItems.items[i].mesh:Destroy()
				table.remove(beltItems.items, i)
				beltItems.items[1].distFromNext += 4
				break
			end
		end

		debug.profileend()
	end
end

return {
	system = ConveyorBeltSystem,
	event = "FixedUpdate",
	after = { MinerSystem },
}
