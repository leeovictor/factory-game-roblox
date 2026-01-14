local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OreDepletedRemoveSystem = require(script.Parent.OreDepletedRemoveSystem)
local RemoveModelsSytem = require(script.Parent.RemoveModelsSytem)
local Components = require(ReplicatedStorage.Shared.Components)
local Enums = require(ReplicatedStorage.Shared.Enums)
local ItemSpecs = require(ReplicatedStorage.Shared.ItemSpecs)
local Types = require(ReplicatedStorage.Shared.Types)

local function recipeRequirementMet(productionFacility: Types.ProductionFacility): boolean
	assert(productionFacility.recipe ~= nil, "requirementMet called with nil recipe")

	for itemKey: Types.ItemKey, requirement: Types.RecipeRequirement in
		pairs((productionFacility.recipe :: Types.RecipeSpec).requirements)
	do
		local slot: Types.Slot = productionFacility.inputSlots[itemKey]
		if not slot then
			error("Input slot not found for itemKey: " .. tostring(itemKey))
		end
		if not slot or slot.quantity < requirement.amount then
			return false
		end
	end

	return true
end

local function allOutputSlotsAvailable(productionFacility: Types.ProductionFacility): boolean
	for itemKey: Types.ItemKey, slot: Types.Slot in pairs(productionFacility.outputSlots) do
		local itemSpec: Types.ItemSpec = ItemSpecs.ByKey[itemKey]
		if not itemKey then
			error("ItemSpec not found for itemKey: " .. tostring(itemKey))
		end

		if slot.quantity >= itemSpec.stackSize then
			return false
		end
	end

	return true
end

local function ProductionFacility(world: Types.World)
	for _id, productionFacility: Types.ProductionFacility in world:query(Components.ProductionFacility) do
		if productionFacility.state == Enums.ProductionFacilityState.Idle then
			if productionFacility.recipe ~= nil then
				productionFacility.state = Enums.ProductionFacilityState.Producing
				productionFacility.progress = 0
				continue
			end
		elseif productionFacility.state == Enums.ProductionFacilityState.LackMaterial then
			if productionFacility.recipe == nil then
				productionFacility.state = Enums.ProductionFacilityState.Idle
				continue
			end

			if recipeRequirementMet(productionFacility) then
				productionFacility.state = Enums.ProductionFacilityState.Producing
				continue
			end
		elseif productionFacility.state == Enums.ProductionFacilityState.Producing then
			if productionFacility.recipe == nil then
				productionFacility.state = Enums.ProductionFacilityState.Idle
				productionFacility.progress = 0
				continue
			end

			if not recipeRequirementMet(productionFacility) then
				productionFacility.state = Enums.ProductionFacilityState.LackMaterial
				continue
			end

			if not allOutputSlotsAvailable(productionFacility) then
				productionFacility.state = Enums.ProductionFacilityState.ProductOverflow
				continue
			end

			local recipe = productionFacility.recipe :: Types.RecipeSpec
			productionFacility.progress += world.FixedDeltaTime
			if productionFacility.progress >= recipe.productionTime then
				local overflow = productionFacility.progress - recipe.productionTime

				-- Consume inputs
				for itemKey: Types.ItemKey, requirement: Types.RecipeRequirement in pairs(recipe.requirements) do
					local slot: Types.Slot = productionFacility.inputSlots[itemKey]
					slot.quantity -= requirement.amount
				end
				-- Produce outputs
				for itemKey: Types.ItemKey, output: Types.RecipeOutput in pairs(recipe.outputs) do
					local slot: Types.Slot = productionFacility.outputSlots[itemKey]
					slot.quantity += output.amount
				end

				productionFacility.progress = overflow
			end
		elseif productionFacility.state == Enums.ProductionFacilityState.ProductOverflow then
			if productionFacility.recipe == nil then
				productionFacility.state = Enums.ProductionFacilityState.Idle
				productionFacility.progress = 0
				continue
			end

			if allOutputSlotsAvailable(productionFacility) then
				productionFacility.state = Enums.ProductionFacilityState.Producing
				continue
			end
		else
			error("Unknown production facility state: " .. tostring(productionFacility.state))
		end
	end
end

return {
	system = ProductionFacility,
	event = "FixedUpdate",
	after = { OreDepletedRemoveSystem, RemoveModelsSytem },
}
