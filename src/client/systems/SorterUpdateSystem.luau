local InsertService = game:GetService("InsertService")
local InstanceExtensionsService = game:GetService("InstanceExtensionsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltHelpers = require(ReplicatedStorage.Shared.BeltHelpers)
local ProductionFacilitySystem = require(script.Parent.ProductionFacilitySystem)
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Enums = require(ReplicatedStorage.Shared.Enums)
local ItemSpecs = require(ReplicatedStorage.Shared.ItemSpecs)
local Types = require(ReplicatedStorage.Shared.Types)

local function SorterUpdateSystem(world: Types.World)
	local function addItem(
		beltId: Types.EntityId,
		beltSeg: Types.BeltSegment,
		beltItems: Types.BeltItemsV2,
		itemKey: string,
		distFromNext: number,
		index: number
	)
		-- print("Adding item", itemKey, "at dist", distFromNext, "at index", index)

		local meshesChanges: Types.MeshesChanges = world:get(beltId, Components.MeshesChanges)
		if meshesChanges == nil then
			meshesChanges = Components.MeshesChanges({ added = {} })
			world:insert(beltId, meshesChanges)
			world:commitCommands()
		end

		local item = {
			distFromNext = distFromNext,
			item = itemKey,
		} :: Types.BeltItemV2
		table.insert(meshesChanges.added, item)

		if beltItems.items[index] ~= nil then
			local diff = beltItems.items[index].distFromNext - distFromNext
			if diff < BeltSettings.ItemOcupancy then
				-- comprimi os items anteriores para abrir espaço
				-- TODO: se o segmento não tiver espaço suficiente? no momento está quebrado nesse caso
				beltItems.items[index].distFromNext = BeltSettings.ItemOcupancy
				local neededSpace = BeltSettings.ItemOcupancy - diff
				local i = index + 1
				while neededSpace > 0 and beltItems.items[i] ~= nil do
					local availableSpace = beltItems.items[i].distFromNext - BeltSettings.ItemOcupancy
					if availableSpace > 0 then
						local toShift = math.min(availableSpace, neededSpace)
						beltItems.items[i].distFromNext -= toShift
						neededSpace -= toShift
					end
					i += 1
				end

				if beltItems.items[i] == nil and neededSpace > 0 then
					beltSeg.distToInsertAtStart -= neededSpace
				end
			else
				beltItems.items[index].distFromNext -= distFromNext
			end
			-- local a = 40
			-- local i = index
			-- while a > 0 and beltItems.items[i] ~= nil do
			-- 	print("Shifting item at index", i, "distFromNext", beltItems.items[i].distFromNext)
			-- 	local space = math.min(beltItems.items[i].distFromNext - 40, a)
			-- 	beltItems.items[i].distFromNext -= space
			-- 	a -= space
			-- 	i += 1
			-- end

			-- if beltItems.items[i] == nil and a > 0 then
			-- 	beltSeg.distToInsertAtStart -= a
			-- 	if beltSeg.distToInsertAtStart < 0 then
			-- 		beltSeg.distToInsertAtStart = 0
			-- 	end
			-- end

			-- beltItems.items[index].distFromNext -= distFromNext
			-- if beltItems.items[index].distFromNext < BeltSettings.ItemOcupancy then
			-- 	beltItems.items[index].distFromNext = BeltSettings.ItemOcupancy
			-- end
		else
			beltSeg.distToInsertAtStart -= distFromNext
			if beltSeg.distToInsertAtStart < 0 then
				beltSeg.distToInsertAtStart = 0
			end
		end

		table.insert(beltItems.items, index, item)
	end

	local function tryTakeItemFromFacility(facilityEntityId: Types.EntityId): Types.ItemKey?
		local facility: Types.ProductionFacility = world:get(facilityEntityId, Components.ProductionFacility)
		if facility.recipe == nil then
			return nil
		end

		-- sempre tenta pegar o primeiro item disponível. depois podemos adicionar logica para sorter com filtro de item (sempre tenta pegar um item específico)
		for itemKey, slot: Types.Slot in pairs(facility.outputSlots) do
			if slot.quantity > 0 then
				slot.quantity -= 1
				return itemKey
			end
		end

		return nil
	end

	local function tryTakeItemFromInput(inputCon: Types.SorterConnection?): Types.ItemKey?
		if inputCon == nil then
			return nil
		end

		if inputCon.entityType == Enums.SorterConnectionEntityType.Belt then
			local item = BeltHelpers.tryTakeItemFromBeltNode(world, inputCon.entityId)
			return item and item.item or nil
		elseif inputCon.entityType == Enums.SorterConnectionEntityType.Facility then
			return tryTakeItemFromFacility(inputCon.entityId)
		else
			error("Tipo de conexão de entrada desconhecido: " .. tostring(inputCon.entityType))
		end
	end

	local function tryDeliverItemToBeltNode(beltNodeEntityId: Types.EntityId, item: Types.ItemKey): boolean
		local beltNode: Types.BeltNodeComponent = world:get(beltNodeEntityId, Components.BeltNode)
		local beltSeg: Types.BeltSegment = world:get(beltNode.beltPath, Components.BeltSegment)
		local beltItems: Types.BeltItemsV2 = world:get(beltNode.beltPath, Components.BeltItemsV2)

		local startNode = BeltHelpers.getNodeRange(beltSeg, beltNode.nodeIndex)

		if #beltItems.items == 0 then
			addItem(beltNode.beltPath, beltSeg, beltItems, item, startNode + BeltSettings.BeltSubdiv * 0.5, 1)
			return true
		end

		local insertionPoint = startNode + BeltSettings.BeltSubdiv * 0.5

		local index = 1
		local itemDist = 0
		for i = 1, #beltItems.items do
			itemDist += beltItems.items[i].distFromNext

			if itemDist <= insertionPoint - BeltSettings.ItemOcupancy then
				index = i + 1
				continue
			end

			if itemDist >= insertionPoint - BeltSettings.ItemOcupancy and itemDist < insertionPoint + 1 then
				return false
			end

			index = i
			itemDist -= beltItems.items[i].distFromNext
			break
		end

		addItem(beltNode.beltPath, beltSeg, beltItems, item, insertionPoint - itemDist, index)
		return true
	end

	local function tryDeliverItemToFacility(facilityEntityId: Types.EntityId, item: Types.ItemKey): boolean
		local facility: Types.ProductionFacility = world:get(facilityEntityId, Components.ProductionFacility)
		if facility.recipe == nil then
			return false
		end

		for itemKey, slot: Types.Slot in pairs(facility.inputSlots) do
			local itemSpec = ItemSpecs.ByKey[itemKey]
			if itemKey == item and slot.quantity < itemSpec.stackSize then
				slot.quantity += 1
				return true
			end
		end

		return false
	end

	local function tryDeliverItemToOutput(outputCon: Types.SorterConnection?, item: Types.ItemKey): boolean
		if outputCon == nil then
			return false
		end

		if outputCon.entityType == Enums.SorterConnectionEntityType.Belt then
			return tryDeliverItemToBeltNode(outputCon.entityId, item)
		elseif outputCon.entityType == Enums.SorterConnectionEntityType.Facility then
			return tryDeliverItemToFacility(outputCon.entityId, item)
		else
			error("Tipo de conexão de saída desconhecido: " .. tostring(outputCon.entityType))
		end
	end

	for _id, sorter: Types.Sorter in world:query(Components.Sorter) do
		if sorter.state == Enums.SorterState.WaitingForCargo then
			local item: Types.ItemKey? = tryTakeItemFromInput(sorter.inputCon)
			if not item then
				continue
			end

			sorter.currentItem = item
			sorter.state = Enums.SorterState.Transporting
		elseif sorter.state == Enums.SorterState.Transporting then
			if sorter.progress < 1 then
				sorter.progress += sorter.speed * world.FixedDeltaTime
			end

			if sorter.progress >= 1 then
				if tryDeliverItemToOutput(sorter.outputCon, sorter.currentItem :: Types.ItemKey) then
					sorter.state = Enums.SorterState.Returning
					sorter.progress = 1
					sorter.currentItem = nil
				end
				continue
			end
		elseif sorter.state == Enums.SorterState.Returning then
			sorter.progress -= sorter.speed * world.FixedDeltaTime
			if sorter.progress <= 0 then
				sorter.state = Enums.SorterState.WaitingForCargo
				sorter.progress = 0
			end
		else
			error("Estado de sorter desconhecido: " .. tostring(sorter.state))
		end
	end
end

return {
	system = SorterUpdateSystem,
	event = "FixedUpdate",
	after = { ProductionFacilitySystem },
}
