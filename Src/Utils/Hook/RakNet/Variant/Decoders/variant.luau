local MAX_DEPTH = 3

local DecoderModule = {
	Type = 0x21,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, parser: any, depth: number)
	if depth >= MAX_DEPTH then
		return { Result = nil, Offset = offset }
	end

	return parser:Parse(offset, depth + 1)
end

return DecoderModule
