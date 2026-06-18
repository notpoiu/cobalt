type RatelimiterOptions = {
	Burst: {
		Time: number,
		Max: number,
	},

	PeriodicInterval: number?,
	MainCallback: (...any) -> ...any,
	OnUnload: (() -> ())?,
}

local Ratelimiter = {}
Ratelimiter.__index = Ratelimiter

function Ratelimiter.new(Options: RatelimiterOptions)
	local self = setmetatable(Options, Ratelimiter)
	self.Bucket = {}
	self.Queue = {}

	self.IsDestroyed = false
	self.ManagerThread = nil
	self.PeriodicThread = nil

	self:SetupManagerThread()

	return self
end

function Ratelimiter:QueueOperation(...: any)
	if self.IsDestroyed then
		return
	end

	table.insert(self.Queue, table.pack(...))
end

function Ratelimiter:SetupManagerThread()
	if self.IsDestroyed then
		return
	end

	self.Bucket = {}
	self.Queue = {}

	if self.ManagerThread then
		task.cancel(self.ManagerThread)
		self.ManagerThread = nil
	end

	if self.PeriodicThread then
		task.cancel(self.PeriodicThread)
		self.PeriodicThread = nil
	end

	self.ManagerThread = task.spawn(function()
		while not wax.shared.Unloaded and not self.IsDestroyed do
			local CurrentTime = tick()

			if #self.Bucket > 0 then
				local NewBucket = {}
				for _, Time in self.Bucket do
					if CurrentTime - Time < self.Burst.Time then
						table.insert(NewBucket, Time)
					end
				end

				self.Bucket = NewBucket
			end

			while #self.Bucket < self.Burst.Max and #self.Queue > 0 do
				local TaskData = table.remove(self.Queue, 1)
				if TaskData then
					table.insert(self.Bucket, tick())

					task.defer(function()
						if self.IsDestroyed then
							return
						end

						self.MainCallback(table.unpack(TaskData, 1, TaskData.n))
					end)
				end
			end

			task.wait()
		end

		if wax.shared.Unloaded and not self.IsDestroyed and self.OnUnload then
			self.OnUnload()
		end
	end)

	if not self.PeriodicInterval then
		return
	end

	self.PeriodicThread = task.spawn(function()
		while not wax.shared.Unloaded and not self.IsDestroyed do
			self:QueueOperation()
			task.wait(self.PeriodicInterval)
		end
	end)
end

function Ratelimiter:Destroy()
	if self.IsDestroyed then
		return
	end

	self.IsDestroyed = true

	if self.ManagerThread then
		task.cancel(self.ManagerThread)
		self.ManagerThread = nil
	end

	if self.PeriodicThread then
		task.cancel(self.PeriodicThread)
		self.PeriodicThread = nil
	end

	table.clear(self.Bucket)
	table.clear(self.Queue)
end

Ratelimiter.Stop = Ratelimiter.Destroy

return Ratelimiter
