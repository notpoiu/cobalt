local Errors = {}

function Errors.PluginErrored(Manager, FilePath, Error)
	if #Manager.Registry.Errored == 0 then
		wax.shared.Sonner.error(`Failed to load plugin: {FilePath}.`)
	end

	local PluginIndex
	do
		for Idx, Plugin in Manager.Registry.Plugins do
			if Plugin.FilePath ~= FilePath then
				continue
			end

			PluginIndex = Idx
			break
		end
	end

	if PluginIndex then
		local PluginInfo = table.remove(Manager.Registry.Plugins, PluginIndex)
		for _, Callback in PluginInfo.UnloadCallbacks or {} do
			task.spawn(pcall, Callback)
		end

		local PluginData = PluginInfo.PluginData or {}
		table.insert(Manager.Registry.Errored, {
			FilePath = PluginInfo.FilePath,
			Name = PluginData.Name,
			Author = PluginData.Author,
			Version = PluginData.Version,
			Error = Error,
		})
	else
		table.insert(Manager.Registry.Errored, {
			FilePath = FilePath,
			Error = Error,
		})
	end
end

return Errors
