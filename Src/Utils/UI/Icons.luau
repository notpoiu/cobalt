local Icons = {}

type Icon = {
	Url: string,
	Id: number,
	IconName: string,
	ImageRectOffset: Vector2,
	ImageRectSize: Vector2,
}

local Success, IconsModule = pcall(function()
	return (loadstring(
		game:HttpGet("https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua")
	) :: () -> { Icons: { string }, GetAsset: (Name: string) -> Icon? })()
end)

function Icons.GetIcon(iconName: string): Icon?
	if not Success then
		return
	end

	local Success, Icon = pcall(IconsModule.GetAsset, iconName)
	if not Success then
		return
	end

	return Icon
end

function Icons.SetIcon(imageInstance: ImageLabel, iconName: string)
	local Icon: Icon? = Icons.GetIcon(iconName)
	if not Icon then
		return
	end

	imageInstance.Image = Icon.Url
	imageInstance.ImageRectOffset = Icon.ImageRectOffset
	imageInstance.ImageRectSize = Icon.ImageRectSize
end

return Icons
