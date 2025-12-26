local TestJob = {}

local result = {
    count = 0
}

function TestJob:Execute(...)
    result.count = result.count + 1
    print("TestJob executed with args:", ...)
end

function TestJob:GetResults()
end

return TestJob