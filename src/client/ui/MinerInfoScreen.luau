local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Packages.matter)
local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Events)

local MinerInfoUIController = {}
MinerInfoUIController.__index = MinerInfoUIController

export type MinerInfo = {
    status: string;
    storage: {
        currentAmount: number;
        capacity: number;
    };
    veinsCount: number;
    miningProgress: number;
}

type MinerInfoUIControllerData = {
    screen: any;
    world: typeof(matter.World);
    entityId: number?;
}

export type MinerInfoUIController = typeof(setmetatable({} :: MinerInfoUIControllerData, MinerInfoUIController))

function MinerInfoUIController.new(world: typeof(matter.World)): MinerInfoUIController
    local self = setmetatable({}, MinerInfoUIController)
    self.screen = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MinerInfoScreen")
    self.world = world;
    self.entityId = nil

    self.screen.Container.CloseButtonContainer.CloseButton.MouseButton1Click:Connect(function()
        self:OnCloseButtonClick()
    end)
    return self
end

function MinerInfoUIController.OnCloseButtonClick(self: MinerInfoUIController)
    Events.CloseMinerInfoEvent:Fire(self.entityId)
end

function MinerInfoUIController.UpdateMinerInfo(self: MinerInfoUIController, minerInfo: MinerInfo)
    self.screen.Container.Status.Text = "Miner Status: " .. minerInfo.status
    self.screen.Container.StorageSize.Text = "Storage: " .. tostring(minerInfo.storage.currentAmount) .. " / " .. tostring(minerInfo.storage.capacity)
    self.screen.Container.OreCount.Text = "Ore Veins: " .. tostring(minerInfo.veinsCount)
    self.screen.Container.ProgressBar.Bar.Size = UDim2.new(minerInfo.miningProgress, 0, 1, 0)
end

function MinerInfoUIController.Show(self: MinerInfoUIController, entityId: number)
    self.entityId = entityId
    self.screen.Enabled = true
end

function MinerInfoUIController.Hide(self: MinerInfoUIController)
    self.entityId = nil
    self.screen.Enabled = false
end

return MinerInfoUIController