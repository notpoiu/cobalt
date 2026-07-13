local SettingSync = {}

function SettingSync.Broadcast(Idx: string, Value: any)
	if not wax.shared.ActorCommunicator then
		return
	end

	pcall(function()
		wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, Value)
	end)
end

function SettingSync.Save(Idx: string, Value: any)
	local Success, Error = wax.shared.SaveManager:SetState(Idx, Value)
	if not Success then
		return false, Error
	end

	SettingSync.Broadcast(Idx, Value)
	return true
end

function SettingSync.Register(Idx: string, Setting: any, Value: any?)
	SettingSync.Broadcast(Idx, if Value == nil then Setting.Value else Value)
	wax.shared.Settings[Idx] = Setting
end

return SettingSync
