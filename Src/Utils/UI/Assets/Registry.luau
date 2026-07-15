export type FontAsset = {
	Type: "Font",
	FileName: string,
	FamilyName: string,
	Url: string,
	FallbackId: number,
}

export type ImageAsset = {
	Type: "Image",
	FileName: string,
	Url: string,
	FallbackId: string,
	Group: string?,
}

export type Asset = FontAsset | ImageAsset

local RepositoryAssetUrl = "https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets"
local RobloxClassIconUrl = "https://robloxapi.github.io/ref/icons/dark"

local Registry: { [string]: Asset } = {
	Inter = {
		Type = "Font",
		
		FileName = "Inter.ttf",
		FamilyName = "Inter",
		
		Url = `{RepositoryAssetUrl}/Inter.ttf`,
		FallbackId = 12187365364,
	},
	IBMPlexMono = {
		Type = "Font",
		
		FileName = "IBMPlexMono.ttf",
		FamilyName = "IBM Plex Mono",

		Url = `{RepositoryAssetUrl}/IBMPlexMono.ttf`,
		FallbackId = 16658246179,
	},
	Logo = {
		Type = "Image",
		FileName = "Logo.png",

		Url = `{RepositoryAssetUrl}/Logo.png`,
		FallbackId = "rbxassetid://91685317120520",
	},
	RemoteEvent = {
		Group = "InstanceClass",
		
		Type = "Image",
		FileName = "RemoteEvent.png",

		Url = `{RobloxClassIconUrl}/RemoteEvent.png`,
		FallbackId = "rbxassetid://110803789420086",
	},
	UnreliableRemoteEvent = {
		Group = "InstanceClass",

		Type = "Image",
		FileName = "UnreliableRemoteEvent.png",

		Url = `{RobloxClassIconUrl}/UnreliableRemoteEvent.png`,
		FallbackId = "rbxassetid://126244162339059",
	},
	RemoteFunction = {
		Group = "InstanceClass",

		Type = "Image",
		FileName = "RemoteFunction.png",
		
		Url = `{RobloxClassIconUrl}/RemoteFunction.png`,
		FallbackId = "rbxassetid://108537517159060",
	},
	BindableEvent = {
		Group = "InstanceClass",

		Type = "Image",
		FileName = "BindableEvent.png",
		
		Url = `{RobloxClassIconUrl}/BindableEvent.png`,
		FallbackId = "rbxassetid://116839398727495",
	},
	BindableFunction = {
		Group = "InstanceClass",

		Type = "Image",
		FileName = "BindableFunction.png",
		
		Url = `{RobloxClassIconUrl}/BindableFunction.png`,
		FallbackId = "rbxassetid://112264959079193",
	},
}

return Registry
