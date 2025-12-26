local ReplicatedStorage = game:GetService("ReplicatedStorage")
local signal = require(ReplicatedStorage.Packages.signal)

return {
    BuildFacility = signal.new(),
    DeconstructFacility = signal.new(),
    CreateBelt = signal.new(),
}