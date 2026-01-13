local ReplicatedStorage = game:GetService("ReplicatedStorage")
local signal = require(ReplicatedStorage.Packages.signal)

return {
	SelectRecipeEvent = signal.new(),
}
