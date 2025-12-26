local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)

local _oreBillboardFrameCounter = 0
local function UpdateOreCountBillboardSystem(world)
    -- Update only each 10 game ticks
    _oreBillboardFrameCounter = (_oreBillboardFrameCounter or 0) + 1
    if _oreBillboardFrameCounter % 10 ~= 0 then
        return
    end
    
    for _id, miner, storage, model in world:query(Components.Miner, Components.Storage, Components.Model) do
        local att = model.instance:FindFirstChild("Attachment")
        if not att then
            continue
        end
        local billboardGui = att:FindFirstChild("BillboardGui")
        if billboardGui then
            local textLabel = billboardGui:FindFirstChild("TextLabel")
            if textLabel then
                local progressText = ""

                if miner.state == 'Mining' then
                    local miningTime = (1 / ((miner.speedPerNode * miner.oreNodesCount) / 60))
                    local ratio = math.clamp(miner.miningProgress / miningTime, 0, 1)
                    progressText = string.format("Mining: %.0f%%", ratio * 100)
                else
                    progressText = miner.state
                end
                
                textLabel.Text = "Ore: " .. tostring(storage.currentAmount) .. ' Veins: ' .. tostring(miner.oreNodesCount) .. ' (' .. progressText .. ')'
            end
        end
    end
end

return {
    system = UpdateOreCountBillboardSystem,
    event = 'FixedUpdate',
    priority = math.huge
}
