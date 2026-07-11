return function(Data, Template)
	local NewData = {}
	for Key, Value in Template do
		if Data[Key] == nil or typeof(Data[Key]) ~= typeof(Value) then
			NewData[Key] = Value
		else
			NewData[Key] = Data[Key]
		end
	end

	return NewData
end
