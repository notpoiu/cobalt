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
	ShouldBlock: (any, any) -> boolean,
	Call: (any, any) -> number?,
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

export type DialogDismissBehavior = "Dismiss" | "Destroy"

export type QueryFilterOperator =
	"Equals"
	| "NotEquals"
	| "LessThan"
	| "LessThanOrEqual"
	| "GreaterThan"
	| "GreaterThanOrEqual"
	| "Contains"
	| "StartsWith"
	| "EndsWith"
	| "TypeIs"
export type QueryFilterJoin = "And" | "Or"
export type QueryFilterAction = "Ignore" | "Block" | "Highlight"
export type QueryFilterDirection = LogDirection | "Any"

export type QueryFilterSubject =
	{ Type: "Argument", Index: number }
	| { Type: "ArgumentCount" }

export type QueryBuilderCondition = {
	Subject: QueryFilterSubject,
	Operator: QueryFilterOperator,
	Value: any,
	Join: QueryFilterJoin?,
}

export type QueryRemoteField = "Name" | "ClassName" | "FullName"
export type QueryRemoteCondition = {
	Field: QueryRemoteField,
	Operator: QueryFilterOperator,
	Value: string,
	Join: QueryFilterJoin?,
}

export type QueryRemoteTarget =
	{ Type: "Instance", Remote: SupportedRemoteTypes }
	| { Type: "Query", Conditions: { QueryRemoteCondition } }

export type QueryBuilderValue = {
	Target: QueryRemoteTarget,
	Direction: QueryFilterDirection,
	Conditions: { QueryBuilderCondition },
	Action: QueryFilterAction,
}

export type CallFilter = QueryBuilderValue & {
	Id: string,
	Enabled: boolean,
}

export type CallFilterManager = {
	GetAll: (CallFilterManager) -> { CallFilter },
	Get: (CallFilterManager, string) -> CallFilter?,
	Add: (CallFilterManager, QueryBuilderValue | CallFilter) -> CallFilter,
	Update: (CallFilterManager, string, { [string]: any }) -> CallFilter?,
	SetEnabled: (CallFilterManager, string, boolean) -> CallFilter?,
	Remove: (CallFilterManager, string) -> boolean,
	ReplaceAll: (CallFilterManager, { CallFilter }, boolean?) -> (),
	Subscribe: (CallFilterManager, ({ CallFilter }) -> ()) -> { Disconnect: (any) -> () },
	Match: (
		CallFilterManager,
		SupportedRemoteTypes,
		LogDirection,
		{ [number]: any }
	) -> (QueryFilterAction?, CallFilter?),
	Resolve: (CallFilterManager, SupportedRemoteTypes, LogDirection, any) -> (QueryFilterAction?, CallFilter?),
}

export type QueryBuilderProps = {
	Target: QueryRemoteTarget,
	Direction: QueryFilterDirection,
	SampleRemote: SupportedRemoteTypes?,
	ArgumentLabels: { [number]: string }?,
	Conditions: { QueryBuilderCondition }?,
	Action: QueryFilterAction?,
	OnChanged: ((QueryBuilderValue) -> ())?,
	OnValidationChanged: ((boolean, { string }) -> ())?,
}

export type QueryBuilder = {
	Root: Frame,
	Target: QueryRemoteTarget,
	Conditions: { QueryBuilderCondition },
	Direction: QueryFilterDirection,
	Action: QueryFilterAction,
	Destroyed: boolean,
	IsValid: boolean,
	ValidationErrors: { string },

	GetValue: (QueryBuilder) -> QueryBuilderValue,
	Validate: (QueryBuilder) -> (boolean, { string }),
	AddCondition: (QueryBuilder, QueryBuilderCondition?) -> QueryBuilderCondition,
	RemoveCondition: (QueryBuilder, number) -> (),
	SetAction: (QueryBuilder, QueryFilterAction) -> (),
	Destroy: (QueryBuilder) -> (),
}

export type QueryBuilderClass = {
	new: (Dialog, QueryBuilderProps) -> QueryBuilder,
}

export type Dialog = {
	DialogId: number,
	DismissBehavior: DialogDismissBehavior,
	IsOpen: boolean,
	Destroyed: boolean,
	Root: Frame,
	Overlay: TextButton,
	Container: CanvasGroup,
	Scale: UIScale,
	CloseButton: ImageButton,
	Header: {
		TitleLabel: TextLabel,
		DescriptionLabel: TextLabel,
		HeaderIcon: ImageLabel,
	},
	MainContent: Frame,
	Buttons: { [string]: DialogButton },
	Footer: {
		CreateButton: any,
		UI: Frame,
	},
	Show: (Dialog) -> (),
	Dismiss: (Dialog, DialogDismissBehavior?) -> Tween?,
	Destroy: (Dialog) -> (),
}

export type DialogFooterAction = "Dismiss" | ((Dialog) -> ())

export type DialogButton = {
	Instance: ImageButton,
	Label: TextLabel,
	Icon: ImageLabel,
	Disabled: boolean,

	SetDisabled: (DialogButton, boolean) -> (),
}

export type DialogFooterButton = {
	Type: ("Primary" | "Secondary")?,
	Text: string?,
	Icon: string?,
	Action: DialogFooterAction?,
	Disabled: boolean?,
	HoldDuration: number?,
	LayoutOrder: number?,
}

export type DialogProps = {
	Title: string,
	TitleColor: Color3?,
	Description: string,
	Icon: string?,
	Footer: { [number | string]: DialogFooterButton },

	AutoShow: boolean?,
	DismissBehavior: DialogDismissBehavior?,
}

export type DialogClass = {
	new: (DialogProps) -> Dialog,
}

export type Window = {
	Dialog: DialogClass,
	QueryBuilder: QueryBuilderClass,
	Dialogs: { [string]: any },
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
