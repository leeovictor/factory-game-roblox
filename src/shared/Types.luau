export type EntityId = number
export type Beltnode = {
    pos: Vector3;
    outDir: Vector3;
}

export type PathPreview = {
    points: {Vector3};
    color: BrickColor?;
    pointSize: Vector3;
}

export type PathPreviewInstances = {
    instances: {Instance};
}
export type BeltPlacer = {
    startPosition: Vector3?;
    endPosition: Vector3?;
    curveDirection: string;
    pathPreview: EntityId?;
}

return {}