local CallTemplates = {}

CallTemplates.IncomingCallbackInvoke = [[{{Prelude}}{{Path}}
local Callback = getcallbackvalue(Event, "{{Method}}")
{{CapturePrefix}}Callback({{Args}}){{CaptureSuffix}}{{ExpectedResultCode}}]]

CallTemplates.IncomingRequestInvoke = [[{{Prelude}}{{Path}}
{{CapturePrefix}}Event:{{Method}}({{Args}}){{CaptureSuffix}}{{ExpectedResultCode}}]]

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
