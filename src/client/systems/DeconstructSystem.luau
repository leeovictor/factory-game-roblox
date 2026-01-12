--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Matter)
local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Events)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local Types = require(ReplicatedStorage.Shared.Types)

local enabled = false

local function DeconstructSystem(world: Types.World)
	for _, event in matter.useEvent(Events, "ToolUnequiped") do
		if event.type == "Deconstruct" then
			enabled = false
		end
	end
	for _, event in matter.useEvent(Events, "ToolEquiped") do
		if event.type == "Deconstruct" then
			enabled = true
		end
	end

	if not enabled then
		return
	end

	MatterHooks.useContextAction("deconstruct:click", function(_actionName, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			local mouse = game.Players.LocalPlayer:GetMouse()
			local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
			local res = workspace:Raycast(ray.Origin, ray.Direction * 5000)

			if not res or not res.Instance then
				return Enum.ContextActionResult.Sink
			end

			local model = Helpers.getModelFromPart(res.Instance)
			if not model then
				return Enum.ContextActionResult.Sink
			end
			local entity = model:GetAttribute("entityId")
			if not entity or not world:contains(entity) then
				return Enum.ContextActionResult.Sink
			end

			local beltNode: Types.BeltNodeComponent = world:get(entity, Components.BeltNode)
			if beltNode then -- delete the belt
				local belt: Types.BeltPath = world:get(beltNode.beltPath, Components.BeltPath)
				local beltItems: Types.BeltItemComponent = world:get(beltNode.beltPath, Components.BeltItems)

				for _, item in ipairs(beltItems.items) do
					item.mesh:Destroy()
				end
				for _, nodeId in ipairs(belt.nodes) do
					world:despawn(nodeId)
				end

				local minerConnected = belt.minerConnected
				if minerConnected then
					local miner: Types.Miner = world:get(minerConnected, Components.Miner)
					miner.outputBelt = nil
				end

				world:despawn(beltNode.beltPath)
				return Enum.ContextActionResult.Sink
			end

			local miner = world:get(entity, Components.Miner)
			if miner then -- delete the miner
				if miner.outputBelt then
					local belt: Types.BeltPath = world:get(miner.outputBelt, Components.BeltPath)
					belt.minerConnected = nil
				end

				world:despawn(entity)
				return Enum.ContextActionResult.Sink
			end

			local facility = world:get(entity, Components.ProductionFacility)
			if facility then -- delete the production facility
				world:despawn(entity)
				return Enum.ContextActionResult.Sink
			end
		end

		return Enum.ContextActionResult.Sink
	end, { inputTypes = { Enum.UserInputType.MouseButton1 } })
end

return {
	system = DeconstructSystem,
	event = "FixedUpdate",
}
