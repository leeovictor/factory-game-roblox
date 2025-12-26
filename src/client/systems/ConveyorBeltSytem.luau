local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local MinerSystem = require(script.Parent.MinerSystem)
local Types = require(ReplicatedStorage.Shared.Types)

type BeltItem = {
    distFromNext: number;
    item: string;
}

local function ConveyorBeltSystem(world)
    for _id, belt, beltItems in world:query(Components.BeltPath, Components.BeltItems) do 
        if not belt.nodesSpawned then
            local nodeModel = ReplicatedStorage.Models.Facilities.BeltNode
            for _, node : Types.Beltnode in belt.nodes do
                local nodeInstance = nodeModel:Clone()
                nodeInstance.Parent = workspace
                
                world:spawn(Components.Model({
                    instance = nodeInstance
                }), Components.Transform({
                    cframe = CFrame.new(node.pos),
                    isStatic = true
                }))
                belt.nodesSpawned = true
            end
        end
        
        if #beltItems.items == 0 then
           continue
        end
        
        local lastGapIndex = 1
        for i=lastGapIndex, #beltItems.items do
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
    end
end

return {
    system = ConveyorBeltSystem,
    event = 'FixedUpdate',
    after = { MinerSystem }
}

