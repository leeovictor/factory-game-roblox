local Types = require(script.Parent.Types)

local IronOre: Types.ItemSpec = {
	displayName = "Iron Ore",
	description = "A chunk of iron-rich rock mined from the earth.",
	key = "iron_ore",
	stackSize = 100,
	iconAssetId = "",
}
local IronPlate: Types.ItemSpec = {
	displayName = "Iron Plate",
	description = "A flat plate made from smelted iron ore. Its a basic building material.",
	key = "iron_plate",
	stackSize = 100,
	iconAssetId = "",
}

return {
	ByKey = {
		[IronOre.key] = IronOre,
		[IronPlate.key] = IronPlate,
	},
}
