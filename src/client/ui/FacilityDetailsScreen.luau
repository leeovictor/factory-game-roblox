local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local UIEvents = require(ReplicatedStorage.Shared.UIEvents)
local RecipeSpecs = require(ReplicatedStorage.Shared.RecipeSpecs)
local Types = require(ReplicatedStorage.Shared.Types)

local FacilityDetailsScreen = {}
FacilityDetailsScreen.__index = FacilityDetailsScreen

export type FacilityDetailsScreenData = {
	screen: any,
	enabled: boolean,
	buttontemplate: TextButton,
	facilityType: string?,
	entityId: Types.EntityId?,
	buttonsConnections: { [TextButton]: RBXScriptConnection },
	selectedRecipe: Types.RecipeSpec?,
}

export type FacilityDetailsScreen = typeof(setmetatable({} :: FacilityDetailsScreenData, FacilityDetailsScreen))

function FacilityDetailsScreen.new(screenInstance: ScreenGui)
	local self = setmetatable({}, FacilityDetailsScreen)

	self.screen = screenInstance
	self.enabled = false
	self.buttonTemplate = self.screen.Frame.RecipeButton :: TextButton
	self.buttonTemplate.Parent = nil
	self.facilityType = nil
	self.selectedRecipe = nil

	self.buttonsConnections = {}

	(self.screen.CloseButton :: ImageButton).MouseButton1Click:Connect(function()
		self:Hide()
	end)

	self:updateRecipeList()
	return self
end

function FacilityDetailsScreen.updateRecipeList(self: FacilityDetailsScreen)
	-- clean children
	for _i, child in ipairs((self.screen.Frame :: Frame):GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
			if self.buttonsConnections[child] ~= nil then
				self.buttonsConnections[child]:Disconnect()
				self.buttonsConnections[child] = nil
			end
		end
	end

	local filteredRecipeList: { [string]: Types.RecipeSpec } = {}
	for key, rec in pairs(RecipeSpecs.ByKey) do
		if self.facilityType == nil or rec.facilityType == self.facilityType then
			filteredRecipeList[key] = rec
		end
	end

	local index = 0
	for key, recipe: Types.RecipeSpec in pairs(filteredRecipeList) do
		local button = self.buttonTemplate:Clone() :: TextButton
		button.Text = recipe.name
		button.Parent = self.screen.Frame
		button.LayoutOrder = index
		button.Name = key
		if self.selectedRecipe ~= nil and recipe.name == self.selectedRecipe.name then
			button:AddTag("Active")
		end
		index += 1
		self.buttonsConnections[button] = button.MouseButton1Click:Connect(function()
			self.selectedRecipe = recipe
			self:updateRecipeList()
			UIEvents.SelectRecipeEvent:Fire({
				entityId = self.entityId :: number,
				recipe = recipe,
			})
		end)
	end
end

function FacilityDetailsScreen.Show(
	self: FacilityDetailsScreen,
	entityId: Types.EntityId,
	facility: Types.ProductionFacility
)
	self.facilityType = facility.facilityType
	self.selectedRecipe = facility.recipe
	self.entityId = entityId
	self:updateRecipeList()

	self.enabled = true
	self.screen.Enabled = self.enabled
end

function FacilityDetailsScreen.Hide(self: FacilityDetailsScreen)
	self.enabled = false
	self.screen.Enabled = self.enabled
	self.entityId = nil
	self.facilityType = nil
	self.selectedRecipe = nil
end

return FacilityDetailsScreen
