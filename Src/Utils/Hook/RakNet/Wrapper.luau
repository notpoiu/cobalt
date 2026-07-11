local RakNetWrapper = {
	Hooks = {
		Receive = {},
		Send = {},
	},
}

local function MatchesPacketId(packetIds: number | { number }, packetId: number): boolean
	if typeof(packetIds) == "number" then
		return packetIds == packetId
	end

	return table.find(packetIds, packetId) ~= nil
end

export type RakNetMessage = {
	AsBuffer: buffer,
	AsString: string,
	AsArray: { number },
	Size: number,
	PacketId: number,
	Priority: number,
	Reliability: number,
	OrderingChannel: number,
	Block: (self: RakNetMessage) -> (),
	SetData: (self: RakNetMessage, data: buffer | string | { number }) -> (),
}

function RakNetWrapper.add_receive_hook(packetId: number | { number }, callback: (msg: RakNetMessage) -> ())
	local registeredHook = raknet.add_receive_hook(function(msg: RakNetMessage)
		if MatchesPacketId(packetId, msg.PacketId) then
			callback(msg)
		end
	end)

	table.insert(RakNetWrapper.Hooks.Receive, registeredHook)
	return registeredHook
end

function RakNetWrapper.add_send_hook(packetId: number | { number }, callback: (msg: RakNetMessage) -> ())
	local registeredHook = raknet.add_send_hook(function(msg: RakNetMessage)
		if MatchesPacketId(packetId, msg.PacketId) then
			callback(msg)
		end
	end)

	table.insert(RakNetWrapper.Hooks.Send, registeredHook)
	return registeredHook
end

function RakNetWrapper.remove_all_hooks()
	for _, hook in RakNetWrapper.Hooks.Receive do
		pcall(raknet.remove_receive_hook, hook)
	end

	for _, hook in RakNetWrapper.Hooks.Send do
		pcall(raknet.remove_send_hook, hook)
	end

	RakNetWrapper.Hooks = {
		Receive = {},
		Send = {},
	}
end

return RakNetWrapper
