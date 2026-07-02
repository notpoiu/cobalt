local Bridge = {
	Current = nil,
}

function Bridge.Attach(WindowBridge)
	Bridge.Current = WindowBridge

	if WindowBridge.InfoModal and WindowBridge.InfoModal.Footer then
		WindowBridge.InfoModal.Footer:UpdateDropdownButtons()
	end
end

function Bridge.Get()
	assert(Bridge.Current, "Cobalt plugin window bridge has not been attached.")
	return Bridge.Current
end

function Bridge.GetOptional()
	return Bridge.Current
end

return Bridge
