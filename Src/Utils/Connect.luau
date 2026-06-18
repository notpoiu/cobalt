local Connections = {}

local function Connect(Connection)
	table.insert(Connections, Connection)
	return Connection
end

local function Disconnect(Connection)
	Connection:Disconnect()

	local Index = table.find(Connections, Connection)
	if Index then
		table.remove(Connections, Index)
	end

	return true
end

wax.shared.Connections = Connections
wax.shared.Connect = Connect
wax.shared.Disconnect = Disconnect

return Connect
