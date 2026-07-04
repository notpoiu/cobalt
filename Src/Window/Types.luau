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
	ClearCalls: (any) -> (),
	SetButton: (any, TextButton, TextLabel, TextLabel) -> (),
	SetConnectionsEnabled: (any, boolean) -> (),
}

export type LogsState = {
	SelectedPageByLog: { [Log]: number },
	CurrentLog: Log?,
}

export type LogsPage = {
	State: LogsState,
	LogList: any?,
	LogCalls: any?,
	CleanLogsList: () -> (),
	ShowLog: (Log?) -> (),
	ClearLogs: (Instance?, LogDirection?) -> (),
	GetCurrentLog: () -> Log?,
	RefreshCurrentLog: () -> (),
}

export type Window = {
	Logs: LogsPage?,
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
	Refresh: (() -> ())?,
}

export type PaginationManager = {
	Helper: any,

	GetInfo: (any) -> any,
	SetOption: (any, PaginationDataKey, any) -> (),
	SetItemsPerPage: (any, number) -> (),
	GetIndexRanges: (any, number?) -> (number, number),
	SetPage: (any, number) -> (),
	Update: (any, number?, number?) -> (),
	GetVisualInfo: (any, number?) -> { any },
	BindPagination: (any, PaginationBinding) -> (),
}

export type LogDirectionTab = {
	Name: LogDirection,
	Logs: { [Instance]: Log },
	Instance: TextButton,
}

return {}
