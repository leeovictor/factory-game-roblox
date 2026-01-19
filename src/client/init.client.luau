local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Components = require(ReplicatedStorage.Shared.Components)
local Matter = require(ReplicatedStorage.Matter)
local Plasma = require(ReplicatedStorage.Packages.plasma)
local Events = require(ReplicatedStorage.Shared.Events)
local FixedUpdate = require(ReplicatedStorage.Shared.FixedUpdate)
local Types = require(ReplicatedStorage.Shared.Types)

local orePatchGenerator = require(script.OrePatchGen)
local FacilityDetailsScreen = require(script.ui.FacilityDetailsScreen)
local MinerInfoScreen = require(script.ui.MinerInfoScreen)

function extendWorld(world): Types.World
	world.FixedDeltaTime = 1 / 60

	function world.GetSingleton(self, component: any): any
		local results = self:query(component):snapshot()
		if #results > 1 then
			error("GetSingleton found multiple entities with the requested component.")
		end
		return results[1][2]
	end

	return world
end

local gameState = {
	debug = false,
	beltDebugger = {
		paused = false,
		stepOnce = false,
	},
	screens = {},
}
local world = extendWorld(Matter.World.new())

gameState.screens.MinerInfoScreen = MinerInfoScreen.new(world)
gameState.screens.FacilityDetailsScreen =
	FacilityDetailsScreen.new(Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("FacilityDetailsScreen"))
local debugger = Matter.Debugger.new(Plasma)
local widgets = debugger:getWidgets()
local loop = Matter.Loop.new(world, gameState, widgets)
loop:setWorlds({ world })

local systems = {}
for _, child in ipairs(script.systems:GetChildren()) do
	if child:IsA("ModuleScript") then
		local system = require(child)
		if system.disabled then
			continue
		end
		table.insert(systems, system)
	end
end

loop:scheduleSystems(systems)
debugger:autoInitialize(loop)

world:spawn(Components.Settings({
	gridSize = 2,
}))
world:spawn(Components.PlacementPointer())
world:spawn(Components.BeltPlacer())
world:spawn(Components.FacilityPlacer())
world:spawn(Components.GridLines({
	gridSize = 2,
	gridExtents = 200,
	center = Vector3.zero,
	enabled = false,
}))

loop:begin({
	default = RunService.Heartbeat,
	FixedUpdate = FixedUpdate.new(world.FixedDeltaTime),
	PreRender = RunService.PreRender,
})

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F4 then
		debugger:toggle()
	end
end)

local player = Players.LocalPlayer

local function GetToolAttributes(tool: Tool)
	local attributes = {
		type = {
			required = true,
		},
		canDisableSnapping = {
			required = false,
		},
		facilityModel = {
			required = false,
		},
		unequipAfterBuild = {
			required = false,
		},
	}
	local values = {}
	for attrName, config in pairs(attributes) do
		local att = tool:GetAttribute(attrName)
		if att == nil and config.required then
			error("Tool is missing required attribute: " .. attrName)
		end
		values[attrName] = tool:GetAttribute(attrName)
	end
	return values
end

local function setupToolEvents(tool: Tool)
	local function onToolEquipped()
		Events.ToolEquiped:Fire(GetToolAttributes(tool))
	end

	local function onToolUnequipped()
		Events.ToolUnequiped:Fire(GetToolAttributes(tool))
	end

	tool.Equipped:Connect(onToolEquipped)
	tool.Unequipped:Connect(onToolUnequipped)
end

function onCharacterAdded()
	for _, tool in pairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") then
			setupToolEvents(tool)
		end
	end
end

if not player.Character then
	player.CharacterAdded:Connect(onCharacterAdded)
else
	onCharacterAdded()
end

orePatchGenerator.generateAll(world)
