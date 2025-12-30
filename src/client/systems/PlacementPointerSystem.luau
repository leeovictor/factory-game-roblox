local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(ReplicatedStorage.Shared.Components)
local Helpers = require(ReplicatedStorage.Shared.Helpers)

local pointerPart = Instance.new("Part")
pointerPart.Size = Vector3.new(1, 1, 1)
pointerPart.Shape = Enum.PartType.Ball
pointerPart.Material = Enum.Material.Plastic
pointerPart.Anchored = true
pointerPart.CanCollide = false
pointerPart.CanQuery = false
pointerPart.Name = "PlacementPointer"
local highlight = Instance.new("Highlight")
highlight.Parent = pointerPart
highlight.FillColor = Color3.fromRGB(255, 255, 255)
highlight.FillTransparency = 0

local mouse = Players.LocalPlayer:GetMouse()

local function PlacementPointerSystem(world: Types.World, _gameState)
	local pointer: Types.PlacementPointer = world:GetSingleton(Components.PlacementPointer)
	local beltPlacer: Types.BeltPlacer = world:GetSingleton(Components.BeltPlacer)
	local facilityPlacer: Types.FacilityPlacer = world:GetSingleton(Components.FacilityPlacer)
	local settings: Types.Settings = world:GetSingleton(Components.Settings)

	pointer.enabled = beltPlacer.enabled or facilityPlacer.enabled

	if pointer.enabled then
		local targetPosition = if pointer.snapToGrid
			then Helpers.snapToGrid(mouse.Hit.Position, settings.gridSize)
			else mouse.Hit.Position
		pointerPart.Position = if pointer.smooth then pointerPart.Position:Lerp(targetPosition, 0.2) else targetPosition
		pointerPart.Color = pointer.color
		pointerPart.Parent = workspace
	else
		pointerPart.Parent = nil
	end
end

return {
	system = PlacementPointerSystem,
}
