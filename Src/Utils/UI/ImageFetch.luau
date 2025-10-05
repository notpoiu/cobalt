local ImageFetcher = {
	FallbackMapping = {
		Logo = "rbxassetid://91685317120520",
	},
}

if not isfolder("Cobalt/Assets") then
	makefolder("Cobalt/Assets")
end

function SafeFetch(Path: string)
	local Success, Result = pcall(function()
		return getcustomasset(Path)
	end)

	return Success and Result or nil
end

function ImageFetcher.GetRemoteImages(Images: { [string]: string })
	if not getcustomasset then
		return Images
	end

	local NewImages = {}
	for ClassName, Image in Images do
		if isfile(`Cobalt/Assets/{ClassName}.png`) then
			NewImages[ClassName] = SafeFetch(`Cobalt/Assets/{ClassName}.png`) or Image
			continue
		end

		writefile(
			`Cobalt/Assets/{ClassName}.png`,
			game:HttpGet(`https://robloxapi.github.io/ref/icons/dark/{ClassName}.png`)
		)

		NewImages[ClassName] = SafeFetch(`Cobalt/Assets/{ClassName}.png`) or Image
	end

	return NewImages
end

function ImageFetcher.GetImage(Image: string)
	if not getcustomasset then
		return ImageFetcher.FallbackMapping[Image] or Image
	end

	if isfile(`Cobalt/Assets/{Image}.png`) then
		return SafeFetch(`Cobalt/Assets/{Image}.png`) or ImageFetcher.FallbackMapping[Image] or Image
	end

	local Response = request({
		Url = `https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets/{Image}.png`,
		Method = "GET",
	})

	if not Response.Success then
		return ImageFetcher.FallbackMapping[Image] or Image
	end

	writefile(`Cobalt/Assets/{Image}.png`, Response.Body)
	return SafeFetch(`Cobalt/Assets/{Image}.png`) or ImageFetcher.FallbackMapping[Image] or Image
end

return ImageFetcher
