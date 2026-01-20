local ObjectPool = {}
ObjectPool.__index = ObjectPool

export type ObjectPoolData = {
	createFunc: () -> Instance,
	pool: { Instance },
	inUse: { Instance },
}

export type ObjectPool = typeof(setmetatable({} :: ObjectPoolData, ObjectPool))

function ObjectPool.new(createFunc: () -> Instance): ObjectPool
	local self = setmetatable({}, ObjectPool)
	self.createFunc = createFunc
	self.pool = {}
	self.inUse = {}
	return self
end

function ObjectPool:Acquire(...)
	local obj
	if #self.pool > 0 then
		obj = table.remove(self.pool)
	elseif #self.inUse + #self.pool then
		obj = self.createFunc(...)
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
