local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Types = require(ReplicatedStorage.Shared.Types)
local MinerSystem = require(script.Parent.MinerSystem)

local function ConveyorBeltSystem(world: Types.World)
	for _, beltPath: Types.BeltPath, beltItems: Types.BeltItemComponent in
		world:query(Components.BeltPath, Components.BeltItems)
	do
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
