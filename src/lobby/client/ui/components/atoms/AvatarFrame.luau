--!strict
--[[
	AvatarFrame.luau - Player avatar with circular frame
	
	Atomic component showing player's Roblox avatar thumbnail
	in a styled circular frame with border.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

-- Fusion primitives
local Children = Fusion.Children

-- Constants
local DEFAULT_SIZE = 64

export type AvatarFrameProps = {
	Scope: Fusion.Scope<any>,
	Size: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	BorderColor: Color3?,
}

local function AvatarFrame(props: AvatarFrameProps): Frame
	local scope = props.Scope
	local size = props.Size or DEFAULT_SIZE
	local borderColor = props.BorderColor or Theme.Colors.Info.Main
	
	-- Get avatar URL
	local player = Players.LocalPlayer
	local avatarUrl = scope:Value("")
	
	task.spawn(function()
		if player then
			local success, url = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if success then
				avatarUrl:set(url)
			end
		end
	end)
	
	return scope:New("Frame") {
		Name = "AvatarFrame",
		Size = UDim2.fromOffset(size, size),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = Theme.Colors.Surface.Main,
		
		[Children] = {
			scope:New("UICorner") {
				CornerRadius = UDim.new(0.5, 0),
			},
			
			scope:New("UIStroke") {
				Color = borderColor,
				Thickness = 3,
			},
			
			-- Avatar image
			scope:New("ImageLabel") {
				Name = "Avatar",
				Size = UDim2.new(1, -6, 1, -6),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = avatarUrl,
				
				[Children] = {
					scope:New("UICorner") {
						CornerRadius = UDim.new(0.5, 0),
					},
				},
			},
		},
	}
end

return AvatarFrame
