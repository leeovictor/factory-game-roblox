local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local Components = require(ReplicatedStorage.Shared.Components)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local Types = require(ReplicatedStorage.Shared.Types)

local function SorterModelLifeCycleSystem(world: Types.World)
	for id, record in world:queryChanged(Components.SorterModel) do
		if record.old == nil and record.new ~= nil then
			local inputModel: Model = ReplicatedStorage.Models.Facilities.Sorter:Clone()
			local outputModel: Model = ReplicatedStorage.Models.Facilities.Sorter:Clone()
			inputModel.Parent = workspace
			outputModel.Parent = workspace

			inputModel:SetAttribute("entityId", id)
			outputModel:SetAttribute("entityId", id)

			local sorterModel: Types.SorterModel = record.new
			inputModel:PivotTo(CFrame.new(sorterModel.inputPos, sorterModel.outputPos))
			outputModel:PivotTo(CFrame.new(sorterModel.outputPos, sorterModel.inputPos))

			Helpers.setCollisionGroupModelParts(inputModel, CollisionGroups.Sorters)
			Helpers.setCollisionGroupModelParts(outputModel, CollisionGroups.Sorters)

			sorterModel.instances = {
				input = inputModel,
				output = outputModel,
			}
			continue
		end

		if record.old ~= nil and record.new == nil then
			local sorterModel: Types.SorterModel = record.old
			if sorterModel.instances ~= nil then
				sorterModel.instances.input:Destroy()
				sorterModel.instances.output:Destroy()
			end
			continue
		end
	end
end

return {
	system = SorterModelLifeCycleSystem,
	event = "FixedUpdate",
}
