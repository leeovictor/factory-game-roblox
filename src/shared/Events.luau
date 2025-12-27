local ReplicatedStorage = game:GetService("ReplicatedStorage")
local signal = require(ReplicatedStorage.Packages.signal)

return {
    CloseMinerInfoEvent = signal.new(),
    MinerModelClicked = signal.new(),
}