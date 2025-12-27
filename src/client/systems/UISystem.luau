local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local MinerInfoScreen = require(StarterPlayer.StarterPlayerScripts.Client.ui.MinerInfoScreen)
local matter = require(ReplicatedStorage.Packages.matter)
local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Events)

local function UISystem(world: typeof(matter.World), gameState)
    for _, entityId in matter.useEvent(Events, 'CloseMinerInfoEvent') do
        print('Closing Miner Info UI for entity:', entityId)
        if world:contains(entityId) then
            world:remove(entityId, Components.UpdateMinerInfoUI)
        end
        
        gameState.screens.MinerInfoScreen:Hide()
    end
    
    for _, entityId in matter.useEvent(Events, 'MinerModelClicked') do
        print('Opening Miner Info UI for entity:', entityId)
        if entityId ~= gameState.screens.MinerInfoScreen.entityId then
            for id in world:query(Components.UpdateMinerInfoUI) do
               world:remove(id, Components.UpdateMinerInfoUI)
               world:commitCommands()
            end
        end
        
        if world:contains(entityId) then
            world:insert(entityId, Components.UpdateMinerInfoUI())
            gameState.screens.MinerInfoScreen:Show(entityId)
        end
    end 

    for _id, miner, storage in world:query(Components.Miner, Components.Storage, Components.UpdateMinerInfoUI) do
        local currentMiningTime = 1 / ((miner.speedPerNode * miner.oreNodesCount) / 60)
        local info: MinerInfoScreen.MinerInfo = {
            status = miner.state,
            storage = {
                currentAmount = storage.currentAmount,
                capacity = storage.capacity,
            },
            veinsCount = miner.oreNodesCount,
            miningProgress = math.clamp(miner.miningProgress / currentMiningTime, 0, 1),
        }
        gameState.screens.MinerInfoScreen:UpdateMinerInfo(info);
    end
end

return {
    system = UISystem,
}