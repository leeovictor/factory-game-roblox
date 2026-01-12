local ItemSpecs = require(script.Parent.ItemSpecs)
local Types = require(script.Parent.Types)

local IronPlate: Types.RecipeSpec = {
	canBeMadeInInventory = true,
	description = "Iron plate is used for building and crafting.",
	facilityType = "Smelter",
	name = "Iron Plate",
	productionTime = 1,
	outputs = {
		[ItemSpecs.Keys.IronPlate] = {
			amount = 1,
			itemSpec = ItemSpecs.ByKey[ItemSpecs.Keys.IronPlate],
		},
	},
	requirements = {
		[ItemSpecs.Keys.IronOre] = {
			amount = 1,
			itemSpec = ItemSpecs.ByKey[ItemSpecs.Keys.IronOre],
		},
	},
}

local CopperPlate: Types.RecipeSpec = {
	canBeMadeInInventory = true,
	description = "Copper plate is used for building and crafting.",
	facilityType = "Smelter",
	name = "Copper Plate",
	productionTime = 1,
	outputs = {
		[ItemSpecs.Keys.CopperPlate] = {
			amount = 1,
			itemSpec = ItemSpecs.ByKey[ItemSpecs.Keys.CopperPlate],
		},
	},
	requirements = {
		[ItemSpecs.Keys.CopperOre] = {
			amount = 1,
			itemSpec = ItemSpecs.ByKey[ItemSpecs.Keys.CopperOre],
		},
	},
}

local EletricCircuit: Types.RecipeSpec = {
	canBeMadeInInventory = true,
	description = "Electronic circuits are used in advanced crafting.",
	facilityType = "Assembler",
	name = "Electronic Circuit",
	productionTime = 1,
	outputs = {
		[ItemSpecs.Keys.ElectronicCircuit] = {
			amount = 2,
			itemSpec = ItemSpecs.ByKey[ItemSpecs.Keys.ElectronicCircuit],
		},
	},
	requirements = {
		[ItemSpecs.Keys.IronPlate] = {
			amount = 2,
			itemSpec = ItemSpecs.ByKey[ItemSpecs.Keys.IronPlate],
		},
		[ItemSpecs.Keys.CopperPlate] = {
			amount = 1,
			itemSpec = ItemSpecs.ByKey[ItemSpecs.Keys.CopperPlate],
		},
	},
}

return {
	ByKey = {
		[ItemSpecs.Keys.IronPlate] = IronPlate,
		[ItemSpecs.Keys.CopperPlate] = CopperPlate,
		[ItemSpecs.Keys.ElectronicCircuit] = EletricCircuit,
	},
}
