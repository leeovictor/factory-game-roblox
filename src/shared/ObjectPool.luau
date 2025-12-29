local ObjectPool = {}
ObjectPool.__index = ObjectPool
function ObjectPool.new(createFunc: () -> Instance, maxSize: number)
	local self = setmetatable({}, ObjectPool)
	self.createFunc = createFunc
	self.pool = {}
	self.inUse = {}
	self.maxSize = maxSize or 100
	return self
end

function ObjectPool:Acquire(...)
	local obj
	if #self.pool > 0 then
		obj = table.remove(self.pool)
	elseif #self.inUse + #self.pool < self.maxSize then
		obj = self.createFunc(...)
	else
		error("ObjectPool: Max size reached")
	end
	table.insert(self.inUse, obj)
	return obj
end

function ObjectPool:Release(obj: Instance)
	for i, v in ipairs(self.inUse) do
		if v == obj then
			table.remove(self.inUse, i)
			table.insert(self.pool, obj)
			return
		end
	end
end

function ObjectPool:ReleaseAll()
	for _, obj in ipairs(self.inUse) do
		table.insert(self.pool, obj)
	end
	self.inUse = {}
end

function ObjectPool:GetSize()
	return #self.pool + #self.inUse
end

function ObjectPool:Clear()
	self.pool = {}
	self.inUse = {}
end

return ObjectPool
