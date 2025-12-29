local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Packages.matter)
local BeltSettings = require(ReplicatedStorage.Shared.BeltSettings)
local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Events)
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

local function snapToGrid(position: Vector3, size: number): Vector3
	return Vector3.new(
		math.floor((position.X + size / 2) / size) * size,
		0,
		math.floor((position.Z + size / 2) / size) * size
	)
end

local ItemMeshes = ReplicatedStorage:WaitForChild("Models"):WaitForChild("ItemMeshes")

local function BeltPlacerSystem(world: Types.World)
	local function spawnBeltPath(points)
		local length = #points * 2 * BeltSettings.BeltSubdiv

		local nodes: { Types.Beltnode } = {}
		for index, nodePos in ipairs(points) do
			local dirToNext: Vector3
			if index == #points then
				dirToNext = nodes[#nodes].outDir
			else
				dirToNext = (points[index + 1] - nodePos).Unit
			end

			table.insert(nodes, {
				pos = nodePos,
				outDir = dirToNext,
			})
		end

		-- generate random items
		local items = {}
		for i = 1, 20 do
			local item = {}
			item.item = math.random() > 0.5 and "iron_ore" or "copper_ore"

			local mesh = ItemMeshes[item.item]:Clone()
			mesh.Parent = workspace
			item.distFromNext = i == 1 and length or BeltSettings.ItemOcupancy * 2
			item.mesh = mesh
			table.insert(items, item)
		end

		world:spawn(
			Components.BeltPath({
				nodes = nodes,
				startPos = points[1],
				endPos = points[#points],
				distToInsertAtStart = 0,
				nodesSpawned = false,
			}),
			Components.BeltItems({
				items = items,
			})
		)
	end

	local placer: Types.BeltPlacer = world:GetSingleton(Components.BeltPlacer)
	local gridLines: Types.GridLines = world:GetSingleton(Components.GridLines)

	for _, event in matter.useEvent(Events, "ToolUnequiped") do
		if event.type == "BeltPlacer" then
			placer.enabled = false
			gridLines.enabled = false
		end
	end
	for _, event in matter.useEvent(Events, "ToolEquiped") do
		if event.type == "BeltPlacer" then
			placer.enabled = true
			gridLines.enabled = true
		end
	end

	if not placer.enabled then
		placer.startPosition = nil
		placer.endPosition = nil
	else
		MatterHooks.useContextAction("beltplacer:select_point", function(_action, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.End then
				if not placer.startPosition then
					placer.startPosition = snapToGrid(mouse.Hit.Position, gridSize)
					return
				end

				local points = getPathPoints(
					placer.startPosition,
					snapToGrid(mouse.Hit.Position, gridSize),
					placer.curveDirection,
					100
				)
				spawnBeltPath(points)
				placer.startPosition = nil
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
	end

	if placer.startPosition then
		local points =
			getPathPoints(placer.startPosition, snapToGrid(mouse.Hit.Position, gridSize), placer.curveDirection, 100)
		if not placer.pathPreview then
			local pathPreviewId = world:spawn(Components.PathPreview({
				color = BrickColor.Yellow(),
				pointSize = Vector3.one * 0.6,
			}))
			world:commitCommands()
			placer.pathPreview = pathPreviewId
		end
		local pathPreview = world:get(placer.pathPreview, Components.PathPreview)
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
