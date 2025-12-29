local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Packages.matter)
local Components = require(ReplicatedStorage.Shared.Components)
local Types = require(ReplicatedStorage.Shared.Types)

local function GridLinesRenderer(world: Types.World)
	local settings: Types.Settings = world:GetSingleton(Components.Settings)
	local gridLines: Types.GridLines = world:GetSingleton(Components.GridLines)

	if gridLines.enabled == false then
		if gridLines.folder then
			for _, part in pairs(gridLines.folder:GetChildren()) do
				part.Parent = nil
			end
		end
		return
	end

	-- update the center based on the position of the player
	local player = game.Players.LocalPlayer
	if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		gridLines.center = player.Character.HumanoidRootPart.Position
	else
		gridLines.center = workspace.CurrentCamera.CFrame.Position
	end

	if not gridLines.folder then
		local folder = Instance.new("Folder")
		folder.Name = "GridLines"
		folder.Parent = workspace
		gridLines.folder = folder
	end

	-- cache for grid line parts
	if not gridLines.cachedParts then
		gridLines.cachedParts = {}
	end

	local needsUpdate = gridLines.gridSize ~= settings.gridSize
		or gridLines.center ~= player.Character
		or player.Character.HumanoidRootPart.Position
		or Vector3.zero

	if needsUpdate then
		gridLines.gridSize = settings.gridSize
		gridLines.center = player.Character.HumanoidRootPart.Position

		local halfExtents = gridLines.gridExtents / 2
		local step = settings.gridSize
		local partIndex = 1
		local cachedParts = gridLines.cachedParts

		-- Calculate how many lines are needed
		local numLines = math.floor((halfExtents * 2) / step) + 1

		-- Find the world position of the first thick line (multiple of 4*step)
		local thickStep = 4 * step
		local baseX = math.floor((gridLines.center.X - halfExtents) / thickStep) * thickStep
		local baseZ = math.floor((gridLines.center.Z - halfExtents) / thickStep) * thickStep

		for i = 0, numLines - 1 do
			local x = -halfExtents + i * step

			-- X lines
			local worldX = math.floor((gridLines.center.X + x) / step) * step
			local isThickX = ((worldX - baseX) % thickStep) == 0
			local thicknessX = isThickX and 0.3 or 0.1

			local line1 = cachedParts[partIndex]
			if not line1 then
				line1 = Instance.new("Part")
				line1.Anchored = true
				line1.CanCollide = false
				line1.Locked = true
				line1.Parent = gridLines.folder
				cachedParts[partIndex] = line1
			end
			line1.Size = Vector3.new(thicknessX, thicknessX, gridLines.gridExtents)
			line1.CFrame = CFrame.new(Vector3.new(worldX, 0, math.floor(gridLines.center.Z / step) * step))
			line1.Color = Color3.fromRGB(28, 255, 85)
			line1.Transparency = 0.7
			line1.Parent = gridLines.folder
			partIndex += 1

			-- Z lines
			local worldZ = math.floor((gridLines.center.Z + x) / step) * step
			local isThickZ = ((worldZ - baseZ) % thickStep) == 0
			local thicknessZ = isThickZ and 0.3 or 0.1

			local line2 = cachedParts[partIndex]
			if not line2 then
				line2 = Instance.new("Part")
				line2.Anchored = true
				line2.CanCollide = false
				line2.Locked = true
				line2.Parent = gridLines.folder
				cachedParts[partIndex] = line2
			end
			line2.Size = Vector3.new(gridLines.gridExtents, thicknessZ, thicknessZ)
			line2.CFrame = CFrame.new(Vector3.new(math.floor(gridLines.center.X / step) * step, 0, worldZ))
			line2.Color = Color3.fromRGB(28, 255, 85)
			line2.Transparency = 0.7
			line2.Parent = gridLines.folder
			partIndex += 1
		end

		-- Hide unused parts
		for i = partIndex, #cachedParts do
			local part = cachedParts[i]
			if part then
				part.Parent = nil
			end
		end
		matter.log(#cachedParts)
	end
end

return {
	system = GridLinesRenderer,
	event = "FixedUpdate",
}
