-- LuaEncode - Fast Table Serialization Library for Pure Luau/Lua 5.1+
-- Copyright (c) 2022-2024 reggie@latte.to | MIT License
-- https://github.com/regginator/LuaEncode

--!optimize 2
--!native

local table, string, next, pcall, game, workspace, tostring, tonumber, getmetatable =
	table, string, next, pcall, game, workspace, tostring, tonumber, getmetatable

local GetFullPath = require(script.Parent.Parent.CodeGen.Generator).GetFullPath

local string_format = string.format
local string_char = string.char
local string_gsub = string.gsub
local string_match = string.match
local string_rep = string.rep
local string_pack = string.pack
local string_byte = string.byte
local string_gmatch = string.gmatch

local table_concat = table.concat

local Type = typeof or type

local function LookupTable(array)
	local Out = {}
	for _, Value in next, array do
		Out[Value] = true
	end

	return Out
end

-- Used to properly serialize NaN values
local NumberCorrection = {
	[string_pack(">n", 0 / 0)] = "0/0",
	[string_pack(">n", -(0 / 0))] = "-(0/0)",
	[string_pack(">n", tonumber("nan"))] = 'tonumber("nan")',
	[string_pack(">n", tonumber("-nan"))] = 'tonumber("-nan")',
}

-- Used for checking direct getfield syntax; Lua keywords can't be used as keys without being a str
-- FYI; `continue` is Luau only (in Lua it's actually a global function)
local LuaKeywords = LookupTable({
	"and",
	"break",
	"do",
	"else",
	"elseif",
	"end",
	"false",
	"for",
	"function",
	"if",
	"in",
	"local",
	"nil",
	"not",
	"or",
	"repeat",
	"return",
	"then",
	"true",
	"until",
	"while",
	"continue",
})

-- Type names that can be used as manual key indexes (i.e. non-reference types)
local KeyIndexTypes = LookupTable({
	"number",
	"string",
	"boolean",
	"Enum",
	"EnumItem",
	"Enums",
})

-- Returns the length of the array part (including holes) and if it's a pure array
local function GetIsArrayAndLength(tbl)
	local maxIndex = 0
	local count = 0
	for k, _ in pairs(tbl) do
		if type(k) == "number" and k > 0 and math.floor(k) == k then
			if k > maxIndex then
				maxIndex = k
			end
			count = count + 1
		else
			return 0, false
		end
	end
	return maxIndex, true
end

-- Simple function for directly checking the type on values, with their input, variable name,
-- and desired type name(s) to check
local function CheckType(inputData, dataName, ...)
	local ValidTypes = { ... }
	local ValidTypesLookup = LookupTable(ValidTypes)
	local InputType = Type(inputData)

	if not ValidTypesLookup[InputType] then
		error(
			string_format(
				"LuaEncode: Incorrect type for `%s`: `%s` expected, got `%s`",
				dataName,
				table_concat(ValidTypes, ", "), -- For if multiple types are accepted
				InputType
			),
			0
		)
	end

	return inputData -- Return back input directly
end

-- This re-serializes a string back into Lua, for the interpreter AND humans to read. This fixes
-- `string_format("%q")` only outputting in system encoding, instead of explicit Lua byte escapes
local SerializeString
do
	-- These are control characters to be encoded in a certain way in Lua rather than just a byte escape
	local SpecialCharacters = {
		['"'] = '\\"',
		["\\"] = "\\\\",
		-- Special ASCII control char codes
		["\a"] = "\\a",
		["\b"] = "\\b",
		["\t"] = "\\t",
		["\n"] = "\\n",
		["\v"] = "\\v",
		["\f"] = "\\f",
		["\r"] = "\\r",
	}

	-- We need to assign all extra normal byte escapes for runtime optimization
	for Index = 0, 255 do
		local Character = string_char(Index)

		if not SpecialCharacters[Character] and (Index < 32 or Index > 126) then
			SpecialCharacters[Character] = string_format("\\x%02X", Index)
		end
	end

	function SerializeString(inputString)
		-- FYI; We can't do "\0-\31" in Lua 5.1 (Only Luau/Lua 5.2+) due to an embedded zeros in pattern
		-- issue. See: https://stackoverflow.com/a/22962409
		return table_concat({ '"', string_gsub(inputString, '[%z\\"\1-\31\127-\255]', SpecialCharacters), '"' })
	end
end

-- Escape warning messages and such for comment block inserts
local function CommentBlock(inputString)
	local Padding = ""
	for Match in string_gmatch(inputString, "%](=*)%]") do
		if #Match >= #Padding then
			Padding = Match .. "="
		end
	end

	return "--[" .. Padding .. "[" .. inputString .. "]" .. Padding .. "]"
end

--[[
LuaEncode(inputTable: {[any]: any}, options: {[string]: any}): string

    ---------- OPTIONS: ----------

    Prettify <boolean:false> | Whether or not the output should use pretty printing

    IndentCount <number:0> | The amount of "spaces" that should be indented per entry (*Note:
    If `Prettify` is set to true and this is unspecified, it'll be set to `4` automatically*)

    InsertCycles <boolean:false> | If there are cyclic references in your table, the output
    will be wrapped in an anonymous function that manually sets paths to those references.
    **NOTE: If a key in the index path to the cycle is a reference type (e.g. `table`,
    `function`), the codegen can't externally set that path, and will be ignored.**

    OutputWarnings <boolean:true> | If "warnings" should be placed to the output (as
    comments); It's recommended to keep this enabled, however this can be disabled at ease

    FunctionsReturnRaw <boolean:false> | If functions in said table return back a "raw"
    value to place in the output as the key/value

    UseInstancePaths <boolean:true> | If `Instance` reference objects should return their
    Lua-accessable path for encoding. If the instance is parented under `nil` or isn't under
    `game`/`workspace`, it'll always fall back to `Instance.new(ClassName)` as before

    SerializeMathHuge <boolean:true> | If numbers calculated as "infinite" (or negative-inf)
    numbers should be serialized with "math.huge". (uses the `math` import, as opposed to just
    a direct data type) If false, "`1/0`" or "`-1/0`" will be serialized, which is supported
    on all target versions

]]

local function LuaEncode(inputTable, options)
	options = options or {}

	-- Check main args
	CheckType(inputTable, "inputTable", "table")
	CheckType(options, "options", "table")

	-- Check options
	CheckType(options.Prettify, "options.Prettify", "boolean", "nil")
	CheckType(options.PrettyPrinting, "options.PrettyPrinting", "boolean", "nil") -- Alias for `Options.Prettify`
	CheckType(options.IndentCount, "options.IndentCount", "number", "nil")
	CheckType(options.InsertCycles, "options.InsertCycles", "boolean", "nil")
	CheckType(options.OutputWarnings, "options.OutputWarnings", "boolean", "nil")
	CheckType(options.FunctionsReturnRaw, "options.FunctionsReturnRaw", "boolean", "nil")
	CheckType(options.UseInstancePaths, "options.UseInstancePaths", "boolean", "nil")
	CheckType(options.DisableNilParentHandler, "options.DisableNilParentHandler", "boolean", "nil")
	CheckType(options.SerializeMathHuge, "options.SerializeMathHuge", "boolean", "nil")

	CheckType(options._StackLevel, "options._StackLevel", "number", "nil")
	CheckType(options._VisitedTables, "options._VisitedTables", "table", "nil")

	local Prettify = (options.Prettify == nil and options.PrettyPrinting == nil and false)
		or (options.Prettify ~= nil and options.Prettify)
		or (options.PrettyPrinting and options.PrettyPrinting)
	local IndentCount = options.IndentCount or (Prettify and 4) or 0
	local InsertCycles = (options.InsertCycles == nil and false) or options.InsertCycles
	local OutputWarnings = (options.OutputWarnings == nil and true) or options.OutputWarnings
	local DisableNilParentHandler = (options.DisableNilParentHandler == nil and false) or options.DisableNilParentHandler
	local UseInstancePaths = (options.UseInstancePaths == nil and true) or options.UseInstancePaths
	local SerializeMathHuge = (options.SerializeMathHuge == nil and true) or options.SerializeMathHuge

	local RefMaps = options._RefMaps or { [inputTable] = "" } -- [Ref: table] = ".example["ref path"]'
	local CycleMaps = options._CycleMaps or {} -- ['.example["ref path"]'] = '.another["ref path"]'

	local StackLevel = options._StackLevel or 1
	local EntryStackLevel = options._StackLevel or 1
	local VisitedTables = options._VisitedTables or {} -- [Ref: table] = true
	local DidInsertNilFunction = options._DidInsertNilFunction or false

	-- Lazy serialization reference values
	local PositiveInf = (SerializeMathHuge and "math.huge") or "1/0"
	local NegativeInf = (SerializeMathHuge and "-math.huge") or "-1/0"
	local NewEntryString = (Prettify and "\n") or ""
	local CodegenNewline = (Prettify and "\n") or " "
	local ValueSeperator = (Prettify and ", ") or ","
	local BlankSeperator = (Prettify and " ") or ""
	local EqualsSeperator = (Prettify and " = ") or "="

	-- For pretty printing we need to keep track of the current stack level, then repeat IndentString by that count
	local IndentStringBase = string_rep(" ", IndentCount)

	-- Calculated in the walk loop, based on the current StackLevel
	local IndentString = nil
	local EndingIndentString = nil

	--IndentString = (Prettify and string_rep(IndentString, StackLevel)) or IndentString
	--local EndingIndentString = (#IndentString > 0 and string_sub(IndentString, 1, -IndentCount - 1)) or ""

	-- For number key values, we want to explicitly serialize the index num ONLY when it needs to be
	local KeyNumIndex = 1

	-- Cases for encoding values, then end setup. Functions are all expected to return a (EncodedKey: string, EncloseInBrackets: boolean)
	local TypeCases = {}
	do
		-- Basic func for getting the direct value of an encoded type without weird table.pack()[1] syntax
		local function TypeCase(typeName, value)
			-- Each of these funcs return a tuple, so it'd be annoying to do case-by-case
			local EncodedValue = TypeCases[typeName](value, false) -- False to label as NOT `isKey`
			return EncodedValue
		end

		-- For "tuple" args specifically, so there isn't a bunch of re-used code
		local function Args(...)
			local EncodedValues = {}

			for _, Arg in next, { ... } do
				EncodedValues[#EncodedValues + 1] = TypeCase(Type(Arg), Arg)
			end

			return table_concat(EncodedValues, ValueSeperator)
		end

		-- For certain Roblox data types, we use a custom serialization method for filling out params etc
		local function Params(newData, params)
			return "(function(v, p) for pn, pv in next, p do v[pn] = pv end return v end)("
				.. table_concat({ newData, TypeCase("table", params) }, ValueSeperator)
				.. ")"
		end

		TypeCases["number"] = function(value, isKey)
			-- If the number isn't the current real index of the table, we DO want to
			-- explicitly define it in the serialization no matter what for accuracy
			if isKey and value == KeyNumIndex then
				-- ^^ What's EXPECTED unless otherwise explicitly defined, if so, return no encoded num
				KeyNumIndex = KeyNumIndex + 1
				return nil, true
			end

			-- Lua's internal `tostring` handling will denote positive/negativie-infinite number TValues as "inf", which
			-- makes certain numbers not encode properly. We also just want to make the output precise
			if value == 1 / 0 then
				return PositiveInf
			elseif value == -1 / 0 then
				return NegativeInf
			elseif value == math.pi then
				return "math.pi"
			end

			-- Provided by felixdm
			local NumberPacked = string_pack(">n", value) -- gameguy is a boss
			local CorrectedNumber = NumberCorrection[NumberPacked]
			if CorrectedNumber then
				return CorrectedNumber
			end

			if value ~= value then
				return string_format(
					'(string.unpack(">n", "\\%*\\%*\\%*\\%*\\%*\\%*\\%*\\%*"))',
					string_byte(NumberPacked, 1, 8)
				)
			end

			-- Return fixed-formatted precision num
			return string_format("%.14g", value)
		end

		TypeCases["string"] = function(value, isKey)
			if isKey and not LuaKeywords[value] and string_match(value, "^[A-Za-z_][A-Za-z0-9_]*$") then
				-- ^^ Then it's a syntaxically-correct variable, doesn't need explicit string def
				return value, true
			end

			return SerializeString(value)
		end

		-- This is NOT used for normal table depth, only tables-as-keys and Roblox data types that use tables as
		-- arguments for constructor functions
		TypeCases["table"] = function(value, isKey)
			-- Primarily for tables-as-keys
			if VisitedTables[value] and OutputWarnings then
				return "{--[[LuaEncode: Duplicate reference]]}"
			end

			local NewOptions = setmetatable({}, { __index = options })
			do
				NewOptions.Prettify = (isKey and false) or Prettify
				NewOptions.IndentCount = (isKey and ((not Prettify and IndentCount) or 1)) or IndentCount
				NewOptions._StackLevel = (isKey and 1) or StackLevel + 1
				NewOptions._VisitedTables = VisitedTables
				NewOptions._DidInsertNilFunction = DidInsertNilFunction
				NewOptions._RefMaps = RefMaps
				NewOptions._CycleMaps = CycleMaps
				NewOptions.InsertCycles = InsertCycles
			end

			local Result, InsertedNilFunction = LuaEncode(value, NewOptions)

			if InsertedNilFunction then
				DidInsertNilFunction = true
			end

			return Result
		end

		TypeCases["boolean"] = function(value)
			return value and "true" or "false"
		end

		TypeCases["nil"] = function(value)
			return "nil"
		end

		TypeCases["thread"] = function(value)
			return "coroutine.create(function() end)"
		end

		TypeCases["function"] = function(value)
			-- We can't serialize functions so we just return a comment block with function information
			local FunctionName, ArgumentCount, VarArg, Line = debug.info(value, "nal")

			local Arguments = {}
			for Index = 1, ArgumentCount do
				Arguments[Index] = string_format("arg%d", Index)
			end

			return string_format(
				[[function(%s)%s%s%s%s%sreturn%send]],
				`{table_concat(Arguments, ", ")}{VarArg and `{Arguments[1] and ", " or ""}...` or ""}`,

				`{CodegenNewline}{IndentString}{IndentStringBase}-- Name: {FunctionName == "" and "Anonymous Function" or FunctionName} | Line: {Line}`,

				`{CodegenNewline}{IndentString}{IndentStringBase}-- {islclosure(value) and `Upvalues: {#debug.getupvalues(
					value
				)}` or "Upvalues: N/A (C Closure)"}`,

				`{CodegenNewline}{IndentString}{IndentStringBase}-- `
					.. (
						getfunctionhash
							and `{islclosure(value) and `Function Hash: {getfunctionhash(value)}` or "Function Hash: N/A (C Closure)"}`
						or "Function Hash: N/A (getfunctionhash == nil)"
					),

				OutputWarnings
						and `{CodegenNewline}{IndentString}{IndentStringBase}-- LuaEncode: Unable to serialize function`
					or "",

				`{CodegenNewline}{IndentString}{IndentStringBase}`,
				`{CodegenNewline}{IndentString}`
			)
		end

		---------- ROBLOX CUSTOM DATA TYPES BELOW ----------

		TypeCases["Axes"] = function(value)
			local EncodedArgs = {}
			local EnumValues = {
				["Enum.Axis.X"] = value.X,
				["Enum.Axis.Y"] = value.Y,
				["Enum.Axis.Z"] = value.Z,
			}

			for EnumValue, IsEnabled in next, EnumValues do
				if IsEnabled then
					EncodedArgs[#EncodedArgs + 1] = EnumValue
				end
			end

			return "Axes.new(" .. table_concat(EncodedArgs, ValueSeperator) .. ")"
		end

		TypeCases["BrickColor"] = function(value)
			-- BrickColor.Number (Its enum ID) will be slightly more efficient in all cases in deser,
			-- so we'll use it if Options.Prettify is false
			return "BrickColor.new(" .. (Prettify and TypeCase("string", value.Name)) or value.Number .. ")"
		end

		TypeCases["CFrame"] = function(value)
			if value == CFrame.identity then
				return "CFrame.identity"
			end

			return "CFrame.new(" .. Args(value:components()) .. ")"
		end

		TypeCases["CatalogSearchParams"] = function(value)
			return Params("CatalogSearchParams.new()", {
				SearchKeyword = value.SearchKeyword,
				MinPrice = value.MinPrice,
				MaxPrice = value.MaxPrice,
				SortType = value.SortType, -- EnumItem
				CategoryFilter = value.CategoryFilter, -- EnumItem
				BundleTypes = value.BundleTypes, -- table
				AssetTypes = value.AssetTypes, -- table
			})
		end

		TypeCases["Color3"] = function(value)
			-- Using floats for RGB values, most accurate for direct serialization
			return "Color3.new(" .. Args(value.R, value.G, value.B) .. ")"
		end

		TypeCases["ColorSequence"] = function(value)
			return "ColorSequence.new(" .. TypeCase("table", value.Keypoints) .. ")"
		end

		TypeCases["ColorSequenceKeypoint"] = function(value)
			return "ColorSequenceKeypoint.new(" .. Args(value.Time, value.Value) .. ")"
		end

		-- We're using fromUnixTimestamp to serialize the object
		TypeCases["DateTime"] = function(value)
			-- Always an int, we don't need to do anything special
			return "DateTime.fromUnixTimestamp(" .. value.UnixTimestamp .. ")"
		end

		-- Properties seem to throw an error on index if the scope isn't a Studio plugin, so we're
		-- directly getting values! (so fun!!!!)
		TypeCases["DockWidgetPluginGuiInfo"] = function(value)
			-- e.g.: "InitialDockState:Right InitialEnabled:0 InitialEnabledShouldOverrideRestore:0 FloatingXSize:0 FloatingYSize:0 MinWidth:0 MinHeight:0"
			local ValueString = tostring(value)

			return "DockWidgetPluginGuiInfo.new("
				.. Args(
					-- InitialDockState (Enum.InitialDockState)
					Enum.InitialDockState[string_match(ValueString, "InitialDockState:(%w+)")], -- Enum.InitialDockState.Right
					-- InitialEnabled and InitialEnabledShouldOverrideRestore (boolean as number; `0` or `1`)
					string_match(ValueString, "InitialEnabled:(%w+)") == "1", -- false
					string_match(ValueString, "InitialEnabledShouldOverrideRestore:(%w+)") == "1", -- false
					-- FloatingXSize/FloatingYSize (numbers)
					tonumber(string_match(ValueString, "FloatingXSize:(%w+)")), -- 0
					tonumber(string_match(ValueString, "FloatingYSize:(%w+)")), -- 0
					-- MinWidth/MinHeight (numbers)
					tonumber(string_match(ValueString, "MinWidth:(%w+)")), -- 0
					tonumber(string_match(ValueString, "MinHeight:(%w+)")) -- 0
				)
				.. ")"
		end

		-- e.g. `Enum.UserInputType`
		TypeCases["Enum"] = function(value)
			return "Enum." .. tostring(value)
		end

		-- e.g. `Enum.UserInputType.Gyro`
		TypeCases["EnumItem"] = function(value)
			return tostring(value) -- Returns the full enum index for now (e.g. "Enum.UserInputType.Gyro")
		end

		-- i.e. the `Enum` global return
		TypeCases["Enums"] = function(value)
			return "Enum"
		end

		TypeCases["Faces"] = function(value)
			local EncodedArgs = {}
			local EnumValues = {
				["Enum.NormalId.Top"] = value.Top, -- These return bools
				["Enum.NormalId.Bottom"] = value.Bottom,
				["Enum.NormalId.Left"] = value.Left,
				["Enum.NormalId.Right"] = value.Right,
				["Enum.NormalId.Back"] = value.Back,
				["Enum.NormalId.Front"] = value.Front,
			}

			for EnumValue, IsEnabled in next, EnumValues do
				if IsEnabled then
					EncodedArgs[#EncodedArgs + 1] = EnumValue
				end
			end

			return "Faces.new(" .. table_concat(EncodedArgs, ValueSeperator) .. ")"
		end

		TypeCases["FloatCurveKey"] = function(value)
			return "FloatCurveKey.new(" .. Args(value.Time, value.Value, value.Interpolation) .. ")"
		end

		TypeCases["Font"] = function(value)
			return "Font.new(" .. Args(value.Family, value.Weight, value.Style) .. ")"
		end

		-- Instance refs can be evaluated to their paths (optional), but if parented to
		-- nil or some DataModel not under `game`, it'll just return nil
		TypeCases["Instance"] = function(value)
			if UseInstancePaths then
				local InstancePath, NilFunctionInserted = GetFullPath(value, {
					DisableNilParentHandler = DisableNilParentHandler,
					OmitNilFunctionGetterCodeGeneration = true
				})

				if NilFunctionInserted then
					DidInsertNilFunction = true
				end

				if InstancePath then
					return InstancePath
				end

				-- ^^ Now, if the path isn't accessable, falls back to the return below anyway
			end

			return "nil"
				.. BlankSeperator
				.. CommentBlock("Instance.new(" .. TypeCase("string", value.ClassName) .. ")")
		end

		TypeCases["NumberRange"] = function(value)
			return "NumberRange.new(" .. Args(value.Min, value.Max) .. ")"
		end

		TypeCases["NumberSequence"] = function(value)
			return "NumberSequence.new(" .. TypeCase("table", value.Keypoints) .. ")"
		end

		TypeCases["NumberSequenceKeypoint"] = function(value)
			return "NumberSequenceKeypoint.new(" .. Args(value.Time, value.Value, value.Envelope) .. ")"
		end

		TypeCases["OverlapParams"] = function(value)
			return Params("OverlapParams.new()", {
				FilterDescendantsInstances = value.FilterDescendantsInstances,
				FilterType = value.FilterType,
				MaxParts = value.MaxParts,
				CollisionGroup = value.CollisionGroup,
				RespectCanCollide = value.RespectCanCollide,
			})
		end

		TypeCases["PathWaypoint"] = function(value)
			return "PathWaypoint.new(" .. Args(value.Position, value.Action, value.Label) .. ")"
		end

		TypeCases["PhysicalProperties"] = function(value)
			return "PhysicalProperties.new("
				.. Args(value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight)
				.. ")"
		end

		TypeCases["Random"] = function()
			return "Random.new()"
		end

		TypeCases["Ray"] = function(value)
			return "Ray.new(" .. Args(value.Origin, value.Direction) .. ")"
		end

		TypeCases["RaycastParams"] = function(value)
			return Params("RaycastParams.new()", {
				FilterDescendantsInstances = value.FilterDescendantsInstances,
				FilterType = value.FilterType,
				IgnoreWater = value.IgnoreWater,
				CollisionGroup = value.CollisionGroup,
				RespectCanCollide = value.RespectCanCollide,
			})
		end

		TypeCases["Rect"] = function(value)
			return "Rect.new(" .. Args(value.Min, value.Max) .. ")"
		end

		-- Roblox doesn't provide read properties for min/max on `Region3`, but they do on Region3int16.. Anyway,
		-- we CAN calculate the min/max of a Region3 from just .CFrame and .Size.. Thanks to wally for linking me
		-- the thread for this method lol
		TypeCases["Region3"] = function(value)
			local ValueCFrame = value.CFrame
			local ValueSize = value.Size

			return "Region3.new("
				.. Args(
					ValueCFrame * CFrame.new(-ValueSize / 2), -- Minimum
					ValueCFrame * CFrame.new(ValueSize / 2) -- Maximum
				)
				.. ")"
		end

		TypeCases["Region3int16"] = function(value)
			return "Region3int16.new(" .. Args(value.Min, value.Max) .. ")"
		end

		TypeCases["TweenInfo"] = function(value)
			return "TweenInfo.new("
				.. Args(
					value.Time,
					value.EasingStyle,
					value.EasingDirection,
					value.RepeatCount,
					value.Reverses,
					value.DelayTime
				)
				.. ")"
		end

		-- CURRENTLY UNDOCUMENTED*
		TypeCases["RotationCurveKey"] = function(value)
			return "RotationCurveKey.new(" .. Args(value.Time, value.Value, value.Interpolation) .. ")"
		end

		TypeCases["UDim"] = function(value)
			return "UDim.new(" .. Args(value.Scale, value.Offset) .. ")"
		end

		TypeCases["UDim2"] = function(value)
			if value.X.Offset == 0 and value.Y.Offset == 0 then
				return "UDim2.fromScale(" .. Args(value.X.Scale, value.Y.Scale) .. ")"
			end

			if value.X.Scale == 0 and value.Y.Scale == 0 then
				return "UDim2.fromOffset(" .. Args(value.X.Offset, value.Y.Offset) .. ")"
			end

			return "UDim2.new("
				.. Args(
					-- Not directly using X and Y UDims for better output (i.e. would be
					-- UDim2.new(UDim.new(1, 0), UDim.new(1, 0)) if I did)
					value.X.Scale,
					value.X.Offset,
					value.Y.Scale,
					value.Y.Offset
				)
				.. ")"
		end

		local Vector2Replacements = {
			[Vector2.zero] = "Vector2.zero",
			[Vector2.one] = "Vector2.one",
			[Vector2.xAxis] = "Vector2.xAxis",
			[Vector2.yAxis] = "Vector2.yAxis",
		}

		TypeCases["Vector2"] = function(value)
			if Vector2Replacements[value] then
				return Vector2Replacements[value]
			end

			return "Vector2.new(" .. Args(value.X, value.Y) .. ")"
		end

		TypeCases["Vector2int16"] = function(value)
			return "Vector2int16.new(" .. Args(value.X, value.Y) .. ")"
		end

		local Vector3Replacements = {
			[Vector3.zero] = "Vector3.zero",
			[Vector3.one] = "Vector3.one",
			[Vector3.xAxis] = "Vector3.xAxis",
			[Vector3.yAxis] = "Vector3.yAxis",
			[Vector3.zAxis] = "Vector3.zAxis",
		}

		TypeCases["Vector3"] = function(value)
			if Vector3Replacements[value] then
				return Vector3Replacements[value]
			end

			return "Vector3.new(" .. Args(value.X, value.Y, value.Z) .. ")"
		end

		TypeCases["Vector3int16"] = function(value)
			return "Vector3int16.new(" .. Args(value.X, value.Y, value.Z) .. ")"
		end

		TypeCases["buffer"] = function(value)
			if wax.shared.SaveManager:GetState("PreferBufferFromString", false) then
				return `buffer.fromstring({SerializeString(buffer.tostring(value))})`
			end

			local Bytes = {}
			for i = 1, buffer.len(value) do
				table.insert(Bytes, buffer.readu8(value, i - 1))
			end

			return table_concat({
				"(function(bytes) ",
				CommentBlock("Type: buffer"),
				NewEntryString,
				IndentString,
				IndentStringBase,
				"local b = buffer.create(#bytes)",
				NewEntryString,
				IndentString,
				IndentStringBase,
				"for i = 1, #bytes do",
				NewEntryString,
				IndentString,
				IndentStringBase,
				IndentStringBase,
				"buffer.writeu8(b, i - 1, bytes[i])",
				NewEntryString,
				IndentString,
				IndentStringBase,
				"end",
				NewEntryString,
				IndentStringBase,
				IndentString,
				"return b",
				NewEntryString,
				IndentString,
				"end)({ ",
				table_concat(Bytes, ", "),
				" })",
			})
		end

		-- With userdata, just encode directly
		TypeCases["userdata"] = function(value)
			if getmetatable(value) ~= nil then -- Has mt
				return "newproxy(true)"
			else
				return "newproxy()" -- newproxy() defaults to false (no mt)
			end
		end
	end

	-- Setup for final output, which will be concat together
	local Output = {}

	local TablePointer = inputTable
	local NextKey = nil -- Used with TableStack so the TablePointer loop knows where to continue from upon stack pop
	local IsNewTable = true -- Used with table stack push/pop to identify when an opening curly brace should be added

	-- Stack array for table depth
	local TableStack = {} -- [Depth: number] = {TablePointer: table, NextKey: any, KeyNumIndex: number}

	while TablePointer do
		-- Update StackLevel for formatting
		StackLevel = EntryStackLevel + #TableStack
		IndentString = (Prettify and string_rep(IndentStringBase, StackLevel)) or ""
		if Prettify and StackLevel > 1 then
			EndingIndentString = string_rep(IndentStringBase, StackLevel - 1)
		else
			EndingIndentString = ""
		end

		-- Only append an opening brace to the table if this isn't just a continution up the stack
		if IsNewTable then
			Output[#Output + 1] = "{"
		elseif next(TablePointer, NextKey) == nil then -- Formatting for the next entry still needs to be added like any other value
			Output[#Output + 1] = NewEntryString .. EndingIndentString
		else
			Output[#Output + 1] = ","
		end

		VisitedTables[TablePointer] = true

		local ArrayLength, IsArray = GetIsArrayAndLength(TablePointer)
		if IsArray and ArrayLength > 0 then
			for i = 1, ArrayLength do
				if Prettify then
					Output[#Output + 1] = NewEntryString .. IndentString
				end
				local Value = TablePointer[i]
				local ValueType = Type(Value)

				if ValueType == "table" then
					local RootIndexPath
					if InsertCycles and RefMaps[TablePointer] then
						local EncodedKeyAsValue = TypeCases["number"](i, false)
						RootIndexPath = table_concat({ "[", EncodedKeyAsValue, "]" })
					end

					if VisitedTables[Value] then
						local IndexPath
						if InsertCycles and RefMaps[TablePointer] and RootIndexPath then
							IndexPath = RefMaps[TablePointer] .. RootIndexPath
						end

						local EncodedValueOrError =
							string_format("{%s}", (OutputWarnings and "--[[LuaEncode: Duplicate reference]]") or "")

						if IndexPath and RefMaps[Value] then
							CycleMaps[IndexPath] = RefMaps[Value]
						end

						Output[#Output + 1] = EncodedValueOrError

						continue
					end

					if InsertCycles and RefMaps[TablePointer] and RootIndexPath then
						RefMaps[Value] = RefMaps[TablePointer] .. RootIndexPath
					end

					-- Create a new options table for the recursive call
					local Encoded, InsertedNilFunction = LuaEncode(
						Value,
						setmetatable({
							Prettify = Prettify,
							IndentCount = IndentCount,
							_StackLevel = StackLevel + 1,
							_VisitedTables = VisitedTables,
							_DidInsertNilFunction = DidInsertNilFunction,
							_RefMaps = RefMaps,
							_CycleMaps = CycleMaps,
							InsertCycles = InsertCycles,
						}, { __index = options })
					)

					if InsertedNilFunction then
						DidInsertNilFunction = true
					end

					Output[#Output + 1] = Encoded
				elseif TypeCases[ValueType] then
					local ValueEncodedSuccess, EncodedValueOrError = pcall(TypeCases[ValueType], Value, false)
					if ValueEncodedSuccess and EncodedValueOrError then
						Output[#Output + 1] = EncodedValueOrError
					else
						Output[#Output + 1] = `nil{OutputWarnings and " " .. CommentBlock(
							string.format(
								"LuaEncode: Failed to encode value of data type %s: %s",
								ValueType,
								SerializeString(EncodedValueOrError)
							)
						) or ""}`
					end
				else
					Output[#Output + 1] = `nil{OutputWarnings and " " .. CommentBlock(
						string.format("LuaEncode: Serialization of data type %s is not supported", ValueType)
					) or ""}`
				end

				if i < ArrayLength then
					Output[#Output + 1] = ","
				end
			end
			Output[#Output + 1] = NewEntryString .. EndingIndentString .. "}"
			if #TableStack > 0 then
				local TableUp = TableStack[#TableStack]
				TableStack[#TableStack] = nil
				TablePointer, NextKey, KeyNumIndex = TableUp[1], TableUp[2], TableUp[3] -- Reverted to TablePointer, NextKey, KeyNumIndex (from outer scope)
				IsNewTable = false
			else
				break
			end

			continue
		end

		-- Just because of control flow restrictions with Lua compatibility
		local SkipStackPop = false

		for Key, Value in next, TablePointer, NextKey do
			local KeyType = Type(Key)
			local ValueType = Type(Value)

			local ValueIsTable = ValueType == "table"

			if TypeCases[KeyType] and TypeCases[ValueType] then
				if Prettify then
					Output[#Output + 1] = NewEntryString .. IndentString
				end

				local ValueWasEncoded = false -- Keeping track of this for adding a "," to the output if needed

				-- Evaluate output for key
				local KeyEncodedSuccess, EncodedKeyOrError, DontEncloseKeyInBrackets =
					pcall(TypeCases[KeyType], Key, true) -- The `true` represents if it's a key or not, here it is

				-- Evaluate output for value, ignoring 2nd arg (`DontEncloseInBrackets`) because this isn't the key
				local ValueEncodedSuccess, EncodedValueOrError
				if not ValueIsTable then
					ValueEncodedSuccess, EncodedValueOrError = pcall(TypeCases[ValueType], Value, false)
				end

				-- Ignoring `if EncodedKeyOrError` because the key doesn't actually need to ALWAYS
				-- be explicitly encoded, like if it's a number of the current key index!
				if KeyEncodedSuccess and (ValueIsTable or (ValueEncodedSuccess and EncodedValueOrError)) then
					-- Append explicit key if necessary
					if EncodedKeyOrError then
						if DontEncloseKeyInBrackets then
							Output[#Output + 1] = EncodedKeyOrError
						else
							Output[#Output + 1] = table_concat({ "[", EncodedKeyOrError, "]" })
						end

						Output[#Output + 1] = EqualsSeperator
					end

					-- Of course, recursive tables are handled differently and use the stack system
					if ValueIsTable then
						local IndexPath
						if InsertCycles and KeyIndexTypes[KeyType] and RefMaps[TablePointer] then
							if
								KeyType == "string"
								and not LuaKeywords[Key]
								and string_match(Key, "^[A-Za-z_][A-Za-z0-9_]*$")
							then
								IndexPath = "." .. Key
							else
								local EncodedKeyAsValue = TypeCases[KeyType](Key)
								IndexPath = table_concat({ "[", EncodedKeyAsValue, "]" })
							end
						end

						if not VisitedTables[Value] then
							if IndexPath then
								RefMaps[Value] = RefMaps[TablePointer] .. IndexPath
							end

							TableStack[#TableStack + 1] = { TablePointer, Key, KeyNumIndex }

							TablePointer = Value
							NextKey = nil
							KeyNumIndex = 1

							IsNewTable = true
							SkipStackPop = true
							break
						else
							EncodedValueOrError =
								string_format("{%s}", (OutputWarnings and "--[[LuaEncode: Duplicate reference]]") or "")

							if IndexPath then
								CycleMaps[IndexPath] = RefMaps[Value]
							end
						end
					end

					-- Append value like normal
					Output[#Output + 1] = EncodedValueOrError

					ValueWasEncoded = true
				elseif OutputWarnings then -- Then `Encoded(Key/Value)OrError` is the error msg
					-- ^^ Then either the key or value wasn't properly checked or encoded, and there
					-- was an error we need to log!
					local ErrorMessage = string_format(
						"LuaEncode: Failed to encode %s of data type %s: %s",
						(not KeyEncodedSuccess and "key") or (not ValueEncodedSuccess and "value") or "key/value",
						ValueType,
						(not KeyEncodedSuccess and SerializeString(EncodedKeyOrError))
							or (not ValueEncodedSuccess and SerializeString(EncodedValueOrError))
							or "(Failed to get error message)"
					)

					Output[#Output + 1] = CommentBlock(ErrorMessage)
				end

				if next(TablePointer, Key) == nil then
					-- If there isn't another value after the current index, add ending formatting
					Output[#Output + 1] = NewEntryString .. EndingIndentString
				elseif ValueWasEncoded then
					Output[#Output + 1] = ","
				end
			end
		end

		-- Vanilla Lua control flow is fun
		if not SkipStackPop then
			Output[#Output + 1] = "}"

			if #TableStack > 0 then
				local TableUp = TableStack[#TableStack]
				TableStack[#TableStack] = nil -- Pop off the table stack

				TablePointer, NextKey, KeyNumIndex = TableUp[1], TableUp[2], TableUp[3]
				IsNewTable = false
			else
				break
			end
		end
	end

	if InsertCycles and StackLevel == 1 then
		local CycleMapsOut = {}
		for CycleIndex, CycleMap in next, CycleMaps do
			CycleMapsOut[#CycleMapsOut + 1] = IndentString
				.. "t"
				.. CycleIndex
				.. EqualsSeperator
				.. "t"
				.. CycleMap
				.. CodegenNewline
		end

		if #CycleMapsOut > 0 then
			return table_concat({
				"(function(t)",
				NewEntryString,
				table_concat(CycleMapsOut),
				NewEntryString,
				IndentString,
				"return t",
				CodegenNewline,
				"end)(",
				table_concat(Output),
				")",
			}),
				DidInsertNilFunction
		end
	end

	return table_concat(Output), DidInsertNilFunction
end

return LuaEncode
