local DEFAULT_TIMEOUT_SECONDS = 1500

local InvocationTracker = {}
InvocationTracker.__index = InvocationTracker

export type Tracker = typeof(setmetatable(
	{} :: {
		Entries: { [Instance]: { [number]: { Value: any, CreatedAt: number } } },
		TimeoutSeconds: number,
		LastPrune: number,
	},
	InvocationTracker
))

function InvocationTracker.new(timeoutSeconds: number?): Tracker
	return setmetatable({
		Entries = setmetatable({}, { __mode = "k" }),
		TimeoutSeconds = timeoutSeconds or DEFAULT_TIMEOUT_SECONDS,
		LastPrune = os.clock(),
	}, InvocationTracker)
end

function InvocationTracker.Prune(self: Tracker, now: number?)
	now = now or os.clock()
	if now - self.LastPrune < 1 then
		return
	end

	self.LastPrune = now
	for instance, entries in self.Entries do
		for invokeId, entry in entries do
			if now - entry.CreatedAt >= self.TimeoutSeconds then
				entries[invokeId] = nil
			end
		end

		if next(entries) == nil then
			self.Entries[instance] = nil
		end
	end
end

function InvocationTracker.Add(self: Tracker, instance: Instance, invokeId: number, value: any)
	self:Prune()

	local entries = self.Entries[instance]
	if not entries then
		entries = {}
		self.Entries[instance] = entries
	end

	entries[invokeId] = {
		Value = value,
		CreatedAt = os.clock(),
	}
end

function InvocationTracker.Consume(self: Tracker, instance: Instance, invokeId: number): any?
	self:Prune()

	local entries = self.Entries[instance]
	if not entries then
		return nil
	end

	local entry = entries[invokeId]
	entries[invokeId] = nil
	if next(entries) == nil then
		self.Entries[instance] = nil
	end

	if not entry or os.clock() - entry.CreatedAt >= self.TimeoutSeconds then
		return nil
	end

	return entry.Value
end

function InvocationTracker.Clear(self: Tracker)
	table.clear(self.Entries)
end

return InvocationTracker
