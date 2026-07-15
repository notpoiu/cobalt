--// Imports \\--
local Registry = require(script.Parent.Registry)
local FileHelper = require("@src/Utils/FileHelper")

--// Manager \\--
local AssetManager = {
	Overrides = {},
	Resolved = {},
	Sources = {},
	Errors = {},
	Preloaded = false,
}

local Assets = FileHelper.new("Cobalt/Assets")

local UsedRandomStrings = {}
local AssetRandom = Random.new(tick())

local IsCustomAssetSafe: boolean?
local UseRawCustomAssetPaths = false

type Resolution = {
	Value: any,
	Source: "Custom" | "Fallback",
	Error: string?,
}

local function GetFallback(Definition)
	if Definition.Type == "Font" then
		return Font.fromId(Definition.FallbackId)
	end

	return Definition.FallbackId
end

local GenerateSafeUniqueRandomFileName
do
	local Charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	GenerateSafeUniqueRandomFileName = function(): string
		while true do
			local RandomString = ""
			for _ = 1, AssetRandom:NextInteger(4, 7) do
				local RandomIndex = AssetRandom:NextInteger(1, #Charset)
				RandomString ..= Charset:sub(RandomIndex, RandomIndex)
			end

			local FileName = RandomString
			local Success, Exists = pcall(function()
				return isfile(FileName) or isfolder(FileName)
			end)

			if Success and Exists then
				continue
			end
			if UsedRandomStrings[FileName] then
				continue
			end

			UsedRandomStrings[FileName] = true
			return FileName
		end
	end
end

local function FetchRandomizedCustomContentId(Path: string): string?
	local RandomFileName = GenerateSafeUniqueRandomFileName()

	local Success, Result = pcall(function()
		writefile(RandomFileName, readfile(Path))
		return getcustomasset(RandomFileName)
	end)

	pcall(delfile, RandomFileName)

	if Success and typeof(Result) == "string" then
		return Result
	end
	return nil
end

local function SafeFetchCustomContentId(Path: string, FileName: string): string?
	if typeof(getcustomasset) ~= "function" then
		return nil
	end

	--// raw getcustomasset path \\--
	if UseRawCustomAssetPaths then
		local Success, Result = pcall(getcustomasset, Path)
		return if Success and typeof(Result) == "string" then Result else nil
	end

	--// Safety check \\--
	local HasEstablishedSafety = typeof(IsCustomAssetSafe) == "boolean"
	
	if
		IsCustomAssetSafe or
		not HasEstablishedSafety
	then
		local Success, Result = pcall(getcustomasset, Path)
		local IsValidResult = Success and typeof(Result) == "string"

		--// Determine safety \\--
		if not HasEstablishedSafety then
			if IsValidResult then
				IsCustomAssetSafe = Result:lower():find(FileName:lower(), 1, true) == nil
			else
				IsCustomAssetSafe = false
			end
		end

		--// Return result if safe \\--
		if IsValidResult and IsCustomAssetSafe then
			return Result
		end
	end

	--// Fallback to randomized custom content id \\--
	return FetchRandomizedCustomContentId(Path)
end

local function FetchAssetData(Url: string): string?
	if typeof(request) ~= "function" then
		return nil
	end

	local Success, Response = pcall(request, {
		Url = Url,
		Method = "GET",
	})

	if not Success then
		return nil
	end

	local StatusCode = tonumber(Response.StatusCode)
	if Response.Success ~= true and not (StatusCode and StatusCode >= 200 and StatusCode < 300) then
		return nil
	end

	return if typeof(Response.Body) == "string" then Response.Body else nil
end

local function EnsureAssetFile(Definition): (boolean, string?)
	if Assets:DoesExist(Definition.FileName) then
		return true
	end

	local Data = FetchAssetData(Definition.Url)
	if not Data then
		return false, `Failed to download {Definition.FileName}`
	end

	local Success, Error = pcall(Assets.WriteFile, Assets, Definition.FileName, Data)
	if not Success then
		return false, tostring(Error)
	end

	return true
end

local function ResolveImage(Name: string, Definition): Resolution
	--// Ensure asset file exists \\--
	local Exists, Error = EnsureAssetFile(Definition)
	if not Exists then
		return {
			Value = GetFallback(Definition),
			Source = "Fallback",
			Error = Error,
		}
	end

	--// Fetch custom content id \\--
	local ContentId = SafeFetchCustomContentId(Assets:GetPath(Definition.FileName), Definition.FileName)
	if not ContentId then
		return {
			Value = GetFallback(Definition),
			Source = "Fallback",
			Error = `Failed to load {Definition.FileName} with getcustomasset`,
		}
	end

	return {
		Value = ContentId,
		Source = "Custom",
	}
end

local function ResolveFont(Name: string, Definition): Resolution
	--// Ensure asset file exists \\--
	local Exists, Error = EnsureAssetFile(Definition)
	if not Exists then
		return {
			Value = GetFallback(Definition),
			Source = "Fallback",
			Error = Error,
		}
	end

	--// Fetch custom content id \\--
	local TTFPath = Assets:GetPath(Definition.FileName)
	local TTFAssetId = SafeFetchCustomContentId(TTFPath, Definition.FileName)
	if not TTFAssetId then
		return {
			Value = GetFallback(Definition),
			Source = "Fallback",
			Error = `Failed to load {Definition.FileName} with getcustomasset`,
		}
	end

	local FontFileName = `{Name}.font`
	local FontPath = Assets:GetPath(FontFileName)
	local Success, WriteError = pcall(
		Assets.WriteFile,
		Assets,
		FontFileName,
		wax.shared.HttpService:JSONEncode({
			name = Definition.FamilyName,
			faces = {
				{
					name = "Regular",
					weight = 400,
					style = "normal",
					assetId = TTFAssetId,
				},
			},
		})
	)

	if not Success then
		return {
			Value = GetFallback(Definition),
			Source = "Fallback",
			Error = tostring(WriteError),
		}
	end

	local FontAssetId = SafeFetchCustomContentId(FontPath, FontFileName)
	if not FontAssetId then
		return {
			Value = GetFallback(Definition),
			Source = "Fallback",
			Error = `Failed to load {FontFileName} with getcustomasset`,
		}
	end

	local Created, FontFace = pcall(Font.new, FontAssetId)
	if not Created then
		return {
			Value = GetFallback(Definition),
			Source = "Fallback",
			Error = tostring(FontFace),
		}
	end

	return {
		Value = FontFace,
		Source = "Custom",
	}
end

local function ResolveAllAssets()
	for Name, Definition in Registry do
		local Success, ResolutionOrError = pcall(function()
			if Definition.Type == "Font" then
				return ResolveFont(Name, Definition)
			end

			return ResolveImage(Name, Definition)
		end)

		if Success then
			AssetManager.Resolved[Name] = ResolutionOrError.Value
			AssetManager.Sources[Name] = ResolutionOrError.Source
			AssetManager.Errors[Name] = ResolutionOrError.Error
		else
			AssetManager.Resolved[Name] = GetFallback(Definition)
			AssetManager.Sources[Name] = "Fallback"
			AssetManager.Errors[Name] = tostring(ResolutionOrError)
		end
	end
end

function AssetManager.SetOverride(Name: string, Value: any)
	assert(Registry[Name], `Unknown asset {Name}`)
	AssetManager.Overrides[Name] = Value
end

function AssetManager.ClearOverride(Name: string)
	AssetManager.Overrides[Name] = nil
end

function AssetManager.UseFallback(Name: string)
	local Definition = assert(Registry[Name], `Unknown asset {Name}`)
	AssetManager.SetOverride(Name, GetFallback(Definition))
end

function AssetManager.PreloadAsync()
	if AssetManager.Preloaded then
		return
	end

	local FileSystemSupport = wax.shared.ExecutorSupport.FileSystem
	if not FileSystemSupport or not FileSystemSupport.IsWorking or typeof(getcustomasset) ~= "function" then
		for Name, Definition in Registry do
			AssetManager.Resolved[Name] = GetFallback(Definition)
			AssetManager.Sources[Name] = "Fallback"
			AssetManager.Errors[Name] = "Custom assets require filesystem and getcustomasset support"
		end

		AssetManager.Preloaded = true
		return
	end

	Assets:EnsureDirectory()
	ResolveAllAssets()

	AssetManager.Preloaded = true
end

local function GetCustomFontErrors(): { [string]: string }
	local Errors = {}
	for Name, Definition in Registry do
		if Definition.Type ~= "Font" then
			continue
		end

		if AssetManager.Sources[Name] ~= "Custom" then
			Errors[Name] = AssetManager.Errors[Name] or "custom font was unavailable"
			continue
		end

		local Params = Instance.new("GetTextBoundsParams")
		Params.Text = "Cobalt"
		Params.RichText = true
		Params.Font = AssetManager.GetCustomFont(Name)
		Params.Size = 16
		Params.Width = 250

		local Success, Result = pcall(wax.shared.TextService.GetTextBoundsAsync, wax.shared.TextService, Params)
		Params:Destroy()
		if not Success or Result.X <= 0 or Result.Y <= 0 then
			Errors[Name] = if Success then "custom font returned invalid bounds" else tostring(Result)
		end
	end

	return Errors
end

function AssetManager.ValidateCustomFonts(): (boolean, string?)
	local Errors = GetCustomFontErrors()

	--// Fallback to raw custom asset paths \\--
	if next(Errors) and IsCustomAssetSafe == false and not UseRawCustomAssetPaths then
		UseRawCustomAssetPaths = true
		ResolveAllAssets() -- Reload assets with raw custom asset paths
		Errors = GetCustomFontErrors() -- Get new errors
	end

	--// Collect error messages \\--
	local ErrorMessages = {}
	for Name, Error in Errors do
		AssetManager.UseFallback(Name)
		table.insert(ErrorMessages, `{Name}: {Error}`)
	end

	if #ErrorMessages > 0 then
		return false, table.concat(ErrorMessages, "\n")
	end

	return true
end

function AssetManager.GetCustomFont(Name: string): Font
	local Definition = assert(Registry[Name], `Unknown asset {Name}`)
	assert(Definition.Type == "Font", `{Name} is not a font asset`)
	return AssetManager.Overrides[Name] or AssetManager.Resolved[Name] or GetFallback(Definition)
end

function AssetManager.GetImage(Name: string): string
	local Definition = assert(Registry[Name], `Unknown asset {Name}`)
	assert(Definition.Type == "Image", `{Name} is not an image asset`)
	return AssetManager.Overrides[Name] or AssetManager.Resolved[Name] or GetFallback(Definition)
end

function AssetManager.GetInstanceClassImages(): { [string]: string }
	local Images = {}
	for Name, Definition in Registry do
		if Definition.Type == "Image" and Definition.Group == "InstanceClass" then
			Images[Name] = AssetManager.GetImage(Name)
		end
	end

	return Images
end

return AssetManager
