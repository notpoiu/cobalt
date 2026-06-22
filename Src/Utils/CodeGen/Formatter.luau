local Formatter = {}

--#region @export "FormatLuaLiteral"
--// Populate CleanTable \\--
Formatter.CleanTable = { ['"'] = '\\"', ["\\"] = "\\\\" }
do
	for i = 0, 31 do
		Formatter.CleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
	end
	for i = 127, 255 do
		Formatter.CleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
	end
end

--// Indent Template \\--
local IndentTemplate = string.rep(" ", 4)

--[[
    Formats a Lua string to be used in a Lua code block.

    @param str: The string to format.
    @return The formatted string.
]]
function Formatter.FormatLuaString(str)
	return string.gsub(str, '["\\\0-\31\127-\255]', Formatter.CleanTable)
end

--[[
    Formats a Lua literal to be used in a Lua code block.

    @param Value: The value to format.
    @return The formatted string.
]]
function Formatter.FormatLuaLiteral(Value): string?
	local ValueType = type(Value)
	if ValueType == "string" then
		return `"{Formatter.FormatLuaString(Value)}"`
	elseif ValueType == "number" or ValueType == "boolean" then
		return tostring(Value)
	end

	return nil
end
--#endregion

--[[
    Formats a Lua array to be used in a Lua code block.

    @param Values: The values to format.
    @return The formatted string.
]]
function Formatter.FormatLuaArray(Values: { any }): string
	local Serialized = {}
	for _, Value in Values do
		local Literal = Formatter.FormatLuaLiteral(Value)
		if not Literal then
			return "{}"
		end

		table.insert(Serialized, Literal)
	end

	return "{ " .. table.concat(Serialized, ", ") .. " }"
end

--[[
    Indents code

    @param Code: The code to indent.
    @param IndentLevel: The amount of indentation to add.
    @return The indented code.
]]
function Formatter.IndentCode(Code: string, IndentLevel: number)
	local Indent = IndentTemplate:rep(IndentLevel)
	local IndentedCode = Code:gsub("\n", "\n" .. Indent)
	return Indent .. IndentedCode
end

--[[
    Creates a string of arguments for a given serialized arguments.

    @param SerializedArgs: The serialized arguments.
    @param Args: The arguments.
    @param Prefix: The prefix to add to the string.
    @return The string of arguments.
]]
function Formatter.CreateArgsString(SerializedArgs: string, Args: { [number]: any, n: number }, Prefix: string?)
	if Args.n == 0 then
		return ""
	end

	--// Cyclic Table Handler \\--
	if string.sub(SerializedArgs, 1, 9) == "(function" then
		return `{Prefix == nil and "" or Prefix}table.unpack({SerializedArgs}, 1, {Args.n})`
	end

	--// Normal Table Handler \\--
	return `{Prefix == nil and "" or Prefix}{string.sub(SerializedArgs, 2, #SerializedArgs - 1)}`
end

return Formatter
