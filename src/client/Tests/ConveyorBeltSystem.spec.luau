local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Matter)
local Components = require(ReplicatedStorage.Shared.Components)
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local ConveyorBeltSystem = require(script.Parent.Parent.systems.ConveyorBeltSytem)

local function createMockItem(pos)
	return { item = "iron_ore", pos = pos }
end

return function()
	describe("ConveyorBeltSystem", function()
		local world

		beforeEach(function()
			world = Matter.World.new()
			world.FixedDeltaTime = 1 / 60
		end)

		afterEach(function()
			world:clear()
		end)

		describe("Item Movement", function()
			it("should move single item on belt with sufficient space ahead", function()
				local beltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = 1,
					}),
					Components.BeltItems({
						items = {
							createMockItem(80),
							createMockItem(60),
						},
						version = 0,
					})
				)
				world:commitCommands()

				ConveyorBeltSystem.system(world)

				local beltItems = world:get(beltId, Components.BeltItems)
				expect(beltItems.items[1].pos).to.equal(79)
			end)

			it("should move multiple items with spacing greater than ItemOcupancy", function()
				local beltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {
							{ item = "iron_ore", pos = 80 },
							{ item = "copper_ore", pos = 120 },
						},
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				local beltItems = world:get(beltId, Components.BeltItems)
				expect(beltItems.items[1].pos).to.equal(76) -- Both should move
				expect(beltItems.items[2].pos).to.equal(116)
			end)

			it("should NOT move item when spacing equals ItemOcupancy", function()
				local beltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {
							{ item = "iron_ore", pos = 40 },
							{ item = "copper_ore", pos = 80 }, -- Exactly ItemOcupancy (40) away
						},
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				local beltItems = world:get(beltId, Components.BeltItems)
				expect(beltItems.items[1].pos).to.equal(40) -- First does NOT move (pos - 0 = 40, not > 40)
				expect(beltItems.items[2].pos).to.equal(80) -- Second does NOT move (spacing = ItemOcupancy)
			end)

			it("should handle first item on belt (no previous item)", function()
				local beltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = 80 } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				local beltItems = world:get(beltId, Components.BeltItems)
				expect(beltItems.items[1].pos).to.equal(76)
			end)
		end)

		describe("Item Transfer", function()
			it("should transfer item to empty target belt", function()
				-- Setup target belt node
				local targetBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 201, 202 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {},
						version = 0,
					})
				)

				local targetNodeId = 201
				world:spawnAt(
					targetNodeId,
					Components.BeltNode({
						beltPath = targetBeltId,
						nodeIndex = 1,
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 1,
						direction = "top",
					})
				)

				-- Setup source belt with output connection
				local sourceBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = targetNodeId,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				-- Item should be removed from source
				local sourceBeltItems = world:get(sourceBeltId, Components.BeltItems)
				expect(#sourceBeltItems.items).to.equal(0)

				-- Item should appear in target
				local targetBeltItems = world:get(targetBeltId, Components.BeltItems)
				expect(#targetBeltItems.items).to.equal(1)
				expect(targetBeltItems.items[1].item).to.equal("iron_ore")
			end)

			it("should NOT transfer when item not at transfer position", function()
				local targetBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 201, 202 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {},
						version = 0,
					})
				)

				local targetNodeId = 201
				world:spawnAt(
					targetNodeId,
					Components.BeltNode({
						beltPath = targetBeltId,
						nodeIndex = 1,
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 1,
						direction = "top",
					})
				)

				local sourceBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = targetNodeId,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = 50 } }, -- Not at ItemOcupancy
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				-- Item should still be in source
				local sourceBeltItems = world:get(sourceBeltId, Components.BeltItems)
				expect(#sourceBeltItems.items).to.equal(1)

				-- Target should remain empty
				local targetBeltItems = world:get(targetBeltId, Components.BeltItems)
				expect(#targetBeltItems.items).to.equal(0)
			end)

			it("should NOT transfer when belt has no output connection", function()
				local sourceBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = nil, -- No connection
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				-- Item should remain in source
				local sourceBeltItems = world:get(sourceBeltId, Components.BeltItems)
				expect(#sourceBeltItems.items).to.equal(1)
			end)

			it("should NOT transfer when target belt has no space", function()
				local targetBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 201, 202 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {
							-- Item blocking the insertion point
							{ item = "copper_ore", pos = 60 },
						},
						version = 0,
					})
				)

				local targetNodeId = 201
				world:spawnAt(
					targetNodeId,
					Components.BeltNode({
						beltPath = targetBeltId,
						nodeIndex = 1,
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 1,
						direction = "top",
					})
				)

				local sourceBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = targetNodeId,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				-- Item should remain in source
				local sourceBeltItems = world:get(sourceBeltId, Components.BeltItems)
				expect(#sourceBeltItems.items).to.equal(1)

				-- Target should still have only one item
				local targetBeltItems = world:get(targetBeltId, Components.BeltItems)
				expect(#targetBeltItems.items).to.equal(1)
				expect(targetBeltItems.items[1].item).to.equal("copper_ore")
			end)

			it("should transfer item to target belt with existing items when space available", function()
				local targetBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 201, 202 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {
							-- Item far enough to allow insertion (pos 10 gives >40 space to pos 60)
							{ item = "copper_ore", pos = 10 },
						},
						version = 0,
					})
				)

				local targetNodeId = 201
				world:spawnAt(
					targetNodeId,
					Components.BeltNode({
						beltPath = targetBeltId,
						nodeIndex = 1,
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 1,
						direction = "top",
					})
				)

				local sourceBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = targetNodeId,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				-- Item should be removed from source
				local sourceBeltItems = world:get(sourceBeltId, Components.BeltItems)
				expect(#sourceBeltItems.items).to.equal(0)

				-- Target should have both items
				local targetBeltItems = world:get(targetBeltId, Components.BeltItems)
				expect(#targetBeltItems.items).to.equal(2)
			end)
		end)

		describe("Insertion Position Calculation", function()
			it("should calculate correct insertion position for single-node belt", function()
				local targetBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 201 }, -- Single node
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {},
						version = 0,
					})
				)

				local targetNodeId = 201
				world:spawnAt(
					targetNodeId,
					Components.BeltNode({
						beltPath = targetBeltId,
						nodeIndex = 1,
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 1,
						direction = "top",
					})
				)

				local sourceBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = targetNodeId,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				local targetBeltItems = world:get(targetBeltId, Components.BeltItems)
				-- Formula: (beltLength - nodeIndex * BeltSubdiv) + BeltSubdiv / 2
				-- = (1 * 40 - 1 * 40) + 40 / 2 = 0 + 20 = 20
				expect(targetBeltItems.items[1].pos).to.equal(20)
			end)

			it("should calculate correct insertion position for multi-node belt at first node", function()
				local targetBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 201, 202, 203 }, -- 3 nodes
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {},
						version = 0,
					})
				)

				local targetNodeId = 201
				world:spawnAt(
					targetNodeId,
					Components.BeltNode({
						beltPath = targetBeltId,
						nodeIndex = 1,
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 1,
						direction = "top",
					})
				)

				local sourceBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = targetNodeId,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				local targetBeltItems = world:get(targetBeltId, Components.BeltItems)
				-- Formula: (beltLength - nodeIndex * BeltSubdiv) + BeltSubdiv / 2
				-- = (3 * 40 - 1 * 40) + 40 / 2 = 80 + 20 = 100
				expect(targetBeltItems.items[1].pos).to.equal(100)
			end)

			it("should calculate correct insertion position for middle node", function()
				local targetBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 201, 202, 203 }, -- 3 nodes
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {},
						version = 0,
					})
				)

				local targetNodeId = 202
				world:spawnAt(
					targetNodeId,
					Components.BeltNode({
						beltPath = targetBeltId,
						nodeIndex = 2, -- Middle node
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 2,
						direction = "top",
					})
				)

				local sourceBeltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = targetNodeId,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				local targetBeltItems = world:get(targetBeltId, Components.BeltItems)
				-- Formula: (beltLength - nodeIndex * BeltSubdiv) + BeltSubdiv / 2
				-- = (3 * 40 - 2 * 40) + 40 / 2 = 40 + 20 = 60
				expect(targetBeltItems.items[1].pos).to.equal(60)
			end)
		end)

		describe("Edge Cases", function()
			it("should skip processing belt with no items", function()
				local beltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {}, -- Empty
						version = 0,
					})
				)

				-- Should not error
				ConveyorBeltSystem.system(world)

				local beltItems = world:get(beltId, Components.BeltItems)
				expect(#beltItems.items).to.equal(0)
			end)

			it("should handle multiple belts simultaneously", function()
				local belt1 = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = 80 } },
						version = 0,
					})
				)

				local belt2 = world:spawn(
					Components.BeltPath({
						nodes = { 200, 201 },
						speed = BeltSettings.BeltSpeeds.Fast,
					}),
					Components.BeltItems({
						items = { { item = "copper_ore", pos = 100 } },
						version = 0,
					})
				)

				ConveyorBeltSystem.system(world)

				local belt1Items = world:get(belt1, Components.BeltItems)
				local belt2Items = world:get(belt2, Components.BeltItems)

				expect(belt1Items.items[1].pos).to.equal(76) -- Moved by Slow speed
				expect(belt2Items.items[1].pos).to.equal(80) -- Moved by Fast speed
			end)

			it("should handle belt chain transfers (A -> B -> C)", function()
				-- Belt C (end of chain)
				local beltC = world:spawn(
					Components.BeltPath({
						nodes = { 301, 302 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = {},
						version = 0,
					})
				)

				local nodeCId = 301
				world:spawnAt(
					nodeCId,
					Components.BeltNode({
						beltPath = beltC,
						nodeIndex = 1,
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 1,
						direction = "top",
					})
				)

				-- Belt B (middle)
				local beltB = world:spawn(
					Components.BeltPath({
						nodes = { 201, 202 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = nodeCId,
					}),
					Components.BeltItems({
						items = { { item = "copper_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				local nodeBId = 201
				world:spawnAt(
					nodeBId,
					Components.BeltNode({
						beltPath = beltB,
						nodeIndex = 1,
						pos = Vector3.new(0, 0, 0),
						dirVector = Vector3.new(1, 0, 0),
						cframe = CFrame.new(0, 0, 0),
						index = 1,
						direction = "top",
					})
				)

				-- Belt A (start)
				local beltA = world:spawn(
					Components.BeltPath({
						nodes = { 101, 102 },
						speed = BeltSettings.BeltSpeeds.Slow,
						beltNodeOutput = nodeBId,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = BeltSettings.ItemOcupancy } },
						version = 0,
					})
				)

				-- First tick: A -> B, B -> C
				ConveyorBeltSystem.system(world)

				local beltAItems = world:get(beltA, Components.BeltItems)
				local beltBItems = world:get(beltB, Components.BeltItems)
				local beltCItems = world:get(beltC, Components.BeltItems)

				expect(#beltAItems.items).to.equal(0) -- Transferred to B
				expect(#beltBItems.items).to.equal(1) -- Received from A (copper transferred to C)
				expect(#beltCItems.items).to.equal(1) -- Received from B
				expect(beltCItems.items[1].item).to.equal("copper_ore")
			end)

			it("should mutate BeltItems components in-place", function()
				local beltId = world:spawn(
					Components.BeltPath({
						nodes = { 100, 101 },
						speed = BeltSettings.BeltSpeeds.Slow,
					}),
					Components.BeltItems({
						items = { { item = "iron_ore", pos = 80 } },
						version = 0,
					})
				)

				local beltItemsBefore = world:get(beltId, Components.BeltItems)
				local initialPos = beltItemsBefore.items[1].pos

				ConveyorBeltSystem.system(world)

				local beltItemsAfter = world:get(beltId, Components.BeltItems)

				-- Should be same component instance (mutated in-place)
				expect(beltItemsAfter.items[1].pos).to.never.equal(initialPos)
				expect(beltItemsAfter.items[1].pos).to.equal(76)
			end)
		end)
	end)
end
