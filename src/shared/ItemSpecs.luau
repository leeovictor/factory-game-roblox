local Types = require(script.Parent.Types)

local IronOre: Types.ItemSpec = {
	displayName = "Iron Ore",
	description = "A chunk of iron-rich rock mined from the earth.",
	key = "iron_ore",
	stackSize = 100,
	iconAssetId = "",
}
local CopperOre: Types.ItemSpec = {
	displayName = "Copper Ore",
	description = "A chunk of copper-rich rock mined from the earth.",
	key = "copper_ore",
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
local CopperPlate: Types.ItemSpec = {
	displayName = "Copper Plate",
	description = "A flat plate made from smelted copper ore. Its a basic building material.",
	key = "copper_plate",
	stackSize = 100,
	iconAssetId = "",
}
local EletricCircuit: Types.ItemSpec = {
	displayName = "Electronic Circuit",
	description = "A basic electronic circuit used in various devices.",
	key = "electronic_circuit",
	stackSize = 200,
	iconAssetId = "",
}

return {
	Keys = {
		IronOre = IronOre.key,
		CopperOre = CopperOre.key,
		IronPlate = IronPlate.key,
		CopperPlate = CopperPlate.key,
		ElectronicCircuit = EletricCircuit.key,
	},
	ByKey = {
		[IronOre.key] = IronOre,
		[CopperOre.key] = CopperOre,
		[IronPlate.key] = IronPlate,
		[CopperPlate.key] = CopperPlate,
		[EletricCircuit.key] = EletricCircuit,
	},
}
