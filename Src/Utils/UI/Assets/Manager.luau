local AssetManager = {
	FallbackMapping = {
		Logo = "rbxassetid://91685317120520",
	},
	SessionLoadedFonts = {},
}

local FileHelper = require(script.Parent.Parent.Parent.FileHelper)
local Assets = FileHelper.new("Cobalt/Assets")

function SafeFetchCustomContentID(Path: string)
	local Success, Result = pcall(function()
		return getcustomasset(Path)
	end)

	return Success and Result or nil
end

function SafeFetchCustomImgData(url)
	local Success, Response = pcall(request, {
		Url = url,
		Method = "GET",
	})

	if Success and Response.Success or Response.StatusCode >= 200 and Response.StatusCode < 300 then
		return Response.Body
	end

	return nil
end

function AssetManager.GetRemoteImages(Images: { [string]: string })
	if not getcustomasset then
		return Images
	end

	local NewImages = {}
	for ClassName, Image in Images do
		local FileName = `{ClassName}.png`
		local FilePath = Assets:GetPath(FileName)

		if Assets:DoesExist(FileName) then
			NewImages[ClassName] = SafeFetchCustomContentID(FilePath) or Image
			continue
		end

		local IconRawData = SafeFetchCustomImgData(`https://robloxapi.github.io/ref/icons/dark/{ClassName}.png`)
		if not IconRawData then
			NewImages[ClassName] = Image
			continue
		end

		Assets:WriteFile(FileName, IconRawData)

		NewImages[ClassName] = SafeFetchCustomContentID(FilePath) or Image
	end

	return NewImages
end

function AssetManager.GetImage(Image: string)
	if not getcustomasset then
		return AssetManager.FallbackMapping[Image] or Image
	end

	local FileName = `{Image}.png`
	local FilePath = Assets:GetPath(FileName)

	if Assets:DoesExist(FileName) then
		return SafeFetchCustomContentID(FilePath) or AssetManager.FallbackMapping[Image] or Image
	end

	local IconRawData =
		SafeFetchCustomImgData(`https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets/{Image}.png`)

	if not IconRawData then
		return AssetManager.FallbackMapping[Image] or Image
	end

	Assets:WriteFile(FileName, IconRawData)
	return SafeFetchCustomContentID(FilePath) or AssetManager.FallbackMapping[Image] or Image
end

function AssetManager.GetCustomFont(FontData: {
	Name: string,
	Url: string,

	FallbackId: number,
})
	if not getcustomasset then
		return FontData.FallbackId
	end

	local TTFFileName = `{FontData.Name}.ttf`
	local TTFPath = Assets:GetPath(TTFFileName)
	if not Assets:DoesExist(TTFFileName) then
		local FontRawData = SafeFetchCustomImgData(FontData.Url)
		if not FontRawData then
			return Font.fromId(FontData.FallbackId)
		end

		Assets:WriteFile(TTFFileName, FontRawData)
	end

	local FontFileName = `{FontData.Name}.font`
	local FontPath = Assets:GetPath(FontFileName)
	if not AssetManager.SessionLoadedFonts[FontData.Name] then
		Assets:WriteFile(
			FontFileName,
			wax.shared.HttpService:JSONEncode({
				name = FontData.Name,
				faces = {
					{
						name = "Regular",
						weight = 400,
						style = "normal",
						assetId = SafeFetchCustomContentID(TTFPath) or FontData.FallbackId,
					},
				},
			})
		)

		AssetManager.SessionLoadedFonts[FontData.Name] = true
	end

	local CustomFontId = SafeFetchCustomContentID(FontPath)
	if CustomFontId then
		return Font.new(CustomFontId)
	end

	return Font.fromId(FontData.FallbackId)
end

return AssetManager
