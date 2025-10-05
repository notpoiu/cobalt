wax.shared.Connections = {}

wax.shared.Connect = function(Connection)
	table.insert(wax.shared.Connections, Connection)
	return Connection
end

wax.shared.Disconnect = function(Connection)
	Connection:Disconnect()

	local Index = table.find(wax.shared.Connections, Connection)
	if Index then
		table.remove(wax.shared.Connections, Index)
	end

	return true
end

return {}