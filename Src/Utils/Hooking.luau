local Hooking = {
	IncludeInStackFunctions = {},
}

local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false
wax.shared.AlternativeEnabled = AlternativeEnabled
wax.shared.CobaltLuaSetStackHidden = false

local BypassState = wax.shared.SaveManager:GetState("AnticheatBypass")
local BypassEnabled = if typeof(BypassState) == "boolean" then BypassState else true

Hooking.SetStackHidden = sethiddenstack
	or setstackhidden
	or (function()
		if AlternativeEnabled then
			return function() end
		end

		wax.shared.CobaltLuaSetStackHidden = true

		local OldDebugTraceback, OldDebugInfo = debug.traceback, debug.info

		local function setstackhidden(functionOrLevel: ((...any) -> ...any) | number, hidden: boolean)
			local Success, CallingFunction = pcall(function()
				if typeof(functionOrLevel) == "number" then
					return OldDebugInfo(functionOrLevel + 2, "f")
				end

				return functionOrLevel
			end)

			assert(
				Success or not CallingFunction,
				`invalid argument #1 to 'setstackhidden' ({typeof(functionOrLevel) == "number" and "level out of range" or `function or number expected, got {typeof(
					functionOrLevel
				)}`})`
			)
			assert(
				typeof(hidden) == "boolean",
				"invalid argument #2 to 'setstackhidden' (boolean expected, got " .. typeof(hidden) .. ")"
			)

			shared.Hooking.IncludeInStackFunctions[CallingFunction] = not hidden
		end

		if restorefunction and isfunctionhooked then
			for _, callback in pairs({ OldDebugTraceback, OldDebugInfo }) do
				if not isfunctionhooked(callback) then
					continue
				end

				pcall(restorefunction, callback)
			end
		elseif shared.CobaltSetStackHiddenLuau then
			return setstackhidden
		end

		shared.CobaltSetStackHiddenLuau = true
		shared.Hooking = Hooking

		local function ValidTraceback(s)
			local dotPos = string.find(s, "%.")
			local colonPos = string.find(s, ":")

			if not dotPos then
				return false
			end

			if not colonPos then
				return true
			end

			return dotPos < colonPos
		end

		local function TracebackLines(str, lvl)
			local pos = lvl
			return function()
				if not pos then
					return nil
				end
				local p1, p2 = string.find(str, "\r?\n", pos)
				local line
				if p1 then
					line = str:sub(pos, p1 - 1)
					pos = p2 + 1
				else
					line = str:sub(pos)
					pos = nil
				end
				return line
			end
		end

		OldDebugTraceback = hookfunction(getrenv().debug.traceback, function(...)
			if checkcaller() or not (pcall(OldDebugTraceback, ...)) then
				return OldDebugTraceback(...)
			end

			local StartingString, StackLevel = ...
			local Traceback = OldDebugTraceback(...)
			local NewTraceback = {}

			if typeof(StartingString) == "string" or typeof(StartingString) == "number" then
				table.insert(NewTraceback, tostring(StartingString))
			end
			if typeof(StackLevel) ~= "number" or not tonumber(Stacklevel) then
				StackLevel = 1
			else
				StackLevel = math.floor(tonumber(StackLevel))
			end

			for Line in TracebackLines(Traceback, StackLevel) do
				if not ValidTraceback(Line) then
					continue
				end

				table.insert(NewTraceback, Line)
			end

			return table.concat(NewTraceback, "\n")
		end)

		OldDebugInfo = hookfunction(getrenv().debug.info, function(...)
			local ToInspect, LevelOrInfo, _ThreadInfo = ...

			if
				checkcaller()
				or typeof(ToInspect) == "function"
				or typeof(ToInspect) == "thread"
				or not pcall(function(LevelOrInfo) -- Validate arguments
					OldDebugInfo(function() end, LevelOrInfo)
				end, LevelOrInfo)
			then
				return OldDebugInfo(...)
			end

			ToInspect = math.floor(ToInspect)

			local ReconstructedConstructedStack = {}
			for Level = 2, 20000 do
				local Function, Source, Line, Name, NumberOfArgs, Varargs = OldDebugInfo(Level, "fslna")

				if not Function or not Source or not Line or not Name then
					break
				end

				if isexecutorclosure(Function) and not shared.Hooking.IncludeInStackFunctions[Function] then
					continue
				end

				table.insert(ReconstructedConstructedStack, {
					f = Function,
					s = Source,
					l = Line,
					n = Name,
					a = { NumberOfArgs, Varargs },
				})
			end

			local InfoLevel = ReconstructedConstructedStack[ToInspect + 1] -- Because the stack starts at 0 and table index at 1 we have to account for the difference

			if not InfoLevel then
				-- Max level is 20000 so this guarantees that it will return nothing
				return OldDebugInfo(3e4, LevelOrInfo)
			end

			local ReturnResult = {}
			for idx, info in string.split(LevelOrInfo, "") do
				local Value = InfoLevel[info]

				if typeof(Value) == "table" then
					for _, v in Value do
						table.insert(ReturnResult, v)
					end

					continue
				end

				table.insert(ReturnResult, Value)
			end

			return table.unpack(ReturnResult, 1, #ReturnResult)
		end)

		--[[
	
		getfenv hook breaks due to luraph integrity checks,
		setmetatable(getfenv(), { __index = getrenv() })) shows a __index chain error
		so for now ill just not hook getfenv

		OldFenv = hookfunction(getrenv().getfenv, function(...)
			if checkcaller() then
				return OldFenv(...)
			end

			local ToInspect: (...any) -> (...any) | number = ...

			local Success, ResultingEnv = pcall(function()
				if typeof(ToInspect) == "number" then
					return OldFenv(ToInspect + 3)
				end

				return OldFenv(ToInspect)
			end)

			if ToInspect == nil --[=[ or (typeof(ToInspect) == "number" and math.floor(ToInspect) == 0) ]=] or not Success or typeof(ToInspect) == "function" then
				return --[=[setmetatable(]=]ResultingEnv--[=[, { -- so as to not interfere with the other multi-line comment above
					__index = getrenv()
				})]=]
			end

			ToInspect = math.floor(ToInspect)

			local ReconstructedConstructedStack = {}
			for Level = 2, 20000 do
				local StackInfoSuccess, Data = pcall(function()
					return {
						Environement = OldFenv(Level + 3),
						Function = OldDebugInfo(Level + 3, "f"),
					}
				end)

				if not StackInfoSuccess or not Data then
					break
				end

				local Environement = Data.Environement
				local Function = Data.Function

				if typeof(Environement["getgenv"]) == "function" and isexecutorclosure(Environement["getgenv"]) then
					if shared.Hooking.IncludeInStackFunctions[Function] then
						Environement = setmetatable(ResultingEnv, {
							__index = getrenv()
						})
					else
						continue
					end
				end

				table.insert(ReconstructedConstructedStack, Environement)
			end

			local InfoLevel = ReconstructedConstructedStack[ToInspect + 1]

			if not InfoLevel then
				-- Max level is 20000 so this guarantees that it will return error
				return OldFenv(3e4)
			end

			return InfoLevel
		end)]]

		return setstackhidden
	end)()

Hooking.HookFunction = function(Original, Replacement)
	if BypassEnabled then
		Hooking.SetStackHidden(Original, false)
	end

	return hookfunction(Original, Replacement)
end
Hooking.HookMetaMethod = function(object, method, hook)
	local Metatable = wax.shared.getrawmetatable(object)
	local originalMethod = rawget(Metatable, method)

	if BypassEnabled then
		Hooking.SetStackHidden(originalMethod, false)
	end

	if AlternativeEnabled then
		setreadonly(Metatable, false)
		rawset(Metatable, method, hook)
		setreadonly(Metatable, true)

		return originalMethod
	end

	return hookmetamethod(object, method, hook)
end

return Hooking
