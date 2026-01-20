local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Matter)
local BeltHelpers = require(ReplicatedStorage.Shared.BeltHelpers)
local Components = require(ReplicatedStorage.Shared.Components)
local Types = require(ReplicatedStorage.Shared.Types)
local ConveyorBeltSystemV2 = require(script.Parent.Parent.systems.ConveyorBeltUpdateV2)

local function createItem(distFromNext: number): Types.BeltItemV2
	return {
		item = "TestItem",
		distFromNext = distFromNext,
	}
end

local function runTimes(callback: () -> (), n: number)
	for _ = 1, n do
		callback()
	end
end

local function createBeltSegComp(data: {
	distToInsertAtStart: number,
	speed: number,
	nextSeg: Types.EntityId?,
	prevSeg: Types.EntityId?,
	nodes: { Types.EntityId }?,
}): Types.BeltSegment
	return Components.BeltSegment({
		distToInsertAtStart = data.distToInsertAtStart,
		nodes = data.nodes or {},
		speed = data.speed,
		prevSeg = data.prevSeg,
		nextSeg = data.nextSeg,
	} :: Types.BeltSegment)
end

local function createBeltItemsComp(data: { positions: { number } }): Types.BeltItemsV2
	local items: { Types.BeltItemV2 } = {}
	for _, p in ipairs(data.positions) do
		table.insert(items, createItem(p))
	end
	return Components.BeltItemsV2({
		items = items,
	})
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

		it(
			"should decrement the first item if it has not reached the end of the belt and update the distToInsertAtStart accordingly",
			function()
				local beltId = world:spawn(
					createBeltSegComp({ distToInsertAtStart = 0, speed = 1 }),
					createBeltItemsComp({ positions = { 100, 50, 200 } })
				)

				ConveyorBeltSystemV2.system(world)

				local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)
				local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)

				expect(beltItems.items[1].distFromNext).to.be.equal(99)
				expect(beltItems.items[2].distFromNext).to.be.equal(50)
				expect(beltItems.items[3].distFromNext).to.be.equal(200)

				expect(beltSeg.distToInsertAtStart).to.be.equal(1)
			end
		)

		it(
			"should increment the last item if it has not reached the end of the belt and update the distToInsertAtStart accordingly",
			function()
				local beltId = world:spawn(
					createBeltSegComp({ distToInsertAtStart = 0, speed = 1 }),
					createBeltItemsComp({ positions = { 40, 40, 200 } })
				)

				ConveyorBeltSystemV2.system(world)

				local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)
				local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)

				expect(beltItems.items[1].distFromNext).to.be.equal(40)
				expect(beltItems.items[2].distFromNext).to.be.equal(40)
				expect(beltItems.items[3].distFromNext).to.be.equal(199)

				expect(beltSeg.distToInsertAtStart).to.be.equal(1)
			end
		)

		it("should move the first item if there a nextBelt connected and has space available", function()
			local nextBeltId = world:spawn()
			local beltId = world:spawn()
			world:insert(
				nextBeltId,
				createBeltSegComp({ distToInsertAtStart = 0, speed = 1, prevSeg = beltId }),
				createBeltItemsComp({ positions = { 100 } })
			)
			world:insert(
				beltId,
				createBeltSegComp({ distToInsertAtStart = 0, speed = 1, nextSeg = nextBeltId }),
				createBeltItemsComp({ positions = { 40, 40 } })
			)

			ConveyorBeltSystemV2.system(world)

			local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)
			local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)

			local nextBeltSeg: Types.BeltSegment = world:get(nextBeltId, Components.BeltSegment)
			local nextBeltItems: Types.BeltItemsV2 = world:get(nextBeltId, Components.BeltItemsV2)

			-- nextseg update
			expect(nextBeltSeg.distToInsertAtStart).to.be.equal(1)
			expect(nextBeltItems.items[1].distFromNext).to.be.equal(99)

			-- current seg update
			expect(beltItems.items[1].distFromNext).to.be.equal(39)
			expect(beltItems.items[2].distFromNext).to.be.equal(40)
			expect(beltSeg.distToInsertAtStart).to.be.equal(1)
		end)

		it("should not move the first item if there not space available in the next belt", function()
			local nextBeltId = world:spawn()
			local beltId = world:spawn()
			world:insert(
				nextBeltId,
				createBeltSegComp({ distToInsertAtStart = 2, speed = 1, prevSeg = beltId }),
				createBeltItemsComp({ positions = { 40 } })
			)
			world:insert(
				beltId,
				createBeltSegComp({ distToInsertAtStart = 0, speed = 1, nextSeg = nextBeltId }),
				createBeltItemsComp({ positions = { 38, 40 } })
			)

			runTimes(function()
				ConveyorBeltSystemV2.system(world)
			end, 50)

			local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)
			local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)

			local nextBeltSeg: Types.BeltSegment = world:get(nextBeltId, Components.BeltSegment)
			local nextBeltItems: Types.BeltItemsV2 = world:get(nextBeltId, Components.BeltItemsV2)

			-- nextseg update
			expect(nextBeltSeg.distToInsertAtStart).to.be.equal(2)
			expect(nextBeltItems.items[1].distFromNext).to.be.equal(40)

			-- current seg update
			expect(beltItems.items[1].distFromNext).to.be.equal(38)
			expect(beltItems.items[2].distFromNext).to.be.equal(40)

			expect(beltSeg.distToInsertAtStart).to.be.equal(0)
		end)

		it("should transfer first item if distFromNext reach 0 and was space on the next belt", function()
			local nextBeltId = world:spawn()
			local beltId = world:spawn()
			world:insert(
				nextBeltId,
				createBeltSegComp({ distToInsertAtStart = 100, speed = 1, prevSeg = beltId }),
				createBeltItemsComp({ positions = {} })
			)
			world:insert(
				beltId,
				createBeltSegComp({ distToInsertAtStart = 0, speed = 1, nextSeg = nextBeltId }),
				createBeltItemsComp({ positions = { 1, 40 } })
			)

			ConveyorBeltSystemV2.system(world)

			local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)
			local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)

			local nextBeltSeg: Types.BeltSegment = world:get(nextBeltId, Components.BeltSegment)
			local nextBeltItems: Types.BeltItemsV2 = world:get(nextBeltId, Components.BeltItemsV2)

			expect(#beltItems.items).to.be.equal(1)
			expect(#nextBeltItems.items).to.be.equal(1)

			expect(nextBeltSeg.distToInsertAtStart).to.be.equal(0)
			expect(beltSeg.distToInsertAtStart).to.be.equal(1)

			expect(beltItems.items[1].distFromNext).to.be.equal(40)
			expect(nextBeltItems.items[1].distFromNext).to.be.equal(100)
		end)
	end)

	describe("BeltHelpers", function()
		local world

		beforeEach(function()
			world = Matter.World.new()
			world.FixedDeltaTime = 1 / 60
		end)

		afterEach(function()
			world:clear()
		end)

		it("should find items in node", function()
			local beltId = world:spawn(
				createBeltSegComp({ distToInsertAtStart = 0, speed = 1, nodes = { 1, 2, 3 } }),
				createBeltItemsComp({ positions = { 39, 40 } })
			)

			local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)
			local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)

			local items
			items = BeltHelpers.findItemsInNode(beltSeg, beltItems, 3)
			expect(items.item).to.be.equal(beltItems.items[1])
			expect(items.index).to.be.equal(1)

			items = BeltHelpers.findItemsInNode(beltSeg, beltItems, 2)
			expect(items.item).to.be.equal(beltItems.items[2])
			expect(items.index).to.be.equal(2)

			items = BeltHelpers.findItemsInNode(beltSeg, beltItems, 1)
			expect(items).to.be.equal(nil)
		end)

		it("should not find item if belt is empty", function()
			local beltId = world:spawn(
				createBeltSegComp({ distToInsertAtStart = 0, speed = 1, nodes = { 1, 2, 3 } }),
				createBeltItemsComp({ positions = {} })
			)

			local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)
			local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)

			local items
			items = BeltHelpers.findItemsInNode(beltSeg, beltItems, 3)
			expect(items).to.be.equal(nil)
		end)

		it("should not find item if first item is beyond the node range", function()
			local beltId = world:spawn(
				createBeltSegComp({ distToInsertAtStart = 0, speed = 1, nodes = { 1, 2, 3 } }),
				createBeltItemsComp({ positions = { 121, 130 } })
			)

			local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)
			local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)

			local items
			items = BeltHelpers.findItemsInNode(beltSeg, beltItems, 3)
			expect(items).to.be.equal(nil)
		end)

		it("should not find item when item are in between the node", function()
			local beltId = world:spawn(
				createBeltSegComp({ distToInsertAtStart = 0, speed = 1, nodes = { 1, 2, 3, 4 } }),
				createBeltItemsComp({ positions = { 38, 159 - 38 } })
			)

			local beltItems: Types.BeltItemsV2 = world:get(beltId, Components.BeltItemsV2)
			local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)

			local result = BeltHelpers.findItemsInNode(beltSeg, beltItems, 4)
			expect(result.item).to.be.equal(beltItems.items[1])
			result = BeltHelpers.findItemsInNode(beltSeg, beltItems, 1)
			expect(result.item).to.be.equal(beltItems.items[2])

			result = BeltHelpers.findItemsInNode(beltSeg, beltItems, 3)
			expect(result).to.be.equal(nil)
		end)

		it("node range", function()
			local beltSeg = createBeltSegComp({ distToInsertAtStart = 0, speed = 1, nodes = { 1, 2, 3, 4 } })

			local start, endRange = BeltHelpers.getNodeRange(beltSeg, 1)
			expect(start).to.be.equal(120)
			expect(endRange).to.be.equal(159)

			start, endRange = BeltHelpers.getNodeRange(beltSeg, 2)
			expect(start).to.be.equal(80)
			expect(endRange).to.be.equal(119)

			start, endRange = BeltHelpers.getNodeRange(beltSeg, 3)
			expect(start).to.be.equal(40)
			expect(endRange).to.be.equal(79)

			start, endRange = BeltHelpers.getNodeRange(beltSeg, 4)
			expect(start).to.be.equal(0)
			expect(endRange).to.be.equal(39)
		end)
	end)
end
