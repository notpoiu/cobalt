local CodeGen = require("@src/Utils/CodeGen/Generator")
local Types = require("@src/Window/Types")
local ModalController = require("@src/Window/Components/Modal")
local InstanceSerializer = require("@src/Utils/CodeGen/Serializer/Instance")
local LuaEncode = require("@src/Utils/CodeGen/Serializer/LuaEncode")

local function CopyToClipboard(Text: string, SuccessMessage: string, ErrorMessage: string)
	local Success, Error = pcall(setclipboard, Text)
	if Success then
		wax.shared.Sonner.success(SuccessMessage)
	else
		wax.shared.Sonner.error(ErrorMessage)
		warn(ErrorMessage, Error)
	end
end

return function(props: {
	Modal: {
		CurrentInfo: any?,
		[any]: any,
	},
	ModalController: ModalController.Modal,
	LogsPage: Types.LogsPage,
})
	local FooterButtons = {}

	local function GetCurrentInfo()
		return props.Modal.CurrentInfo
	end

	local function GetCurrentLog()
		return props.LogsPage.GetCurrentLog()
	end

	table.insert(FooterButtons, {
		Icon = "code",
		Title = "Code",
		Options = {
			{
				Text = "Calling Code",
				Icon = "forward",
				Callback = function()
					local CurrentInfo = GetCurrentInfo()
					if not CurrentInfo then
						return
					end

					CopyToClipboard(
						CodeGen:BuildCallCode(CurrentInfo),
						"Copied code to clipboard",
						"Failed to copy code to clipboard"
					)
				end,
			},
			{
				Text = "Intercept Code",
				Icon = "shield-alert",
				Callback = function()
					local CurrentInfo = GetCurrentInfo()
					if not CurrentInfo then
						return
					end

					CopyToClipboard(
						CodeGen:BuildHookCode(CurrentInfo),
						"Copied code to clipboard",
						"Failed to copy code to clipboard"
					)
				end,
			},
			{
				Text = "Function Info",
				Icon = "parentheses",
				Callback = function()
					local CurrentInfo = GetCurrentInfo()
					if not CurrentInfo then
						return
					end

					local Info = {
						Function = typeof(CurrentInfo.Function) == "function"
								and {
									Name = CurrentInfo.Function and debug.info(CurrentInfo.Function, "n") or "Unknown",
									Source = CurrentInfo.Source
										or (CurrentInfo.Function and debug.info(CurrentInfo.Function, "s"))
										or "Unknown",
									Type = CurrentInfo.Function
											and (iscclosure(CurrentInfo.Function) and "C Closure" or "Luau function")
										or "N/A",
									Address = tostring(CurrentInfo.Function),
									Arguments = {
										wax.shared.SafePack.Unpack(
											CurrentInfo.Arguments,
											1,
											wax.shared.GetTableLength(CurrentInfo.Arguments)
										),
									},
								}
							or CurrentInfo.Function,
						Script = CurrentInfo.Origin,
						Line = CurrentInfo.Line,
					}

					if typeof(CurrentInfo.Function) == "function" and islclosure(CurrentInfo.Function) then
						local FunctionInfo = {
							Constants = debug.getconstants,
							Upvalues = debug.getupvalues,
							Protos = debug.getprotos,
						}

						for Type, Func in pairs(FunctionInfo) do
							if Func then
								Info.Function[Type] = Func(CurrentInfo.Function)
							end
						end
					end

					CopyToClipboard(
						`local Info = {LuaEncode(Info, { Prettify = true, DisableNilParentHandler = true })}`,
						"Copied function info to clipboard",
						"Failed to copy function info to clipboard"
					)
				end,
			},
		},
	})

	table.insert(FooterButtons, {
		Icon = "scroll-text",
		Title = "Origin",
		Options = {
			{
				Text = "Remote Path",
				Icon = "package-search",
				Callback = function()
					local CurrentInfo = GetCurrentInfo()
					if not CurrentInfo then
						return
					end

					CopyToClipboard(
						InstanceSerializer.Serialize(CurrentInfo.Instance, {
							VariableName = "Event",
							DisableNilParentHandler = false,
						}),
						"Copied remote path to clipboard",
						"Failed to copy remote path to clipboard"
					)
				end,
			},
			{
				Text = "Script Path",
				Icon = "file-search",
				Condition = function()
					local CurrentInfo = GetCurrentInfo()
					return CurrentInfo and typeof(CurrentInfo.Origin) == "Instance"
				end,
				Callback = function()
					local CurrentInfo = GetCurrentInfo()
					if not (CurrentInfo and typeof(CurrentInfo.Origin) == "Instance") then
						return
					end

					CopyToClipboard(
						InstanceSerializer.Serialize(CurrentInfo.Origin),
						"Copied script path to clipboard",
						"Failed to copy script path to clipboard"
					)
				end,
			},
			{
				Text = "Decompiled Script",
				Icon = "file-text",
				Condition = function()
					local CurrentInfo = GetCurrentInfo()
					return CurrentInfo and typeof(CurrentInfo.Origin) == "Instance" and typeof(decompile) == "function"
				end,
				Callback = function()
					local CurrentInfo = GetCurrentInfo()
					if
						not (
							CurrentInfo
							and typeof(CurrentInfo.Origin) == "Instance"
							and typeof(decompile) == "function"
						)
					then
						return
					end

					local Decompiled, Result = pcall(decompile, CurrentInfo.Origin)
					if Decompiled then
						CopyToClipboard(
							Result,
							"Copied decompiled script to clipboard",
							"Failed to copy decompiled script to clipboard"
						)
					else
						wax.shared.Sonner.error("Failed to decompile script")
						warn("Failed to decompile script", Result)
					end
				end,
			},
		},
	})

	table.insert(FooterButtons, {
		Icon = "network",
		Title = "Event",
		Options = {
			{
				Text = "Replay",
				Icon = "play",
				Callback = function()
					local CurrentInfo = GetCurrentInfo()
					if not CurrentInfo then
						return
					end

					wax.shared.Sonner.promise(function()
						CodeGen:ReplayCallInfo(CurrentInfo)
					end, {
						loadingText = "Replaying event...",
						successText = "Replayed event successfully!",
						errorText = "Failed to replay event",
						time = 4.5,
					})
				end,
			},
			{
				Text = function()
					local CurrentLog = GetCurrentLog()
					return CurrentLog and (CurrentLog.Ignored and "Unignore" or "Ignore") or "Ignore"
				end,
				Icon = function()
					local CurrentLog = GetCurrentLog()
					return CurrentLog and (CurrentLog.Ignored and "eye" or "eye-off") or "eye"
				end,
				Callback = function()
					local CurrentLog = GetCurrentLog()
					if not CurrentLog then
						return
					end

					CurrentLog:Ignore()
					wax.shared.Sonner.success(`{CurrentLog.Ignored and "Started" or "Stopped"} ignoring event`)
				end,
			},
			{
				Text = function()
					local CurrentLog = GetCurrentLog()
					return CurrentLog and (CurrentLog.Blocked and "Unblock" or "Block") or "Block"
				end,
				Icon = function()
					local CurrentLog = GetCurrentLog()
					return CurrentLog and (CurrentLog.Blocked and "lock" or "lock-open") or "lock"
				end,
				Callback = function()
					local CurrentLog = GetCurrentLog()
					if not CurrentLog then
						return
					end

					CurrentLog:Block()

					local BlockedRemoteList = wax.shared.Settings["BlockedRemotes"]
					if BlockedRemoteList then
						if CurrentLog.Blocked then
							BlockedRemoteList:AddToList(CurrentLog)
						else
							BlockedRemoteList:RemoveFromList(CurrentLog)
						end
					end

					wax.shared.Sonner.success(`{CurrentLog.Blocked and "Started" or "Stopped"} blocking event`)
				end,
			},
			{
				Text = "Clear Logs",
				Icon = "trash",
				Callback = function()
					local CurrentLog = GetCurrentLog()
					if not CurrentLog then
						return
					end

					props.LogsPage.ClearLogs(CurrentLog.Instance, CurrentLog.Type)
					props.ModalController:Close()
				end,
			},
		},
	})

	return FooterButtons
end
