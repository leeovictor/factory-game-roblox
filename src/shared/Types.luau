local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Matter)

export type EntityId = number

export type BeltSegment = {
	distToInsertAtStart: number,
	nodes: { EntityId },
	speed: number,
	prevSeg: EntityId?,
	nextSeg: EntityId?,
	minerConnected: EntityId?,
	lastGapIndex: number?,
}

export type BeltItemV2 = {
	item: string,
	distFromNext: number,
}

export type BeltItemsV2 = {
	items: { BeltItemV2 },
}

export type Transform = {
	cframe: CFrame,
	isStatic: boolean,
}

export type ModelComponent = {
	instance: Model,
	disabled: boolean?,
}

export type BeltItemComponent = {
	items: { BeltItem },
}

export type BeltItem = {
	item: string,
	pos: number,
	mesh: MeshPart,
}

export type BeltPath = {
	nodes: { EntityId },
	distToInsertAtStart: number,
	beltNodeOutput: EntityId?,
	speed: number,
	minerConnected: EntityId?,
}

export type BeltsConnected = {
	belts: { [string]: boolean },
}

export type BeltNodeDirection = "top" | "right" | "left"
export type BeltNodeComponent = {
	beltPath: EntityId,
	nodeIndex: number,
	pos: Vector3,
	dirVector: Vector3,
	cframe: CFrame,
	index: number,
	direction: BeltNodeDirection,
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
export type World = typeof(Matter.World) & {
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

export type SorterState = "waiting_for_cargo" | "transporting" | "returning"
export type SorterSpeed = number
export type SorterConnectionEntityType = "belt" | "facility"

export type SorterConnection = {
	entityId: EntityId,
	entityType: SorterConnectionEntityType,
}

export type Sorter = {
	inputCon: SorterConnection?,
	outputCon: SorterConnection?,
	currentItem: ItemKey?,
	state: SorterState,
	progress: number,
	speed: SorterSpeed,
}

export type SorterModel = {
	inputPos: Vector3,
	outputPos: Vector3,
	instances: { input: Model, output: Model }?,
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

type ProductionFacilityState = "idle" | "producing" | "lack_material" | "product_overflow"

export type ItemKey = string

export type ItemSpec = {
	key: ItemKey,
	displayName: string,
	description: string,
	stackSize: number,
	iconAssetId: string,
}

export type RecipeRequirement = {
	itemSpec: ItemSpec,
	amount: number,
}

export type RecipeOutput = {
	itemSpec: ItemSpec,
	amount: number,
}

export type RecipeSpec = {
	name: string,
	description: string,
	requirements: { [ItemKey]: RecipeRequirement },
	outputs: { [ItemKey]: RecipeOutput },
	productionTime: number, -- in seconds
	facilityType: ProductionFacilityType, -- the type of facility that can produce this recipe
	canBeMadeInInventory: boolean,
}

export type Slot = {
	quantity: number,
}

export type SlotMap = {
	[ItemKey]: Slot,
}

export type SortersConnected = {
	sorters: { [string]: boolean },
}

export type ProductionFacilityType = "Smelter" | "Assembler"

export type ProductionFacility = {
	recipe: RecipeSpec?,
	inputSlots: SlotMap,
	outputSlots: SlotMap,
	state: ProductionFacilityState,
	progress: number,
	facilityType: ProductionFacilityType,
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
	oreType: ItemKey,
}

export type Storage = {
	capacity: number,
	currentAmount: number,
}

-- Sinaliza mudanças nos meshes dos items em esteiras. Usado no sistema ItemsMeshesSync
-- para adicionar/remover meshes conforme items são adicionados/removidos das esteiras
-- e também para transferir meshes entre segmentos de esteiras sem deparentamento e chamadas
-- para o object pool.
-- Esse componente é adicionado à esteira quando há mudanças e removido após o ItemsMeshesSync
-- processar as mudanças. Esteiras não sendo renderizadas não terão esse componente.
-- Esse componente é criado em chamadas aos métodos de BeltItemsManager.
export type MeshesChanges = {
	added: { BeltItemV2 },
	removed: { BeltItemV2 },

	--[[ Usado apenas na transferência de items entre segmentos de esteira
	evitando reparentamento e chamadas para o mesh object pool ]]
	transferred: { { to: EntityId, item: BeltItemV2 } },
}

export type ItemsMeshes = {
	[BeltItemV2]: MeshPart,
}

return {}
