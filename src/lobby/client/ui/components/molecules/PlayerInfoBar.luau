--!strict
--[[
	PlayerInfoBar.luau - Player info display (avatar + level + resources)
	
	Molecule combining AvatarFrame, LevelBadge, and ResourcePills.
	Displayed at top-left of lobby HUD.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)

local Atoms = script.Parent.Parent.atoms
local AvatarFrame = require(Atoms.AvatarFrame)
local LevelBadge = require(Atoms.LevelBadge)
local ResourcePill = require(Atoms.ResourcePill)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed

export type PlayerInfoBarProps = {
	Scope: Fusion.Scope<any>,
	Level: any, -- Fusion.Value<number>
	XP: any?, -- Fusion.Value<number>
	XPRequired: any?, -- Fusion.Value<number>
	Coins: any, -- Fusion.Value<number>
	Gems: any, -- Fusion.Value<number>
	Position: UDim2?,
}

local function PlayerInfoBar(props: PlayerInfoBarProps): Frame
	local scope = props.Scope
	
	return New(scope, "Frame") {
		Name = "PlayerInfoBar",
		Size = UDim2.fromOffset(280, 70),
		Position = props.Position or UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		
		[Children] = {
			-- Avatar (left)
			AvatarFrame({
				Scope = scope,
				Size = 64,
				Position = UDim2.fromOffset(0, 0),
				BorderColor = Theme.Colors.Info.Main,
			}),
			
			-- Level badge (overlapping avatar)
			LevelBadge({
				Scope = scope,
				Level = props.Level,
				XP = props.XP,
				XPRequired = props.XPRequired,
				Size = 40,
				Position = UDim2.fromOffset(44, 28),
				AnchorPoint = Vector2.new(0, 0),
			}),
			
			-- Resources (right of avatar)
			New(scope, "Frame") {
				Name = "Resources",
				Size = UDim2.fromOffset(180, 70),
				Position = UDim2.fromOffset(95, 0),
				BackgroundTransparency = 1,
				
				[Children] = {
					New(scope, "UIListLayout") {
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 4),
					},
					
					-- Coins
					ResourcePill({
						Scope = scope,
						Icon = Theme.Icons.Coin,
						Value = props.Coins,
						Color = "Gold",
						Width = 100,
						LayoutOrder = 1,
					}),
					
					-- Gems
					ResourcePill({
						Scope = scope,
						Icon = Theme.Icons.Gem,
						Value = props.Gems,
						Color = "Purple",
						Width = 100,
						LayoutOrder = 2,
					}),
				},
			},
		},
	}
end

return PlayerInfoBar
