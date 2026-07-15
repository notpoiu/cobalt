local Types = require("@src/Window/Types")

local LoggingDisabled = {}

function LoggingDisabled.Open(Window: Types.Window)
	return Window.Dialog.new({
		Title = "Limited Logging Support",
		TitleColor = Color3.fromRGB(245, 166, 35),
		Description = "Your executor can't fully support Cobalt's remote logging. Incoming RemoteEvents will still be captured with limited info; outgoing calls and incoming RemoteFunctions won't be logged on this executor.",
		Icon = "triangle-alert",
		Footer = {
			{
				Text = "I understand",
				Type = "Primary",
				HoldDuration = 3,
				Action = function(Dialog: Types.Dialog)
					if wax.shared.SaveManager:SetState("LimitedLoggingAcknowledged", true) then
						Dialog:Dismiss()
					end
				end,
			},
		},
	})
end

return LoggingDisabled
