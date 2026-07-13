local Types = require("@src/Window/Types")

local DetectionRisk = {}

function DetectionRisk.Open(Window: Types.Window, Failures: { string })
	local Details = {}
	for _, Name in Failures do
		local Check = wax.shared.ExecutorSupport[Name]
		local CheckDetails = if Check then Check.Details else "No details available."
		table.insert(
			Details,
			`<b><font color="#ff9900">{Name}</font></b>\n<font transparency="0.35">{CheckDetails}</font>`
		)
	end

	return Window.Dialog.new({
		Title = "Detection Risk",
		TitleColor = Color3.fromRGB(245, 60, 54),
		Description = "Cobalt may be detectable because your executor does not support the following functions or libraries:\n\n"
			.. table.concat(Details, "\n\n"),
		Icon = "triangle-alert",
		Footer = {
			{
				Text = "Close",
				Action = "Dismiss",
			},
		},
	})
end

return DetectionRisk
