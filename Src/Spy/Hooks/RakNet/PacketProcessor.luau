--// Imports \\--
local raknet = require("@src/Utils/Hook/RakNet/Wrapper")
local Constants = require("@src/Spy/Hooks/RakNet/Constants")

--// Utils \\--
local Lookup = require("@src/Utils/Hook/RakNet/Lookup")
local Codec = require("@src/Utils/Hook/RakNet/Codec")
local Parser = require("@src/Utils/Hook/RakNet/Variant/Parser")

--// Constants \\--
local ItemTypes = Constants.ItemTypes

type ByteRange = {
	Start: number,
	Finish: number,
}

export type RemoteFunctionPayload = {
	Type: "RemoteFunction",
	Response: Parser.RemoteFunctionPayload,
	Offset: number,
}

export type ArgumentsPayload = {
	Type: "Arguments",
	Arguments: Parser.Arguments,
	Offset: number,
}

export type Payload = RemoteFunctionPayload | ArgumentsPayload

local function RewriteWithoutRanges(Message: raknet.RakNetMessage, Data: buffer, Length: number, Ranges: { ByteRange })
	local RemovedLength = 0
	for _, Range in Ranges do
		RemovedLength += Range.Finish - Range.Start
	end

	local NewLength = Length - RemovedLength
	if NewLength <= 1 then
		Message:Block()
		return
	end

	local Rewritten = buffer.create(NewLength)
	local SourceOffset = 0
	local DestinationOffset = 0

	for _, Range in Ranges do
		local CopyLength = Range.Start - SourceOffset
		if CopyLength > 0 then
			buffer.copy(Rewritten, DestinationOffset, Data, SourceOffset, CopyLength)
			DestinationOffset += CopyLength
		end

		SourceOffset = Range.Finish
	end

	local RemainingLength = Length - SourceOffset
	if RemainingLength > 0 then
		buffer.copy(Rewritten, DestinationOffset, Data, SourceOffset, RemainingLength)
	end

	Message:SetData(Rewritten)
end

--// Processor \\--
return function(
	Message: raknet.RakNetMessage,
	Postprocess: (Instance: Instance, Payload: Payload, Message: raknet.RakNetMessage) -> boolean?
)
	local Data = Message.AsBuffer
	local Length = buffer.len(Data)
	if Length < 2 then
		return
	end

	local BlockedRanges: { ByteRange } = {}
	local Offset = 1
	while Offset < Length do
		local ItemStart = Offset
		local Success, Parsed = pcall(function()
			local ItemType = buffer.readu8(Data, Offset)
			Offset += 1

			if
				ItemType ~= ItemTypes.ReliableEventInvocationItem
				and ItemType ~= ItemTypes.UnreliableEventInvocationItem
			then
				return { Stop = true }
			end

			local InstanceRef, NextOffset = Codec.ReadInstanceRef(Data, Offset)
			Offset = NextOffset

			if InstanceRef.is_null or Offset + 2 > Length then
				return { Stop = true }
			end

			local _ScopeId = buffer.readu16(Data, Offset)
			Offset += 2

			local Instance = Lookup.Instance.ByRef(InstanceRef)
			if not Instance then
				return { Stop = true }
			end

			local PayloadParser = Parser.new(Data)
			local Payload: Payload
			if Instance:IsA("RemoteFunction") then
				local Response = PayloadParser:ParseRemoteFunction(Offset)
				Payload = {
					Type = "RemoteFunction",
					Response = Response,
					Offset = Response.Offset,
				}
			else
				local Arguments = PayloadParser:ParseArgs(Offset)
				Payload = {
					Type = "Arguments",
					Arguments = {
						Values = Arguments.Values,
						Count = Arguments.Count,
					},
					Offset = Arguments.Offset,
				}
			end

			if Payload.Offset <= Offset or Payload.Offset > Length then
				return { Stop = true }
			end

			return {
				Instance = Instance,
				Payload = Payload,
			}
		end)

		if not Success or Parsed.Stop then
			break
		end

		local ItemEnd = Parsed.Payload.Offset
		if Postprocess(Parsed.Instance, Parsed.Payload, Message) then
			table.insert(BlockedRanges, {
				Start = ItemStart,
				Finish = ItemEnd,
			})
		end

		Offset = ItemEnd
	end

	if #BlockedRanges > 0 then
		RewriteWithoutRanges(Message, Data, Length, BlockedRanges)
	end
end
