local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)
local ObjectPool = require(ReplicatedStorage.Shared.ObjectPool)

local function createBasePoint()
    local part = Instance.new("Part")
    part.Size = Vector3.new(1, 1, 1)
    part.Shape = Enum.PartType.Ball
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    return part
end

local PathPointsPool = ObjectPool.new(createBasePoint, 100)

local function PathPreviewRenderer(world)
    -- release removed path preview instances
    for _, record in world:queryChanged(Components.PathPreviewInstances) do
        if record.new == nil then
            for _, instance in ipairs(record.old.instances) do
                instance.Parent = nil
                PathPointsPool:Release(instance)
            end
        end
    end

    for id, pathPreview in world:query(Components.PathPreview):without(Components.PathPreviewInstances) do
        local instances = {}
        for _ in ipairs(pathPreview.points) do
            local instance = PathPointsPool:Acquire()
            instance.Parent = workspace
            table.insert(instances, instance)
        end
        world:insert(id, Components.PathPreviewInstances({
            instances = instances,
        }))
        world:commitCommands()
    end

    -- update path preview instances
    for _id, pathPreview, pathInstances in world:query(Components.PathPreview, Components.PathPreviewInstances) do
        if #pathInstances.instances ~= #pathPreview.points then
            if #pathInstances.instances < #pathPreview.points then
                for _i = #pathInstances.instances + 1, #pathPreview.points do
                    local instance = PathPointsPool:Acquire()
                    instance.Parent = workspace
                    table.insert(pathInstances.instances, instance)
                end
            else
                for _i = #pathPreview.points + 1, #pathInstances.instances do
                    local instance = table.remove(pathInstances.instances)
                    instance.Parent = nil
                    PathPointsPool:Release(instance)
                end
            end
        end
        
        for pointIndex, point in ipairs(pathPreview.points) do
            if point ~= pathInstances.instances[pointIndex].Position then
                pathInstances.instances[pointIndex].Position = point
            end
            
            if pathPreview.color and pathInstances.instances[pointIndex].BrickColor ~= pathPreview.color then
                pathInstances.instances[pointIndex].BrickColor = pathPreview.color
            end

            if pathPreview.pointSize and pathInstances.instances[pointIndex].Size ~= pathPreview.pointSize then
                pathInstances.instances[pointIndex].Size = pathPreview.pointSize
            end
        end
    end
end

return {
    system = PathPreviewRenderer,
    priority = math.huge,
}