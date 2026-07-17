--[[

	Very lightweight checks for various executor functions and reports whether they are working or not.
	Some checks also verify that the function works as intended, not just that it exists.

]]

local ExecutorSupport = {
	FailedChecks = {
		Essential = {},
		NonEssential = {},
		DetectionRisk = {},
	},
}

local BrokenFeatures = {
	["Volcano"] = { "oth", "run_on_actor" },
	["Potassium"] = { "oth" }, -- submit a pr to luau
}

type TestOptions = {
	ExistenceOnly: boolean?,
	Essential: boolean?,
	DetectionRisk: boolean?,
}

local DEFAULT_OPTIONS: TestOptions = {
	ExistenceOnly = false,
	Essential = true,
	DetectionRisk = false,
}

local function CheckFFlagValue(Name: string, Value: any)
	local Success, Result = pcall(getfflag, Name)
	if not Success then
		return false
	end

	if typeof(Result) == "boolean" then
		return Result
	end

	if typeof(Result) == "string" then
		return Result == tostring(Value)
	end

	return false
end

local function test(name: string, Callback: any, options: TestOptions?)
	options = options or DEFAULT_OPTIONS

	local ExistenceOnly = if options.ExistenceOnly == nil then DEFAULT_OPTIONS.ExistenceOnly else options.ExistenceOnly
	local Essential = if options.Essential == nil then DEFAULT_OPTIONS.Essential else options.Essential
	local DetectionRisk = if options.DetectionRisk == nil then DEFAULT_OPTIONS.DetectionRisk else options.DetectionRisk

	local TestFunction = if not ExistenceOnly
		then Callback
		else function()
			assert(typeof(Callback) == "function", string.format("%s is not a function.", name))
			return "Passed nil check."
		end

	local Success, Result
	if BrokenFeatures[wax.shared.ExecutorName] and table.find(BrokenFeatures[wax.shared.ExecutorName], name) then
		Success = false
		Result = "This function/library is broken or can crash your game on this executor."
	else
		Success, Result = pcall(TestFunction)
	end

	ExecutorSupport[name] = {
		IsWorking = Success,
		Details = Result,
		Essential = Essential,
		DetectionRisk = DetectionRisk,
	}

	if not Success then
		if Essential then
			table.insert(ExecutorSupport.FailedChecks.Essential, name)
		else
			table.insert(ExecutorSupport.FailedChecks.NonEssential, name)
		end

		if DetectionRisk then
			table.insert(ExecutorSupport.FailedChecks.DetectionRisk, name)
		end
	end
end

local TEST_EXISTENCE_ONLY = { ExistenceOnly = true }

-- Filesystem Library
test("FileSystem", function()
	for Name, Function in {
		isfile = isfile,
		isfolder = isfolder,
		makefolder = makefolder,
		writefile = writefile,
		appendfile = appendfile,
		readfile = readfile,
		delfile = delfile,
		delfolder = delfolder,
		listfiles = listfiles,
	} do
		assert(typeof(Function) == "function", `{Name} is not a function`)
	end

	local TestDirectory = `Cobalt-Filesystem-Test-{wax.shared.HttpService:GenerateGUID(false)}`
	local TestFile = `{TestDirectory}/test.txt`
	local Success, Error = pcall(function()
		makefolder(TestDirectory)
		assert(isfolder(TestDirectory), "makefolder did not create a directory")

		writefile(TestFile, "Cobalt")
		assert(isfile(TestFile), "writefile did not create a file")
		assert(readfile(TestFile) == "Cobalt", "readfile did not return the written contents")

		appendfile(TestFile, " filesystem test")
		assert(readfile(TestFile) == "Cobalt filesystem test", "appendfile did not append contents")
		assert(#listfiles(TestDirectory) > 0, "listfiles did not return the test file")
	end)

	pcall(delfile, TestFile)
	pcall(delfolder, TestDirectory)
	assert(Success, Error)
end, { Essential = false })

local function SkipOptionalChecks(): boolean
	if not ExecutorSupport.FileSystem.IsWorking or not isfile("Cobalt/Settings.json") then
		return false
	end

	local Success, Settings = pcall(function()
		return wax.shared.HttpService:JSONDecode(readfile("Cobalt/Settings.json"))
	end)
	return Success and Settings.DisableNonEssentialChecks == true
end

-- FFlag Library
test("getfflag", getfflag, TEST_EXISTENCE_ONLY)
test("setfflag", setfflag, TEST_EXISTENCE_ONLY)

-- Actor Library
test("getactors", getactors, TEST_EXISTENCE_ONLY)
test("run_on_actor", run_on_actor, TEST_EXISTENCE_ONLY)
test("create_comm_channel", create_comm_channel, TEST_EXISTENCE_ONLY)

-- Closure Library
test("newcclosure", function()
	assert(typeof(newcclosure) == "function", "newcclosure is not a function")
	local CClosure = newcclosure(function()
		return true
	end)

	assert(typeof(CClosure) == "function", "newcclosure did not return a function")
	assert(CClosure() == true, "Failed to create a new closure")

	assert(debug.info(CClosure, "s") == "[C]", "newcclosure did not create a C closure")
end)

test("iscclosure", function()
	assert(typeof(iscclosure) == "function", "iscclosure is not a function")
	assert(iscclosure(math.abs), "iscclosure did not identify a C closure")
	assert(not iscclosure(function() end), "iscclosure identified a Luau closure as a C closure")
end)

test("islclosure", function()
	assert(typeof(islclosure) == "function", "islclosure is not a function")
	assert(islclosure(function() end), "islclosure did not identify a Luau closure")
	assert(not islclosure(math.abs), "islclosure identified a C closure as a Luau closure")
end)

test("checkcaller", checkcaller, TEST_EXISTENCE_ONLY)
test("getcallingscript", getcallingscript, TEST_EXISTENCE_ONLY)

test("hookfunction", function()
	assert(typeof(hookfunction) == "function", "hookfunction is not a function")

	local function Original(a, b)
		return a + b
	end

	local ref = hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(Original(2, 3) == 6, "Failed to hook a function and change the return value")
	assert(ref(2, 3) == 5, "Did not return the original function")
end)
test("isfunctionhooked", function()
	assert(typeof(isfunctionhooked) == "function", "isfunctionhooked is not a function")
	assert(typeof(hookfunction) == "function", "hookfunction is required for this test")

	local function Original(a, b)
		return a + b
	end

	assert(isfunctionhooked(Original) == false, "isfunctionhooked returned true for an unhooked function")

	hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(isfunctionhooked(Original) == true, "isfunctionhooked returned false for a hooked function")
end)
test("restorefunction", function()
	assert(typeof(restorefunction) == "function", "restorefunction is not a function")
	assert(typeof(hookfunction) == "function", "hookfunction is required for this test")

	local function Original(a, b)
		return a + b
	end

	hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(Original(2, 3) == 6, "Failed to hook a function and change the return value")

	restorefunction(Original)

	assert(Original(2, 3) == 5, "restorefunction did not restore the original function")
end)

test("setstackhidden", function()
	assert(typeof(setstackhidden) == "function", "setstackhidden is not a function")

	local StackCheck = {}

	local CallerFunctionSource = [[
		local StackCheck = ...
		local function CallerFunction()
			return StackCheck[1]()
		end
		return CallerFunction
	]]

	local CallerFunction = (loadstring(CallerFunctionSource, "=CallerFunction") :: (...any) -> ...any)(StackCheck)

	setstackhidden(CallerFunction, true)

	StackCheck[1] = function()
		return debug.info(2, "f") ~= CallerFunction
	end

	local IsHidden = CallerFunction()
	assert(IsHidden == true, "setstackhidden did not hide the function from the stack (debug.info)")

	StackCheck[1] = function()
		return not debug.traceback():find("CallerFunction")
	end

	IsHidden = CallerFunction()
	assert(IsHidden == true, "setstackhidden did not hide the function from the stack (debug.traceback)")

	local TestTable = { math.huge, 0 / 0, 123, 58913 } :: { any }
	setfenv(CallerFunction, TestTable)

	StackCheck[1] = function()
		return getfenv(2) ~= TestTable
	end

	IsHidden = CallerFunction()
	assert(IsHidden == true, "setstackhidden did not hide the function from the stack (getfenv)")

	StackCheck[1] = function()
		return not select(2, pcall(error, "", 3)):find("CallerFunction")
	end

	IsHidden = CallerFunction()
	assert(IsHidden == true, "setstackhidden did not hide the function from the stack (error with level traceback)")
end, { Essential = false, DetectionRisk = true })

test("FilterBase", function()
	assert(AllFilter ~= nil, "AllFilter not found")
	assert(AnyFilter ~= nil, "AnyFilter not found")
	assert(NotFilter ~= nil, "NotFilter not found")
	assert(ArgumentFilter ~= nil, "ArgumentFilter not found")
	assert(InstanceTypeFilter ~= nil, "InstanceTypeFilter not found")
	assert(NamecallFilter ~= nil, "NamecallFilter not found")
end, { Essential = false, DetectionRisk = false })

-- Oth Library
test("oth", function()
	assert(oth ~= nil, "oth library not found")

	assert(typeof(oth.hook) == "function", "oth.hook is not a function")
	assert(hookfunction ~= oth.hook, "oth.hook is an alias of hookfunction")

	assert(typeof(oth.unhook) == "function", "oth.unhook is not a function")
	assert(restorefunction ~= oth.unhook, "oth.unhook is an alias of restorefunction")

	assert(typeof(oth.is_hook_thread) == "function", "oth.is_hook_thread is not a function")
	assert(typeof(oth.get_original_thread) == "function", "oth.get_original_thread is not a function")

	local VIM = Instance.new("VirtualInputManager")
	local Origin = coroutine.running()

	local Working, AttributeChangedCalled = nil, false
	local AttributeChangedConnect = VIM.AttributeChanged.Connect

	local Old
	Old = oth.hook(AttributeChangedConnect, function(...)
		if Working == nil then
			Working = (Origin ~= coroutine.running() and oth.is_hook_thread() and oth.get_original_thread() == Origin)
			return
		end

		return Old(...)
	end)

	AttributeChangedConnect(VIM.AttributeChanged, function(name)
		if name ~= "cobalt" then
			return
		end

		AttributeChangedCalled = true
		coroutine.resume(Origin)
	end)

	VIM:SetAttribute("cobalt", true)
	repeat
		task.wait()
	until Working ~= nil or AttributeChangedCalled
	assert(Working, "oth.hook is not running on a seperate thread")

	local Success, Error = pcall(oth.unhook, AttributeChangedConnect, Old)
	assert(Success, "oth.unhook failed: " .. tostring(Error))
	VIM:Destroy()

	if not SkipOptionalChecks() then
		assert(typeof(getrawmetatable) == "function", "getrawmetatable is required to validate oth __namecall returns")
		assert(
			typeof(getnamecallmethod) == "function",
			"getnamecallmethod is required to validate oth __namecall returns"
		)

		local function CheckInvokeResult(Result, Context)
			if Result.n ~= 4 then
				return false, `{Context}: returned {Result.n} values instead of 4`
			end
			if Result[1] ~= "expected" then
				return false, `{Context}: did not preserve the first return value`
			end
			if Result[2] ~= 123 then
				return false, `{Context}: did not preserve the second return value`
			end
			if Result[3] ~= nil then
				return false, `{Context}: did not preserve the nil return value`
			end
			if Result[4] ~= "tail" then
				return false, `{Context}: did not preserve the tail return value`
			end

			return true
		end

		local Bindable = Instance.new("BindableFunction")
		Bindable.OnInvoke = function()
			return "expected", 123, nil, "tail"
		end

		local SuccededInsideHook, InsideError = false, nil

		local OldNamecall
		OldNamecall = oth.hook(getrawmetatable(game).__namecall, function(...)
			local self = ...
			local Method = getnamecallmethod()

			if self == Bindable and Method == "Invoke" then
				pcall(function() end)

				local Result = table.pack(OldNamecall(...))

				SuccededInsideHook, InsideError = CheckInvokeResult(Result, "Result corruption in __namecall oth hook")

				return table.unpack(Result, 1, Result.n)
			end

			return OldNamecall(...)
		end)

		local Result = table.pack(Bindable:Invoke())
		pcall(oth.unhook, getrawmetatable(game).__namecall)
		Bindable:Destroy()

		assert(SuccededInsideHook, InsideError)
		assert(CheckInvokeResult(Result, "Result corruption post oth hook and pcall"))
	end
end, { Essential = false, DetectionRisk = true })

-- RakNet Library
test("raknet", function()
	assert(raknet ~= nil, "raknet library not found")

	assert(typeof(raknet.add_send_hook) == "function", "raknet.add_send_hook is not a function")
	assert(typeof(raknet.remove_send_hook) == "function", "raknet.remove_send_hook is not a function")

	assert(typeof(raknet.add_receive_hook) == "function", "raknet.add_receive_hook is not a function")
	assert(typeof(raknet.remove_receive_hook) == "function", "raknet.remove_receive_hook is not a function")

	assert(typeof(raknet.send) == "function", "raknet.send is not a function")
	assert(typeof(raknet.receive) == "function", "raknet.receive is not a function")

	if typeof(raknet.is_enabled) == "function" then
		assert(raknet.is_enabled() == true, "raknet is not enabled")
	else
		local Success, Error = pcall(function()
			local hook = raknet.add_send_hook(function() end)
			raknet.remove_send_hook(hook)
		end)
	
		assert(Success, "raknet failed to hook (not enabled?): " .. tostring(Error))
	end
end, { Essential = false })

-- Metamethod
test("hookmetamethod", function()
	assert(typeof(hookmetamethod) == "function", "hookmetamethod is not a function")

	local object = setmetatable({}, {
		__index = newcclosure(function()
			return false
		end),
		__metatable = "Locked!",
	})

	local ref = hookmetamethod(object, "__index", function()
		return true
	end)

	assert(object.test == true, "Failed to hook a metamethod and change the return value")
	assert(ref() == false, "Did not return the original function")
end)
test("getnamecallmethod", function()
	assert(typeof(getnamecallmethod) == "function", "getnamecallmethod is not a function")

	pcall(function()
		game:TEST_NAMECALL_METHOD()
	end)

	assert(getnamecallmethod() == "TEST_NAMECALL_METHOD", "getnamecallmethod did not return the real namecall method")
end)
test("getrawmetatable", function()
	assert(typeof(getrawmetatable) == "function", "getrawmetatable is not a function")

	local BaseLockedMetatable = {
		__index = function()
			return false
		end,
		__metatable = "Locked!",
	}

	local TestMetatable = setmetatable({}, BaseLockedMetatable)

	local FetchedMetatable = getrawmetatable(TestMetatable)
	assert(typeof(FetchedMetatable) == "table", "getrawmetatable did not return a table")

	assert(FetchedMetatable.__index() == false, "getrawmetatable did not return the correct metatable [__index()]")
	assert(
		FetchedMetatable.__metatable == "Locked!",
		"getrawmetatable did not return the correct metatable [locked mt check]"
	)

	assert(
		FetchedMetatable == BaseLockedMetatable,
		"getrawmetatable did not return the correct metatable [mt eq check]"
	)
end)

-- Instance Library
test("getcallbackvalue", function()
	assert(typeof(getcallbackvalue) == "function", "getcallbackvalue is not a function")

	local bindable = Instance.new("BindableFunction")
	local InvokeRan = false
	local InvokeFunction = function(value)
		InvokeRan = true
		return value * 2
	end
	bindable.OnInvoke = InvokeFunction

	local FetchedInvoke = getcallbackvalue(bindable, "OnInvoke")
	bindable:Destroy()

	assert(typeof(FetchedInvoke) == "function", "getcallbackvalue did not return a function")

	assert(FetchedInvoke(5) == 10, "getcallbackvalue's function return did not match expected value")
	assert(InvokeRan, "getcallbackvalue's function did not run")
end)
test("getnilinstances", function()
	assert(typeof(getnilinstances) == "function", "getnilinstances is not a function")

	local NilInstances = getnilinstances()
	assert(typeof(NilInstances) == "table", "getnilinstances did not return a table")
end)
test("getconnections", function()
	assert(typeof(getconnections) == "function", "getconnections is not a function")

	local Event = Instance.new("BindableEvent")
	local ConnectionFunction = function() end
	local OnceFunction = function() end

	Event.Event:Connect(ConnectionFunction)
	Event.Event:Once(OnceFunction)
	task.spawn(function()
		Event.Event:Wait()
	end)

	local Connections = getconnections(Event.Event)

	assert(typeof(Connections) == "table", "getconnections did not return a table")
	assert(#Connections == 3, "getconnections did not return the correct number of connections")

	local FoundFunctions = {}
	for _, Connection in Connections do
		local _, ConnFunc = pcall(function()
			return Connection.Function
		end)

		if typeof(ConnFunc) == "function" then
			table.insert(FoundFunctions, ConnFunc)
		end
	end

	assert(
		table.find(FoundFunctions, ConnectionFunction) ~= nil,
		"getconnections did not return the correct connection [:Connect()]"
	)
	assert(
		table.find(FoundFunctions, OnceFunction) ~= nil,
		"getconnections did not return the correct connection [:Once()]"
	)

	Event:Destroy()
end)
test("firesignal", function()
	assert(typeof(firesignal) == "function", "firesignal is not a function")

	local event = Instance.new("BindableEvent")
	local fired = false

	event.Event:Once(function(value)
		fired = value
	end)

	firesignal(event.Event, true)
	task.wait(0.1)
	event:Destroy()

	assert(fired, "Failed to fire a BindableEvent")
end)
test("cloneref", function()
	assert(typeof(cloneref) == "function", "cloneref is not a function")

	local ref = cloneref(game)
	assert(ref ~= game, "cloneref did not create a ref to instance")
	assert(typeof(ref) == "Instance", "cloneref did not return an instance")
end)
test("compareinstances", function()
	assert(typeof(compareinstances) == "function", "compareinstances is not a function")
	assert(typeof(cloneref) == "function", "cloneref is required for this test")

	assert(compareinstances(game, cloneref(game)) == true, "compareinstances did not return true for the same instance")
	assert(compareinstances(game, workspace) == false, "compareinstances did not return false for different instances")
end)

if CheckFFlagValue("DebugRunParallelLuaOnMainThread", false) and not ExecutorSupport["run_on_actor"].IsWorking then
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end

		local GameUsesActors = false

		local CategoryToSearch = { game:QueryDescendants("Actor") }
		if ExecutorSupport["getnilinstances"].IsWorking then
			table.insert(CategoryToSearch, getnilinstances())
		end

		for _, Category in CategoryToSearch do
			if GameUsesActors then
				break
			end

			for _, Instance in Category do
				if not Instance:IsA("Actor") then
					continue
				end

				GameUsesActors = true
				break
			end
		end

		if not GameUsesActors then
			return
		end

		local bindable = Instance.new("BindableFunction")

		function bindable.OnInvoke(response)
			if response == "Enable Fix" then
				setfflag("DebugRunParallelLuaOnMainThread", "true")
				wax.shared.StarterGui:SetCore("SendNotification", {
					Title = "Cobalt",
					Text = "Please rejoin for the fix to take effect!",
					Duration = math.huge,
				})
			end

			bindable:Destroy()
		end

		wax.shared.StarterGui:SetCore("SendNotification", {
			Title = "Cobalt",
			Text = "This game may use remotes in a way that your executor can't intercept. You can enable the fix and rejoin to detect them.",
			Duration = math.huge,
			Callback = bindable,
			Button1 = "Enable Fix",
			Button2 = "Dismiss",
		})
	end)
end

function ExecutorSupport.ValidateCustomAssets(AssetManager)
	test("getcustomasset", function()
		assert(typeof(getcustomasset) == "function", "getcustomasset is not a function")

		local Success, Error = AssetManager.ValidateCustomFonts()
		assert(Success, Error)
	end, { Essential = false })
end

return ExecutorSupport
