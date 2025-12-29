local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SmoothVoxelsUpgraderService = game:GetService("SmoothVoxelsUpgraderService")
local Matter = require(ReplicatedStorage.Packages.matter)

return {
	Miner = Matter.component("Miner"),
	OreNode = Matter.component("OreNode", {
		minersConnected = {},
	}),
	Storage = Matter.component("Storage"),
	ProductionFacility = Matter.component("ProductionFacility"),

	Model = Matter.component("Model"),
	Transform = Matter.component("Transform"),
	StaticTransform = Matter.component("StaticTransform"),
	StaticTransformUpdated = Matter.component("StaticTransformUpdated"),

	-- Miner States
	MinerState_NodesDepleted = Matter.component("MinerState_NodesDepleted"),

	-- Ore Node States
	OreNodeDepleted = Matter.component("OreNodeDepleted"),

	BeltPath = Matter.component("BeltPath"),
	BeltItems = Matter.component("BeltItems"),

	PathPreview = Matter.component("PathPreview"),
	PathPreviewInstances = Matter.component("PathPreviewInstances"),

	BeltPlacer = Matter.component("BeltPlacer", {
		curveDirection = "X",
	}),
	FacilityPlacer = Matter.component("FacilityPlacer"),

	DistanceFromPlayer = Matter.component("DistanceFromPlayer"),
	HightlightOnHoverInitialized = Matter.component("HightlightOnHoverInitialized"),

	UpdateMinerInfoUI = Matter.component("UpdateMinerInfoUI"),

	Event = Matter.component("Event"),
	CloseMinerInfoEvent = Matter.component("CloseMinerInfoEvent"),

	PlacementPointer = Matter.component("PlacementPointer", {
		snapToGrid = true,
		color = Color3.fromRGB(255, 255, 255),
		smooth = false,
	}),

	Settings = Matter.component("Settings"),

	GridLines = Matter.component("GridLines"),
}
