local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local matter = require(ReplicatedStorage.Matter)

export type ContextActionOptions = {
	createButton: boolean?,
	inputTypes: { Enum.KeyCode | Enum.UserInputType }?,
}
type NormalizedOptions = {
	createButton: boolean,
	inputTypes: { Enum.KeyCode | Enum.UserInputType },
}

local function normalizeOptions(options: ContextActionOptions?): NormalizedOptions
	return {
		createButton = if options and options.createButton ~= nil then options.createButton else false,
		inputTypes = if options and options.inputTypes then options.inputTypes else {},
	}
end

local function cleanup(storage)
	ContextActionService:UnbindAction(storage.actionName)
end

local function diffTables(left: { unknown }?, right: { unknown }?): boolean
	if left and right then
		if left == right then
			return false
		end

		local size = 0

		for index, value in left do
			if value ~= right[index] then
				return true
			end
			size += 1
		end

		for _ in right do
			size -= 1
		end

		if size ~= 0 then
			return true
		end

		return false
	end

	return true
end

local function useContextAction(
	actionName: string,
	callback: (string, Enum.UserInputState, InputObject) -> Enum.ContextActionResult?,
	options
)
	local storage = matter.useHookState(actionName, cleanup)

	if not storage.actionName then
		local opts = normalizeOptions(options)
		storage.actionName = actionName

		ContextActionService:BindAction(actionName, function(...)
			return storage.callback(...)
		end, opts.createButton, unpack(opts.inputTypes))
	end

	storage.callback = callback
end

local function useChange(dependencies: { unknown }, discriminator: unknown?): boolean
	local storage = matter.useHookState(discriminator)
	local previous = storage.dependencies
	storage.dependencies = dependencies
	return diffTables(dependencies, previous)
end

return {
	useContextAction = useContextAction,
	useChange = useChange,
}
