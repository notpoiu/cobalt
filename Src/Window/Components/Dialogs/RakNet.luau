local Types = require("@src/Window/Types")

local RakNet = {}

function RakNet.ConfirmEnable(Window: Types.Window): boolean
	local Support = wax.shared.ExecutorSupport["raknet"]
	if not Support.IsWorking then
		wax.shared.Sonner.error("RakNet hooks are not supported by your executor:\n\n" .. Support.Details)
		return false
	end

	local Thread = coroutine.running()
	task.spawn(Window.Dialog.new, {
		Title = "Warning",
		Description = "Are you sure you want to use RakNet hooks? This is risky and could theoretically lead to account bans. Cobalt is not responsible for any bans you may receive. This change takes effect the next time Cobalt launches.",
		Icon = "triangle-alert",
		AutoShow = true,
		Footer = {
			{
				Text = "Nevermind",
				Action = function(Dialog: Types.Dialog)
					Dialog:Dismiss()
					coroutine.resume(Thread, false)
				end,
			},
			{
				Text = "Continue (Hold to Confirm)",
				Type = "Primary",
				HoldDuration = 5,
				Action = function(Dialog: Types.Dialog)
					Dialog:Dismiss()
					coroutine.resume(Thread, true)
				end,
			},
		},
	})

	return coroutine.yield()
end

return RakNet
