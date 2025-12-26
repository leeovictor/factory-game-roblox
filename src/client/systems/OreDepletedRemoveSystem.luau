local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)
local TableUtils = require(ReplicatedStorage.Shared.TableUtils)

local function OreDepletedRemoveSystem(world)
    for id, oreNode in world:query(Components.OreNode, Components.OreNodeDepleted) do
        for _, minerId in ipairs(oreNode.minersConnected) do
            local miner = world:get(minerId, Components.Miner)
            miner.oreNodesCount -= 1
            miner.oreNodes = TableUtils.Remove(miner.oreNodes, id)
        end
        
        world:despawn(id)
    end
end

return {
    system = OreDepletedRemoveSystem,
    event = 'FixedUpdate',
}