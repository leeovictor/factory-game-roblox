local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)

local _oreBillboardFrameCounter = 0

local function UpdateOreCountBillboardSystem(world, gameState)
end

return {
    system = UpdateOreCountBillboardSystem,
    event = 'RenderStepped',
    disabled = true
}
