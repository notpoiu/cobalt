export type SupportedRemoteTypes = RemoteEvent | RemoteFunction | BindableEvent | BindableFunction | UnreliableRemoteEvent

export type LogDirection = "Outgoing" | "Incoming"

export type LogButton = {
	Instance: TextButton,
	Name: TextLabel,
	Calls: TextLabel,
}

export type Log = {
	Instance: SupportedRemoteTypes,
	Type: LogDirection,
	Method: string?,
	Index: number,
	Calls: { any },
	GameCalls: { number },
	SpamHistory: { number },
	Ignored: boolean,
	Blocked: boolean,
	Button: LogButton?,

	Ignore: (any) -> (),
	Block: (any) -> (),
	SetButton: (any, TextButton, TextLabel, TextLabel) -> (),
	SetConnectionsEnabled: (any, boolean) -> (),
}

export type LogsView = {
	CleanLogsList: (() -> ())?,
	ShowLog: (Log?) -> (),
}

export type WindowState = {
	SelectedPageByLog: { [Log]: number },
	CurrentLog: Log?,
}

export type WindowFunctions = {
	BindListView: (LogsView) -> (),
	CleanLogsList: () -> (),
	ShowLog: (Log?) -> (),
	ClearLogs: (Instance?, LogDirection?) -> (),
	GetCurrentLog: () -> Log?,
	[string]: any,
}

export type Window = {
	State: WindowState,
	Functions: WindowFunctions,
	Modals: { [string]: any },
}

export type PaginationData = {
	TotalItems: number,
	ItemsPerPage: number?,
	CurrentPage: number?,
	SiblingCount: number?,
}

export type PaginationDataKey = keyof<PaginationData>

export type PaginationBinding = {
	Component: any,
	PaginationKey: PaginationDataKey,
	Refresh: boolean,
}

export type PaginationManager = {
	Helper: any,
	Window: Window,

	GetInfo: (any) -> any,
	SetOption: (any, PaginationDataKey, any) -> (),
	SetItemsPerPage: (any, number) -> (),
	GetIndexRanges: (any, number?) -> (number, number),
	SetPage: (any, number) -> (),
	Update: (any, number?, number?) -> (),
	GetVisualInfo: (any, number?) -> { any },
	CreateRefreshCallback: (any) -> () -> (),
	BindPagination: (any, PaginationBinding) -> (),
}

export type LogDirectionTab = {
	Name: LogDirection,
	Logs: { [Instance]: Log },
	Instance: TextButton,
}

return {}
