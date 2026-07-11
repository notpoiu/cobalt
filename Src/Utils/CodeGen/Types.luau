export type SupportedRemoteTypes = RemoteEvent | RemoteFunction | BindableEvent | BindableFunction | UnreliableRemoteEvent
export type Direction = "Incoming" | "Outgoing"

export type CallInfo = {
	Arguments: { [number]: any, n: number },
	CreationTime: number,
	Origin: BaseScript?,
	Function: (
		...any
	) -> any | {
		Address: string,
		Name: string,
		Source: string?,
		IsC: boolean,
		Constants: { any }?,
		Upvalues: { any }?,
		Protos: { any }?,
		FunctionHash: string?,
	},
	Line: number?,
	Source: string?,
	Instance: SupportedRemoteTypes,
	Order: number,
	Type: Direction,
	InvokeResult: { [number]: any, n: number }?,
	Error: string?,
	InvokeKind: "Callback" | "Request"?,
	IsExecutor: boolean?,
	IsRakNet: boolean?,
	IsActor: true?,
	Path: string?,
	Actor: Actor?,
	Blocked: boolean?,
}

export type Scenario = {
	Type: Direction,
	Direction: Direction,
	Class: string,
	Method: string,
	Arguments: { [number]: any, n: number },
	Result: { [number]: any, n: number }?,
	Error: string?,
	InvokeKind: ("Callback" | "Request")?,
	Shape: "Request" | "SSE" | "Signal",
}

return {}
