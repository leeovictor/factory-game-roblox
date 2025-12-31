local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)

local function UpdateModelTransformsSystem(world)
	for id, transform, model in
		world:query(Components.Transform, Components.Model):without(Components.StaticTransformUpdated)
	do
		if model.instance:GetPivot() ~= transform.cframe then
			model.instance:PivotTo(transform.cframe)
			if transform.isStatic then -- mark static transforms as updated so we don't update them again
				world:insert(id, Components.StaticTransformUpdated())
			end
		end
	end

	for id, record in world:queryChanged(Components.Model) do
		if record.old == nil and record.new ~= nil and record.new.instance:GetAttribute("entityId") == nil then
			record.new.instance:SetAttribute("entityId", id)
		end
	end
end

return {
	system = UpdateModelTransformsSystem,
	event = "FixedUpdate",
	priority = math.huge,
}
