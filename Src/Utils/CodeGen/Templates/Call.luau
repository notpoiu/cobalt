local CallTemplates = {}

CallTemplates.IncomingCallbackInvoke = [[{{Prelude}}{{Path}}
local Callback = getcallbackvalue(Event, "{{Method}}")
local Result = table.pack(Callback({{Args}})){{ExpectedResultCode}}]]

CallTemplates.IncomingRequestInvoke = [[{{Prelude}}{{Path}}
local Result = Event:{{Method}}({{Args}}){{ExpectedResultCode}}]]

CallTemplates.IncomingSignal = [[{{Prelude}}{{Path}}
firesignal(Event.{{Method}}{{ArgsWithLeadingComma}})]]

CallTemplates.OutgoingCall = [[{{Prelude}}{{Path}}
Event:{{Method}}({{Args}})]]

CallTemplates.Incoming = {
	SSE = CallTemplates.IncomingCallbackInvoke,
	Request = CallTemplates.IncomingRequestInvoke,
	Signal = CallTemplates.IncomingSignal,
}

CallTemplates.Outgoing = CallTemplates.OutgoingCall

return CallTemplates
