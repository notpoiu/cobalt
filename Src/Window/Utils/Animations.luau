local Animations = {
	TweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Exponential),
	Exclusions = {},
	Expectations = { In = {}, Out = {} },
}

local function GetTransparencyProperty(object)
	if table.find(Animations.Exclusions, object) then
		return nil
	end

	if object:IsA("TextButton") or object:IsA("TextLabel") or object:IsA("TextBox") then
		return { "TextTransparency" }
	elseif object:IsA("CanvasGroup") then
		return { "GroupTransparency" }
	elseif object:IsA("Frame") then
		return { "BackgroundTransparency" }
	elseif object:IsA("ScrollingFrame") then
		return { "ScrollBarImageTransparency" }
	elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
		return { "ImageTransparency", "BackgroundTransparency" }
	elseif object:IsA("UIStroke") then
		return { "Transparency" }
	end

	return nil
end

local function BuildPropertyTable(properties, type, object)
	if Animations.Expectations[type][object] then
		return Animations.Expectations[type][object]
	end

	local propTable = {}
	for _, prop in properties do
		propTable[prop] = type == "In" and 0 or 1
	end
	return propTable
end

function Animations.FadeOut(object, time)
	local tweenInfo = time and TweenInfo.new(time, Enum.EasingStyle.Exponential) or Animations.TweenInfo
	local properties = GetTransparencyProperty(object)

	if not properties then
		return
	end

	wax.shared.TweenService:Create(object, tweenInfo, BuildPropertyTable(properties, "Out", object)):Play()

	if object:IsA("CanvasGroup") then
		return
	end

	for _, child in object:GetDescendants() do
		local prop = GetTransparencyProperty(child)
		if not prop then
			continue
		end

		wax.shared.TweenService:Create(child, tweenInfo, BuildPropertyTable(prop, "Out", child)):Play()
	end
end

function Animations.FadeIn(object, time)
	local tweenInfo = time and TweenInfo.new(time, Enum.EasingStyle.Exponential) or Animations.TweenInfo
	local property = GetTransparencyProperty(object)

	if property then
		wax.shared.TweenService:Create(object, tweenInfo, BuildPropertyTable(property, "In", object)):Play()
	end

	if object:IsA("CanvasGroup") then
		return
	end

	for _, child in object:GetDescendants() do
		local prop = GetTransparencyProperty(child)
		if not prop then
			continue
		end

		wax.shared.TweenService:Create(child, tweenInfo, BuildPropertyTable(prop, "In", child)):Play()
	end
end

function Animations.AddFadeExclusion(object)
	local prop = GetTransparencyProperty(object)
	if not prop then
		return
	end

	table.insert(Animations.Exclusions, object)
end

function Animations.AddFadeExclusions(objects)
	for _, object in objects do
		local prop = GetTransparencyProperty(object)
		if not prop then
			continue
		end

		table.insert(Animations.Exclusions, object)
	end
end

function Animations.SetFadeExpectation(type: "In" | "Out", object: GuiBase2d, properties: { [string]: any })
	if not Animations.Expectations[type] then
		return
	end

	Animations.Expectations[type][object] = properties
end

return Animations
