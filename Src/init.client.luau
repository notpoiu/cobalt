local FileLogger = require(script.Utils.FileLog)

-- Environment
for _, Service in pairs({
	"ContentProvider",
	"CoreGui",
	"TweenService",
	"Players",
	"RunService",
	"HttpService",
	"UserInputService",
	"TextService",
	"StarterGui",
}) do
	wax.shared[Service] = cloneref(game:GetService(Service))
end

wax.shared.CobaltVerificationToken = wax.shared.HttpService:GenerateGUID()
wax.shared.SaveManager = require(script.Utils.SaveManager)
wax.shared.Settings = {}

wax.shared.Hooks = {}

-- Executor Support
wax.shared.ExecutorName = identifyexecutor()
wax.shared.ExecutorSupport = require(script.ExecutorSupport)

-- Utils
require(script.Utils.Connect)
wax.shared.Hooking = require(script.Utils.Hooking)

-- UI
wax.shared.Sonner = require(script.Utils.UI.Sonner)

-- Code Generation
local LuaEncode = require(script.Utils.Serializer.LuaEncode)
wax.shared.LuaEncode = LuaEncode

local CodeGen = require(script.Utils.CodeGen)

-- Variables
if not wax.shared.Players.LocalPlayer then
	wax.shared.Players.PlayerAdded:Wait()
end
wax.shared.LocalPlayer = wax.shared.Players.LocalPlayer
wax.shared.PlayerScripts = cloneref(wax.shared.LocalPlayer:WaitForChild("PlayerScripts"))

-- Functions
wax.shared.gethui = gethui or function()
	return wax.shared.CoreGui
end
wax.shared.checkcaller = checkcaller or function()
	return nil
end
wax.shared.restorefunction = function(Function: (...any) -> ...any, Silent: boolean?)
	local Original = wax.shared.Hooks[Function]

	if Silent and not Original then
		return
	end

	assert(Original, "Function not hooked")

	if restorefunction and isfunctionhooked(Function) then
		restorefunction(Function)
	else
		wax.shared.Hooking.HookFunction(Function, Original)
	end

	wax.shared.Hooks[Function] = nil
end
wax.shared.getrawmetatable = wax.shared.ExecutorSupport["getrawmetatable"].IsWorking
		and (getrawmetatable or debug.getmetatable)
	or function()
		return setmetatable({}, {
			__index = function()
				return function() end
			end,
		})
	end

wax.shared.newcclosure = wax.shared.ExecutorName == "AWP"
		and function(f)
			local env = getfenv(f)
			local x = setmetatable({
				__F = f,
			}, {
				__index = env,
				__newindex = env,
			})

			local nf = function(...)
				return __F(...)
			end

			setfenv(nf, x) -- set func env (env of nf gets deoptimized)
			return newcclosure(nf)
		end
	or newcclosure
wax.shared.queue_on_teleport = queue_on_teleport or queueonteleport or function(...) end

wax.shared.IsPlayerModule = function(Origin: LocalScript | ModuleScript, Instance: Instance): boolean
	if Instance and Instance.ClassName ~= "BindableEvent" then
		return false
	end

	if not Origin or typeof(Origin) ~= "Instance" or not Origin.IsA(Origin, "LuaSourceContainer") then
		return false
	end

	local PlayerModule = Origin and Origin.FindFirstAncestor(Origin, "PlayerModule") or nil
	if not PlayerModule then
		return false
	end

	if PlayerModule.Parent == nil then
		return true
	end

	return compareinstances(PlayerModule.Parent, wax.shared.PlayerScripts)
end
wax.shared.ShouldIgnore = function(Instance, Origin)
	return wax.shared.Settings.IgnoredRemotesDropdown.Value[Instance.ClassName] == true
		or (wax.shared.Settings.IgnorePlayerModule.Value and wax.shared.IsPlayerModule(Origin, Instance))
end

wax.shared.GetTableLength = function(Table)
	if Table["n"] then
		return Table.n
	end

	local Length = 0
	for _, _ in pairs(Table) do
		Length += 1
	end
	return Length
end
wax.shared.JoinTable = function(Table, Prefix, Suffix)
	local FinalString = ""
	for _, Value in pairs(Table) do
		FinalString ..= Prefix .. tostring(Value) .. Suffix
	end

	FinalString = string.sub(FinalString, 1, string.len(FinalString) - string.len(Suffix))

	return FinalString
end
wax.shared.GetTextBounds = function(Text: string, Font: Font, Size: number, Width: number?): (number, number)
	local Params = Instance.new("GetTextBoundsParams")
	Params.Text = Text
	Params.RichText = true
	Params.Font = Font
	Params.Size = Size
	Params.Width = Width or workspace.CurrentCamera.ViewportSize.X - 32

	local Bounds = wax.shared.TextService:GetTextBoundsAsync(Params)
	return Bounds.X, Bounds.Y
end

wax.shared.Unloaded = false
wax.shared.Unload = function()
	for _, Connection in pairs(wax.shared.Connections) do
		wax.shared.Disconnect(Connection)
	end

	local gameMetatable = wax.shared.getrawmetatable(game)

	if wax.shared.ExecutorSupport["oth"].IsWorking then
		pcall(oth.unhook, gameMetatable.__namecall, wax.shared.NamecallHook)
		pcall(oth.unhook, gameMetatable.__newindex, wax.shared.NewIndexHook)
	else
		if restorefunction and not wax.shared.AlternativeEnabled then
			pcall(restorefunction, gameMetatable.__namecall)
			pcall(restorefunction, gameMetatable.__newindex)
		else
			wax.shared.Hooking.HookMetaMethod(game, "__namecall", wax.shared.NamecallHook)
			wax.shared.Hooking.HookMetaMethod(game, "__newindex", wax.shared.NewIndexHook)
		end
	end

	for Function, Original in pairs(wax.shared.Hooks) do
		task.spawn(pcall, wax.shared.restorefunction, Function, true)
	end

	if wax.shared.ActorCommunicator then
		wax.shared.ActorCommunicator:Fire("Unload")
	end

	wax.shared.Communicator:Destroy()
	wax.shared.ScreenGui:Destroy()

	wax.shared.Unloaded = true
end

local AnticheatData = require(script.Utils.Anticheats.Main)

-- Load Script
wax.shared.Communicator = Instance.new("BindableEvent")

wax.shared.SetupLoggingConnection = function()
	if wax.shared.LogConnection then
		wax.shared.LogConnection:Disconnect()
	end

	wax.shared.LogFileName = `Cobalt/Logs/{DateTime.now():ToIsoDate():gsub(":", "_")}.log`
	local FileLog = FileLogger.new(wax.shared.LogFileName, FileLogger.LOG_LEVELS.INFO, true)

	return function(RemoteInstance, Type, CallOrderInLog)
		local LogEntry = wax.shared.Logs[Type][RemoteInstance]
		if not LogEntry then
			return
		end

		local CallDataFromHook = LogEntry.Calls[CallOrderInLog]

		local success, err = pcall(function()
			local generatedCode = CodeGen:BuildCallCode(setmetatable({
				Instance = RemoteInstance,
				Type = Type,
			}, {
				__index = CallDataFromHook,
			}) :: any)

			local comprehensiveDataToSerialize = {
				RemoteInstanceInfo = {
					Name = RemoteInstance and RemoteInstance.Name,
					ClassName = RemoteInstance and RemoteInstance.ClassName,
					Path = RemoteInstance and CodeGen.GetFullPath(RemoteInstance, true),
				},
				EventType = Type,
				CallOrderInLog = CallOrderInLog,
				DataFromHook = CallDataFromHook,
			}

			local serializedEventData = LuaEncode(
				comprehensiveDataToSerialize,
				{ Prettify = true, InsertCycles = true, UseInstancePaths = true }
			)

			local instanceName = RemoteInstance and RemoteInstance.Name or "UnknownInstance"
			local instanceClassName = RemoteInstance and RemoteInstance.ClassName or "UnknownClass"
			local instancePath = RemoteInstance and CodeGen.GetFullPath(RemoteInstance, true) or "UnknownPath"

			local logParts = {
				("Instance: %s (%s)"):format(instanceName, instanceClassName),
				("Path: %s"):format(instancePath),
				("Call Order In Log: %s"):format(CallOrderInLog or "N/A"),
				"-------------------- Event Data --------------------",
				serializedEventData,
				"-------------------- Generated Code --------------------",
				generatedCode,
			}
			local logMessage = table.concat(logParts, "\n\t")
			local threadId = ("%s:%s"):format(Type or "S", instanceName)

			FileLog:Info(threadId, logMessage)
		end)

		if not success then
			local instanceNameForError = RemoteInstance and RemoteInstance.Name or "Unknown"
			FileLog:Error(
				"Logger",
				("Failed to log remote communication for %s:%s - %s"):format(
					Type or "UnknownType",
					instanceNameForError,
					tostring(err)
				)
			)

			warn(
				("Cobalt: Failed to log remote communication for %s:%s - %s"):format(
					Type or "UnknownType",
					instanceNameForError,
					tostring(err)
				)
			)
		end
	end
end

if wax.shared.SaveManager:GetState("EnableLogging", false) then
	local LogConnection = wax.shared.SetupLoggingConnection()
	wax.shared.LogConnection = wax.shared.Connect(wax.shared.Communicator.Event:Connect(LogConnection))
end

wax.shared.Log = require(script.Utils.Log)
wax.shared.Logs = {
	Outgoing = {},
	Incoming = {},
}

wax.shared.NewLog = function(Instance, Type, Method, CallingScript)
	local Log =
		wax.shared.Log.new(Instance, Type, Method, wax.shared.GetTableLength(wax.shared.Logs[Type]) + 1, CallingScript)
	wax.shared.Logs[Type][Instance] = Log
	return Log
end

require(script.Window)
require(script.Spy.Init)

wax.shared.Connect(wax.shared.LocalPlayer.OnTeleport:Connect(function()
	if not wax.shared.SaveManager:GetState("ExecuteOnTeleport", false) then
		return
	end

	-- getgenv().COBALT_LATEST_URL for dev environments
	local CobaltURL = getgenv().COBALT_LATEST_URL
		or "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau"
	wax.shared.queue_on_teleport(string.format(
		[[
		if getgenv().CobaltAutoExecuted then
			return
		end

		getgenv().CobaltAutoExecuted = true
		loadstring(game:HttpGet("%s"))()
	]],
		CobaltURL
	))
end))

task.wait(1)
if AnticheatData.Disabled then
	wax.shared.Sonner.success(`Cobalt has bypassed {AnticheatData.Name} (anticheat detected)`)
end
