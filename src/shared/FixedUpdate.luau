local RunService = game:GetService("RunService")

local FixedUpdate = {}
FixedUpdate.__index = FixedUpdate
function FixedUpdate.new(fixedDeltaTime: number)
    local self = setmetatable({}, FixedUpdate)
    self.fixedDeltaTime = fixedDeltaTime
    self.accumulatedTime = 0
    self.sameFrameCallCount = 0
    return self
end

function FixedUpdate:Connect(callback)
    return RunService.Heartbeat:Connect(function(dt)
        self.accumulatedTime += dt
        self.sameFrameCallCount = 0
        while self.accumulatedTime >= self.fixedDeltaTime do
            if self.sameFrameCallCount > 3 then
                warn("Frame rate is too low to keep up with FixedUpdate. Skipping remaining FixedUpdate calls this frame to avoid build-up more lag.")
                self.accumulatedTime = 0
                break
            end
            callback(self.fixedDeltaTime)
            self.accumulatedTime -=self.fixedDeltaTime
            self.sameFrameCallCount += 1
        end
    end)
end

return FixedUpdate