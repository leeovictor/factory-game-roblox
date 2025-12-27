local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Signals = require(ReplicatedStorage.Shared.Signals)
local TableUtils = require(ReplicatedStorage.Shared.TableUtils)

-- quando a ferramenta é ativada eu começo o processo de construção da esteira
-- 1. mostro um indicador do mouse no mundo conectado à grid
-- 2. no primeiro clique eu defino a posição inicial da esteira
--      a. pode ser que o primeiro clique seja um node de esteira já existente. nesse caso tenho os seguintes cenários
--          i. se a direção da esteira existente for compatível com a nova esteira, eu continuo a esteira a partir daquele node e desconecto nodes da esteira existente que estão além desse node selecionado
--         ii. se a direção da esteira existente não for compatível, eu crio uma nova esteira a partir daquele node, e desconecto nodes da esteira existente que estão além desse node selecionado
--         iii. se o node selecionado for o node final da esteira existente, eu vou então mergear as duas esteiras em uma só
-- 3. no segundo clique eu defino a posição final da esteira
--      a. pode ser que o segundo clique seja um node de esteira já existente. nesse caso tenho os seguintes cenários
--          i. se a direção da esteira existente for compatível com a nova esteira, eu continuo a esteira a partir daquele node e desconecto nodes da esteira existente que estão além desse node selecionado
--         ii. se a direção da esteira existente não for compatível, eu crio uma nova esteira a partir daquele node, e desconecto nodes da esteira existente que estão além desse node selecionado
--         iii. se o node selecionado for o node inicial da esteira existente, eu vou então mergear as duas esteiras em uma só
-- 4. durante o processo de seleção do segundo ponto eu mostro uma prévia da esteira no mundo, atualizando conforme o mouse se move

local PathRenderer = {}
PathRenderer.__index = PathRenderer

function PathRenderer.new()
    local self = setmetatable({}, PathRenderer)
    self.markeTemplate = Instance.new('Part')
    self.markeTemplate.Name = 'PathMarker'
    self.markeTemplate.Size = Vector3.new(1, 1, 1) * 0.6
    self.markeTemplate.Anchored = true
    self.markeTemplate.CanCollide = false
    self.markeTemplate.Shape = Enum.PartType.Ball
    self.markeTemplate.Color = Color3.fromRGB(255, 0, 0)
    self.markeTemplate.CanQuery = false
    self.markeTemplate.CanTouch = false
    self.cache = {}

    self.lastRenderPoints = {}
    return self
end

function PathRenderer:renderPoint(point: Vector3)
    if not self.cache[point] then
        self.cache[point] = self.markeTemplate:Clone()
        self.cache[point].Position = point
        self.cache[point].Parent = workspace
    end

    table.insert(self.lastRenderPoints, point)
end

function PathRenderer:commit()
    for point, marker in pairs(self.cache) do
        local found = false
        for _, p in ipairs(self.lastRenderPoints) do
            if p == point then
                found = true
                break
            end
        end

        if not found then
            marker.Parent = nil
            self.cache[point] = nil
        end
    end

    self.lastRenderPoints = {}
end

local gridSize = 2
local function getPathPoints(startPos: Vector3, endPos: Vector3, curveDirection: string)
    local points = {}
    if startPos == endPos then
        return points
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
    

    -- TODO: change de algorithm to avoid duplicate points. this is only a quick fix
    local set = {}
    for i, p in ipairs(points) do
        if set[p] == nil then
            set[p] = true
        else
            table.remove(points, i)
        end
    end

    return points;
end


local BeltToolController = {}
BeltToolController.__index = BeltToolController

function BeltToolController.new(placementPointer)
    local self = setmetatable({}, BeltToolController)
    self.placementPointer = placementPointer
    self.startPosition = nil
    self.endPosition = nil

    self.startMarker = Instance.new('Part')
    self.startMarker.Size = Vector3.new(1, 1, 1)
    self.startMarker.Anchored = true
    self.startMarker.CanCollide = false
    self.startMarker.Shape = Enum.PartType.Ball
    self.startMarker.Color = Color3.fromRGB(79, 255, 246)
    self.startMarker.CanQuery = false
    self.startMarker.CanTouch = false

    self.curveDirection = 'X'
    self.curveDirectionCon = nil
    
    self.pathRenderer = PathRenderer.new()
    return self
end

function BeltToolController:activate()
end

function BeltToolController:deactivate()
    if not self.startPosition then
        self.startPosition = self.placementPointer.position
        return
    end
    self.endPosition = self.placementPointer.position
    
    local points = getPathPoints(self.startPosition, self.endPosition, self.curveDirection)
    Signals.CreateBelt:Fire({ nodes = points })

    self.startPosition = nil
    self.endPosition = nil
end

function BeltToolController:equiped()
    self.curveDirectionCon = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.R then
            if self.curveDirection == 'X' then
                self.curveDirection = 'Z'
            elseif self.curveDirection == 'Z' then
                self.curveDirection = 'X'
            end
        end
    end)
end

function BeltToolController:update()
    if not self.startPosition then
        self.startMarker.Parent = nil
    end
    
    -- place start marker
    if self.startPosition and self.startMarker.Parent == nil then
        self.startMarker.Parent = workspace
        self.startMarker.Position = self.startPosition
    end

    -- render path preview
    if self.startPosition then
        for _, p in ipairs(getPathPoints(self.startPosition, self.placementPointer.position, self.curveDirection)) do
            -- validation goes here
            -- 1. collision checks (the belts on this points are not colliding with any other object)
            -- 2. change marker color based on validation
            -- 3. what to do when cross other belts?
                -- a. pass over? (how to handle this? elevation changes?)
            self.pathRenderer:renderPoint(p)

        end
    end
    self.pathRenderer:commit()
end

function BeltToolController:unequiped()
    self.curveDirectionCon:Disconnect()
    self.startPosition = nil
    self.endPosition = nil
    self.startMarker.Parent = nil
    self.curveDirectionCon = nil
end

return BeltToolController