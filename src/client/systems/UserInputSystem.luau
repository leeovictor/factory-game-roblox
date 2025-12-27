local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local matter = require(ReplicatedStorage.Packages.matter)
local Components = require(ReplicatedStorage.Shared.Components)
local TableUtils = require(ReplicatedStorage.Shared.TableUtils)
local Types = require(ReplicatedStorage.Shared.Types)

local mouse = Players.LocalPlayer:GetMouse()

local gridSize = 2

-- TODO: improve this algorithm to avoid overlapping points and less loops
local function getPathPoints(startPos: Vector3, endPos: Vector3, curveDirection: string, maxPoints: number)
    local points = {}
    if startPos == endPos then
        return { startPos }
    end

    if curveDirection == 'FREE' then
        local direction = (endPos - startPos).Unit
        local distance = (endPos - startPos).Magnitude
        local segments = math.floor(distance / gridSize)
        local rest = distance - (segments * gridSize)
        local plus = rest/segments
        for i = 0, segments do
            local point = startPos + direction * (i * gridSize) + direction * (i * plus)
            table.insert(points, Vector3.new(point.X, 0, point.Z))
        end
        table.insert(points, Vector3.new(endPos.X, 0, endPos.Z))
        return points
    end

    local first = {}
    if startPos.X ~= endPos.X then
        for x = startPos.X, endPos.X, math.sign(endPos.X - startPos.X) * gridSize do
            table.insert(first, Vector3.new(x, 0, curveDirection == 'X' and startPos.Z or endPos.Z))
        end
    end
    
    local second = {}
    if startPos.Z ~= endPos.Z then
        for z = startPos.Z, endPos.Z, math.sign(endPos.Z - startPos.Z) * gridSize do
            table.insert(second, Vector3.new(curveDirection == 'X' and endPos.X or startPos.X, 0, z))
        end
    end

    if curveDirection == 'X' then
        points = TableUtils.Merge(first, second)
    else
        points = TableUtils.Merge(second, first)
    end
    
    local finalPoints = {}
    for i = 1, math.min(#points, maxPoints) do
        finalPoints[i] = points[i]
    end

    local set = {}
    for i, p in ipairs(finalPoints) do
        if set[p] == nil then
            set[p] = true
        else
            table.remove(finalPoints, i)
        end
    end

    return finalPoints;
end

local function snapToGrid(position: Vector3, size: number): Vector3
    return Vector3.new(
        math.floor((position.X + size / 2) / size) * size,
        0,
        math.floor((position.Z + size / 2) / size) * size
    )
end

local function UserInputSystem(world)
    for id, placer in world:query(Components.BeltPlacer) do
        for _id, event: InputObject in matter.useEvent(UserInputService, 'InputBegan') do
            if event.UserInputType == Enum.UserInputType.MouseButton1 then
                if not placer.startPosition then
                    placer.startPosition = snapToGrid(mouse.Hit.Position, gridSize)
                elseif not placer.endPosition then
                    placer.startPosition = nil
                end
            end
            
            if event.KeyCode ==  Enum.KeyCode.R then
                placer.curveDirection = placer.curveDirection == 'X' and 'Z' or 'X'
            end
        end
        
        if placer.startPosition then
            local points = getPathPoints(placer.startPosition, snapToGrid(mouse.Hit.Position, gridSize), placer.curveDirection, 100)
            if not placer.pathPreview then
                local pathPreviewId = world:spawn(Components.PathPreview({
                    color = BrickColor.new("Bright green"),
                    pointSize = Vector3.new(1,1,1) * 0.6,
                }))
                world:commitCommands()
                placer.pathPreview = pathPreviewId
            end
            
            local pathPreview = world:get(placer.pathPreview, Components.PathPreview)
            pathPreview.points = points
            if #pathPreview.points > 30 then
                pathPreview.color = BrickColor.new("Bright red")
            else
                pathPreview.color = BrickColor.new("Bright green")
            end
            
        elseif placer.pathPreview then
            world:despawn(placer.pathPreview)
            placer.pathPreview = nil
        end
    end
    
    -- for id, event in matter.useEvent(UserInputService, 'InputEnded') do
    --     if event.UserInputType == Enum.UserInputType.MouseButton1 then
    --         -- TODO:             
    --     end
    -- end
end

return {
    system = UserInputSystem,
    priority = 0,
    event = 'FixedUpdate',
    disabled = true
}