local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local BeltItemsMovement = require(script.Parent.BeltItemsMovement)
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

	-- 1. check for available ore nodes
	-- how to choose which ore node to mine from?
	-- option 1: random: not predictable but simple
	-- option 2: selected a ore node index and advance to next index each time: predictable and fair distribution among ore nodes
	-- validate if a ore node is available and has quantity > 0, update the oreNodes list id necessary (removing depleted nodes)

	-- a. if no ore nodes available then
	-- i. update miner state to NodesDepleted
	-- ii. remove Mining component
	-- iii. return
	-- 2. extract ore from ore node and commit changes to world soo other miners can see the updated quantity
	-- 3. add ore to miner storage
	-- a. after adding ore to storage check if storage is full
	-- i. if full then update miner state to ProductOverflow and remove Mining component
	-- ii. else restart mining process by updating startMiningTime

	-- considera que o oreNodeIndex é valido e que o ore node tem minério disponível, necessário determinar antes qual index usar

	-- Plano para estrutura com threads
	-- como distribuir a atualização dos miner entre aas threads?
	-- cada thread processa uma parte dos miners (preciso então saber quantos miners existem no total e dividir igualmente entre as threads)
	-- cada thread itera sobre sua parte dos miners e processa o mining logic
	-- quando uma thread termina, ela sinaliza que terminou
	-- quantos todas as threads terminarem, o update do sistema de miners está completo para esse frame

	-- tenho que ter acesso ao world compartilhado entre as threads? as thread precisam ler o estado do world para processar os miners
	-- e também precisam escrever as mudanças no world (quantidade de minério nos ore nodes, além das alterações no miner e storage)
	-- como garantir que as threads não vão causar condições de corrida ao acessar o world?

	for id, miner: Types.Miner, storage: Types.Storage in world:query(Components.Miner, Components.Storage) do
		if miner.outputBelt ~= nil and storage.currentAmount > 0 then
			local beltItems: Types.BeltItemComponent = world:get(miner.outputBelt, Components.BeltItems)
			local beltPath: Types.BeltPath = world:get(miner.outputBelt, Components.BeltPath)

			-- try to pass item to belt
			local beltLength = #beltPath.nodes * BeltSettings.BeltSubdiv
			if
				#beltItems.items == 0
				or beltLength - beltItems.items[#beltItems.items].pos >= BeltSettings.ItemOcupancy
			then
				table.insert(
					beltItems.items,
					{
						pos = beltLength,
						item = "iron_ore",
						mesh = Helpers.createItemMesh("iron_ore"),
					} :: Types.BeltItem
				)
				storage.currentAmount -= 1
			end
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
