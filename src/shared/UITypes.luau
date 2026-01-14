local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

export type SelectRecipeEvent = {
	entityId: Types.EntityId,
	recipe: Types.RecipeSpec,
}

return {}
