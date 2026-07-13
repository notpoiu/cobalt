local Registry = require(script.Registry)

for Name, Setting in Registry do
	assert(Name == Setting.Key, `Setting registry key {Name} does not match setting key {Setting.Key}`)
end

return Registry
