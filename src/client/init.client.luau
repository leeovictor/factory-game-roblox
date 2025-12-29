local ExperienceAuthService = game:GetService("ExperienceAuthService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Components = require(ReplicatedStorage.Shared.Components)
local Matter = require(ReplicatedStorage.Packages.matter)
local Plasma = require(ReplicatedStorage.Packages.plasma)
local Events = require(ReplicatedStorage.Shared.Events)
local FixedUpdate = require(ReplicatedStorage.Shared.FixedUpdate)
local Types = require(ReplicatedStorage.Shared.Types)
local orePatchGenerator = require(script.OrePatchGen)
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
	screens = {},
}
local world = extendWorld(Matter.World.new())

gameState.screens.MinerInfoScreen = MinerInfoScreen.new(world)
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
world:spawn(Components.BeltPlacer())
world:spawn(Components.PlacementPointer())
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
})

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F4 then
		debugger:toggle()
	end
end)

function renderGridLines(gridSize: number, gridExtends: number, center: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "GridLines"
	folder.Parent = workspace
	center = center or Vector3.zero

	for x = -gridExtends, gridExtends, gridSize do
		local line = Instance.new("Part")
		if x % 10 == 0 then
			line.Size = Vector3.new(0.2, 0.2, gridExtends * 2)
			line.Transparency = 0.7
		else
			line.Transparency = 0.9
			line.Size = Vector3.new(0.1, 0.1, gridExtends * 2)
		end

		line.Anchored = true
		line.CanCollide = false
		line.Color = Color3.fromRGB(22, 160, 63)
		line.Material = Enum.Material.Neon
		line.Position = Vector3.new(center.X + x, center.Y, center.Z)
		line.Parent = folder
	end

	for z = -gridExtends, gridExtends, gridSize do
		local line = Instance.new("Part")
		if z % 10 == 0 then
			line.Size = Vector3.new(gridExtends * 2, 0.2, 0.2)
			line.Transparency = 0.7
		else
			line.Transparency = 0.9
			line.Size = Vector3.new(gridExtends * 2, 0.1, 0.1)
		end
		line.Anchored = true
		line.CanCollide = false
		line.Material = Enum.Material.Neon
		line.Color = Color3.fromRGB(22, 160, 63)
		line.Position = Vector3.new(center.X, center.Y, center.Z + z)
		line.Parent = folder
	end
end

function hideGrid()
	local gridFolder = workspace:FindFirstChild("GridLines")
	if gridFolder then
		gridFolder:Destroy()
	end
	local pointsFolder = workspace:FindFirstChild("GridPoints")
	if pointsFolder then
		pointsFolder:Destroy()
	end
end

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
