local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Matter)

export type EntityId = number

export type ModelComponent = {
	instance: Model,
	disabled: boolean,
}

export type BeltItemComponent = {
	items: { BeltItem },
}

export type BeltItem = {
	item: string,
	distFromNext: number,
	mesh: MeshPart,
}

export type BeltPath = {
	nodes: { EntityId },
	distToInsertAtStart: number,
	beltNodeOutput: EntityId?,
	speed: number,
	prevBelt: EntityId?,
	nextBelt: EntityId?,
	lastGapIndex: number?,
	minerConnected: EntityId?,
}

export type BeltNodeComponent = {
	beltPath: EntityId,
	nodeIndex: number,
	pos: Vector3,
	dirVector: Vector3,
	cframe: CFrame,
	index: number,
	direction: "top" | "right" | "left",
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
	minerToConnect: EntityId?,
	lastBelt: EntityId?,
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

export type MinerStates = "Mining" | "NodesDepleted" | "ProductOverflow"

export type Miner = {
	miningProgress: number,
	oreNodes: { EntityId },
	oreNodesCount: number,
	speedPerNode: number,
	startMiningTime: number,
	state: MinerStates,
	outputBelt: EntityId?,
}

export type Storage = {
	capacity: number,
	currentAmount: number,
}

return {}
