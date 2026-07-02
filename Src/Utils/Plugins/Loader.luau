--// Imports \\--
local Environment = require(script.Parent.Environment)
local Errors = require(script.Parent.Errors)

local FileHelperUtil = require("@src/Utils/FileHelper")

local PluginFiles = FileHelperUtil.new("Cobalt/Plugins")

local Loader = {}

function Loader.SetupPlugins(Manager)
	for _, FilePath in PluginFiles:ListFiles() do
		local Plugin, CompileError =
			loadstring(PluginFiles:ReadFile(FilePath), `CobaltPlugin-{PluginFiles:GetFileName(FilePath)}`)
		if CompileError then
			Errors.PluginErrored(Manager, FilePath, CompileError)
			continue
		end

		local PluginThread = task.spawn(function()
			coroutine.yield()

			local Success, Error = pcall(Plugin)
			if not Success then
				Errors.PluginErrored(Manager, FilePath, Error)
			end
		end)

		setfenv(
			Plugin,
			Environment.Create(Manager, FilePath, Plugin, PluginThread, function(ErrorFilePath, Error)
				Errors.PluginErrored(Manager, ErrorFilePath, Error)
			end)
		)

		coroutine.resume(PluginThread)
	end
end

return Loader
