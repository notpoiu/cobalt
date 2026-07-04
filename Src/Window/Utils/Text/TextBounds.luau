local TextBounds = {}

local BoundsCache = {}
local BoundsCacheOrder = {}
local MaxCachedTextLength = 128
local MaxCacheEntries = 256

local function CreateCacheKey(Text: string, FontFace: Font, TextSize: number, Width: number?): string
	return `{TextSize}:{tostring(FontFace)}:{Width or ""}:{Text}`
end

function TextBounds.Get(Text: string, FontFace: Font, TextSize: number, Width: number?): (number, number)
	return wax.shared.GetTextBounds(Text, FontFace, TextSize, Width)
end

function TextBounds.GetCached(Text: string, FontFace: Font, TextSize: number, Width: number?): (number, number)
	if #Text > MaxCachedTextLength then
		return TextBounds.Get(Text, FontFace, TextSize, Width)
	end

	local CacheKey = CreateCacheKey(Text, FontFace, TextSize, Width)
	local Bounds = BoundsCache[CacheKey]
	if Bounds then
		return Bounds.X, Bounds.Y
	end

	local X, Y = TextBounds.Get(Text, FontFace, TextSize, Width)
	BoundsCache[CacheKey] = Vector2.new(X, Y)
	table.insert(BoundsCacheOrder, CacheKey)

	if #BoundsCacheOrder > MaxCacheEntries then
		local OldestKey = table.remove(BoundsCacheOrder, 1)
		BoundsCache[OldestKey] = nil
	end

	return X, Y
end

function TextBounds.GetCachedWidth(Text: string, FontFace: Font, TextSize: number, Width: number?): number
	local X = TextBounds.GetCached(Text, FontFace, TextSize, Width)
	return X
end

function TextBounds.ClearCache()
	table.clear(BoundsCache)
	table.clear(BoundsCacheOrder)
end

return TextBounds
