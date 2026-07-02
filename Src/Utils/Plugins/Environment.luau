--// Imports \\--
local Metadata = require(script.Parent.Metadata)

local CodeGenAPI = require(script.Parent.API.CodeGen)
local SpyAPI = require(script.Parent.API.Spy)
local UIAPI = require(script.Parent.API.UI)

local Environment = {}

function Environment.Create(
	Manager,
	FilePath: string,
	PluginCallback: (...any) -> ...any,
	PluginThread: thread,
	PluginErrored: (string, any) -> ()
)
	local State = {
		CurrentPluginData = nil,
		CurrentPluginSettings = nil,
	}

	local Cobalt = {
		Sonner = wax.shared.Sonner,
		UI = { RemoteInfo = {}, ContextMenu = {} },
		Spy = {},
		CodeGen = {},
		ExecutorSupport = wax.shared.ExecutorSupport,
	}

	Cobalt.Settings = setmetatable({}, {
		__index = function(_, key)
			return wax.shared.SaveManager:GetState(key, false)
		end,
		__newindex = function(_, key, value)
			wax.shared.SaveManager:SetState(key, value)
		end,
	})

	function Cobalt:BindToUnload(Callback: () -> ())
		for _, Plugin in Manager.Registry.Plugins do
			if Plugin.PluginData == State.CurrentPluginData then
				table.insert(Plugin.UnloadCallbacks, Callback)
				return
			end
		end
	end

	UIAPI.Apply(Cobalt, Manager, State)
	SpyAPI.Apply(Cobalt, Manager)
	CodeGenAPI.Apply(Cobalt, Manager)

	setmetatable(Cobalt, {
		__newindex = function(_, Key, Value)
			if Key:lower() == "plugindata" then
				local PluginData = Metadata.Validate(Value, Metadata.TemplatePluginData)

				if not Metadata.IsSupportedInCurrentGame(PluginData) then
					PluginErrored(FilePath, "Plugin is not supported in this game.")

					if coroutine.status(PluginThread) ~= "dead" then
						pcall(task.cancel, PluginThread)
					end

					return
				end

				table.insert(Manager.Registry.Plugins, {
					FilePath = FilePath,
					PluginData = PluginData,
					PluginThread = PluginThread,
					UnloadCallbacks = {},
				})

				State.CurrentPluginData = PluginData
				return
			end

			return rawset(Cobalt, Key, Value)
		end,
	})

	return setmetatable({ Cobalt = Cobalt }, {
		__index = getfenv(PluginCallback),
	})
end

return Environment
