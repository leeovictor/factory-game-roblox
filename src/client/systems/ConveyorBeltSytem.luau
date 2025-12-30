local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Gizmos = require(ReplicatedStorage.Shared.Gizmos)
local Types = require(ReplicatedStorage.Shared.Types)
local MinerSystem = require(script.Parent.MinerSystem)

type BeltItem = {
	distFromNext: number,
	item: string,
}

local function ConveyorBeltSystem(world: Types.World)
	for _id, belt, beltItems in world:query(Components.BeltPath, Components.BeltItems) do
		if #beltItems.items == 0 then
			continue
		end

		debug.profilebegin("ConveyorBeltSystem")
		local lastGapIndex = 1
		for i = lastGapIndex, #beltItems.items do
			if beltItems.items[i].distFromNext > BeltSettings.ItemOcupancy then
				beltItems.items[i].distFromNext -= 2
				belt.distToInsertAtStart += 2
				break
			end

			if beltItems.items[i + 1] == nil then
				break
			end

			lastGapIndex = i + 1
		end

		belt.lastGapIndex = lastGapIndex
		belt.stopped = beltItems.items[lastGapIndex].distFromNext == BeltSettings.ItemOcupancy
		debug.profileend()
	end
end

return {
	system = ConveyorBeltSystem,
	event = "FixedUpdate",
	after = { MinerSystem },
}
