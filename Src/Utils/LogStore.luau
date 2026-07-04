local LogStore = {}

function LogStore.GetMatching(FilterInstance: Instance?, FilterType: string?): { any }
	local Logs = {}

	for Type, LogCategory in pairs(wax.shared.Logs) do
		if FilterType and Type ~= FilterType then
			continue
		end

		for _, Log in pairs(LogCategory) do
			if FilterInstance and Log.Instance ~= FilterInstance then
				continue
			end

			table.insert(Logs, Log)
		end
	end

	return Logs
end

function LogStore.Clear(FilterInstance: Instance?, FilterType: string?): { any }
	local ClearedLogs = LogStore.GetMatching(FilterInstance, FilterType)

	for _, Log in ClearedLogs do
		Log:ClearCalls()
	end

	return ClearedLogs
end

return LogStore
