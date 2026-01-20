local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local ItemSpecs = require(ReplicatedStorage.Shared.ItemSpecs)
local ObjectPool = require(ReplicatedStorage.Shared.ObjectPool)
local Types = require(ReplicatedStorage.Shared.Types)

local MeshesPools: { [Types.ItemKey]: ObjectPool.ObjectPool } = {}

for itemKey, _spec in pairs(ItemSpecs.ByKey) do
	MeshesPools[itemKey] = ObjectPool.new(function()
		return Helpers.createItemMesh(itemKey)
	end)
end

local function _printPoolSizes()
	for itemKey, pool in pairs(MeshesPools) do
		print("Pool for item:", itemKey, "size:", pool:GetSize())
	end
end

local function ItemsMeshesSync(world: Types.World)
	-- Sync added/removed meshes
	for id, changes: Types.MeshesChanges, meshes: Types.ItemsMeshes in
		world:query(Components.MeshesChanges, Components.ItemsMeshes)
	do
		for _, item in ipairs(changes.added or {}) do
			local pool = MeshesPools[item.item]
			assert(pool ~= nil, "No mesh pool for item: " .. item.item)

			local mesh = pool:Acquire()
			mesh.Parent = workspace
			meshes[item] = mesh
		end

		for _, item in ipairs(changes.removed or {}) do
			local pool = MeshesPools[item.item]
			assert(pool ~= nil, "No mesh pool for item: " .. item.item)

			if meshes[item] ~= nil then
				meshes[item].Parent = nil
				pool:Release(meshes[item])
				meshes[item] = nil
			end
		end

		for _, item in ipairs(changes.transferred or {}) do
			local mesh = meshes[item.item]
			if not mesh then
				error("No mesh found for transferred item: " .. item.item)
			end

			local meshesAnotherBelt: Types.ItemsMeshes = world:get(item.to, Components.ItemsMeshes)
			if not meshesAnotherBelt then -- não é possível transferir para um esteira que não tem o componente ItemsMeshes -- fazer release do mesh
				local pool = MeshesPools[item.item.item]
				assert(pool ~= nil, "No mesh pool for item: " .. item.item)

				if meshes[item.item] ~= nil then
					meshes[item.item].Parent = nil
					pool:Release(meshes[item.item])
					meshes[item.item] = nil
					continue
				end
			end

			meshesAnotherBelt[item.item] = mesh
			meshes[item.item] = nil
		end

		world:remove(id, Components.MeshesChanges)
	end

	-- Cleanup meshes when ItemsMeshes component is removed
	for _id, record in world:queryChanged(Components.ItemsMeshes) do
		if record.old == nil and record.new ~= nil then
			-- TODO: check se tem itens para criar os meshes aqui (talvez a feature de culling use isso aqui para controlar as esteiras que estão sendo renderizadas)
		end

		if record.old ~= nil and record.new == nil then
			local meshes: Types.ItemsMeshes = record.old
			for item, mesh in pairs(meshes) do
				MeshesPools[item.item]:Release(mesh)
				mesh.Parent = nil
			end
		end
	end

	-- _printPoolSizes()
end

return {
	system = ItemsMeshesSync,
	event = "FixedUpdate",
	priority = 1000,
}
