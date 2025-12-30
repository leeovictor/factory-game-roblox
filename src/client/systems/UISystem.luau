local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local MinerInfoScreen = require(StarterPlayer.StarterPlayerScripts.Client.ui.MinerInfoScreen)
local matter = require(ReplicatedStorage.Packages.matter)
local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Events)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local Types = require(ReplicatedStorage.Shared.Types)

local mouse = Players.LocalPlayer:GetMouse()

local ctrlHold = false
local function UISystem(world: Types.World, gameState)
	MatterHooks.useContextAction("uisystem:open_facility_details_ui", function(_action, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.End then
			if mouse.Target and mouse.Target:FindFirstAncestorWhichIsA("Model") then
				local model = mouse.Target:FindFirstAncestorWhichIsA("Model")
				local entityId = model:GetAttribute("entityId")
				if entityId and world:contains(entityId) then
					Events.MinerModelClicked:Fire({ entityId = entityId })
				end
			end
		end
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
		end,
		{ inputTypes = { Enum.KeyCode.LeftControl, Enum.KeyCode.C } }
	)

	for _, entityId in matter.useEvent(Events, "CloseMinerInfoEvent") do
		print("Closing Miner Info UI for entity:", entityId)
		if world:contains(entityId) then
			world:remove(entityId, Components.UpdateMinerInfoUI)
		end

		gameState.screens.MinerInfoScreen:Hide()
	end

	for _, event in matter.useEvent(Events, "MinerModelClicked") do
		print("Opening Miner Info UI for entity:", event.entityId)
		if event.entityId ~= gameState.screens.MinerInfoScreen.entityId then
			for id in world:query(Components.UpdateMinerInfoUI) do
				world:remove(id, Components.UpdateMinerInfoUI)
				world:commitCommands()
			end
		end

		if world:contains(event.entityId) then
			world:insert(event.entityId, Components.UpdateMinerInfoUI())
			gameState.screens.MinerInfoScreen:Show(event.entityId)
		end
	end

	for _id, miner, storage in world:query(Components.Miner, Components.Storage, Components.UpdateMinerInfoUI) do
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
