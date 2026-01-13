--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local Matter = require(ReplicatedStorage.Matter)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local Components = require(ReplicatedStorage.Shared.Components)
local Enums = require(ReplicatedStorage.Shared.Enums)
local Gizmos = require(ReplicatedStorage.Shared.Gizmos)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local Types = require(ReplicatedStorage.Shared.Types)

local enabled = false
local startPos: Vector3?
local endPos: Vector3?
local startConnection: Types.SorterConnection?

local mouse = Players.LocalPlayer:GetMouse()

local function SorterPlacerSystem(world: Types.World, gameState)
	for _, event in Matter.useEvent(Events, "ToolUnequiped") do
		if event.type == "SorterPlacer" then
			enabled = false
			startConnection = nil
		end
	end
	for _, event in Matter.useEvent(Events, "ToolEquiped") do
		if event.type == "SorterPlacer" then
			enabled = true
			startConnection = nil
		end
	end

	local function findConnectionEntityInMouseHit(): Types.SorterConnection?
		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.CollisionGroup = CollisionGroups.SorterValidConnectionCheck
		local res = workspace:Raycast(ray.Origin, ray.Direction * 5000, raycastParams)

		if res == nil then
			return nil
		end

		local model: Model? = Helpers.getModelFromPart(res.Instance)
		if model == nil then
			return nil
		end

		local entityId = model:GetAttribute("entityId")
		if entityId == nil then
			return nil
		end

		if world:get(entityId, Components.BeltNode) ~= nil then
			return {
				entityId = entityId,
				entityType = Enums.SorterConnectionEntityType.Belt,
			} :: Types.SorterConnection
		elseif world:get(entityId, Components.ProductionFacility) ~= nil then
			return {
				entityId = entityId,
				entityType = Enums.SorterConnectionEntityType.Facility,
			} :: Types.SorterConnection
		else
			error("Entidade selecionada não é uma belt nem uma facility.")
		end
	end

	local function connectSorterTo(entityId: Types.EntityId, sorterId: Types.EntityId)
		print("Connecting sorter ", sorterId, " to entity ", entityId)

		local sortersConnected: Types.SortersConnected = world:get(entityId, Components.SortersConnected)
		sortersConnected.sorters[`{sorterId}`] = true
	end

	if enabled then
		MatterHooks.useContextAction("sorter_placer:select_point", function(_actionName, inputState, _inputObject)
			if inputState == Enum.UserInputState.Begin then
				local sorterConnection: Types.SorterConnection? = findConnectionEntityInMouseHit()
				if sorterConnection == nil then
					print("No valid connection found")
					return Enum.ContextActionResult.Sink
				end

				if startConnection == nil then
					startPos = Helpers.snapToGrid(mouse.Hit, 2)
					startConnection = sorterConnection
					print("Start connection selected: ", startConnection)
				else
					endPos = Helpers.snapToGrid(mouse.Hit, 2)

					local sorterId = world:spawn()

					connectSorterTo(startConnection.entityId, sorterId)
					connectSorterTo(sorterConnection.entityId, sorterId)

					world:insert(
						sorterId,
						Components.Sorter({
							inputCon = startConnection,
							outputCon = sorterConnection,
							currentItem = nil,
							progress = 0,
							speed = Enums.SorterSpeeds.Slow,
							state = Enums.SorterState.WaitingForCargo,
						} :: Types.Sorter),
						Components.SorterModel({
							inputPos = startPos :: Vector3,
							outputPos = endPos :: Vector3,
						} :: Types.SorterModel)
					)

					startPos = nil
					endPos = nil
					startConnection = nil
				end
			end
			return Enum.ContextActionResult.Sink
		end, { inputTypes = { Enum.UserInputType.MouseButton1 } })

		MatterHooks.useContextAction("sorter_placer:cancel", function(_actionName, inputState, _inputObject)
			if inputState == Enum.UserInputState.Begin then
				local humanoid: Humanoid = Players.LocalPlayer.Character:FindFirstChild("Humanoid")
				humanoid:UnequipTools()
			end
			return Enum.ContextActionResult.Sink
		end, { inputTypes = { Enum.UserInputType.MouseButton2 } })
	end
end

return {
	system = SorterPlacerSystem,
	event = "FixedUpdate",
}
