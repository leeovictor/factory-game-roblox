local BeltSettings = require(script.Parent.BeltSettings)
local Components = require(script.Parent.Components)
local TableUtils = require(script.Parent.TableUtils)
local Types = require(script.Parent.Types)
local BeltHelpers = {}

local function updateNode(world: Types.World, nodeId: Types.EntityId, updates: { [string]: any })
	local beltNodeComp: Types.BeltNodeComponent = world:get(nodeId, Components.BeltNode)
	for key, value in pairs(updates) do
		beltNodeComp[key] = value
	end
end

function BeltHelpers.getNodeRange(beltSeg: Types.BeltSegment, nodeIndex: number): (number, number)
	local length = #beltSeg.nodes * BeltSettings.BeltSubdiv
	local nodeStart = length - nodeIndex * BeltSettings.BeltSubdiv
	local nodeEnd = nodeStart + BeltSettings.BeltSubdiv - 1
	return nodeStart, nodeEnd
end

function BeltHelpers.tryInsertItemAtStartOfBelt(
	world: Types.World,
	beltId: Types.EntityId,
	itemKey: Types.ItemKey
): boolean
	local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)
	if beltSeg.distToInsertAtStart < BeltSettings.ItemOcupancy then
		return false
	end

	local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)

	local meshesChanges: Types.MeshesChanges = world:get(beltId, Components.MeshesChanges)
	if meshesChanges == nil then
		meshesChanges = Components.MeshesChanges({ added = {} })
		world:insert(beltId, meshesChanges)
		world:commitCommands()
	end

	local item = {
		distFromNext = beltSeg.distToInsertAtStart,
		item = itemKey,
	} :: Types.BeltItemV2
	table.insert(meshesChanges.added, item)
	table.insert(beltItems.items, item)
	beltSeg.distToInsertAtStart = 0

	return true
end

function BeltHelpers.mergeBelts(world: Types.World, beltId: Types.EntityId, nextBeltId: Types.EntityId)
	local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)
	local nextBeltSeg: Types.BeltSegment = world:get(nextBeltId, Components.BeltSegment)

	assert(beltSeg.nextSeg == nil, "Cannot merge: current belt has a next segment")
	assert(nextBeltSeg.prevSeg == nil, "Cannot merge: next belt has a previous segment")

	for i = 1, #nextBeltSeg.nodes do
		updateNode(world, nextBeltSeg.nodes[i], { beltPath = beltId, nodeIndex = #beltSeg.nodes + i })
		table.insert(beltSeg.nodes, nextBeltSeg.nodes[i])
	end

	beltSeg.nextSeg = nextBeltSeg.nextSeg

	local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)
	local nextBeltItems: Types.BeltItemsV2 = world:get(nextBeltId, Components.BeltItemsV2)

	if beltItems.items[1] ~= nil then
		beltItems.items[1].distFromNext += nextBeltSeg.distToInsertAtStart
	end

	for i = #nextBeltItems.items, 1, -1 do
		table.insert(beltItems.items, 1, nextBeltItems.items[i])
	end

	world:despawn(nextBeltId)
end

export type FindItemInNodeResult = { item: Types.BeltItemV2, index: number }

function BeltHelpers.findItemsInNode(
	beltSeg: Types.BeltSegment,
	beltItems: Types.BeltItemsV2,
	nodeIndex: number
): FindItemInNodeResult?
	if #beltItems.items == 0 then
		return nil
	end

	local nodeStart, nodeEnd = BeltHelpers.getNodeRange(beltSeg, nodeIndex)

	local distAcc = 0
	for i, item in ipairs(beltItems.items) do
		distAcc += item.distFromNext

		if distAcc - 1 < nodeStart then
			continue
		end

		if distAcc - 1 <= nodeEnd and distAcc - 1 >= nodeStart then
			return { item = item, index = i }
		end

		return nil
	end

	return nil
end

function BeltHelpers.tryTakeItemFromBeltNode(world: Types.World, beltNodeEntityId: Types.EntityId): Types.BeltItemV2?
	local beltNode: Types.BeltNodeComponent = world:get(beltNodeEntityId, Components.BeltNode)
	local beltSeg: Types.BeltSegment = world:get(beltNode.beltPath, Components.BeltSegment)
	local beltItems: Types.BeltItemsV2 = world:get(beltNode.beltPath, Components.BeltItemsV2)

	local result = BeltHelpers.findItemsInNode(beltSeg, beltItems, beltNode.nodeIndex)

	if result == nil then
		return nil
	end

	local meshesChanges: Types.MeshesChanges = world:get(beltNode.beltPath, Components.MeshesChanges)
	if meshesChanges == nil then
		meshesChanges = Components.MeshesChanges({ removed = {} })
		world:insert(beltNode.beltPath, meshesChanges)
		world:commitCommands()
	end
	meshesChanges.removed = meshesChanges.removed or {}
	table.insert(meshesChanges.removed, result.item)

	return BeltHelpers.takeItem(beltSeg, beltItems, result.index)
end

function BeltHelpers.takeItem(beltSeg: Types.BeltSegment, items: Types.BeltItemsV2, index: number): Types.BeltItemV2
	if items.items[index] == nil then
		error("No item at index " .. tostring(index))
	end

	local prevItem = items.items[index + 1]
	if prevItem ~= nil then
		prevItem.distFromNext += items.items[index].distFromNext
	else
		beltSeg.distToInsertAtStart += items.items[index].distFromNext
	end

	return table.remove(items.items, index) :: Types.BeltItemV2
end

return BeltHelpers
