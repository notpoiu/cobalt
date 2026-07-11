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

			--// :InvokeServer() response (Server -> Client) \\--
			local OutgoingRequest = Requests.Outgoing:Consume(Instance, Response.InvokeId)
			if OutgoingRequest then
				if OutgoingRequest.ShouldLog == false then
					return false
				end

				local Log = InterceptorUtils.GetLog(Instance, "Incoming")
				local Info = {
					Arguments = OutgoingRequest.Arguments,
					InvokeResult = InterceptorUtils.PackArguments(Response.Arguments),
					Error = Response.Error,
					Origin = nil,
					Function = nil,
					Line = nil,
					Source = nil,
					IsExecutor = nil,
					IsRakNet = true,
					InvokeKind = "Request",
				}

				if Log.Blocked then
					if wax.shared.SaveManager:GetState("LogBlockedRemotes", false) then
						Info.Blocked = true
						Log:Call(Info)
					end

					return true
				elseif not Log.Ignored then
					Log:Call(Info)
				end

				return false
			end

			--// .OnClientInvoke request (Server -> Client) \\--
			local Log = InterceptorUtils.GetLog(Instance, "Incoming")
			local Info = {
				Arguments = InterceptorUtils.PackArguments(Response.Arguments),
				InvokeResult = nil,
				Error = Response.Error,
				Origin = nil,
				Function = nil,
				Line = nil,
				Source = nil,
				IsExecutor = nil,
				IsRakNet = true,
				InvokeKind = "Callback",
			}

			if Log.Blocked then
				if wax.shared.SaveManager:GetState("LogBlockedRemotes", false) then
					Info.Blocked = true
					Log:Call(Info)
				end

				return true
			end

			Requests.Incoming:Add(Instance, Response.InvokeId, {
				Info = Info,
				Instance = Instance,
				ShouldLog = ShouldCapture and not Log.Ignored,
			})
			return false
		end

		--// Blocked RemoteEvents (Server -> Client) \\--
		--// Actual Logging is done with regular luau & getconnections because it has richer information. \\--
		if not ShouldCapture then
			return false
		end

		local Log = InterceptorUtils.GetLog(Instance, "Incoming")
		if Log and Log.Blocked then
			if wax.shared.SaveManager:GetState("LogBlockedRemotes", false) then
				Log:Call({
					Arguments = InterceptorUtils.PackArguments(Payload.Arguments),
					Origin = nil,
					Function = nil,
					Line = nil,
					Source = nil,
					IsExecutor = nil,
					IsRakNet = true,
					Blocked = true,
				})
			end

			return true
		end

		return false
	end
end

--// Hooks \\--
return function(Requests: Requests)
	local HandlePayload = CreateHandler(Requests)
	return raknet.add_receive_hook(Constants.PacketIds.ID_DATA, function(Message: raknet.RakNetMessage)
		ProcessPacket(Message, HandlePayload)
	end)
end
