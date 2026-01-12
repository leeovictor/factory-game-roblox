--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Matter)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local Components = require(ReplicatedStorage.Shared.Components)
local Enums = require(ReplicatedStorage.Shared.Enums)
local Events = require(ReplicatedStorage.Shared.Events)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local TableUtils = require(ReplicatedStorage.Shared.TableUtils)
local Types = require(ReplicatedStorage.Shared.Types)

local FacilitiesModels = ReplicatedStorage:WaitForChild("Models"):WaitForChild("Facilities")
local mouse = Players.LocalPlayer:GetMouse()

local buildingCollisionOverlapParams = OverlapParams.new()
buildingCollisionOverlapParams.CollisionGroup = CollisionGroups.BuildingCollisionCheck
local minerOreCheckOverlapParams = OverlapParams.new()
minerOreCheckOverlapParams.CollisionGroup = CollisionGroups.MinerOreNodeCheck

local function validateFacilityPlacement(model: Model, facilityName: string)
	if facilityName == "Assembler" or facilityName == "Smelter" then
		local primaryPart = model.PrimaryPart :: BasePart
		local canPlace = #workspace:GetPartBoundsInBox(
			primaryPart.CFrame,
			primaryPart.Size,
			buildingCollisionOverlapParams
		) == 0
		return {
			canPlace = canPlace,
			reason = canPlace and "" or "Colliding with other objects.",
		}
	elseif facilityName == "Miner" then
		-- check if miner primary part is colliding with other objects
		local primaryPart = model.PrimaryPart :: BasePart
		local primaryPartColliding = #workspace:GetPartBoundsInBox(
			primaryPart.CFrame,
			primaryPart.Size,
			buildingCollisionOverlapParams
		) > 0

		-- check if miner area has ores
		local minerArea = model:FindFirstChild("MinerActiveArea")
		local oresInstances = workspace:GetPartsInPart(minerArea, minerOreCheckOverlapParams)
		local minerAreaWithOres = #oresInstances > 0

		local canPlace = not primaryPartColliding and minerAreaWithOres
		local reason = ""
		if primaryPartColliding then
			reason = "Colliding with other objects."
		elseif not minerAreaWithOres then
			reason = "No ores in mining area."
		end

		return {
			canPlace = canPlace,
			reason = reason,
			data = oresInstances,
		}
	end

	return {
		canPlace = true,
		reason = "",
	}
end

local function FacilityPlacementSystem(world: Types.World, _gameState)
	local facilityPlacer: Types.FacilityPlacer = world:GetSingleton(Components.FacilityPlacer)
	local placementPointer: Types.PlacementPointer = world:GetSingleton(Components.PlacementPointer)
	local settings: Types.Settings = world:GetSingleton(Components.Settings)

	local function spawnMiner()
		local oreEntities = {}
		for _, orePart in pairs(facilityPlacer.validationResult.data :: { Instance }) do
			local entityId = orePart:GetAttribute("entityId")
			if entityId then
				table.insert(oreEntities, entityId)
			end
		end

		local payload = {
			cframe = facilityPlacer.currentCFrame :: CFrame,
			oreEntities = oreEntities,
		}
		local minerId = world:spawn(
			Components.Miner({
				miningProgress = 0,
				oreNodes = payload.oreEntities,
				oreNodesCount = #payload.oreEntities,
				speedPerNode = 30,
				startMiningTime = os.clock(),
				state = "Mining",
			}),
			Components.Transform({
				cframe = payload.cframe,
				isStatic = true,
			}),
			Components.Storage({
				capacity = 100,
				currentAmount = 0,
			})
		)
		for _, oreEntityId in ipairs(payload.oreEntities) do
			local oreNode = world:get(oreEntityId, Components.OreNode)
			world:insert(
				oreEntityId,
				oreNode:patch({
					minersConnected = TableUtils.Insert(oreNode.minersConnected, minerId),
				})
			)
		end
	end

	local function spawnProductionFacility(facilityName: Types.ProductionFacilityType)
		if ReplicatedStorage.Models.Facilities[facilityName] == nil then
			error("Facility model not found: " .. facilityName)
		end
		local model = ReplicatedStorage.Models.Facilities[facilityName]:Clone()
		Helpers.setCollisionGroupModelParts(model, CollisionGroups.Buildings)

		world:spawn(
			Components.ProductionFacility({
				recipe = nil,
				inputSlots = {},
				outputSlots = {},
				state = Enums.ProductionFacilityState.Idle,
				progress = 0,
				facilityType = facilityName :: Types.ProductionFacilityType,
			} :: Types.ProductionFacility),
			Components.Transform({
				cframe = facilityPlacer.currentCFrame,
				isStatic = true,
			} :: Types.Transform),
			Components.Model({
				instance = model,
			} :: Types.ModelComponent)
		)
	end

	for _, event in matter.useEvent(Events, "ToolUnequiped") do
		if event.type == "FacilityPlacer" then
			facilityPlacer.enabled = false
			if facilityPlacer.hologramModel then
				facilityPlacer.hologramModel:Destroy()
			end
			facilityPlacer.hologramModel = nil
		end
	end
	for _, event in matter.useEvent(Events, "ToolEquiped") do
		if event.type == "FacilityPlacer" then
			facilityPlacer.enabled = true
			facilityPlacer.hologramModel = FacilitiesModels[event.facilityModel]:Clone()
			facilityPlacer.canDisableSnapping = event.canDisableSnapping
			facilityPlacer.rotationAngle = 0
			facilityPlacer.facilityName = event.facilityModel

			if not facilityPlacer.hologramModel then
				error("Facility model not found: " .. event.facilityName)
			end
			Helpers.changeModelParts(facilityPlacer.hologramModel, {
				Transparency = 0.8,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Anchored = true,
				Color = Color3.fromRGB(58, 150, 255),
			})
			facilityPlacer.hologramModel.Parent = workspace
		end
	end

	if not facilityPlacer.enabled then
		return
	end

	MatterHooks.useContextAction("facility_placer:rotate_facility", function(_action, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			facilityPlacer.rotateActionActive = true
			if not facilityPlacer.snapDisabled then
				facilityPlacer.rotationAngle = ((facilityPlacer.rotationAngle or 0) - math.rad(90)) % math.rad(360)
			end
		elseif inputState == Enum.UserInputState.End then
			facilityPlacer.rotateActionActive = false
		end

		return Enum.ContextActionResult.Sink
	end, { inputTypes = { Enum.KeyCode.R } })

	if facilityPlacer.canDisableSnapping then
		MatterHooks.useContextAction(
			"facility_placer:toggle_snapping",
			function(_action, inputState: Enum.UserInputState)
				if inputState == Enum.UserInputState.Begin then
					facilityPlacer.snapDisabled = true
				elseif inputState == Enum.UserInputState.End then
					facilityPlacer.snapDisabled = false
				end

				placementPointer.snapToGrid = not facilityPlacer.snapDisabled
				return Enum.ContextActionResult.Sink
			end,
			{ inputTypes = { Enum.KeyCode.LeftShift } }
		)
	end

	MatterHooks.useContextAction("facility_placer:place_facility", function(_action, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.End and facilityPlacer.validationResult.canPlace then
			if facilityPlacer.facilityName == "Miner" then
				spawnMiner()
			else
				spawnProductionFacility(facilityPlacer.facilityName :: Types.ProductionFacilityType)
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Sink
	end, { inputTypes = { Enum.UserInputType.MouseButton1 } })

	if facilityPlacer.hologramModel then
		if facilityPlacer.rotateActionActive and facilityPlacer.snapDisabled then
			facilityPlacer.rotationAngle = (facilityPlacer.rotationAngle or 0) + world.FixedDeltaTime * math.rad(-180)
		end

		mouse.TargetFilter = facilityPlacer.hologramModel
		local targetPosition = facilityPlacer.snapDisabled and mouse.Hit.Position
			or Helpers.snapToGrid(mouse.Hit.Position, settings.gridSize)
		facilityPlacer.currentCFrame = CFrame.new(targetPosition.X, 0, targetPosition.Z)
			* CFrame.Angles(0, facilityPlacer.rotationAngle or 0, 0)
		facilityPlacer.validationResult =
			validateFacilityPlacement(facilityPlacer.hologramModel, facilityPlacer.hologramModel.Name)

		if MatterHooks.useChange({ facilityPlacer.validationResult.canPlace }, facilityPlacer.facilityName) then
			Helpers.changeModelParts(facilityPlacer.hologramModel, {
				Color = facilityPlacer.validationResult.canPlace and Color3.fromRGB(58, 150, 255)
					or Color3.fromRGB(255, 50, 50),
			})
		end

		if facilityPlacer.hologramModel:GetPivot() ~= facilityPlacer.currentCFrame then
			facilityPlacer.hologramModel:PivotTo(facilityPlacer.currentCFrame :: CFrame)
		end
	end
end

return {
	system = FacilityPlacementSystem,
	event = "FixedUpdate",
	priority = 1,
}
