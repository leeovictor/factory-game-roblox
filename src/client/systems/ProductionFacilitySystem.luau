local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConstructionSystem = require(script.Parent.ConstructionSystem)
local OreDepletedRemoveSystem = require(script.Parent.OreDepletedRemoveSystem)
local RemoveModelsSytem = require(script.Parent.RemoveModelsSytem)
local matter = require(ReplicatedStorage.Packages.matter)
local Components = require(ReplicatedStorage.Shared.Components)

local function ProductionFacility(world)
    for id, facility in world:query(Components.ProductionFacility) do
        if facility.state == 'idle' then
            if facility.recipe ~= nil then
                -- check for input components requirements
                local metRequirements = true
                for item, reqAmount in pairs(facility.recipe.requirements) do
                    assert(facility.inputSlots[item], "Input slot for item "..item.." not found in facility ".. tostring(id))
                    if facility.inputSlots[item].quantity < reqAmount then
                        metRequirements = false
                        break
                    end
                end
                
                if not metRequirements then
                    world:insert(id, facility:patch({
                        state = 'lack_material',
                    }))
                    continue
                end
                
                -- requirements met, consume input components and start producing
                local updatedInputSlots = {}
                for item, slot in pairs(facility.inputSlots) do
                    local reqAmount = facility.recipe.requirements[item] or 0
                    updatedInputSlots[item] = {
                        quantity = slot.quantity - reqAmount,
                        capacity = slot.capacity,
                    }
                end
                world:insert(id, facility:patch({
                    state = 'producing',
                    inputSlots = updatedInputSlots,
                    progress = 0,
                    startProductingTime = os.clock(),
                }))
                continue
            end
            
            continue
        end

        if facility.state == 'lack_material' then
            local metRequirements = true
            for item, reqAmount in pairs(facility.recipe.requirements) do
                if facility.inputSlots[item].quantity < reqAmount then
                    metRequirements = false
                    break
                end
            end

            if not metRequirements then
                continue
            end
            
            -- requirements met, consume input components and start producing
            local updatedInputSlots = {}
            for item, slot in pairs(facility.inputSlots) do
                local reqAmount = facility.recipe.requirements[item] or 0
                updatedInputSlots[item] = {
                    quantity = slot.quantity - reqAmount,
                    capacity = slot.capacity,
                }
            end
            world:insert(id, facility:patch({
                state = 'producing',
                inputSlots = updatedInputSlots,
                progress = 0,
                startProductingTime = os.clock(),
            }))
            continue
        end
        
        if facility.state == 'producing' then
            -- facility = facility:patch({
            --     progress = facility.progress + facility.speed * matter.useDeltaTime(),
            -- })
            
            if os.clock() - facility.startProductingTime >= (facility.recipe.processingTime / facility.speed) then
                local overshot = os.clock() - facility.startProductingTime - (facility.recipe.processingTime / facility.speed)
                local updatedOutputSlots = facility.outputSlots
                for item, amount in pairs(facility.recipe.outputs) do
                    updatedOutputSlots[item] = {
                        quantity = facility.outputSlots[item].quantity + amount,
                        capacity = facility.outputSlots[item].capacity,
                    }
                end
                
                facility = facility:patch({
                    outputSlots = updatedOutputSlots,
                })
                
                local metRequirements = true
                for item, reqAmount in pairs(facility.recipe.requirements) do
                    if facility.inputSlots[item].quantity < reqAmount then
                        metRequirements = false
                        break
                    end
                end

                if not metRequirements then
                    facility = facility:patch({
                        state = 'lack_material',
                        startProductingTime = matter.None
                    })
                else
                    -- requirements met, consume input components and start producing
                    local updatedInputSlots = {}
                    for item, slot in pairs(facility.inputSlots) do
                        local reqAmount = facility.recipe.requirements[item] or 0
                        updatedInputSlots[item] = {
                            quantity = slot.quantity - reqAmount,
                            capacity = slot.capacity,
                        }
                    end
                    world:insert(id, facility:patch({
                        inputSlots = updatedInputSlots,
                        startProductingTime = os.clock() - overshot,
                    }))
                    continue
                end    
                
                world:insert(id, facility)
            end
            continue
        end
         
        if facility.state == 'product_overflow' then
            print('TODO: handle product_overflow state for production facility ', id)
            continue
        end
    end
end

return {
    system = ProductionFacility,
    event = 'FixedUpdate',
    after = { OreDepletedRemoveSystem, RemoveModelsSytem, ConstructionSystem }
}