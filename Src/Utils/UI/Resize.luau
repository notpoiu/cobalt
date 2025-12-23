local Resize = {}
Resize.__index = Resize

local Interface = require(script.Parent.Interface)
local Drag = require(script.Parent.Drag)

local HANDLE_SIZE = 6
local CORNER_HANDLE_SIZE = 20

function Resize.new(Options: {
	MainFrame: Frame,
	MinimumSize: Vector2? | UDim2?,
	MaximumSize: UDim2?,
	HandleSize: number?,
	CornerHandleSize: number?,
	Mirrored: boolean?,
	LockedPosition: boolean? | UDim2?,
})
	local MainFrame = Options.MainFrame
	local HandleSize = Options.HandleSize or HANDLE_SIZE
	local CornerHandleSize = Options.CornerHandleSize or CORNER_HANDLE_SIZE
	local Mirrored = Options.Mirrored or false
	local LockedPosition = Options.LockedPosition

	local MinimumSize
	if typeof(Options.MinimumSize) == "Vector2" then
		MinimumSize = UDim2.fromOffset(Options.MinimumSize.X, Options.MinimumSize.Y)
	elseif typeof(Options.MinimumSize) == "UDim2" then
		MinimumSize = Options.MinimumSize
	else
		MinimumSize = UDim2.fromOffset(100, 100)
	end

	local MaximumSize = Options.MaximumSize

	local self = setmetatable({
		MainFrame = MainFrame,
		ScreenGui = MainFrame:FindFirstAncestorOfClass("ScreenGui"),
		Parent = MainFrame.Parent,
	}, Resize)

	local function CalculateResizeProperties(
		initialFramePosition: UDim2,
		initialFrameSize: UDim2,
		mouseDelta: Vector2,
		resizeTypeX: string?,
		resizeTypeY: string?
	)
		if Mirrored then
			local parentAbsSize = self.Parent.AbsoluteSize

			local newSizeOffsetX = initialFrameSize.X.Offset
			local newSizeOffsetY = initialFrameSize.Y.Offset

			if resizeTypeX then
				local deltaX = 0
				if resizeTypeX == "Right" then
					deltaX = 2 * mouseDelta.X
				elseif resizeTypeX == "Left" then
					deltaX = -2 * mouseDelta.X
				end
				newSizeOffsetX = initialFrameSize.X.Offset + deltaX

				local minWidthAbs = MinimumSize.X.Scale * parentAbsSize.X + MinimumSize.X.Offset
				local maxWidthAbs = (MaximumSize and (MaximumSize.X.Scale * parentAbsSize.X + MaximumSize.X.Offset))
					or math.huge
				local scaleContributionX = initialFrameSize.X.Scale * parentAbsSize.X
				local minAllowedTotalOffsetX = minWidthAbs - scaleContributionX
				local maxAllowedTotalOffsetX = maxWidthAbs - scaleContributionX
				newSizeOffsetX = math.clamp(newSizeOffsetX, minAllowedTotalOffsetX, maxAllowedTotalOffsetX)
			end

			if resizeTypeY then
				local deltaY = 0
				if resizeTypeY == "Bottom" then
					deltaY = 2 * mouseDelta.Y
				elseif resizeTypeY == "Top" then
					deltaY = -2 * mouseDelta.Y
				end
				newSizeOffsetY = initialFrameSize.Y.Offset + deltaY

				local minHeightAbs = MinimumSize.Y.Scale * parentAbsSize.Y + MinimumSize.Y.Offset
				local maxHeightAbs = (MaximumSize and (MaximumSize.Y.Scale * parentAbsSize.Y + MaximumSize.Y.Offset))
					or math.huge
				local scaleContributionY = initialFrameSize.Y.Scale * parentAbsSize.Y
				local minAllowedTotalOffsetY = minHeightAbs - scaleContributionY
				local maxAllowedTotalOffsetY = maxHeightAbs - scaleContributionY
				newSizeOffsetY = math.clamp(newSizeOffsetY, minAllowedTotalOffsetY, maxAllowedTotalOffsetY)
			end

			local finalNewSize =
				UDim2.new(initialFrameSize.X.Scale, newSizeOffsetX, initialFrameSize.Y.Scale, newSizeOffsetY)
			local finalNewPosition = initialFramePosition
			if typeof(LockedPosition) == "UDim2" then
				finalNewPosition = LockedPosition
			end
			return finalNewSize, finalNewPosition
		else
			-- Non-mirrored logic
			local currentScreenGuiAbsSize = self.ScreenGui.AbsoluteSize
			local parentAbsSizeForMinMax = currentScreenGuiAbsSize -- As per original non-mirrored logic for min/max context

			-- These will store the final UDim offset values for position and the absolute pixel values for size calculation
			local finalPosOffsetX = initialFramePosition.X.Offset
			local finalPosOffsetY = initialFramePosition.Y.Offset

			-- Initial absolute pixel size of the frame
			local initialAbsWidthPx = initialFrameSize.X.Scale * self.Parent.AbsoluteSize.X + initialFrameSize.X.Offset
			local initialAbsHeightPx = initialFrameSize.Y.Scale * self.Parent.AbsoluteSize.Y + initialFrameSize.Y.Offset

			local newAbsWidthPx = initialAbsWidthPx
			local newAbsHeightPx = initialAbsHeightPx

			-- Min/max pixel dimensions
			local minWidthPx = MinimumSize.X.Scale * parentAbsSizeForMinMax.X + MinimumSize.X.Offset
			local minHeightPx = MinimumSize.Y.Scale * parentAbsSizeForMinMax.Y + MinimumSize.Y.Offset
			local maxWidthPx = MaximumSize and (MaximumSize.X.Scale * parentAbsSizeForMinMax.X + MaximumSize.X.Offset)
				or math.huge
			local maxHeightPx = MaximumSize and (MaximumSize.Y.Scale * parentAbsSizeForMinMax.Y + MaximumSize.Y.Offset)
				or math.huge

			-- Original edge calculation logic (assuming MainFrame.Position is center if AnchorPoint is 0.5,0.5 for these calcs)
			local initialAbsCenterX = currentScreenGuiAbsSize.X * initialFramePosition.X.Scale
				+ initialFramePosition.X.Offset
			local initialAbsSizeX_forEdgeCalc = initialFrameSize.X.Offset -- Original code used offset for this part of edge calculation
			local initialRightEdgeX = initialAbsCenterX + initialAbsSizeX_forEdgeCalc / 2
			local initialLeftEdgeX = initialAbsCenterX - initialAbsSizeX_forEdgeCalc / 2

			local initialAbsCenterY = currentScreenGuiAbsSize.Y * initialFramePosition.Y.Scale
				+ initialFramePosition.Y.Offset
			local initialAbsSizeY_forEdgeCalc = initialFrameSize.Y.Offset -- Original code used offset for this part of edge calculation
			local initialBottomEdgeY = initialAbsCenterY + initialAbsSizeY_forEdgeCalc / 2
			local initialTopEdgeY = initialAbsCenterY - initialAbsSizeY_forEdgeCalc / 2

			if resizeTypeX then
				if resizeTypeX == "Left" then
					local newLeftEdge = initialLeftEdgeX + mouseDelta.X
					newAbsWidthPx = math.clamp(initialRightEdgeX - newLeftEdge, minWidthPx, maxWidthPx)
					if newAbsWidthPx ~= (initialRightEdgeX - newLeftEdge) then -- Readjust edge if clamped
						newLeftEdge = initialRightEdgeX - newAbsWidthPx
					end
					if not LockedPosition then
						local newAbsCenterX = newLeftEdge + newAbsWidthPx / 2 -- Assuming center is halfway for position update
						finalPosOffsetX = newAbsCenterX - currentScreenGuiAbsSize.X * initialFramePosition.X.Scale
					end
				elseif resizeTypeX == "Right" then
					local newRightEdge = initialRightEdgeX + mouseDelta.X
					newAbsWidthPx = math.clamp(newRightEdge - initialLeftEdgeX, minWidthPx, maxWidthPx)
					if not LockedPosition then
						local newAbsCenterX = initialLeftEdgeX + newAbsWidthPx / 2 -- Assuming center is halfway
						finalPosOffsetX = newAbsCenterX - currentScreenGuiAbsSize.X * initialFramePosition.X.Scale
					end
				end
			end

			if resizeTypeY then
				if resizeTypeY == "Top" then
					local newTopEdge = initialTopEdgeY + mouseDelta.Y
					newAbsHeightPx = math.clamp(initialBottomEdgeY - newTopEdge, minHeightPx, maxHeightPx)
					if newAbsHeightPx ~= (initialBottomEdgeY - newTopEdge) then -- Readjust edge if clamped
						newTopEdge = initialBottomEdgeY - newAbsHeightPx
					end
					if not LockedPosition then
						local newAbsCenterY = newTopEdge + newAbsHeightPx / 2 -- Assuming center is halfway
						finalPosOffsetY = newAbsCenterY - currentScreenGuiAbsSize.Y * initialFramePosition.Y.Scale
					end
				elseif resizeTypeY == "Bottom" then
					local newBottomEdge = initialBottomEdgeY + mouseDelta.Y
					newAbsHeightPx = math.clamp(newBottomEdge - initialTopEdgeY, minHeightPx, maxHeightPx)
					if not LockedPosition then
						local newAbsCenterY = initialTopEdgeY + newAbsHeightPx / 2 -- Assuming center is halfway
						finalPosOffsetY = newAbsCenterY - currentScreenGuiAbsSize.Y * initialFramePosition.Y.Scale
					end
				end
			end

			-- Convert final absolute pixel dimensions back to UDim offsets for size
			local finalSizeOffsetX = newAbsWidthPx - (initialFrameSize.X.Scale * self.Parent.AbsoluteSize.X)
			local finalSizeOffsetY = newAbsHeightPx - (initialFrameSize.Y.Scale * self.Parent.AbsoluteSize.Y)

			local finalNewSize =
				UDim2.new(initialFrameSize.X.Scale, finalSizeOffsetX, initialFrameSize.Y.Scale, finalSizeOffsetY)
			local finalNewPosition = initialFramePosition -- Default if LockedPosition is true
			if typeof(LockedPosition) == "UDim2" then
				finalNewPosition = LockedPosition
			elseif not LockedPosition then -- Only update if not locked (boolean false)
				finalNewPosition = UDim2.new(
					initialFramePosition.X.Scale,
					finalPosOffsetX,
					initialFramePosition.Y.Scale,
					finalPosOffsetY
				)
			end
			return finalNewSize, finalNewPosition
		end
	end

	local function createDragHandler(resizeTypeX, resizeTypeY)
		return function(Info, Input: InputObject)
			local mouseDelta = Input.Position - Info.StartPosition
			if wax.shared.GetDPIScale then
				mouseDelta = mouseDelta / wax.shared.GetDPIScale()
			end
			
			local newSize, newPosition =
				CalculateResizeProperties(Info.FramePosition, Info.FrameSize, mouseDelta, resizeTypeX, resizeTypeY)

			MainFrame.Size = newSize
			MainFrame.Position = newPosition
		end
	end

	local LeftSide = Interface.New("Frame", {
		Size = UDim2.new(0, HandleSize, 1, -CornerHandleSize * 2),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	Drag.Setup(MainFrame, LeftSide, createDragHandler("Left", nil))

	local RightSide = Interface.New("Frame", {
		Size = UDim2.new(0, HandleSize, 1, -CornerHandleSize * 2),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	Drag.Setup(MainFrame, RightSide, createDragHandler("Right", nil))

	local TopSide = Interface.New("Frame", {
		Size = UDim2.new(1, -CornerHandleSize * 2, 0, HandleSize),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	Drag.Setup(MainFrame, TopSide, createDragHandler(nil, "Top"))

	local BottomSide = Interface.New("Frame", {
		Size = UDim2.new(1, -CornerHandleSize * 2, 0, HandleSize),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6,
	})
	Drag.Setup(MainFrame, BottomSide, createDragHandler(nil, "Bottom"))

	local TopLeftCorner = Interface.New("Frame", {
		Size = UDim2.fromOffset(CornerHandleSize, CornerHandleSize),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	Drag.Setup(MainFrame, TopLeftCorner, createDragHandler("Left", "Top"))

	local TopRightCorner = Interface.New("Frame", {
		Size = UDim2.fromOffset(CornerHandleSize, CornerHandleSize),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	Drag.Setup(MainFrame, TopRightCorner, createDragHandler("Right", "Top"))

	local BottomLeftCorner = Interface.New("Frame", {
		Size = UDim2.fromOffset(CornerHandleSize, CornerHandleSize),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	Drag.Setup(MainFrame, BottomLeftCorner, createDragHandler("Left", "Bottom"))

	local BottomRightCorner = Interface.New("Frame", {
		Size = UDim2.fromOffset(CornerHandleSize, CornerHandleSize),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = MainFrame,
		ZIndex = 9e6 + 1,
	})
	Drag.Setup(MainFrame, BottomRightCorner, createDragHandler("Right", "Bottom"))

	return self
end

return Resize
