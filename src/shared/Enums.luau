local ProductionFacilityState = {
	Idle = "idle",
	Producing = "producing",
	LackMaterial = "lack_material",
	ProductOverflow = "product_overflow",
}

local SorterState = {
	WaitingForCargo = "waiting_for_cargo",
	Transporting = "transporting",
	Returning = "returning",
}

local SorterConnectionEntityType = {
	Belt = "belt",
	Facility = "facility",
}

local SorterSpeeds = {
	Slow = 2,
	Normal = 5,
	Fast = 10,
}

return {
	ProductionFacilityState = ProductionFacilityState,
	SorterSpeeds = SorterSpeeds,
	SorterState = SorterState,
	SorterConnectionEntityType = SorterConnectionEntityType,
}
