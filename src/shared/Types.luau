local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Packages.matter)

export type EntityId = number
export type Beltnode = {
	pos: Vector3,
	outDir: Vector3,
}

export type PathPreview = {
	points: { Vector3 },
	color: BrickColor?,
	pointSize: Vector3,
}

export type PathPreviewInstances = {
	instances: { Instance },
}
export type BeltPlacer = {
	startPosition: Vector3?,
	endPosition: Vector3?,
	curveDirection: string,
	pathPreview: EntityId?,
	enabled: boolean,
}
export type World = typeof(matter.World) & {
	GetSingleton: (self: World, component: any) -> any,
	FixedDeltaTime: number,
}

export type PlacementPointer = {
	position: Vector3,
	color: Color3,
	snapToGrid: boolean,
	enabled: boolean,
	smooth: boolean,
}

export type Settings = {
	gridSize: number,
}

export type FacilityPlacer = {
	enabled: boolean,
	hologramModel: Model?,
	canDisableSnapping: boolean,
	snapDisabled: boolean,
	rotationAngle: number,
	rotateActionActive: boolean,
	currentCFrame: CFrame?,
	validationResult: {
		canPlace: boolean,
		reason: string,
		data: any?,
	},
	facilityName: string,
}

export type ToolType = "BeltPlacer" | "FacilityPlacer"

export type GridLines = {
	folder: Instance?,
	gridSize: number,
	gridExtents: number,
	center: Vector3,
	cachedParts: { [number]: Instance }?,
	enabled: boolean,
}

return {}
