local GetNilCode = [[local function GetNil(Name, DebugId)
	for _, Object in getnilinstances() do
		if Object.Name == Name and Object:GetDebugId() == DebugId then
			return Object
		end
	end
end]]

local GetEventReferenceCode = [[local function GetEventReference(options)
	local Hash, Index, ExcludeExecutor, Path = options.Hash, options.Index, options.ExcludeExecutor, options.Path
	local Retrieved = nil

	if filtergc then
		Retrieved = filtergc("function", {
			Hash = Hash,
			IgnoreExecutor = ExcludeExecutor
		}, true)
	else
		for _, Func in getgc() do
			if typeof(Func) ~= "function" then
				continue
			end

			if ExcludeExecutor and isexecutorclosure(Func) then
				continue
			end
			
			if getfunctionhash(Func) == Hash then
				Retrieved = Func
				break
			end
		end
	end

	assert(Retrieved, "Could not find function with hash " .. tostring(Hash))
	local Value = debug.getupvalue(Retrieved, Index)

	if Path then
		for _, Key in next, Path do
			Value = Value[Key]
		end
	end

	return Value
end]]

return {
    GetNilCode = GetNilCode,
    GetEventReferenceCode = GetEventReferenceCode,
}