local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)

local function HighlightOnHover(world)
    for _id, record in world:queryChanged(Components.HightlightOnHoverInitialized) do
        if record.new == nil then
            for _, conn in ipairs(record.old.connections) do
                conn:Disconnect()
            end
        end
    end
    
    for id, _hightlistOnHover, model in world:query(Components.HightlightOnHover, Components.Model):without(Components.HightlightOnHoverInitialized) do
        local modelInstance = model.instance
        local hightlight = Instance.new("Highlight")
        hightlight.Enabled = false
        hightlight.FillTransparency = 1
        hightlight.Parent = modelInstance
        
        local clickDetector = Instance.new("ClickDetector")
        clickDetector.Parent = modelInstance
        clickDetector.CursorIcon = 'a'
        clickDetector.MaxActivationDistance = 500
        
        local con1 = clickDetector.MouseHoverEnter:Connect(function()
            hightlight.Enabled = true
        end)
        local con2 = clickDetector.MouseHoverLeave:Connect(function()
            hightlight.Enabled = false
        end)
        
        world:insert(id, Components.HightlightOnHoverInitialized({
            connections = { con1, con2 }
        }))
    end
end

return {
    system = HighlightOnHover,
    event = 'FixedUpdate',
    priority = 101,
}