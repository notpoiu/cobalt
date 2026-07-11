--// Imports \\--
local Codec = require(script.Parent.Parent.Codec)

--// Decoders \\--
local LazilyLoadDecoders, Decoders
do
	LazilyLoadDecoders = function()
		if Decoders then
			return
		end
		Decoders = {}

		for _, decoder in script.Parent.Decoders:GetChildren() do
			local Module = require(decoder)
			assert(Module.Type, "Decoder must have a Type field")

			local SanitizedType = {}
			if typeof(Module.Type) == "number" then
				table.insert(SanitizedType, Module.Type)
			elseif typeof(Module.Type) == "table" then
				SanitizedType = Module.Type
			end

			for _, t in SanitizedType do
				Decoders[t] = Module
			end
		end
	end
end

--// Parser \\--
local Parser = {}
Parser.__index = Parser

function Parser.new(data: buffer)
	LazilyLoadDecoders()
	assert(Decoders, "Could not load variant decoders.")

	local self = setmetatable({
		Data = data,
	}, Parser)
	return self
end

function Parser:Parse(offset: number, depth: number?): { Result: any, Offset: number }
	depth = depth or 0

	local length = buffer.len(self.Data)
	if offset >= length then
		return { Result = nil, Offset = -1 }
	end

	local typeId = buffer.readu8(self.Data, offset)
	offset += 1

	local decoder = Decoders[typeId]
	if not decoder then
		return { Result = nil, Offset = -1 }
	end

	return decoder.Parse(self.Data, offset, typeId, self, depth)
end

export type Arguments = {
	Values: { any },
	Count: number,
}

export type ParsedArguments = Arguments & {
	Offset: number,
}

function Parser:ParseArgs(offset: number, depth: number?): ParsedArguments
	depth = depth or 0

	local length = buffer.len(self.Data)
	if offset >= length then
		return { Values = {}, Offset = offset, Count = 0 }
	end

	local count, nextOffset = Codec.LEB128(self.Data, offset)
	if count > 50 then
		return { Values = {}, Offset = -1, Count = 0 }
	end

	offset = nextOffset
	local args = table.create(count)
	for i = 1, count do
		local parsed = self:Parse(offset, depth)
		if parsed.Offset < 0 then
			return { Values = args, Offset = -1, Count = i - 1 }
		end
		args[i] = parsed.Result
		offset = parsed.Offset
	end

	return { Values = args, Offset = offset, Count = count }
end

export type RemoteFunctionPayload = {
	InvokeId: number,
	IsError: boolean,
	Error: string?,
	Arguments: Arguments,
	Offset: number,
}

function Parser:ParseRemoteFunction(offset: number, depth: number?): RemoteFunctionPayload
	depth = depth or 0
	local length = buffer.len(self.Data)
	local invokeId, nextOffset = Codec.LEB128(self.Data, offset)

	if nextOffset < length and buffer.readu8(self.Data, nextOffset) == 0x3D then
		local start = nextOffset + 1
		local finish = start
		while finish < length and buffer.readu8(self.Data, finish) ~= 0 do
			finish += 1
		end
		local message = if finish > start then buffer.readstring(self.Data, start, finish - start) else ""
		local endOffset = if finish < length then finish + 1 else finish
		return {
			InvokeId = invokeId,
			IsError = true,
			Error = message,
			Arguments = {
				Values = {},
				Count = 0,
			},
			Offset = endOffset,
		}
	end

	local parsed = self:ParseArgs(nextOffset, depth)
	return {
		InvokeId = invokeId,
		IsError = false,
		Error = nil,
		Arguments = {
			Values = parsed.Values,
			Count = parsed.Count,
		},
		Offset = parsed.Offset,
	}
end

return Parser
