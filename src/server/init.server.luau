local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService("RunService")
local Matter = require(ReplicatedStorage.Packages.matter)
local Plasma = require(ReplicatedStorage.Packages.plasma)
local debugger = Matter.Debugger.new(Plasma)
local widgets = debugger:getWidgets()

local world = Matter.World.new()
local loop = Matter.Loop.new(world, widgets)
loop:setWorlds({ world })

local systems = {}
for _, child in ipairs(script.systems:GetChildren()) do
    if child:IsA("ModuleScript") then
        table.insert(systems, require(child))
    end
end
loop:scheduleSystems(systems)
debugger:autoInitialize(loop)

loop:begin({
    default = RunService.Heartbeat
})