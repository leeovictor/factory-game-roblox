local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local MatterHooks = require(ReplicatedStorage.Shared.MatterHooks)

local cameraYaw = 0
local cameraPitch = 0
local movementEnabled = false
local minZoom = 5
local maxZoom = 100
local currentZoom = minZoom

local function CameraMovementSystem()
	local character = Players.LocalPlayer.Character

	if workspace.CurrentCamera and workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	end

	if character and character:FindFirstChild("HumanoidRootPart") then
		if workspace.CurrentCamera.Focus ~= character.HumanoidRootPart then
			workspace.CurrentCamera.Focus = character.HumanoidRootPart.CFrame
		end

		MatterHooks.useContextAction(
			"camera_movement:activate_move_camera",
			function(_actionName, inputState: Enum.UserInputState, inputOjb: InputObject)
				if inputOjb.UserInputType == Enum.UserInputType.MouseButton3 then
					if inputState == Enum.UserInputState.Begin then
						UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
						movementEnabled = true
					elseif inputState == Enum.UserInputState.End then
						UserInputService.MouseBehavior = Enum.MouseBehavior.Default
						movementEnabled = false
					end
					return
				end

				if
					inputState == Enum.UserInputState.Change
					and inputOjb.UserInputType == Enum.UserInputType.MouseMovement
					and movementEnabled
				then
					local delta = inputOjb.Delta
					cameraYaw -= delta.X
					cameraPitch -= delta.Y
					cameraPitch = math.clamp(cameraPitch, -80, 80)
				end
			end,
			{
				inputTypes = { Enum.UserInputType.MouseMovement, Enum.UserInputType.MouseButton3 },
			}
		)

		MatterHooks.useContextAction(
			"camera_movement:camera_zoom",
			function(_actionName, inputState: Enum.UserInputState, inputOjb: InputObject)
				if
					inputState == Enum.UserInputState.Change
					and inputOjb.UserInputType == Enum.UserInputType.MouseWheel
				then
					local delta = inputOjb.Position.Z
					currentZoom = math.clamp(currentZoom - delta * 4, minZoom, maxZoom)
					return
				end
			end,
			{
				inputTypes = { Enum.UserInputType.MouseWheel },
			}
		)

		-- local humanoidRootPart = character.HumanoidRootPart
		local targetPosition = character:GetPivot().Position
		local angles = CFrame.Angles(0, math.rad(cameraYaw), 0) * CFrame.Angles(math.rad(cameraPitch), 0, 0)

		-- search for objects occluding the camera and aproximate the camera based on this
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { character }
		local cameraCFrame = CFrame.new(targetPosition) * angles * CFrame.new(0, 0, currentZoom)
		local res =
			workspace:Raycast(targetPosition, (cameraCFrame.Position - targetPosition).Unit * 100, raycastParams)

		if res then
			local distance = (res.Position - targetPosition).Magnitude
			cameraCFrame = CFrame.new(targetPosition)
				* angles
				* CFrame.new(0, 0, math.clamp(distance - 1, 0, currentZoom))
		end

		if workspace.CurrentCamera then
			workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(cameraCFrame, 0.2)
		end
	end
end

return {
	system = CameraMovementSystem,
	event = "PreRender",
}
