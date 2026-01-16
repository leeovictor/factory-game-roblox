local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProductionFacilitySystem = require(script.Parent.ProductionFacilitySystem)
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Enums = require(ReplicatedStorage.Shared.Enums)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local ItemSpecs = require(ReplicatedStorage.Shared.ItemSpecs)
local Types = require(ReplicatedStorage.Shared.Types)

local function SorterUpdateSystem(world: Types.World)
	local function addItem(beltItems: Types.BeltItemComponent, item: string, pos: number, index: number)
		table.insert(
			beltItems.items,
			index,
			{
				pos = pos,
				item = item,
				mesh = Helpers.createItemMesh(item),
			} :: Types.BeltItem
		)
	end

	local function takeItem(items: { Types.BeltItem }, index: number): Types.ItemKey
		local item = items[index]
		table.remove(items, index)
		item.mesh:Destroy()
		return item.item
	end

	local function tryTakeItemFromBeltNode(beltNodeEntityId: Types.EntityId): Types.ItemKey?
		-- REVIEW: podemos tentar salvar na conexao do sorter o belt id junto com o node index para evitar esse get
		local beltNode: Types.BeltNodeComponent = world:get(beltNodeEntityId, Components.BeltNode)
		local beltItems: Types.BeltItemComponent = world:get(beltNode.beltPath, Components.BeltItems)

		if #beltItems.items == 0 then
			return nil
		end

		local beltPath: Types.BeltPath = world:get(beltNode.beltPath, Components.BeltPath)
		local removePoint = #beltPath.nodes * BeltSettings.BeltSubdiv
			- beltNode.nodeIndex * BeltSettings.BeltSubdiv
			+ BeltSettings.BeltSubdiv / 2
		local startPoint = removePoint + (BeltSettings.BeltSubdiv / 2)
		local endPoint = removePoint - (BeltSettings.BeltSubdiv / 2)

		if beltItems.items[1].pos > startPoint then
			return nil
		end

		for index, item: Types.BeltItem in ipairs(beltItems.items) do
			if item.pos < endPoint then
				continue
			end

			if item.pos > startPoint then
				break
			end

			return takeItem(beltItems.items, index)
		end

		return nil
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
			return tryTakeItemFromBeltNode(inputCon.entityId)
		elseif inputCon.entityType == Enums.SorterConnectionEntityType.Facility then
			return tryTakeItemFromFacility(inputCon.entityId)
		else
			error("Tipo de conexão de entrada desconhecido: " .. tostring(inputCon.entityType))
		end
	end

	local function tryDeliverItemToBeltNode(beltNodeEntityId: Types.EntityId, item: Types.ItemKey): boolean
		local beltNode: Types.BeltNodeComponent = world:get(beltNodeEntityId, Components.BeltNode)
		local beltPath: Types.BeltPath = world:get(beltNode.beltPath, Components.BeltPath)
		local beltItems: Types.BeltItemComponent = world:get(beltNode.beltPath, Components.BeltItems)

		local itemPosInsertion = (
			#beltPath.nodes * BeltSettings.BeltSubdiv - beltNode.nodeIndex * BeltSettings.BeltSubdiv
		) + BeltSettings.BeltSubdiv / 2

		if #beltItems.items == 0 then
			addItem(beltItems, item, itemPosInsertion, 1)
			return true
		end

		local index
		for i = 1, #beltItems.items do
			local itemDist = beltItems.items[i].pos

			if itemDist < itemPosInsertion - BeltSettings.ItemOcupancy then
				index = i + 1
				continue
			end

			if itemDist >= itemPosInsertion - BeltSettings.ItemOcupancy and itemDist <= itemPosInsertion + 1 then
				return false
			end

			index = i
			break
		end

		addItem(beltItems, item, itemPosInsertion, index)
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
