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
wax.shared.SaveManager = require("Utils/SaveManager")
wax.shared.Settings = {}

require("ExecutorSupport")

-- UI
require("Utils/Connect")

wax.shared.LuaEncode = require("Utils/Serializer/LuaEncode")
wax.shared.Drag = require("Utils/Drag")
wax.shared.Interface = require("Utils/Interface")
wax.shared.Icons = require("Utils/Icons")
wax.shared.Animations = require("Utils/Animations")
wax.shared.Sonner = require("Utils/Sonner")
wax.shared.Highlighter = require("Utils/Highlighter")
wax.shared.Pagination = require("Utils/Pagination")
wax.shared.CodeGen = require("Utils/CodeGen")
wax.shared.Resize = require("Utils/Resize")
wax.shared.Hooking = require("Utils/Hooking")

-- Variables
if not wax.shared.Players.LocalPlayer then
	wax.shared.Players.PlayerAdded:Wait()
end
wax.shared.LocalPlayer = wax.shared.Players.LocalPlayer
wax.shared.PlayerScripts = wax.shared.LocalPlayer:WaitForChild("PlayerScripts")
wax.shared.ExecutorName = string.split(identifyexecutor(), " ")[1]

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
wax.shared.getrawmetatable = getrawmetatable or debug.getmetatable
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

wax.shared.IsClickInput = function(Input: InputObject): boolean
	return Input.UserInputState == Enum.UserInputState.Begin
		and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
end
wax.shared.IsMoveInput = function(Input: InputObject): boolean
	return Input.UserInputState == Enum.UserInputState.Change
		and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch)
end
wax.shared.IsMouseOverFrame = function(Frame: GuiObject, Position: Vector2): boolean
	local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
	return Position.X >= AbsPos.X
		and Position.X <= AbsPos.X + AbsSize.X
		and Position.Y >= AbsPos.Y
		and Position.Y <= AbsPos.Y + AbsSize.Y
end

wax.shared.IsPlayerModule = function(Origin: LocalScript | ModuleScript)
	local PlayerModule = Origin and Origin.FindFirstAncestor(Origin, "PlayerModule") or nil
	return PlayerModule and PlayerModule.Parent == wax.shared.PlayerScripts
end
wax.shared.ShouldIgnore = function(Instance, Origin)
	return wax.shared.Settings.IgnoredRemotesDropdown.Value[Instance.ClassName] == true
		or (wax.shared.Settings.IgnorePlayerModule.Value and wax.shared.IsPlayerModule(Origin))
end

wax.shared.DisplayNumber = function(Number: number)
	if Number % 1 ~= 0 then
		return string.format("%.3f", Number)
	end
	return Number
end
wax.shared.DisplayArgument = function(Argument)
	if typeof(Argument) == "string" then
		return string.format('"%s"', Argument)
	elseif typeof(Argument) == "number" then
		return wax.shared.DisplayNumber(Argument)
	elseif typeof(Argument) == "Vector2" then
		return string.format("%s, %s", wax.shared.DisplayNumber(Argument.X), wax.shared.DisplayNumber(Argument.Y))
	elseif typeof(Argument) == "Vector3" then
		return string.format(
			"%s, %s, %s",
			wax.shared.DisplayNumber(Argument.X),
			wax.shared.DisplayNumber(Argument.Y),
			wax.shared.DisplayNumber(Argument.Z)
		)
	elseif typeof(Argument) == "CFrame" then
		local Components = { Argument:GetComponents() }
		for Index, Value in pairs(Components) do
			Components[Index] = wax.shared.DisplayNumber(Value)
		end
		return table.concat(Components, ", ")
	elseif typeof(Argument) == "table" then
		return "{...}"
	elseif typeof(Argument) == "Instance" then
		return wax.shared.CodeGen.GetFullPath(Argument, true)
	end

	return tostring(Argument)
end

wax.shared.GetTableLength = function(Table)
	local Length = 0
	for _, _ in pairs(Table) do
		Length += 1
	end
	return Length
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

	if restorefunction then
		pcall(restorefunction, gameMetatable.__namecall)
		pcall(restorefunction, gameMetatable.__newindex)
	else
		wax.shared.Hooking.HookMetaMethod(game, "__namecall", wax.shared.NamecallHook)
		wax.shared.Hooking.HookMetaMethod(game, "__newindex", wax.shared.NewIndexHook)
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

-- Load Script
wax.shared.Communicator = Instance.new("BindableEvent")

wax.shared.SetupLoggingConnection = function()
	if wax.shared.LogConnection then
		wax.shared.LogConnection:Disconnect()
	end

	wax.shared.LogFileName = `Cobalt/Logs/{DateTime.now():ToIsoDate():gsub(":", "_")}.log`
	local FileLog = FileLogger.new(wax.shared.LogFileName, FileLogger.LOG_LEVELS.INFO, true)

	return function(RemoteInstance, Type, CallDataFromHook, CallOrderInLog)
		local LogEntry = wax.shared.Logs[Type][RemoteInstance]
		if not LogEntry then
			return
		end

		local success, err = pcall(function()
			local generatedCode = wax.shared.CodeGen:BuildCallCode(setmetatable({
				Instance = RemoteInstance,
				Type = Type,
			}, {
				__index = CallDataFromHook,
			}))

			local comprehensiveDataToSerialize = {
				RemoteInstanceInfo = {
					Name = RemoteInstance and RemoteInstance.Name,
					ClassName = RemoteInstance and RemoteInstance.ClassName,
					Path = RemoteInstance and wax.shared.CodeGen.GetFullPath(RemoteInstance, true),
				},
				EventType = Type,
				CallOrderInLog = CallOrderInLog,
				DataFromHook = CallDataFromHook,
			}

			local serializedEventData = wax.shared.LuaEncode(
				comprehensiveDataToSerialize,
				{ Prettify = true, InsertCycles = true, UseInstancePaths = true }
			)

			local instanceName = RemoteInstance and RemoteInstance.Name or "UnknownInstance"
			local instanceClassName = RemoteInstance and RemoteInstance.ClassName or "UnknownClass"
			local instancePath = RemoteInstance and wax.shared.CodeGen.GetFullPath(RemoteInstance, true)
				or "UnknownPath"

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

if wax.shared.SaveManager:GetState("EnableLogging") then
	local LogConnection = wax.shared.SetupLoggingConnection()
	wax.shared.LogConnection = wax.shared.Connect(wax.shared.Communicator.Event:Connect(LogConnection))
end

wax.shared.Log = require("Utils/Log")
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

require("Window")
require("Spy/Init")
