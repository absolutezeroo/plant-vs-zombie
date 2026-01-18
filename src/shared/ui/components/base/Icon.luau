--!strict
--[[
	Icon.luau - Universal icon component (Image or Emoji fallback)
	
	Automatically displays ImageLabel if asset is uploaded,
	falls back to TextLabel with emoji if not.
	
	USAGE:
		Icon(scope, {
			Name = "Sun",
			Size = UDim2.fromOffset(32, 32),
			Color = Color3.new(1, 1, 0), -- Optional tint
		})
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages.Fusion)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IconAssets = require(Shared.ui.design.IconAssets)

-- Fusion imports
local Children = Fusion.Children

-- Types
type Scope = Fusion.Scope<typeof(Fusion)>
type CanBeState<T> = Fusion.CanBeState<T>
type IconName = IconAssets.IconName

export type IconProps = {
	Name: CanBeState<IconName>,
	Size: CanBeState<UDim2>?,
	Position: CanBeState<UDim2>?,
	AnchorPoint: CanBeState<Vector2>?,
	Color: CanBeState<Color3>?, -- Image tint or text color
	LayoutOrder: CanBeState<number>?,
	Visible: CanBeState<boolean>?,
	ZIndex: CanBeState<number>?,
}

local DEFAULT_SIZE = UDim2.fromOffset(24, 24)
local DEFAULT_COLOR = Color3.new(1, 1, 1)

local function Icon(scope: Scope, props: IconProps): Frame
	-- Unwrap reactive values for computation
	local nameValue = if typeof(props.Name) == "string" then props.Name else Fusion.peek(props.Name)
	
	local hasImage = scope:Computed(function(use)
		local name = if typeof(props.Name) == "string" then props.Name else use(props.Name)
		return IconAssets.HasImage(name)
	end)
	
	local imageAsset = scope:Computed(function(use)
		local name = if typeof(props.Name) == "string" then props.Name else use(props.Name)
		return IconAssets.Get(name)
	end)
	
	local emojiText = scope:Computed(function(use)
		local name = if typeof(props.Name) == "string" then props.Name else use(props.Name)
		return IconAssets.GetEmoji(name)
	end)
	
	return scope:New("Frame")({
		Name = `Icon_{nameValue}`,
		Size = props.Size or DEFAULT_SIZE,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		
		[Children] = {
			-- Image version (shown when asset is uploaded)
			scope:New("ImageLabel")({
				Name = "Image",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = imageAsset,
				ImageColor3 = props.Color or DEFAULT_COLOR,
				ScaleType = Enum.ScaleType.Fit,
				Visible = hasImage,
			}),
			
			-- Emoji fallback (shown when no image asset)
			scope:New("TextLabel")({
				Name = "Emoji",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = emojiText,
				TextColor3 = props.Color or DEFAULT_COLOR,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				Visible = scope:Computed(function(use)
					return not use(hasImage)
				end),
			}),
		},
	})
end

return Icon
