--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Matter)
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Events)
local Helpers = require(ReplicatedStorage.Shared.Helpers)
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)
local TableUtils = require(ReplicatedStorage.Shared.TableUtils)
local Types = require(ReplicatedStorage.Shared.Types)

local mouse = Players.LocalPlayer:GetMouse()
local gridSize = 2

-- TODO: improve this algorithm to avoid overlapping points and less loops
local function getPathPoints(startPos: Vector3, endPos: Vector3, curveDirection: string, maxPoints: number)
	local points = {}
	if startPos == endPos then
		return { startPos }
	end

	if curveDirection == "FREE" then
		local direction = (endPos - startPos).Unit
		local distance = (endPos - startPos).Magnitude
		local segments = math.floor(distance / gridSize)
		local rest = distance - (segments * gridSize)
		local plus = rest / segments
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
			table.insert(first, Vector3.new(x, 0, curveDirection == "X" and startPos.Z or endPos.Z))
		end
	end

	local second = {}
	if startPos.Z ~= endPos.Z then
		for z = startPos.Z, endPos.Z, math.sign(endPos.Z - startPos.Z) * gridSize do
			table.insert(second, Vector3.new(curveDirection == "X" and endPos.X or startPos.X, 0, z))
		end
	end

	if curveDirection == "X" then
		points = TableUtils.Merge(first, second)
	else
		points = TableUtils.Merge(second, first)
	end

	local finalPoints = {}
	for i = 1, math.min(#points, maxPoints) do
		finalPoints[i] = points[i]
	end

	local set = {}
	for i, p in ipairs(finalPoints) do
		if set[p] == nil then
			set[p] = true
		else
			table.remove(finalPoints, i)
		end
	end

	return finalPoints
end

local function getLengthByNodesCount(nodesCount: number): number
	return nodesCount * BeltSettings.BeltSubdiv
end

local function findDirectionFromVectors(v1: Vector3, v2: Vector3): Types.BeltNodeDirection
	if v1.X == 1 then
		if v2.Z == 1 then
			return "right"
		elseif v2.Z == -1 then
			return "left"
		end
	elseif v1.X == -1 then
		if v2.Z == 1 then
			return "left"
		elseif v2.Z == -1 then
			return "right"
		end
	elseif v1.Z == 1 then
		if v2.X == 1 then
			return "left"
		elseif v2.X == -1 then
			return "right"
		end
	elseif v1.Z == -1 then
		if v2.X == 1 then
			return "right"
		elseif v2.X == -1 then
			return "left"
		end
	end
	return "top"
end

local function calculateNodeDir(points: { Vector3 }, index: number): (Vector3, Types.BeltNodeDirection)
	local inDir = if index == 1 then nil else (points[index] - points[index - 1]).Unit
	local outDir = if index == #points then nil else (points[index + 1] - points[index]).Unit

	local direction = if inDir and outDir then findDirectionFromVectors(inDir, outDir) else "top"
	local dirVector = (if inDir then inDir else outDir) :: Vector3
	return dirVector, direction :: Types.BeltNodeDirection
end

local function recalculateNodesDir(world: Types.World, nodes: { Types.EntityId })
	local points: { Vector3 } = {}
	for _, nodeId in ipairs(nodes) do
		local node: Types.BeltNodeComponent = world:get(nodeId, Components.BeltNode)
		table.insert(points, node.pos)
	end

	for i, nodeId in ipairs(nodes) do
		local node: Types.BeltNodeComponent = world:get(nodeId, Components.BeltNode)
		local dirVector, direction = calculateNodeDir(points, i)
		node.dirVector = dirVector
		node.direction = direction :: Types.BeltNodeDirection
	end
end

local function BeltPlacerSystem(world: Types.World)
	local placer: Types.BeltPlacer = world:GetSingleton(Components.BeltPlacer)
	local settings: Types.Settings = world:GetSingleton(Components.Settings)

	local function spawnNodes(beltPathEntity: number, points: { Vector3 }, startIndex: number?): { Types.EntityId }
		local index = startIndex or 1

		assert(#points >= 2, "Need at least 2 points to spawn belt nodes")

		local nodes: { { pos: Vector3, index: number, direction: "top" | "right" | "left", dirVector: Vector3 } } = {}

		for i = 1, #points do
			local dirVector, direction = calculateNodeDir(points, i)
			table.insert(
				nodes,
				{
					pos = points[i],
					dirVector = dirVector,
					direction = direction,
					index = index,
				} :: Types.BeltNodeComponent
			)
			index += 1
		end

		local nodesIds: { Types.EntityId } = {}
		for _, node in ipairs(nodes) do
			local nodeInstance: Model = ReplicatedStorage.Models.Facilities.BeltNode:Clone()
			for _, instance in ipairs(nodeInstance:GetDescendants()) do
				if instance:IsA("BasePart") then
					instance.CollisionGroup = CollisionGroups.BeltNodes
				end
			end

			local id = world:spawn(
				Components.BeltNode({
					beltPath = beltPathEntity,
					nodeIndex = node.index,
					pos = node.pos,
					cframe = CFrame.new(node.pos, node.pos + node.dirVector),
					index = node.index,
					direction = node.direction,
					dirVector = node.dirVector,
				} :: Types.BeltNodeComponent),
				Components.Model({
					instance = nodeInstance,
				} :: Types.ModelComponent),
				Components.Transform({
					cframe = CFrame.new(node.pos, node.pos + node.dirVector),
					isStatic = true,
				} :: Types.Transform),
				Components.SortersConnected({ sorters = {} } :: Types.SortersConnected),
				Components.BeltsConnected({ belts = {} } :: Types.BeltsConnected)
			)
			world:commitCommands()
			table.insert(nodesIds, id)
		end
		return nodesIds
	end

	local function spawnBelt(points: { Vector3 }): (number, { Types.EntityId })
		local length = getLengthByNodesCount(#points)

		local beltId = world:spawn()
		local nodesIds = spawnNodes(beltId, points) :: { Types.EntityId }

		world:insert(
			beltId,
			Components.BeltSegment({
				nodes = nodesIds,
				distToInsertAtStart = length,
				speed = BeltSettings.BeltSpeeds.Slow,
			} :: Types.BeltSegment),
			Components.BeltItemsV2({ items = {} }),
			Components.ItemsMeshes({} :: Types.ItemsMeshes)
		)
		world:commitCommands()

		return beltId, nodesIds
	end

	local function extendBelt(beltId: Types.EntityId, pointsToInsert: { Vector3 })
		if #pointsToInsert < 2 then
			warn("Need at least 2 points to extend belt")
			return
		end

		local beltSeg: Types.BeltSegment = world:get(beltId, Components.BeltSegment)
		local nextBeltId = spawnBelt(pointsToInsert)

		beltSeg.nextSeg = nextBeltId
		local nextBeltSeg: Types.BeltSegment = world:get(nextBeltId, Components.BeltSegment)
		nextBeltSeg.prevSeg = beltId

		recalculateNodesDir(world, TableUtils.Merge(beltSeg.nodes, nextBeltSeg.nodes))

		return nextBeltId
	end

	local function findMinerAtPosition(): Types.EntityId?
		local raycastParams = RaycastParams.new()
		raycastParams.CollisionGroup = CollisionGroups.BuildingCollisionCheck

		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local res = workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)

		if res and res.Instance and res.Instance:FindFirstAncestorOfClass("Model") then
			local entityId = res.Instance:FindFirstAncestorOfClass("Model"):GetAttribute("entityId")
			local miner: Types.Miner = world:get(entityId, Components.Miner)
			if miner ~= nil and miner.outputBelt == nil then
				return entityId
			end
		end

		return nil
	end

	local function findNodeAtPosition(pos: Vector3): Types.EntityId?
		local raycastParams = RaycastParams.new()
		raycastParams.CollisionGroup = CollisionGroups.BuildingCollisionCheck

		local res = workspace:Raycast(pos + Vector3.yAxis * 10, -Vector3.yAxis * 20, raycastParams)

		if res and res.Instance and res.Instance:FindFirstAncestorOfClass("Model") then
			local entityId = res.Instance:FindFirstAncestorOfClass("Model"):GetAttribute("entityId")
			if entityId == nil then
				return nil
			end

			local beltNode: Types.BeltNodeComponent = world:get(entityId, Components.BeltNode)
			if beltNode == nil then
				return nil
			end

			return entityId
		end

		return nil
	end

	for _, event in matter.useEvent(Events, "ToolUnequiped") do
		if event.type == "BeltPlacer" then
			placer.enabled = false
			placer.startPosition = nil
			placer.endPosition = nil
			placer.lastBelt = nil
		end
	end
	for _, event in matter.useEvent(Events, "ToolEquiped") do
		if event.type == "BeltPlacer" then
			placer.enabled = true
		end
	end

	if not placer.enabled then
		placer.startPosition = nil
		placer.endPosition = nil
	else
		MatterHooks.useContextAction("beltplacer:select_point", function(_action, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				if not placer.startPosition then
					local pos = Helpers.snapToGrid(mouse.Hit.Position, settings.gridSize)
					local minerId = findMinerAtPosition()
					placer.minerToConnect = minerId

					if minerId ~= nil then
						local model = world:get(minerId, Components.Model)
						local outputAtt = model.instance.OutputAtt :: Attachment
						placer.startPosition = Helpers.snapToGrid(outputAtt.WorldCFrame.Position, 2)
					else
						placer.startPosition = pos
					end

					return Enum.ContextActionResult.Sink
				end

				local endPosition = Helpers.snapToGrid(mouse.Hit.Position, settings.gridSize)
				local nodeAtEnd = findNodeAtPosition(endPosition)

				local points = getPathPoints(placer.startPosition, endPosition, placer.curveDirection, 100)

				if placer.lastBelt ~= nil then
					local pointsToInsert = TableUtils.Slice(points, 2, #points)
					placer.lastBelt = extendBelt(placer.lastBelt, pointsToInsert)
				else
					local pointsToInsert = if nodeAtEnd ~= nil then TableUtils.Slice(points, 1, #points - 1) else points
					placer.lastBelt = spawnBelt(pointsToInsert)
				end

				placer.startPosition = points[#points]

				if placer.minerToConnect ~= nil then
					local miner: Types.Miner = world:get(placer.minerToConnect, Components.Miner)
					local beltSeg: Types.BeltSegment = world:get(placer.lastBelt, Components.BeltSegment)
					beltSeg.minerConnected = placer.minerToConnect
					miner.outputBelt = placer.lastBelt
					placer.minerToConnect = nil
				end

				-- if nodeAtEnd ~= nil then
				-- 	local beltsConnected: Types.BeltsConnected = world:get(nodeAtEnd, Components.BeltsConnected)
				-- 	beltsConnected.belts[`{placer.lastBelt}`] = true

				-- 	local beltSeg: Types.BeltSegment = world:get(placer.lastBelt, Components.BeltSegment)
				-- 	beltSeg.beltNodeOutput = nodeAtEnd
				-- 	placer.startPosition = nil
				-- 	placer.lastBelt = nil
				-- end

				return Enum.ContextActionResult.Sink
			end

			return Enum.ContextActionResult.Sink
		end, { inputTypes = { Enum.UserInputType.MouseButton1 } })

		MatterHooks.useContextAction(
			"beltplacer:change_curve_direction",
			function(_action, inputState: Enum.UserInputState)
				if inputState == Enum.UserInputState.Begin then
					placer.curveDirection = placer.curveDirection == "X" and "Z" or "X"
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end,
			{ inputTypes = { Enum.KeyCode.R } }
		)

		MatterHooks.useContextAction(
			"beltplacer:cancel_current_path",
			function(_action, inputState: Enum.UserInputState)
				if inputState == Enum.UserInputState.Begin then
					if placer.startPosition == nil then
						Players.LocalPlayer.Character.Humanoid:UnequipTools()
						return Enum.ContextActionResult.Sink
					end

					placer.startPosition = nil
					placer.endPosition = nil
					placer.lastBelt = nil
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end,
			{ inputTypes = { Enum.UserInputType.MouseButton2 } }
		)
	end

	if placer.startPosition then
		local points = getPathPoints(
			placer.startPosition,
			Helpers.snapToGrid(mouse.Hit.Position, gridSize),
			placer.curveDirection,
			100
		)
		if not placer.pathPreview then
			local pathPreviewId = world:spawn(Components.PathPreview({
				color = BrickColor.Yellow(),
				pointSize = Vector3.one * 0.6,
			}))
			world:commitCommands()
			placer.pathPreview = pathPreviewId
		end
		local pathPreview = world:get(placer.pathPreview, Components.PathPreview)

		local function validatePoint(point: Vector3)
			local overlapParams = OverlapParams.new()
			overlapParams.CollisionGroup = CollisionGroups.Buildings

			local res = workspace:GetPartBoundsInBox(CFrame.new(point), Vector3.one * 1.7, overlapParams)
			return #res == 0
		end

		-- TODO: color red each invalid point. need to improve path preview to support per point color
		local hasInvalidPoint = false
		for _i, point in ipairs(points) do
			if not validatePoint(point) then
				hasInvalidPoint = true
				break
			end
		end

		if MatterHooks.useChange({ hasInvalidPoint }) then
			pathPreview.color = BrickColor.Yellow()
		end

		pathPreview.points = points
	elseif placer.pathPreview then
		world:despawn(placer.pathPreview)
		placer.pathPreview = nil
	end
end

return {
	system = BeltPlacerSystem,
	priority = 1,
	event = "FixedUpdate",
	disabled = false,
}
