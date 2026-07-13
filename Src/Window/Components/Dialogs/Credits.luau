local Types = require("@src/Window/Types")

local Credits = {}

function Credits.Open(Window: Types.Window)
	return Window.Dialog.new({
		Title = "Credits",
		Description = table.concat({
			"<b>upio</b> · Cobalt Developer",
			"<b>deivid</b> · Cobalt Developer",
			'<b>shadcn</b> · UI design inspiration · <font color="#3798ff">ui.shadcn.com</font>',
			'<b>The Lucide Team</b> · Icon library · <font color="#3798ff">lucide.dev</font>',
			'<b>Emil Kowalski</b> · Sonner · <font color="#3798ff">sonner.emilkowal.ski</font>',
		}, "\n\n"),
		Footer = {
			{
				Text = "Close",
				Action = "Dismiss",
			},
		},
	})
end

return Credits
