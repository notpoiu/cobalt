--[[

	Pagination Wrapper Util for the window

]]

local RawPagination = require("@src/Utils/Pagination")
local Types = require("@src/Window/Types")

local PaginationWrapper = {}
PaginationWrapper.__index = PaginationWrapper

type PaginationWrapperData = Types.PaginationData
type PaginationWrapperDataKeys = Types.PaginationDataKey

export type PaginationManager = Types.PaginationManager

function PaginationWrapper.new(data: PaginationWrapperData)
	local SanitizedData = {
		TotalItems = data.TotalItems,
		ItemsPerPage = data.ItemsPerPage or 20,
		SiblingCount = data.SiblingCount,
		CurrentPage = data.CurrentPage,
	}

	return setmetatable({
		Helper = RawPagination.new(SanitizedData),
	}, PaginationWrapper)
end

function PaginationWrapper:GetInfo()
	return self.Helper:GetInfo()
end

function PaginationWrapper:SetOption(Key: PaginationWrapperDataKeys, Value: any)
	self.Helper:SetOption(Key, Value)
end

function PaginationWrapper:SetItemsPerPage(Max: number)
	self.Helper:SetItemsPerPage(Max)
end

function PaginationWrapper:GetIndexRanges(Page: number?)
	return self.Helper:GetIndexRanges(Page)
end

function PaginationWrapper:SetPage(Page: number)
	self.Helper:SetPage(Page)
end

function PaginationWrapper:Update(TotalItems: number?, ItemsPerPage: number?)
	self.Helper:Update(TotalItems, ItemsPerPage)
end

function PaginationWrapper:GetVisualInfo(Page: number?)
	return self.Helper:GetVisualInfo(Page)
end

function PaginationWrapper:BindPagination(data: Types.PaginationBinding)
	local Component = data.Component
	local PaginationKey = data.PaginationKey

	local function RefreshValue()
		self.Helper:SetOption(PaginationKey, Component.Value)

		if data.Refresh then
			data.Refresh()
		end
	end

	Component.Callback = RefreshValue
	self.Helper:SetOption(PaginationKey, Component.Value)
end

return {
	new = function(data: PaginationWrapperData)
		return PaginationWrapper.new(data)
	end,
}
