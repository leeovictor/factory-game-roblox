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
		for i = 1, #beltItems.items do
			if beltItems.items[i].distFromNext > BeltSettings.ItemOcupancy then
				beltItems.items[i].distFromNext -= 2
				belt.distToInsertAtStart += 2
				break
			end

			if beltItems.items[i + 1] == nil then
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
