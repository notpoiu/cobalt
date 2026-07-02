--// Imports \\--
local Bridge = require(script.Parent.Bridge)
local Loader = require(script.Parent.Loader)
local Registry = require(script.Parent.Registry)

--// Manager \\--
local Manager = {
	Registry = Registry,
	HasInterceptors = false,
	HasCodeGenInterceptors = false,
	Initialized = false,
}

function Manager.AttachWindow(WindowBridge)
	Bridge.Attach(WindowBridge)
end

function Manager.SetupPlugins()
	Loader.SetupPlugins(Manager)
	Manager.Initialized = true
end

return Manager
