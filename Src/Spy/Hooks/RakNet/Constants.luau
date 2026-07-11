local Constants = {
	PacketIds = {},
	ItemTypes = {},
}

--// Packet IDs \\--
Constants.PacketIds.ID_DATA = 0x83

--// Item Types \\--
Constants.ItemTypes.ReliableEventInvocationItem = 0x07
Constants.ItemTypes.UnreliableEventInvocationItem = 0x03

return Constants
