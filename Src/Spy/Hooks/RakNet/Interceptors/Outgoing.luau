--// Imports \\--
local raknet = require("@src/Utils/Hook/RakNet/Wrapper")
local Constants = require("@src/Spy/Hooks/RakNet/Constants")
local ProcessPacket = require("@src/Spy/Hooks/RakNet/PacketProcessor")

--// Helpers \\--
local InvocationTracker = require("@src/Spy/Hooks/RakNet/InvocationTracker")
local InterceptorUtils = require("@src/Spy/Hooks/RakNet/InterceptorUtils")

--// Types \\--
type Requests = {
	Incoming: InvocationTracker.Tracker,
	Outgoing: InvocationTracker.Tracker,
}

--// Handler \\--
local function CreateHandler(Requests: Requests)
	return function(Instance: Instance, Payload: ProcessPacket.Payload): boolean
		local ShouldCapture = not wax.shared.ShouldIgnore(Instance, nil)

		if Payload.Type == "RemoteFunction" then
			local Response = Payload.Response

			--// .OnClientInvoke return value (Client -> Server) \\--
			local IncomingRequest = Requests.Incoming:Consume(Instance, Response.InvokeId)
			if IncomingRequest then
				local Info = IncomingRequest.Info
				Info.InvokeResult = InterceptorUtils.PackArguments(Response.Arguments)
				Info.Error = Response.Error

				if IncomingRequest.ShouldLog then
					local Log = InterceptorUtils.GetLog(IncomingRequest.Instance, "Incoming")
					Log:Call(Info)
				end

				return false
			end

			--// :InvokeServer() request (Client -> Server) \\--
			local Log = InterceptorUtils.GetLog(Instance, "Outgoing")
			local Info = {
				Arguments = InterceptorUtils.PackArguments(Response.Arguments),
				Error = Response.Error,
				Origin = nil,
				Function = nil,
				Line = nil,
				Source = nil,
				IsExecutor = nil,
				IsRakNet = true,
			}

			if not ShouldCapture then
				Requests.Outgoing:Add(Instance, Response.InvokeId, {
					Arguments = Info.Arguments,
					ShouldLog = false,
				})
				return false
			end

			local ShouldBlock = Log:ShouldBlock(Info)
			Log:Call(Info)
			if ShouldBlock then
				return true
			end

			Requests.Outgoing:Add(Instance, Response.InvokeId, {
				Arguments = Info.Arguments,
				ShouldLog = true,
			})
			return false
		end

		--// :FireServer() - RemoteEvent/UnreliableRemoteEvent (Client -> Server) \\--
		if not ShouldCapture then
			return false
		end

		local Log = InterceptorUtils.GetLog(Instance, "Outgoing")
		local Info = {
			Arguments = InterceptorUtils.PackArguments(Payload.Arguments),
			Origin = nil,
			Function = nil,
			Line = nil,
			Source = nil,
			IsExecutor = nil,
			IsRakNet = true,
		}
		local ShouldBlock = Log:ShouldBlock(Info)
		Log:Call(Info)
		if ShouldBlock then
			return true
		end

		return false
	end
end

--// Hooks \\--
return function(Requests: Requests)
	local HandlePayload = CreateHandler(Requests)
	return raknet.add_send_hook(Constants.PacketIds.ID_DATA, function(Message: raknet.RakNetMessage)
		ProcessPacket(Message, HandlePayload)
	end)
end
