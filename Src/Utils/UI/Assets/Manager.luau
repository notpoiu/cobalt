local AssetManager = {
	FallbackMapping = {
		Logo = "rbxassetid://91685317120520",
	},
	SessionLoadedFonts = {},
}

local FileHelper = require("@src/Utils/FileHelper")
local Assets = FileHelper.new("Cobalt/Assets")

local UsedRandomStrings = {}
local AssetRandom = Random.new(tick())

local Charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
function GenerateSafeUniqueRandomString(length: number): string
	local randomString = ""
	while true do
		randomString = ""
		for i = 1, length do
			local randomIndex = AssetRandom:NextInteger(1, #Charset)
			randomString ..= string.sub(Charset, randomIndex, randomIndex)
		end

		local Success, Exists = pcall(function()
			return isfile(randomString) or isfolder(randomString)
		end)

		if Success and Exists then continue end
		if UsedRandomStrings[randomString] then continue end

		UsedRandomStrings[randomString] = true
		break
	end
	
	return randomString
end

local IsCustomAssetSafe
function SafeFetchCustomContentID(Path: string, FileName: string)
	local HasEstablishedSafe = typeof(IsCustomAssetSafe) == "boolean"
	if IsCustomAssetSafe or not HasEstablishedSafe then
		local Success, Result = pcall(function()
			return getcustomasset(Path)
		end)

		if not Success then
			return nil
		end

		--// Check if custom asset is something like `rbxasset://jkasdljflkas/filename` \\--
		if not HasEstablishedSafe then
			IsCustomAssetSafe = (
				Result:lower():find(
					FileName:lower(),
					1,
					true
				) == nil
			)
		end

		if IsCustomAssetSafe then
			return Result
		end
	end

	--// Executor Implementation is not safe, we randomize the asset name. \\--
	local RandomString = GenerateSafeUniqueRandomString(AssetRandom:NextInteger(4, 7))

	local Success, Result = pcall(function()
		writefile(RandomString, readfile(Path))
		return getcustomasset(RandomString)
	end)

	pcall(delfile, RandomString)

	if Success then
		return Result
	end

	return nil
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

--[[
	Returns a table of asset IDs for the given classname icons.

	@param Images: A table of classname icons.
	@return A table of asset IDs for the given classname icons.
]]
function AssetManager.GetInstanceClassImages(Images: { [string]: string })
	if not getcustomasset then
		return Images
	end

	local NewImages = {}
	for ClassName, Image in Images do
		local FileName = `{ClassName}.png`
		local FilePath = Assets:GetPath(FileName)

		if Assets:DoesExist(FileName) then
			NewImages[ClassName] = SafeFetchCustomContentID(FilePath, ClassName) or Image
			continue
		end

		local IconRawData = SafeFetchCustomImgData(`https://robloxapi.github.io/ref/icons/dark/{ClassName}.png`)
		if not IconRawData then
			NewImages[ClassName] = Image
			continue
		end

		Assets:WriteFile(FileName, IconRawData)

		NewImages[ClassName] = SafeFetchCustomContentID(FilePath, ClassName) or Image
	end

	return NewImages
end

--[[
	Returns the asset ID for the given image in registry.

	@param Image: The name of the image.
	@return The asset ID for the given image.
]]
function AssetManager.GetImage(Image: string)
	if not getcustomasset then
		return AssetManager.FallbackMapping[Image] or Image
	end

	local FileName = `{Image}.png`
	local FilePath = Assets:GetPath(FileName)

	if Assets:DoesExist(FileName) then
		return SafeFetchCustomContentID(FilePath, Image) or AssetManager.FallbackMapping[Image] or Image
	end

	local IconRawData =
		SafeFetchCustomImgData(`https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets/{Image}.png`)

	if not IconRawData then
		return AssetManager.FallbackMapping[Image] or Image
	end

	Assets:WriteFile(FileName, IconRawData)
	return SafeFetchCustomContentID(FilePath, Image) or AssetManager.FallbackMapping[Image] or Image
end

--[[
	Returns a custom font asset ID derived from the TTF url provided.

	@param FontData: A table containing the font data.
	@return The asset ID for the given font.
]]
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
						assetId = SafeFetchCustomContentID(TTFPath, FontData.Name) or FontData.FallbackId,
					},
				},
			})
		)

		AssetManager.SessionLoadedFonts[FontData.Name] = true
	end

	local CustomFontId = SafeFetchCustomContentID(FontPath, FontData.Name)
	if CustomFontId then
		return Font.new(CustomFontId)
	end

	return Font.fromId(FontData.FallbackId)
end

return AssetManager
