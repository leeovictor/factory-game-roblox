--!strict
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

local debugEnabled = true
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

local function nodeIsBeginningNode(world: Types.World, nodeId: Types.EntityId): boolean
	local node: Types.BeltNodeComponent = world:get(nodeId, Components.BeltNode)
	local beltPath: Types.BeltPath = world:get(node.beltPath, Components.BeltPath)
	return beltPath.nodes[1] == nodeId
end

local function nodeIsEndNode(world: Types.World, nodeId: Types.EntityId): boolean
	local node: Types.BeltNodeComponent = world:get(nodeId, Components.BeltNode)
	local beltPath: Types.BeltPath = world:get(node.beltPath, Components.BeltPath)
	return beltPath.nodes[#beltPath.nodes] == nodeId
end

local function extendBeltAtEnd(world: Types.World, belt: Types.EntityId, points: { Vector3 })
	-- TODO
end

local function getLengthByNodesCount(nodesCount: number): number
	return nodesCount * BeltSettings.BeltSubdiv * 2
end

local function BeltPlacerSystem(world: Types.World)
	local placer: Types.BeltPlacer = world:GetSingleton(Components.BeltPlacer)
	local settings: Types.Settings = world:GetSingleton(Components.Settings)

	local function spawnNodes(beltPathEntity: number, points: { Vector3 }): { Types.EntityId }
		local nodes: { { pos: Vector3, outDir: Vector3, index: number } } = {}
		for i, point in ipairs(points) do
			local outDir: Vector3 = if i == #points then nodes[#nodes].outDir else (points[i + 1] - point).Unit
			table.insert(nodes, {
				pos = point,
				outDir = outDir,
				index = i,
			})
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
					outDir = node.outDir,
					index = node.index,
				} :: Types.BeltNodeComponent),
				Components.Model({
					instance = nodeInstance,
				}),
				Components.Transform({
					cframe = CFrame.new(node.pos),
					isStatic = true,
				})
			)
			world:commitCommands()
			table.insert(nodesIds, id)
		end
		return nodesIds
	end

	local function spawnBeltPath(points): (number, { Types.EntityId })
		local length = getLengthByNodesCount(#points)

		local beltItemsComp = Components.BeltItems({
			items = {},
		})
		if false then
			local itemType = math.random() > 0.5 and "iron_ore" or "copper_ore"
			for i = 1, 10 do
				local item = {}
				item.item = itemType

				local mesh = ItemMeshes[item.item]:Clone()
				mesh.Parent = workspace
				item.distFromNext = i == 1 and length or BeltSettings.ItemOcupancy * 2
				item.mesh = mesh
				table.insert(beltItemsComp.items, item)
			end
		end

		local beltId = world:spawn()

		local nodesIds = spawnNodes(beltId, points) :: { Types.EntityId }
		world:insert(
			beltId,
			Components.BeltPath({
				nodes = nodesIds,
				distToInsertAtStart = length,
			} :: Types.BeltPath),
			beltItemsComp
		)
		world:commitCommands()

		return beltId, nodesIds
	end

	local function findMinerAtPosition(pos: Vector3): Types.EntityId?
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
					local minerId = findMinerAtPosition(pos)
					placer.minerToConnect = minerId

					if minerId ~= nil then
						local model = world:get(minerId, Components.Model)
						local outputAtt = model.instance.OutputAtt :: Attachment
						placer.startPosition = Helpers.snapToGrid(outputAtt.WorldCFrame.Position, 2)
					else
						placer.startPosition = pos
					end

					placer.nodeAtStartPosition = findNodeAtPosition(pos)
					return Enum.ContextActionResult.Sink
				end

				local endPosition = Helpers.snapToGrid(mouse.Hit.Position, settings.gridSize)
				local points = getPathPoints(placer.startPosition, endPosition, placer.curveDirection, 100)
				local beltId, nodes = spawnBeltPath(points)
				placer.nodeAtStartPosition = world:get(nodes[#nodes], Components.BeltNode)
				placer.startPosition = nil

				if placer.minerToConnect ~= nil then
					local miner: Types.Miner = world:get(placer.minerToConnect, Components.Miner)
					miner.outputBelt = beltId
					placer.minerToConnect = nil
				end

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
					placer.nodeAtStartPosition = nil
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
