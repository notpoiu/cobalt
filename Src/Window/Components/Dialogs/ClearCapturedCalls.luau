local Types = require("@src/Window/Types")

local ClearCapturedCalls = {}

function ClearCapturedCalls.Open(Window: Types.Window, ClearLogs: () -> ())
	return Window.Dialog.new({
		Title = "Clear Captured Calls?",
		TitleColor = Color3.fromRGB(245, 60, 54),
		Description = "This will permanently remove all captured incoming and outgoing calls. This action cannot be undone.",
		Icon = "trash",
		Footer = {
			{
				Text = "Cancel",
				Action = "Dismiss",
			},
			{
				Text = "Clear Calls",
				Type = "Primary",
				Action = function(Dialog: Types.Dialog)
					ClearLogs()
					Dialog:Dismiss()
				end,
			},
		},
	})
end

return ClearCapturedCalls
