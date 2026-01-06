--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Packages.matter)
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
			local pos = Helpers.snapToGrid(mouse.Hit.Position, 2)
			local res = workspace:Raycast(pos + Vector3.yAxis * 10, Vector3.yAxis * -20)

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

				local prevBeltId = belt.prevBelt
				local nextBeltId = belt.nextBelt
				local minerConnected = belt.minerConnected
				if prevBeltId then
					local prevBelt: Types.BeltPath = world:get(prevBeltId, Components.BeltPath)
					prevBelt.nextBelt = nil
				end
				if nextBeltId then
					local nextBelt: Types.BeltPath = world:get(nextBeltId, Components.BeltPath)
					nextBelt.prevBelt = nil
				end
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
		end

		return Enum.ContextActionResult.Sink
	end, { inputTypes = { Enum.UserInputType.MouseButton1 } })
end

return {
	system = DeconstructSystem,
	event = "FixedUpdate",
}
