local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Packages.matter)
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

local ItemMeshes = ReplicatedStorage:WaitForChild("Models"):WaitForChild("ItemMeshes")

local function createNodesFromPoints(points: { Vector3 }, startIndex: number?): { Types.BeltNode }
	local nodes: { Types.BeltNode } = {}

	local index = startIndex or 1
	for i, nodePos in ipairs(points) do
		local dirToNext: Vector3
		if i == #points then
			dirToNext = nodes[#nodes].outDir
		else
			dirToNext = (points[i + 1] - nodePos).Unit
		end

		table.insert(nodes, {
			pos = nodePos,
			inDir = if i == 1 then (points[i + 1] - nodePos).Unit else (nodePos - points[i - 1]).Unit,
			outDir = dirToNext,
			index = index,
		})
		index += 1
	end
	return nodes
end

local function recalculateNodesOutDirs(nodes: { Types.BeltNode })
	for index, node in ipairs(nodes) do
		if index == #nodes then
			node.outDir = nodes[#nodes].outDir
		else
			node.outDir = (nodes[index + 1].pos - node.pos).Unit
		end
	end
end

local function getLengthByNodesCount(nodesCount: number): number
	return nodesCount * BeltSettings.BeltSubdiv * 2
end

local function BeltPlacerSystem(world: Types.World)
	local placer: Types.BeltPlacer = world:GetSingleton(Components.BeltPlacer)
	local settings: Types.Settings = world:GetSingleton(Components.Settings)

	local function spawnNodes(beltPathEntity: number, nodes: { Types.BeltNode }): { Types.EntityId }
		local nodesIds: { Types.EntityId } = {}
		-- local nodeModel = ReplicatedStorage.Models.Facilities.BeltNode
		for _, node: Types.BeltNode in ipairs(nodes) do
			local nodeInstance: Model = ReplicatedStorage.Models.Facilities.BeltNode:Clone()
			for _, instance in ipairs(nodeInstance:GetDescendants()) do
				if instance:IsA("BasePart") then
					instance.CollisionGroup = CollisionGroups.BeltNodes
				end
			end
			nodeInstance.Parent = workspace

			local nodeId = world:spawn(
				Components.BeltNode({
					beltPath = beltPathEntity,
					nodeIndex = node.index,
				}),
				Components.Model({
					instance = nodeInstance,
				}),
				Components.Transform({
					cframe = CFrame.new(node.pos),
					isStatic = true,
				})
			)
			world:commitCommands()
			table.insert(nodesIds, nodeId)
			nodeInstance:SetAttribute("entityId", nodeId)
		end
		return nodesIds
	end

	local function spawnBeltPath(points): (number, { Types.EntityId })
		local length = getLengthByNodesCount(#points)
		local nodes = createNodesFromPoints(points)

		-- generate random items
		local itemType = math.random() > 0.5 and "iron_ore" or "copper_ore"
		local items = {}
		for i = 1, 10 do
			local item = {}
			item.item = itemType

			local mesh = ItemMeshes[item.item]:Clone()
			mesh.Parent = workspace
			item.distFromNext = i == 1 and length or BeltSettings.ItemOcupancy * 2
			item.mesh = mesh
			table.insert(items, item)
		end

		local id = world:spawn(
			Components.BeltPath({
				nodes = nodes,
				startPos = points[1],
				endPos = points[#points],
				distToInsertAtStart = length,
				nodesSpawned = false,
			}),
			Components.BeltItems({
				items = items,
			})
		)
		world:commitCommands()
		local nodesIds = spawnNodes(id, nodes)
		return id, nodesIds
	end

	local function findNodeAtPosition(pos: Vector3): Types.BeltNodeComponent?
		local raycastParams = RaycastParams.new()
		raycastParams.CollisionGroup = CollisionGroups.BeltNodes

		local start = pos
		local res = workspace:Raycast(start + Vector3.yAxis * 2, -Vector3.yAxis * 20, raycastParams)

		if res and res.Instance and res.Instance:FindFirstAncestorOfClass("Model") then
			local entityId = res.Instance:FindFirstAncestorOfClass("Model"):GetAttribute("entityId")
			return world:get(entityId, Components.BeltNode)
		end
		return nil
	end

	for _, event in matter.useEvent(Events, "ToolUnequiped") do
		if event.type == "BeltPlacer" then
			placer.enabled = false
			placer.startPosition = nil
			placer.endPosition = nil
			placer.nodeAtStartPosition = nil
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
			if inputState == Enum.UserInputState.End then
				if not placer.startPosition then
					local pos = Helpers.snapToGrid(mouse.Hit.Position, settings.gridSize)
					placer.nodeAtStartPosition = findNodeAtPosition(pos)
					placer.startPosition = pos
					return
				end

				local endPosition = Helpers.snapToGrid(mouse.Hit.Position, settings.gridSize)
				local nodeAtEndPosition = findNodeAtPosition(endPosition)

				local points = getPathPoints(placer.startPosition, endPosition, placer.curveDirection, 100)
				if placer.nodeAtStartPosition then
					local beltPath: Types.BeltPath = world:get(placer.nodeAtStartPosition.beltPath, Components.BeltPath)
					local newNodes = createNodesFromPoints(
						TableUtils.Slice(points, 2, #points),
						placer.nodeAtStartPosition.nodeIndex + 1
					)
					local nodes = spawnNodes(placer.nodeAtStartPosition.beltPath, newNodes)
					beltPath.nodes = TableUtils.Merge(beltPath.nodes, newNodes)

					recalculateNodesOutDirs(beltPath.nodes)

					local beltItems: Types.BeltItemComponent =
						world:get(placer.nodeAtStartPosition.beltPath, Components.BeltItems)
					if beltItems.items[1] then
						beltItems.items[1].distFromNext += getLengthByNodesCount(#newNodes)
					else
						beltPath.distToInsertAtStart += getLengthByNodesCount(#newNodes)
					end

					placer.nodeAtStartPosition = world:get(nodes[#nodes], Components.BeltNode)
				else
					local _, nodes = spawnBeltPath(points)
					placer.nodeAtStartPosition = world:get(nodes[#nodes], Components.BeltNode)
				end

				placer.startPosition = endPosition
			end
		end, { inputTypes = { Enum.UserInputType.MouseButton1 } })

		MatterHooks.useContextAction(
			"beltplacer:change_curve_direction",
			function(_action, inputState: Enum.UserInputState)
				if inputState == Enum.UserInputState.Begin then
					placer.curveDirection = placer.curveDirection == "X" and "Z" or "X"
				end
			end,
			{ inputTypes = { Enum.KeyCode.R } }
		)

		MatterHooks.useContextAction(
			"beltplacer:cancel_current_path",
			function(_action, inputState: Enum.UserInputState)
				if inputState == Enum.UserInputState.Begin then
					if placer.startPosition == nil then
						Players.LocalPlayer.Character.Humanoid:UnequipTools()
						return
					end

					placer.startPosition = nil
					placer.endPosition = nil
					placer.nodeAtStartPosition = nil
				end
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
