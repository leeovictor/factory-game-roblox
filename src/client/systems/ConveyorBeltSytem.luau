local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local Types = require(ReplicatedStorage.Shared.Types)
local MinerSystem = require(script.Parent.MinerSystem)

local function ConveyorBeltSystem(world: Types.World)
	local function addItem(item: string, beltItems: Types.BeltItemComponent, pos: number, index: number)
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

	local function transferItemIfBeltNodeHasSpace(nodeId: Types.EntityId, item: Types.BeltItem): boolean
		local beltNode: Types.BeltNodeComponent = world:get(nodeId, Components.BeltNode)
		local beltPath: Types.BeltPath = world:get(beltNode.beltPath, Components.BeltPath)
		local beltItems: Types.BeltItemComponent = world:get(beltNode.beltPath, Components.BeltItems)

		local beltLength = #beltPath.nodes * BeltSettings.BeltSubdiv
		local itemPosInsertion = (beltLength - beltNode.nodeIndex * BeltSettings.BeltSubdiv)
			+ BeltSettings.BeltSubdiv / 2

		if #beltItems.items == 0 then
			addItem(item.item, beltItems, itemPosInsertion, 1)
			return true
		end

		local index
		for i = 1, #beltItems.items do
			local itemDist = beltItems.items[i].pos

			if itemDist < itemPosInsertion - BeltSettings.ItemOcupancy then
				index = i + 1
				continue
			end

			-- TODO: preciso melhorar isso para comprimir a esteira
			-- 1. se tiver pelo 1 unidade de espaço disponível, eu quero adicionar o item
			-- 2. preciso atualizar a posicao dos outros items reduzindo os gaps entre os items com o excendente de espaço
			-- do item adicionado em relação ao espaço disponível
			-- ex. local overflowSpace = BeltSettings.ItemOcupancy - spaceAvailable
			-- usando então o overflowSpace para ajustar as posições dos outros items
			-- é importante garantir que o item só seja adicionado se houver espaço suficiente em todo a esteira, o que significa que é necessário
			-- calcular os gaps dos items anteriores pra determinar se é possível comprimir
			if itemDist >= itemPosInsertion - BeltSettings.ItemOcupancy and itemDist <= itemPosInsertion + 1 then
				return false
			end

			index = i
			break
		end

		addItem(item.item, beltItems, itemPosInsertion, index)
		return true
	end

	for _, beltPath: Types.BeltPath, beltItems: Types.BeltItemComponent in
		world:query(Components.BeltPath, Components.BeltItems)
	do
		if #beltItems.items == 0 then
			continue
		end

		if
			beltPath.beltNodeOutput ~= nil
			and beltItems.items[1].pos == BeltSettings.ItemOcupancy
			and transferItemIfBeltNodeHasSpace(beltPath.beltNodeOutput, beltItems.items[1])
		then
			beltItems.items[1].mesh:Destroy()
			table.remove(beltItems.items, 1)
		end

		for i = 1, #beltItems.items do
			local prevItem = beltItems.items[i - 1]
			local distDiff = beltItems.items[i].pos - if prevItem then prevItem.pos else 0

			if distDiff > BeltSettings.ItemOcupancy then
				beltItems.items[i].pos -= beltPath.speed
			end
		end
	end
end

return {
	system = ConveyorBeltSystem,
	event = "FixedUpdate",
	after = { MinerSystem },
}
