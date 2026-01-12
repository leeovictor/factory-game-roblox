--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local Matter = require(ReplicatedStorage.Matter)
local component = require(ReplicatedStorage.Matter.component)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local Components = require(ReplicatedStorage.Shared.Components)
local Enums = require(ReplicatedStorage.Shared.Enums)
local Gizmos = require(ReplicatedStorage.Shared.Gizmos)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local Types = require(ReplicatedStorage.Shared.Types)

local enabled = false
local startConnection: Types.SorterConnection?

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
		local mouse = Players.LocalPlayer:GetMouse()
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

	if enabled then
		MatterHooks.useContextAction("sorter_placer:select_point", function(_actionName, inputState, _inputObject)
			if inputState == Enum.UserInputState.Begin then
				local sorterConnection: Types.SorterConnection? = findConnectionEntityInMouseHit()
				if sorterConnection == nil then
					print("No valid connection found")
					return Enum.ContextActionResult.Sink
				end

				if startConnection == nil then
					startConnection = sorterConnection
					print("Start connection selected: ", startConnection)
				else
					world:spawn(Components.Sorter({
						inputCon = startConnection,
						outputCon = sorterConnection,
						currentItem = nil,
						progress = 0,
						speed = Enums.SorterSpeeds.Normal,
						state = Enums.SorterState.WaitingForCargo,
					} :: Types.Sorter))

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

	if gameState.debug then
		for _id, sorter: Types.Sorter in world:query(Components.Sorter) do
			local inputModel: Types.ModelComponent =
				world:get((sorter.inputCon :: Types.SorterConnection).entityId, Components.Model)
			local outputModel: Types.ModelComponent =
				world:get((sorter.outputCon :: Types.SorterConnection).entityId, Components.Model)

			local startPos = inputModel.instance:GetPivot()
			local endPos = outputModel.instance:GetPivot()

			Gizmos.drawPoint(startPos.Position)
			Gizmos.drawPoint(endPos.Position)
			Gizmos.drawLine(startPos.Position, endPos.Position)
		end
	end
end

return {
	system = SorterPlacerSystem,
	event = "FixedUpdate",
}
