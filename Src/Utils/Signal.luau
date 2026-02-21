local SignalHandler = {
	Signals = {},
}

function SignalHandler.New(self)
	local Signal = {
		Connections = {},
		Disconnect = nil,
	}

	function Signal:Connect(callback)
		local connection = {
			Connected = true,
			Enabled = true,
			Callback = callback,
		}

		function connection:Disconnect()
			connection.Connected = false
		end

		function connection:Reconnect()
			if not connection.Enabled then
				return
			end

			connection.Connected = true
		end

		function connection:Enable()
			connection.Enabled = true
		end

		function connection:Disable()
			connection.Enabled = false
		end

		table.insert(Signal.Connections, connection)

		return connection
	end

	function Signal:Once(callback)
		local connection
		connection = Signal:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)

		return connection
	end

	function Signal:Fire(...)
		for _, connection in Signal.Connections do
			if connection.Connected and connection.Enabled then
				task.spawn(connection.Callback, ...)
			end
		end
	end

	function Signal:Wait(...)
		local return_data = {}
		local finishedWaiting = false

		Signal:Once(function(...)
			return_data = { ... }
			finishedWaiting = true
		end)

		repeat
			task.wait()
		until finishedWaiting
		return table.unpack(return_data)
	end

	table.insert(SignalHandler.Signals, Signal)
	return Signal
end

function SignalHandler.StopAll(self: any)
	for Index, Signal in SignalHandler.Signals do
		for _, Connection in Signal.Connections do
			Connection:Disable()
			Connection:Disconnect()
		end
	end
end

return SignalHandler
