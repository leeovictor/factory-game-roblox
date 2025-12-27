local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local BeltToolController = require(script.BeltToolController)
local Components = require(ReplicatedStorage.Shared.Components)
local Matter = require(ReplicatedStorage.Packages.matter)
local Plasma = require(ReplicatedStorage.Packages.plasma)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Types = require(ReplicatedStorage.Shared.Types)
local orePatchGenerator = require(script.OrePatchGen)
local MinerInfoScreen = require(script.ui.MinerInfoScreen)
local debugger = Matter.Debugger.new(Plasma)
local widgets = debugger:getWidgets()

local FixedUpdate = {}
FixedUpdate.__index = FixedUpdate
function FixedUpdate.new(fixedDeltaTime: number)
    local self = setmetatable({}, FixedUpdate)
    self.fixedDeltaTime = fixedDeltaTime
    self.accumulatedTime = 0
    self.sameFrameCallCount = 0
    return self
end

function FixedUpdate:Connect(callback)
    return RunService.Heartbeat:Connect(function(dt)
        self.accumulatedTime += dt
        self.sameFrameCallCount = 0
        while self.accumulatedTime >= self.fixedDeltaTime do
            if self.sameFrameCallCount > 3 then
                warn("Frame rate is too low to keep up with FixedUpdate. Skipping remaining FixedUpdate calls this frame to avoid build-up more lag.")
                self.accumulatedTime = 0
                break
            end
            callback(self.fixedDeltaTime)
            self.accumulatedTime -=self.fixedDeltaTime
            self.sameFrameCallCount += 1
        end
    end)
end

function extendWorld(world)
    function world:GetSingleton(component: any): any
        local id, comp = self:query(component):next()
        return id, comp
    end
end

local gameState = {
    screens = {}
}
local world = Matter.World.new()
extendWorld(world)
gameState.screens.MinerInfoScreen = MinerInfoScreen.new(world)

function world:GetSingleton(component)
    local _id, comp = self:query(component):next()
    return comp
end

world.FixedDeltaTime = 1 / 60
local loop = Matter.Loop.new(world, gameState, widgets)
loop:setWorlds({ world })

local systems = {}
for _, child in ipairs(script.systems:GetChildren()) do
    if child:IsA("ModuleScript") then
        local system = require(child)
        if system.disabled then
            continue
        end
        table.insert(systems, system)
    end
end
loop:scheduleSystems(systems)

debugger:autoInitialize(loop)
world:spawn(Components.BeltPlacer())
loop:begin({
    default = RunService.Heartbeat,
    FixedUpdate = FixedUpdate.new(world.FixedDeltaTime),
})


UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F4 then
		debugger:toggle()
	end
end)

local FacilitiesModels = ReplicatedStorage:WaitForChild("Models"):WaitForChild("Facilities")

-- function renderGridPoints(gridSize: number, gridExtends: number, center: Vector3)
--     local folder = Instance.new('Folder')
--     folder.Name = "GridPoints"
--     folder.Parent = workspace
--     center = center or Vector3.zero
    
--     local ball = Instance.new('Part')
--     ball.Size = Vector3.new(0.3,0.3,0.3)
--     ball.Shape = Enum.PartType.Ball
--     ball.Color = Color3.fromRGB(255,0,0)
--     ball.Anchored = true
--     ball.CanCollide = false

--     for x = -gridExtends, gridExtends, gridSize do
--         for z = -gridExtends, gridExtends, gridSize do
--             local point = ball:Clone()
--             point.Position = Vector3.new(center.X + x, center.Y, center.Z + z)
--             point.Parent = folder
--         end
--     end
-- end

function renderGridLines(gridSize: number, gridExtends: number, center: Vector3)
    local folder = Instance.new('Folder')
    folder.Name = "GridLines"
    folder.Parent = workspace
    center = center or Vector3.zero

    for x = -gridExtends, gridExtends, gridSize do
        local line = Instance.new('Part')
        if x % 10 == 0 then
            line.Size = Vector3.new(0.2, 0.2, gridExtends * 2)
            line.Transparency = 0.7
        else
            line.Transparency = 0.9
            line.Size = Vector3.new(0.1, 0.1, gridExtends * 2)
        end
        
        line.Anchored = true
        line.CanCollide = false
        line.Color = Color3.fromRGB(22, 160, 63)
        line.Material = Enum.Material.Neon
        line.Position = Vector3.new(center.X + x, center.Y, center.Z)
        line.Parent = folder
    end

    for z = -gridExtends, gridExtends, gridSize do
        local line = Instance.new('Part')
        if z % 10 == 0 then
            line.Size = Vector3.new(gridExtends * 2, 0.2, 0.2)
            line.Transparency = 0.7
        else
            line.Transparency = 0.9
            line.Size = Vector3.new(gridExtends * 2, 0.1, 0.1)
        end
        line.Anchored = true
        line.CanCollide = false
        line.Material = Enum.Material.Neon
        line.Color = Color3.fromRGB(22, 160, 63)
        line.Position = Vector3.new(center.X, center.Y, center.Z + z)
        line.Parent = folder
    end
end

function hideGrid()
    local gridFolder = workspace:FindFirstChild("GridLines")
    if gridFolder then
        gridFolder:Destroy()
    end
    local pointsFolder = workspace:FindFirstChild("GridPoints")
    if pointsFolder then
        pointsFolder:Destroy()
    end
end

local gridSize = 2
local pointer = Instance.new('Part')
pointer.Size = Vector3.new(1,1,1)
pointer.Shape = Enum.PartType.Ball
pointer.Color = Color3.fromRGB(255,255,0)
pointer.Anchored = true
pointer.CanCollide = false
pointer.CanQuery = false
pointer.CanTouch = false

function getFacilityModelByName(facilityName: string): Model
    assert(facilityName, 'facilityName must be provided')
    local model: Model = FacilitiesModels:FindFirstChild(facilityName)
    if model == nil then
        error("Facility model not found: " .. facilityName .. '. Check if the model exists in ReplicatedStorage.Models.Facilities')
    end
    return model:Clone()
end

function snapToGrid(position: Vector3, size: number): Vector3
    return Vector3.new(
        math.floor((position.X + size / 2) / size) * size,
        0,
        math.floor((position.Z + size / 2) / size) * size
    )
end

function validateFacilityPlacement(model: Model, facilityName: string)
    if facilityName == "Assembler" or facilityName == "Smelter" then
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {model, workspace.GridLines, workspace.Baseplate, Players.LocalPlayer.Character}
        local primaryPart = model.PrimaryPart
        local canPlace = #workspace:GetPartBoundsInBox(primaryPart.CFrame, primaryPart.Size, overlapParams) == 0
        return {
            canPlace = canPlace,
            reason = canPlace and "" or "Colliding with other objects." 
        }
    elseif facilityName == "Miner" then
        -- check if miner primary part is colliding with other objects
        local primaryPart = model.PrimaryPart
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {model, workspace.GridLines, workspace.Baseplate, Players.LocalPlayer.Character}
        local primaryPartColliding = #workspace:GetPartBoundsInBox(primaryPart.CFrame, primaryPart.Size, overlapParams) > 0
        
        -- check if miner area has ores
        local oresOverlapParams = OverlapParams.new()
        oresOverlapParams.FilterType = Enum.RaycastFilterType.Include
        oresOverlapParams.FilterDescendantsInstances = {workspace:FindFirstChild('Ores')}
        local minerArea = model:FindFirstChild('MinerActiveArea')
        local oresInstances = workspace:GetPartsInPart(minerArea, oresOverlapParams)
        local minerAreaWithOres = #oresInstances > 0

        local canPlace = not primaryPartColliding and minerAreaWithOres
        local reason = ''
        if primaryPartColliding then
            reason = "Colliding with other objects."
        elseif not minerAreaWithOres then
            reason = "No ores in mining area."
        end
        
        return {
            canPlace = canPlace,
            reason = reason,
            data = oresInstances,
        }
    end
    
    return {
        canPlace = true,
        reason = ""
    }
end

function changeModelProperties(model: Model, props: {[string]: any})
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            for propertyName, value in pairs(props) do
                part[propertyName] = value
            end
        end
    end
end

local PlacementPointerController = {}
PlacementPointerController.__index = PlacementPointerController
function PlacementPointerController.new()
    local self = setmetatable({}, PlacementPointerController)
    self.instance = Instance.new('Part')
    self.instance.Size = Vector3.new(1,1,1)
    self.instance.Shape = Enum.PartType.Ball
    self.instance.Color = Color3.fromRGB(255, 255, 255)
    self.instance.Anchored = true
    self.instance.CanCollide = false
    self.instance.CanQuery = false
    self.instance.CanTouch = false

    self.mouse = Players.LocalPlayer:GetMouse()
    self.position = nil
    self.gridSnap = true
    return self
end

function PlacementPointerController:update()
    if self.gridSnap then
        self.position = snapToGrid(self.mouse.Hit.Position, gridSize)
    else
        self.position = self.mouse.Hit.Position
    end
    
    self.instance.Position = Vector3.new(self.position.X, 0, self.position.Z)
end

function PlacementPointerController:setMouseFilter(instance: Instance)
    self.mouse.TargetFilter = instance
end

function PlacementPointerController:enableGridSnap()
    self.gridSnap = true
end
function PlacementPointerController:disableGridSnap()
    self.gridSnap = false
end

function PlacementPointerController:enabled()
    self.instance.Parent = workspace
end

function PlacementPointerController:disabled()
    self.instance.Parent = nil
end

local placementPointer = PlacementPointerController.new()

local beltTool = BeltToolController.new(placementPointer)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mouse = Players.LocalPlayer:GetMouse()
        if not mouse.Target.Parent:IsA('Model') then
            return
        end
        local model = mouse.Target.Parent
        local entityId = model:GetAttribute("entityId")
        if not entityId then
            return
        end
        
        Signals.DeconstructFacility:Fire({
            entityId = entityId,
        })
    end
end)

function setupTool(tool: Tool)
    local character = Players.LocalPlayer.Character
    local humanoid: Humanoid = character:WaitForChild("Humanoid")

    local facilityName = tool:GetAttribute("facilityName")
    local unequipAfterBuild = tool:GetAttribute('unequipAfterBuild')
    local canDisableSnapping = tool:GetAttribute('canDisableSnapping')
    
    local hologram
    if facilityName ~= "Belt" then
        hologram = getFacilityModelByName(facilityName)
    else
        hologram = getFacilityModelByName('Assembler')
    end
    changeModelProperties(hologram, {
        Transparency = 0.8,
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(37, 110, 206),
        CanCollide = false
    })
    hologram.Name = "FacilityPlacementHologram"
    
    local indicatorCon = nil
    local rotationAction = nil
    local currentPlacementCFrame = nil

    local canPlace = false
    local reason = ""
    local data = nil
    
    local function onToolActivated()
        beltTool:activate()
        -- control modes of placement
        -- 1. multiple placements with mouse drag
        -- 2. multi click placements (belts, start click to start position and end click to end position)
	end

    local function onToolDeactivated()
        if facilityName == "Belt" then
            beltTool:deactivate()
        end
        
        if not canPlace then
            print('Not possible to place: ', reason)
            return
        end
        
        -- local facility = getFacilityModelByName(facilityName)
        -- facility:PivotTo(currentPlacementCFrame)
        -- facility.Parent = workspace
        
        if facilityName == "Miner" then
            local oreEntities = {}
            for _, orePart in pairs(data) do
                local entityId = orePart:GetAttribute('entityId')
                if entityId then
                    table.insert(oreEntities, entityId)
                end
            end

            local payload = {
                facilityName = facilityName,
                cframe = currentPlacementCFrame,
                oreEntities = oreEntities,
            }
            Signals.BuildFacility:Fire(payload)
            
            -- local minerId = world:spawn(
            --     Components.Miner({
            --         oreNodes = oresEntities,
            --         oreNodesCount = #oresEntities,
            --         speedPerNode = 30, -- 30 per min per node 30/60 = 1/2 per sec
            --     }),
            --     Components.MinerState_Mining({
            --         startMiningTime = os.clock(),
            --     }),
            --     Components.Transform({
            --         cframe = currentPlacementCFrame,
            --         isStatic = true,
            --     }),
            --     Components.Storage({
            --         capacity = 100000000,
            --         currentAmount = 0,
            --     })
            -- )
            -- for _, oreEntityId in ipairs(oresEntities) do
            --     local oreNode = world:get(oreEntityId, Components.OreNode)
            --     world:insert(oreEntityId, oreNode:patch({
            --         minersConnected = Insert(oreNode.minersConnected, minerId),
            --     }))
            -- end
        elseif facilityName == 'Smelter' then
            for _=1,1 do
                world:spawn(
                    Components.ProductionFacility({
                        facilityType = "Smelter", -- used to identify compatible recipes
                        progress = 0,
                        speed = 0.75, -- 0.75 of normal speed (a recipe that takes 4s will take 5.33s)
                        state = "idle", -- idle, producing, no_recipe, lack_material, product_overflow
                        recipe = {
                            name = 'Iron Plate',
                            processingTime = 1,
                            requirements = {
                                ['iron-ore'] = 1
                            },
                            outputs = {
                                ['iron-plate'] = 1
                            },
                        },
                        outputSlots = {
                            ['iron-plate'] = {
                                quantity = 0,
                                capacity = 100,
                            }
                        },
                        inputSlots = {
                            ['iron-ore'] = {
                                quantity = 10,
                                capacity = 100,
                            }
                        }
                    })
                )
            end 
        end


        if unequipAfterBuild then
            humanoid:UnequipTools()
        end
    end

    local function onToolEquiped()
        placementPointer:enabled()
        placementPointer:setMouseFilter(hologram)
        
        if facilityName == "Belt" then
            beltTool:equiped()
        end
        
        renderGridLines(2, 300, Vector3.zero)
        hologram.Parent = workspace
        pointer.Parent = workspace
        
        local rotateInputToProcess = false
        rotationAction = UserInputService.InputBegan:Connect(function (input: InputObject)
            if input.KeyCode == Enum.KeyCode.R then
                rotateInputToProcess = true
            end
        end)

        indicatorCon = RunService.Heartbeat:Connect(function (dt)
            placementPointer:update()
            
            if facilityName == "Belt" then
                beltTool:update(dt)
                return
            end

            if canDisableSnapping and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                placementPointer:disableGridSnap()
            else
                placementPointer:enableGridSnap()
            end

            local position = placementPointer.position

            local result = validateFacilityPlacement(hologram, facilityName)
            if not result.canPlace then
                changeModelProperties(hologram, {
                    Color = Color3.fromRGB(255, 0, 0)
                })
            else
                changeModelProperties(hologram, {
                    Color = Color3.fromRGB(37, 110, 206)
                })
            end
            data = result.data
            
            canPlace = result.canPlace
            reason = result.reason
            
            canPlace = result.canPlace
            hologram:PivotTo(CFrame.new(position) * hologram:GetPivot().Rotation)
            
            if canDisableSnapping and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and UserInputService:IsKeyDown(Enum.KeyCode.R) then
                hologram:PivotTo(hologram:GetPivot() * CFrame.Angles(0, math.rad(-90) * 2 * dt, 0))
                rotateInputToProcess = false
            elseif rotateInputToProcess then
                hologram:PivotTo(hologram:GetPivot() * CFrame.Angles(0, math.rad(-90), 0))
                rotateInputToProcess = false
            end
            
            currentPlacementCFrame = hologram:GetPivot()
        end)
    end

    local function onToolUnequiped()
        hideGrid()
        
        if facilityName == "Belt" then
            beltTool:unequiped()
        end
        
        placementPointer:disabled()
        
        indicatorCon:Disconnect()
        rotationAction:Disconnect()
        hologram.Parent = nil
        pointer.Parent = nil
    end
    
    tool.Equipped:Connect(onToolEquiped)
    tool.Unequipped:Connect(onToolUnequiped)
	tool.Activated:Connect(onToolActivated)
    tool.Deactivated:Connect(onToolDeactivated)
end

local player = Players.LocalPlayer

function onCharacterAdded()
    for _, tool in pairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name ~= 'Delete' then
            setupTool(tool)
        end
    end
end

if not player.Character then
    player.CharacterAdded:Connect(onCharacterAdded)
else
    onCharacterAdded()
end

print('generating ore patches...')
orePatchGenerator.generateAll(world)