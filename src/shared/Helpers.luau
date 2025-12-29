local AssetService = game:GetService("AssetService")
local Helpers = {}

function Helpers.snapToGrid(position: Vector3, size: number): Vector3
    return Vector3.new(
        math.floor((position.X + size / 2) / size) * size,
        0,
        math.floor((position.Z + size / 2) / size) * size
    )
end

function Helpers.changeModelParts(model: Model, props: {[string]: any})
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            for propertyName, value in pairs(props) do
                part[propertyName] = value
            end
        end
    end
end

-- TODO: test this
function Helpers.curveBeltNodeMesh(mesh: MeshPart, startNodePosition: Vector3, nextNodePosition: Vector3)
    local editableMesh = AssetService:CreateEditableMeshAsync(mesh.MeshContent)
    local vertices = editableMesh:GetVertices()
    local meshPosition = mesh.Position

    -- Find the vertex closest to the direction from start node to next node
    local direction = (nextNodePosition - startNodePosition).Unit
    local closestVertexIndex = nil
    local closestDot = -math.huge

    for i, vertex in ipairs(vertices) do
        local vertexWorldPos = mesh.CFrame:PointToWorldSpace(vertex.Position)
        local vertexDir = (vertexWorldPos - meshPosition).Unit
        local dot = vertexDir:Dot(direction)
        if dot > closestDot then
            closestDot = dot
            closestVertexIndex = i
        end
    end

    if closestVertexIndex then
        -- Move the closest vertex towards the next node to create a curve
        local curveStrength = 1 -- You can tweak this value for more/less curve
        local targetPos = mesh.CFrame:PointToObjectSpace(nextNodePosition)
        local newVertexPos = vertices[closestVertexIndex].Position:Lerp(targetPos, curveStrength)
        editableMesh:SetVertexPosition(closestVertexIndex, newVertexPos)
    end

    editableMesh:Apply()
end


return Helpers