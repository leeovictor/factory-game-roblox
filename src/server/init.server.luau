local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Matter = require(ReplicatedStorage.Matter)
local Plasma = require(ReplicatedStorage.Packages.plasma)
local debugger = Matter.Debugger.new(Plasma)
local widgets = debugger:getWidgets()

local world = Matter.World.new()
local loop = Matter.Loop.new(world, widgets)
loop:setWorlds({ world })
loop:scheduleSystems({})
debugger:autoInitialize(loop)

loop:begin({
	default = RunService.Heartbeat,
})
