local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local Types = require(ReplicatedStorage.Shared.Types)

local MinerInfoUIController = {}
MinerInfoUIController.__index = MinerInfoUIController

export type MinerInfo = {
	status: string,
	storage: {
		currentAmount: number,
		capacity: number,
	},
	veinsCount: number,
	miningProgress: number,
}

type MinerInfoUIControllerData = {
	screen: any,
	world: Types.World,
	entityId: number?,
	enabled: boolean,
}

export type MinerInfoUIController = typeof(setmetatable({} :: MinerInfoUIControllerData, MinerInfoUIController))

function MinerInfoUIController.new(world: Types.World): MinerInfoUIController
	local self = setmetatable({}, MinerInfoUIController)
	self.screen = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MinerInfoScreen")
	self.world = world
	self.entityId = nil
	self.enabled = false

	self.screen.Container.CloseButtonContainer.CloseButton.MouseButton1Click:Connect(function()
		self:OnCloseButtonClick()
	end)
	return self
end

function MinerInfoUIController:SetEntityId(entityId: Types.EntityId)
	self.entityId = entityId
end

function MinerInfoUIController.OnCloseButtonClick()
	Events.CloseMinerInfoEvent:Fire()
end

function MinerInfoUIController.UpdateMinerInfo(self: MinerInfoUIController, minerInfo: MinerInfo)
	self.screen.Container.Status.Text = "Miner Status: " .. minerInfo.status
	self.screen.Container.StorageSize.Text = "Storage: "
		.. tostring(minerInfo.storage.currentAmount)
		.. " / "
		.. tostring(minerInfo.storage.capacity)
	self.screen.Container.OreCount.Text = "Ore Veins: " .. tostring(minerInfo.veinsCount)
	self.screen.Container.ProgressBar.Bar.Size = UDim2.fromScale(minerInfo.miningProgress, 1)
end

function MinerInfoUIController.Show(self: MinerInfoUIController)
	self.enabled = true
	self.screen.Enabled = self.enabled
end

function MinerInfoUIController.Hide(self: MinerInfoUIController)
	self.enabled = false
	self.screen.Enabled = self.enabled
end

return MinerInfoUIController
