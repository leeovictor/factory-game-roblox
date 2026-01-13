--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Matter)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Events)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local Types = require(ReplicatedStorage.Shared.Types)

local enabled = false

local function DeconstructSystem(world: Types.World)
	local function despawnSorter(entity: Types.EntityId)
		local sorter: Types.Sorter = world:get(entity, Components.Sorter)

		if sorter.inputCon ~= nil and world:contains(sorter.inputCon.entityId) then
			local sortersConnected: Types.SortersConnected =
				world:get(sorter.inputCon.entityId, Components.SortersConnected)
			sortersConnected.sorters[`{entity}`] = nil
		end
		if sorter.outputCon ~= nil and world:contains(sorter.outputCon.entityId) then
			local sortersConnected: Types.SortersConnected =
				world:get(sorter.outputCon.entityId, Components.SortersConnected)
			sortersConnected.sorters[`{entity}`] = nil
		end

		world:despawn(entity)
	end

	local function despawnConnectedSorters(entityId: Types.EntityId)
		local sortersConnected: Types.SortersConnected = world:get(entityId, Components.SortersConnected)
		if sortersConnected == nil then
			return
		end

		for sorterId, value in pairs(sortersConnected.sorters) do
			if not value then
				continue
			end
			despawnSorter(tonumber(sorterId) :: Types.EntityId)
		end
	end

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
			local raycastParams = RaycastParams.new()
			raycastParams.CollisionGroup = CollisionGroups.DeconstructCollisionCheck
			local res = workspace:Raycast(ray.Origin, ray.Direction * 5000, raycastParams)

			if not res or not res.Instance then
				return Enum.ContextActionResult.Sink
			end

			local model = Helpers.getModelFromPart(res.Instance)
			if not model then
				return Enum.ContextActionResult.Sink
			end
			local entity = model:GetAttribute("entityId") :: number
			if not entity or not world:contains(entity) then
				return Enum.ContextActionResult.Sink
			end

			local beltNode: Types.BeltNodeComponent = world:get(entity, Components.BeltNode)
			if beltNode then -- delete the belt
				local beltPath: Types.BeltPath = world:get(beltNode.beltPath, Components.BeltPath)
				local beltItems: Types.BeltItemComponent = world:get(beltNode.beltPath, Components.BeltItems)

				for _, item in ipairs(beltItems.items) do
					item.mesh:Destroy()
				end
				for _, nodeId in ipairs(beltPath.nodes) do
					despawnConnectedSorters(nodeId)
					world:despawn(nodeId)
				end

				local minerConnected = beltPath.minerConnected
				if minerConnected then
					local miner: Types.Miner = world:get(minerConnected, Components.Miner)
					miner.outputBelt = nil
				end

				world:despawn(beltNode.beltPath)
				return Enum.ContextActionResult.Sink
			end

			local miner = world:get(entity, Components.Miner)
			if miner then
				if miner.outputBelt then
					local belt: Types.BeltPath = world:get(miner.outputBelt, Components.BeltPath)
					belt.minerConnected = nil
				end

				world:despawn(entity)
				return Enum.ContextActionResult.Sink
			end

			local facility = world:get(entity, Components.ProductionFacility)
			if facility then
				despawnConnectedSorters(entity)
				world:despawn(entity)
				return Enum.ContextActionResult.Sink
			end

			local sorter: Types.Sorter = world:get(entity, Components.Sorter)
			if sorter then
				despawnSorter(entity)
			end
		end

		return Enum.ContextActionResult.Sink
	end, { inputTypes = { Enum.UserInputType.MouseButton1 } })
end

return {
	system = DeconstructSystem,
	event = "FixedUpdate",
}
