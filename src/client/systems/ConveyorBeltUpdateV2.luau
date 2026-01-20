local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Types = require(ReplicatedStorage.Shared.Types)

local function transferItemToNextBelt(world: Types.World, nextBeltId: Types.EntityId, item: Types.BeltItemV2): boolean
	if item.distFromNext > 0 then
		return false
	end

	local nextBeltItems: Types.BeltItemsV2 = world:get(nextBeltId, Components.BeltItemsV2)
	local nextBeltSeg: Types.BeltSegment = world:get(nextBeltId, Components.BeltSegment)

	item.distFromNext = nextBeltSeg.distToInsertAtStart
	table.insert(nextBeltItems.items, item)
	nextBeltSeg.distToInsertAtStart = 0

	return true
end

local function ConveyorBeltUpdateV2(world: Types.World, gameState)
	if RunService:IsStudio() then
		if gameState.beltDebugger.paused and not gameState.beltDebugger.stepOnce then
			return
		elseif gameState.beltDebugger.stepOnce then
			gameState.beltDebugger.stepOnce = false
		end
	end

	local lastBeltSegments: { Types.EntityId } = {}
	for beltId, beltSeg: Types.BeltSegment in world:query(Components.BeltSegment) do
		if beltSeg.nextSeg == nil then
			table.insert(lastBeltSegments, beltId)
		end
	end

	for _, beltId in ipairs(lastBeltSegments) do
		local currentSegId = beltId

		while currentSegId ~= nil do
			local beltSeg: Types.BeltSegment = world:get(currentSegId, Components.BeltSegment)
			local beltItems: Types.BeltItemsV2 = world:get(currentSegId, Components.BeltItemsV2)

			if #beltItems.items == 0 then
				currentSegId = beltSeg.prevSeg
				continue
			end

			for i = 1, #beltItems.items do
				if beltItems.items[i].distFromNext > BeltSettings.ItemOcupancy then
					beltItems.items[i].distFromNext = math.clamp(
						beltItems.items[i].distFromNext - beltSeg.speed,
						BeltSettings.ItemOcupancy,
						math.huge
					)
					beltSeg.distToInsertAtStart = math.clamp(
						beltSeg.distToInsertAtStart + beltSeg.speed,
						0,
						#beltSeg.nodes * BeltSettings.BeltSubdiv
					)
					break
				end

				if beltSeg.nextSeg == nil then
					continue
				end

				local prevSeg: Types.BeltSegment = world:get(beltSeg.nextSeg, Components.BeltSegment)

				if i == 1 and beltItems.items[i].distFromNext > 0 then
					-- verifica se tem espaço suficiente para mover o item, considerando também o espaço na proxima esteira
					if beltItems.items[i].distFromNext + prevSeg.distToInsertAtStart > BeltSettings.ItemOcupancy then
						beltItems.items[i].distFromNext =
							math.clamp(beltItems.items[i].distFromNext - beltSeg.speed, 0, math.huge)
						beltSeg.distToInsertAtStart = math.clamp(
							beltSeg.distToInsertAtStart + beltSeg.speed,
							0,
							#beltSeg.nodes * BeltSettings.BeltSubdiv
						)

						if beltItems.items[i].distFromNext == 0 then
							transferItemToNextBelt(world, beltSeg.nextSeg, beltItems.items[i])
							local meshesChanges: Types.MeshesChanges = world:get(currentSegId, Components.MeshesChanges)
							if meshesChanges == nil then
								meshesChanges = Components.MeshesChanges({ added = {}, removed = {}, transferred = {} })
								world:insert(currentSegId, meshesChanges)
								world:commitCommands()
							end

							table.insert(meshesChanges.transferred, { to = beltSeg.nextSeg, item = beltItems.items[i] })
							table.remove(beltItems.items, i)
						end

						break
					end

					continue
				end
			end

			currentSegId = beltSeg.prevSeg
		end
	end
end

return {
	system = ConveyorBeltUpdateV2,
	event = "FixedUpdate",
}
