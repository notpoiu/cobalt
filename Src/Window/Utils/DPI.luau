local DPI = {}
export type DPI = typeof(DPI)
DPI.__index = DPI

function DPI.new(data: {
    Scale: UIScale,
    SaveKey: string,
})
    local self = setmetatable({
        Scale = data.Scale,
        SaveKey = data.SaveKey,
    }, DPI)

    self.Scale.Scale = self:GetDPIScale()

    return self
end

function DPI:GetDPIScale()
	local Scale = wax.shared.SaveManager:GetState(self.SaveKey)
	return (tonumber(Scale:sub(1, #Scale - 1)) or 100) / 100
end

function DPI:CreateDPIScaleChangedCallback()
    return function()
        self.Scale.Scale = self:GetDPIScale()
    end
end

return DPI
