local Parser = require("@src/Utils/Hook/RakNet/Variant/Parser")

local SafePack = wax.shared.SafePack

local InterceptorUtils = {}

function InterceptorUtils.GetLog(instance: Instance, direction: "Outgoing" | "Incoming")
	local log = wax.shared.Logs[direction][instance]
	if not log then
		log = wax.shared.NewLog(instance, direction, getcallingscript())
	end

	return log
end

function InterceptorUtils.PackArguments(arguments: Parser.Arguments)
	return SafePack.Pack(SafePack.Unpack(arguments.Values, 1, arguments.Count))
end

return InterceptorUtils
