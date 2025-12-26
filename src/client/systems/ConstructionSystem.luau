local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Packages.matter)
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Signals = require(ReplicatedStorage.Shared.Signals)
local TableUtils = require(ReplicatedStorage.Shared.TableUtils)
local Types = require(ReplicatedStorage.Shared.Types)

local inventory = {
    quantity = 0,
}

type BeltPath = {
    nodes: { Vector3 };
    startPos: Vector3;
    endPos: Vector3;
    distToInsertAtStart: number;
    nodesSpawned: boolean;
    nextBelt: number;
    prevBelt: number;
}

local ItemMeshes = ReplicatedStorage:WaitForChild('Models'):WaitForChild('ItemMeshes')

local function ConstructionSystem(world)
    for _i, payload in matter.useEvent(Signals, 'CreateBelt') do
        local length = #payload.nodes * 2 * BeltSettings.BeltSubdiv

        print(payload.nodes)
        local nodes: { Types.Beltnode } = {}
        for index, nodePos in ipairs(payload.nodes) do
            local dirToNext: Vector3
            if index == #payload.nodes then
                dirToNext = nodes[#nodes].outDir
            else
                dirToNext = (payload.nodes[index + 1] - nodePos).Unit
            end
            
            table.insert(nodes, {
                pos = nodePos,
                outDir = dirToNext,
            })
        end

        local items = {
            {
                distFromNext = length,
                item = 'iron_ore',
            },
            {
                distFromNext = 10,
                item = 'iron_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'iron_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'iron_ore'
            },
            {
                distFromNext = 10,
                item = 'iron_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'iron_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'copper_ore'
            },
            {
                distFromNext = 10,
                item = 'iron_ore'
            }
        }
        for _i, item in ipairs(items) do
            local mesh = ItemMeshes[item.item]:Clone()
            mesh.Parent = workspace
            item.distFromNext = _i == 1 and length or BeltSettings.ItemOcupancy * 2
            item.mesh = mesh
        end 
        
        world:spawn(
            Components.BeltPath({
                nodes = nodes,
                startPos = payload.nodes[1],
                endPos = payload.nodes[#payload.nodes],
                distToInsertAtStart = 0,
                nodesSpawned = false,
            }),
            Components.BeltItems({
                items = items,
            })
        )
    end
    
    for _i, payload in matter.useEvent(Signals, 'DeconstructFacility') do
        print('ConstructionSystem - DeconstructFacility event received', payload)

        -- 1. Miner
        --      a. query the miner
        --      b. take items from storage and pass to player inventory (if possible, if not drop on ground)
        --      c. update entities that have relation with the miner
        --          ore nodes: remove miner id from minersConnected
        --          belt path: remove miner input/output connections
        --      d. despawn miner entity
        local miner = world:get(payload.entityId, Components.Miner)
        local storage = world:get(payload.entityId, Components.Storage)

        inventory.quantity = inventory.quantity + storage.currentAmount
        world:insert(payload.entityId, storage:patch({
            currentAmount = 0,
        }))
    
        print('ConstructionSystem - DeconstructFacility - total ore in inventory:', inventory.quantity)

        for _, oreEntityId in ipairs(miner.oreNodes) do
            local oreNode = world:get(oreEntityId, Components.OreNode)
            world:insert(oreEntityId, oreNode:patch({
                minersConnected = TableUtils.Remove(oreNode.minersConnected, payload.entityId),
            }))
        end
        world:despawn(payload.entityId)
    end
    for _i, payload in matter.useEvent(Signals, 'BuildFacility') do
        print('ConstructionSystem - BuildFacility event received', payload)
        
        local minerId = world:spawn(
            Components.Miner({
                miningProgress = 0,
                oreNodes = payload.oreEntities,
                oreNodesCount = #payload.oreEntities,
                speedPerNode = 30,
                startMiningTime = os.clock(),
                state = 'Mining',
            }),
            Components.Transform({
                cframe = payload.cframe,
                isStatic = true,
            }),
            Components.Storage({
                capacity = 10000000,
                currentAmount = 0,
            })
        )
        for _, oreEntityId in ipairs(payload.oreEntities) do
            local oreNode = world:get(oreEntityId, Components.OreNode)
            world:insert(oreEntityId, oreNode:patch({
                minersConnected = TableUtils.Insert(oreNode.minersConnected, minerId),
            }))
        end
    end
end

return {
    system = ConstructionSystem,
    event = 'FixedUpdate',
    priority = 1,
}