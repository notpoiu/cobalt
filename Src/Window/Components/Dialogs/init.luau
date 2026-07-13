local Registry = {}

for _, Dialog in script:GetChildren() do
	Registry[Dialog.Name] = require(Dialog)
end

return Registry