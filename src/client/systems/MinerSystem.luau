local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltHelpers = require(ReplicatedStorage.Shared.BeltHelpers)
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local OreDepletedRemoveSystem = require(script.Parent.OreDepletedRemoveSystem)
local Components = require(ReplicatedStorage.Shared.Components)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local TableUtils = require(ReplicatedStorage.Shared.TableUtils)
local Types = require(ReplicatedStorage.Shared.Types)

local function MinerSystem(world)
	for id in world:query(Components.Miner):without(Components.Model) do
		local model = ReplicatedStorage.Models.Facilities.Miner:Clone()
		Helpers.setCollisionGroupModelParts(model, CollisionGroups.Buildings, { excludeParts = { "MinerActiveArea" } })

		world:insert(
			id,
			Components.Model({
				instance = model,
			})
		)
	end

	for _id, miner: Types.Miner, storage: Types.Storage in world:query(Components.Miner, Components.Storage) do
		-- tenta empurrar item para a esteira de saída
		if
			miner.outputBelt ~= nil
			and storage.currentAmount > 0
			and BeltHelpers.tryInsertItemAtStartOfBelt(world, miner.outputBelt, miner.oreType)
		then
			storage.currentAmount -= 1
		end

		if miner.state == "ProductOverflow" then
			if storage.currentAmount < storage.capacity then
				miner.state = "Mining"
				miner.startMiningTime = os.clock()
			end
			continue
		end

		if miner.oreNodesCount == 0 then
			miner.state = "NodesDepleted"
			continue
		end

		local miningTime = (1 / ((miner.speedPerNode * miner.oreNodesCount) / 60))
		local currentMiningProgress = miner.miningProgress + world.FixedDeltaTime
		miner.miningProgress = currentMiningProgress

		if currentMiningProgress >= miningTime then
			local overshot = currentMiningProgress - miningTime
			miner.miningProgress = overshot

			-- TODO: otimizar isso para não precisar interar toda vez que minerar
			-- usar indice circular que avança a cada mineração (se o indice é um ore node esgotado, pular para o próximo)
			-- o caso de encontrar um ore esgotado quer dizer que um miner anterior esgostou ele, mas a remoção ainda não foi processada
			-- pelo OreDepletedRemoveSystem, isso significa que as vezes o miner pode ter que pular o ore até encontrar um com minério disponível
			-- se não encontrar nenhum, então o miner deve mudar para o estado NodesDepleted, pois o processo atual de mineração não é possível
			-- e deve ser cancelada
			local filteredOreNodes = TableUtils.Filter(miner.oreNodes, function(nodeId)
				local oreNode = world:get(nodeId, Components.OreNode)
				return oreNode and oreNode.quantity > 0
			end)
			if #filteredOreNodes == 0 then
				miner.state = "NodesDepleted"
				continue
			end

			local oreNodeId = filteredOreNodes[math.random(1, #filteredOreNodes)]
			local oreNode = world:get(oreNodeId, Components.OreNode)

			oreNode.quantity -= 1
			if oreNode.quantity <= 0 then
				world:insert(oreNodeId, Components.OreNodeDepleted())
			end

			storage.currentAmount += 1

			if storage.currentAmount >= storage.capacity then
				miner.state = "ProductOverflow"
				continue
			end
		end
	end
end

return {
	system = MinerSystem,
	event = "FixedUpdate",
	after = { OreDepletedRemoveSystem },
}
