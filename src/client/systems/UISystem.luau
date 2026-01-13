--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local MinerInfoScreen = require(StarterPlayer.StarterPlayerScripts.Client.ui.MinerInfoScreen)
local UIEvents = require(StarterPlayer.StarterPlayerScripts.Client.ui.UIEvents)
local UITypes = require(StarterPlayer.StarterPlayerScripts.Client.ui.UITypes)
local matter = require(ReplicatedStorage.Matter)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Events)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local Types = require(ReplicatedStorage.Shared.Types)

local mouse = Players.LocalPlayer:GetMouse()

local ctrlHold = false
local function UISystem(
	world: Types.World,
	gameState: { screens: { MinerInfoScreen: MinerInfoScreen.MinerInfoUIController } }
)
	local function initializeSlotsForRecipe(facility: Types.ProductionFacility, recipe: Types.RecipeSpec)
		facility.inputSlots = {}
		facility.outputSlots = {}
		for itemKey in pairs(recipe.requirements) do
			facility.inputSlots[itemKey] = {
				quantity = 0,
			} :: Types.Slot
		end
		for itemKey in pairs(recipe.outputs) do
			facility.outputSlots[itemKey] = {
				quantity = 0,
			} :: Types.Slot
		end
	end

	MatterHooks.useContextAction("uisystem:open_facility_details_ui", function(_action, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
			local raycastParams = RaycastParams.new()
			raycastParams.CollisionGroup = CollisionGroups.ViewEntityDetailsCheck
			local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

			if res ~= nil and res.Instance ~= nil then
				local model: Model? = Helpers.getModelFromPart(res.Instance)
				if model == nil then
					return
				end
				local entityId = model:GetAttribute("entityId") :: number?
				if entityId == nil or not world:contains(entityId) then
					return
				end

				local miner: Types.Miner? = world:get(entityId, Components.Miner)
				if miner ~= nil then
					gameState.screens.MinerInfoScreen:SetEntityId(entityId)
					if not gameState.screens.MinerInfoScreen.enabled then
						gameState.screens.MinerInfoScreen:Show()
					end
				end

				-- TODO: handle other entity types (e.g., ProductionFacility)
			end
		end
		return Enum.ContextActionResult.Sink
	end, { inputTypes = { Enum.UserInputType.MouseButton1 } })

	MatterHooks.useContextAction(
		"uisystem:copy_command",
		function(_action, inputState: Enum.UserInputState, inputObj: InputObject)
			if inputObj.KeyCode == Enum.KeyCode.LeftControl and inputState == Enum.UserInputState.Begin then
				ctrlHold = true
			elseif inputObj.KeyCode == Enum.KeyCode.LeftControl and inputState == Enum.UserInputState.End then
				ctrlHold = false
			end

			if inputObj.KeyCode == Enum.KeyCode.C and inputState == Enum.UserInputState.Begin and ctrlHold then
				print("Ctrl + C detected")
			end
			return Enum.ContextActionResult.Sink
		end,
		{ inputTypes = { Enum.KeyCode.LeftControl, Enum.KeyCode.C } }
	)

	for _, event: UITypes.SelectRecipeEvent in matter.useEvent(UIEvents, "SelectRecipeEvent") do
		print("SelectRecipeEvent received for entity:", event.entityId)
		local facility: Types.ProductionFacility = world:get(event.entityId, Components.ProductionFacility)
		facility.recipe = event.recipe
		initializeSlotsForRecipe(facility, event.recipe)
	end

	for _, _ in matter.useEvent(Events, "CloseMinerInfoEvent") do
		gameState.screens.MinerInfoScreen:Hide()
		gameState.screens.MinerInfoScreen:SetEntityId(nil)
	end

	if gameState.screens.MinerInfoScreen.enabled then
		if not world:contains(gameState.screens.MinerInfoScreen.entityId) then
			gameState.screens.MinerInfoScreen:Hide()
			gameState.screens.MinerInfoScreen:SetEntityId(nil)
			return
		end

		local miner: Types.Miner = world:get(gameState.screens.MinerInfoScreen.entityId, Components.Miner)
		local storage: Types.Storage = world:get(gameState.screens.MinerInfoScreen.entityId, Components.Storage)

		local currentMiningTime = 1 / ((miner.speedPerNode * miner.oreNodesCount) / 60)
		local info: MinerInfoScreen.MinerInfo = {
			status = miner.state,
			storage = {
				currentAmount = storage.currentAmount,
				capacity = storage.capacity,
			},
			veinsCount = miner.oreNodesCount,
			miningProgress = math.clamp(miner.miningProgress / currentMiningTime, 0, 1),
		}
		gameState.screens.MinerInfoScreen:UpdateMinerInfo(info)
	end
end

return {
	system = UISystem,
}
