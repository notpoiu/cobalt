local Types = require("@src/Window/Types")

return function(props: {
	Window: Types.Window,
})
	local Window = props.Window

	local Logs = {}
	local ListView = nil

	function Logs.BindListView(View: Types.LogsView)
		assert(type(View) == "table", "Logs.BindListView expects a view table")
		assert(type(View.ShowLog) == "function", "Logs.BindListView expects View.ShowLog")

		ListView = View
	end

	function Logs.CleanLogsList()
		if ListView and ListView.CleanLogsList then
			ListView.CleanLogsList()
		end
	end

	function Logs.ShowLog(Log)
		assert(ListView, "Window log list view has not been ported/bound yet")
		return ListView.ShowLog(Log)
	end

	function Logs.ClearLogs(FilterInstance: Instance?, FilterType: string?)
		local ClearedAny = false

		for Type, LogCategory in pairs(wax.shared.Logs) do
			if FilterType and Type ~= FilterType then
				continue
			end

			for _, Log in pairs(LogCategory) do
				if FilterInstance and Log.Instance ~= FilterInstance then
					continue
				end

				if Log.Button then
					Log.Button.Instance:Destroy()
					Log.Button = nil
				end

				Window.State.SelectedPageByLog[Log] = nil

				table.clear(Log.Calls)
				table.clear(Log.GameCalls)
				Log.Index = 0
				ClearedAny = true
			end
		end

		Logs.CleanLogsList()

		if not FilterInstance then
			Window.State.CurrentLog = nil
		elseif Window.State.CurrentLog and Window.State.CurrentLog.Instance == FilterInstance then
			Window.State.CurrentLog = nil
		end

		if ClearedAny then
			wax.shared.Sonner.success(
				`Successfully Cleared {FilterInstance and FilterInstance.Name .. " " or ""}{FilterType or "All"} Logs`
			)
		end
	end

	function Logs.GetCurrentLog()
		return Window.State.CurrentLog
	end

	return Logs
end
