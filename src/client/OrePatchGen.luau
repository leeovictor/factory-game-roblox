local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)
local tag = 'OrePatchGenMarker'

local point = Instance.new('Part')
point.Size = Vector3.new(0.5,0.5,0.5)
point.Anchored = true
point.CanCollide = false
point.Color = Color3.fromRGB(198, 201, 17)

local math_random = math.random
local math_floor = math.floor
local math_ceil = math.ceil
local math_sqrt = math.sqrt
local math_cos = math.cos
local math_sin = math.sin
local math_rad = math.rad

local width = 200
local height = 200

local function dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function isValidPoint(grid, cellsize, gwidth, gheight, p, radius)
    if p.x < 0 or p.x >= width or p.y < 0 or p.y >= height then
        return false
    end

    local xindex = math_floor(p.x / cellsize)
    local yindex = math_floor(p.y / cellsize)
    local i0 = math.max(xindex - 1, 0)
    local i1 = math.min(xindex + 1, gwidth - 1)
    local j0 = math.max(yindex - 1, 0)
    local j1 = math.min(yindex + 1, gheight - 1)

    for i = i0, i1 do
        for j = j0, j1 do
            local cell = grid[i] and grid[i][j]
            if cell then
                if dist(cell.x, cell.y, p.x, p.y) < radius then
                    return false
                end
            end
        end
    end

    return true
end

local function insertPoint(grid, cellsize, p)
    local xindex = math_floor(p.x / cellsize)
    local yindex = math_floor(p.y / cellsize)
    grid[xindex] = grid[xindex] or {}
    grid[xindex][yindex] = p
end

local function poissonDiskSampling(radius, k, startPoint, maxPoints)
    local N = 2
    local points = {}
    local active = {}
    local function randomf(a, b)
        return a + (b - a) * math_random()
    end

    local p0 = startPoint or {x = randomf(0, width), y = randomf(0, height)}
    local cellsize = math_floor(radius / math_sqrt(N))
    if cellsize < 1 then
        cellsize = 1
    end

    local ncells_width = math_ceil(width / cellsize) + 1
    local ncells_height = math_ceil(height / cellsize) + 1

    local grid = {}
    for i = 0, ncells_width - 1 do
        grid[i] = {}
        for j = 0, ncells_height - 1 do
            grid[i][j] = nil
        end
    end

    insertPoint(grid, cellsize, p0)
    table.insert(points, p0)
    table.insert(active, p0)

    while #active > 0 do
        local random_index = math_random(1, #active)
        local p = active[random_index]

        local found = false
        for _ = 1, k do
            local theta = randomf(0, 360)
            local new_radius = randomf(radius, 2 * radius)
            local pnewx = p.x + new_radius * math_cos(math_rad(theta))
            local pnewy = p.y + new_radius * math_sin(math_rad(theta))
            local pnew = {x = pnewx, y = pnewy}

            if not isValidPoint(grid, cellsize, ncells_width, ncells_height, pnew, radius) then
                continue
            end

            table.insert(points, pnew)
            insertPoint(grid, cellsize, pnew)
            table.insert(active, pnew)
            found = true
            break
        end

        if maxPoints ~= nil and #points > maxPoints then
            break
        end
        if not found then
            table.remove(active, random_index)
        end
    end

    return points
end

function generateOrePatch(center: Vector3, nodesCount: number, world)
    local points = poissonDiskSampling(3, 100, {x = 100, y = 100}, nodesCount - 1)
    for _, p in points do
        p.x = p.x - (width / 2)
        p.y = p.y - (height / 2)
    end

    for _, p in points do
        local ppart = point:Clone()
        ppart.Position = Vector3.new(p.x, 0, p.y) + Vector3.new(center.X, 0, center.Z)
        if p.x == center.X and p.y == center.Z then
            ppart.Color = Color3.fromRGB(0, 255, 0)
        end
        ppart.Parent = workspace.Ores
        local entityId = world:spawn(
            Components.OreNode({
                oreType = "Iron",
                quantity = 10000,
            }),
            Components.Model({
                instance = ppart
            })
        )
        ppart:SetAttribute('entityId', entityId)
    end
end

local OrePathchGen = {}

function OrePathchGen.generateAll(world)
    task.wait(3)
    local markers = CollectionService:GetTagged(tag)
    for _, marker in markers do
        local orePatchGen: Part = marker
        orePatchGen.Transparency = 0.8
        generateOrePatch(orePatchGen.Position, (orePatchGen:GetAttribute('nodesCount'):: number) or 6, world)
    end
end

return OrePathchGen