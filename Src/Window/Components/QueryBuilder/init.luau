local Types = require("@src/Window/Types")
local UI = require("@src/Window/Components/QueryBuilder/UI")
local Operators = require("@src/Utils/CallFilter/Operators")

type Dialog = Types.Dialog
type QueryBuilder = Types.QueryBuilder
type QueryBuilderProps = Types.QueryBuilderProps

local QueryBuilderClass = {
	ContextMenu = nil,
}

function QueryBuilderClass.new(Dialog: Dialog, Props: QueryBuilderProps): QueryBuilder
	local ContextMenu = assert(QueryBuilderClass.ContextMenu, "QueryBuilder.ContextMenu has not been configured")
	return UI.new(Dialog, Props, ContextMenu, Operators)
end

return QueryBuilderClass
