local AssetManager = {
	FallbackMapping = {
		Logo = "rbxassetid://91685317120520",
	},
	SessionLoadedFonts = {},
}

if not isfolder("Cobalt/Assets") then
	makefolder("Cobalt/Assets")
end

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
		if isfile(`Cobalt/Assets/{ClassName}.png`) then
			NewImages[ClassName] = SafeFetchCustomContentID(`Cobalt/Assets/{ClassName}.png`) or Image
			continue
		end

		local IconRawData = SafeFetchCustomImgData(`https://robloxapi.github.io/ref/icons/dark/{ClassName}.png`)
		if not IconRawData then
			NewImages[ClassName] = Image
			continue
		end

		writefile(
			`Cobalt/Assets/{ClassName}.png`,
			IconRawData
		)

		NewImages[ClassName] = SafeFetchCustomContentID(`Cobalt/Assets/{ClassName}.png`) or Image
	end

	return NewImages
end

function AssetManager.GetImage(Image: string)
	if not getcustomasset then
		return AssetManager.FallbackMapping[Image] or Image
	end

	if isfile(`Cobalt/Assets/{Image}.png`) then
		return SafeFetchCustomContentID(`Cobalt/Assets/{Image}.png`) or AssetManager.FallbackMapping[Image] or Image
	end

	local IconRawData = SafeFetchCustomImgData(`https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets/{Image}.png`)

	if not IconRawData then
		return AssetManager.FallbackMapping[Image] or Image
	end

	writefile(`Cobalt/Assets/{Image}.png`, IconRawData)
	return SafeFetchCustomContentID(`Cobalt/Assets/{Image}.png`) or AssetManager.FallbackMapping[Image] or Image
end

function AssetManager.GetCustomFont(FontData: {
	Name: string,
	Url: string,

	FallbackId: number,
})
	if not getcustomasset then
		return FontData.FallbackId
	end

	local TTFPath = `Cobalt/Assets/{FontData.Name}.ttf`
	if not isfile(TTFPath) then
		local FontRawData = SafeFetchCustomImgData(FontData.Url)
		if not FontRawData then return Font.fromId(FontData.FallbackId) end

		writefile(TTFPath, FontRawData)
	end

	if not AssetManager.SessionLoadedFonts[FontData.Name] then
		writefile(`Cobalt/Assets/{FontData.Name}.font`, wax.shared.HttpService:JSONEncode({
			name = FontData.Name,
			faces = {
				{
					name = "Regular",
					weight = 400,
					style = "normal",
					assetId = SafeFetchCustomContentID(TTFPath) or FontData.FallbackId
				}
			}
		}))

		AssetManager.SessionLoadedFonts[FontData.Name] = true
	end

	local CustomFontId = SafeFetchCustomContentID(`Cobalt/Assets/{FontData.Name}.font`)
	if CustomFontId then
		return Font.new(CustomFontId)
	end

	return Font.fromId(FontData.FallbackId)
end

return AssetManager
