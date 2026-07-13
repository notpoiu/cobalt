local Types = require("@src/Window/Types")

local DeleteCallFilter = {}

function DeleteCallFilter.Open(Window: Types.Window, Filter: Types.CallFilter)
	return Window.Dialog.new({
		Title = "Delete Call Filter?",
		Description = "This permanently removes the selected call filter.",
		Icon = "trash",
		Footer = {
			{ Text = "Cancel", Action = "Dismiss" },
			{
				Text = "Delete",
				Action = function(Dialog: Types.Dialog)
					wax.shared.CallFilters:Remove(Filter.Id)
					wax.shared.Sonner.success("Call filter deleted")
					Dialog:Dismiss()
				end,
			},
		},
	})
end

return DeleteCallFilter
