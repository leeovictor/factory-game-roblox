local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.matter)

return {
    Miner = Matter.component('Miner'),
    OreNode = Matter.component('OreNode', {
        minersConnected = {},
    }),
    Storage = Matter.component('Storage'),
    ProductionFacility = Matter.component('ProductionFacility'),
    
    Model = Matter.component('Model'),
    Transform = Matter.component('Transform'),
    StaticTransform = Matter.component('StaticTransform'),
    StaticTransformUpdated = Matter.component('StaticTransformUpdated'),

    -- Miner States
    MinerState_NodesDepleted = Matter.component('MinerState_NodesDepleted'),

    -- Ore Node States
    OreNodeDepleted = Matter.component('OreNodeDepleted'),
    
    BeltPath = Matter.component('BeltPath'),
    BeltItems = Matter.component('BeltItems'),
}

