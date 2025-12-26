local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)

local function RemoveModelsSystem(world)
    for _, record in world:queryChanged(Components.Model) do
        if record.new == nil then
            if record.old and record.old.instance then
                record.old.instance:Destroy()
            end
        end
    end
end

return {
    system = RemoveModelsSystem,
    event = 'FixedUpdate',
}