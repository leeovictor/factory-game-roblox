local TableUtils = {}

function TableUtils.Remove(tb, value)
	local res = {}
	for _i, v in ipairs(tb) do
		if v ~= value then
			table.insert(res, v)
		end
	end
	return res
end

function TableUtils.Find(table, predicate)
	for _i, v in ipairs(table) do
		if predicate(v) then
			return v
		end
	end
	return nil
end

function TableUtils.FindIndex(table, predicate)
	for i, v in ipairs(table) do
		if predicate(v) then
			return i
		end
	end
	return nil
end

function TableUtils.RemoveAll(tb, values)
	local valuesSet = {}
	for _i, v in ipairs(values) do
		valuesSet[v] = true
	end

	local res = {}
	for _i, v in ipairs(tb) do
		if not valuesSet[v] then
			table.insert(res, v)
		end
	end
	return res
end

function TableUtils.Filter(tb, predicate)
	local res = {}
	for _i, v in ipairs(tb) do
		if predicate(v) then
			table.insert(res, v)
		end
	end
	return res
end

function TableUtils.Insert(tb, value)
	local res = {}
	for _i, v in ipairs(tb) do
		table.insert(res, v)
	end
	table.insert(res, value)
	return res
end

function TableUtils.InsertAll(tb, values)
	local res = {}
	for _i, v in ipairs(tb) do
		table.insert(res, v)
	end
	for _i, v in ipairs(values) do
		table.insert(res, v)
	end
	return res
end

function TableUtils.DeepCopy(tb)
	local res = {}
	for k, v in pairs(tb) do
		if type(v) == "table" then
			res[k] = TableUtils.DeepCopy(v)
		else
			res[k] = v
		end
	end
	return res
end

function TableUtils.Clone(tb)
	local res = {}
	for _i, v in ipairs(tb) do
		table.insert(res, v)
	end
	return res
end

function TableUtils.Merge(tb1, tb2)
	local res = {}
	for _i, v in ipairs(tb1) do
		table.insert(res, v)
	end
	for _i, v in ipairs(tb2) do
		table.insert(res, v)
	end
	return res
end

function TableUtils.MergeObject(tb1, tb2)
	local res = table.clone(tb1)
	for k, v in pairs(tb2) do
		res[k] = v
	end
	return res
end

function TableUtils.Slice(tb, startIdx, endIdx)
	local res = {}
	for i = startIdx, endIdx do
		table.insert(res, tb[i])
	end
	return res
end

return TableUtils
