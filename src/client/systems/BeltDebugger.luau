local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Matter = require(ReplicatedStorage.Matter)
local Components = require(ReplicatedStorage.Shared.Components)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local Types = require(ReplicatedStorage.Shared.Types)

local debugger = {
	enabled = false,
	selectedBeltId = nil,
}
local mouse = Players.LocalPlayer:GetMouse()

local function BeltDebugger(world: Types.World, gameState)
	if not RunService:IsStudio() then
		return
	end

	local function printBeltSegmentInfo(beltId: Types.EntityId)
		local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)
		local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)

		print("--- BELT SEGMENT INFO ---")
		print("BeltId:", beltId)
		print("distToInsertAtStart:", beltSeg.distToInsertAtStart)
		print("Nodes Count:", #beltSeg.nodes)
		print("Items on Belt:")
		for i = 1, math.min(#beltItems.items, 10) do -- limit to first 10 items
			print(
				string.format(
					" Item %d: Type=%s, DistFromNext=%.2f",
					i,
					beltItems.items[i].item,
					beltItems.items[i].distFromNext
				)
			)
		end
		print("--- END ---")
	end

	local function handleSelectBelt(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
			local res = workspace:Raycast(ray.Origin, ray.Direction * 500, nil)

			if not res or not res.Instance then
				return
			end

			local model = Helpers.getModelFromPart(res.Instance)
			if not model then
				return
			end

			local entityId = model:GetAttribute("entityId")
			if not entityId then
				return
			end

			local beltNode: Types.BeltNodeComponent = world:get(entityId, Components.BeltNode)
			if not beltNode then
				return
			end

			debugger.selectedBeltId = beltNode.beltPath
			print("Belt Debugger: Selected BeltId =", debugger.selectedBeltId)
			printBeltSegmentInfo(debugger.selectedBeltId)
		end
	end

	local function handleToggleDebugger(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			debugger.enabled = not debugger.enabled
			print("Belt Debugger enabled:", debugger.enabled)
		end
	end

	local function handlePauseBeltSim(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			gameState.beltDebugger.paused = not gameState.beltDebugger.paused
			print("Belt Debugger: Paused =", gameState.beltDebugger.paused)
		end
	end

	local function handleOneStepBeltSim(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			gameState.beltDebugger.stepOnce = true
			print("Belt Debugger: Step Once")

			if debugger.selectedBeltId ~= nil then
				printBeltSegmentInfo(debugger.selectedBeltId)
			end
		end
	end

	if debugger.enabled then
		MatterHooks.useContextAction(
			"belt_debugger:select_belt",
			handleSelectBelt,
			{ inputTypes = { Enum.UserInputType.MouseButton1 } }
		)

		MatterHooks.useContextAction(
			"belt_debugger:pause_belt_sim",
			handlePauseBeltSim,
			{ inputTypes = { Enum.KeyCode.P } }
		)

		MatterHooks.useContextAction(
			"belt_debugger:one_step_belt_sim",
			handleOneStepBeltSim,
			{ inputTypes = { Enum.KeyCode.Right } }
		)
	end

	MatterHooks.useContextAction(
		"belt_debugger:toggle_belt_debugger",
		handleToggleDebugger,
		{ inputTypes = { Enum.KeyCode.B } }
	)
end

return {
	system = BeltDebugger,
	event = "FixedUpdate",
	priority = math.huge,
}
