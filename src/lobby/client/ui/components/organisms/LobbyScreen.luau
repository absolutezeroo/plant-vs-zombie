--!strict
--[[
	LobbyScreen.luau - Main lobby HUD organism (Responsive)
	
	Combines PlayerInfoBar, DeckPreviewBar, and NavBar into the main lobby interface.
	Uses percentage-based positioning for full responsiveness.
	
	Uses Fusion 0.3 scope:Method() syntax.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResponsiveUtils = require(Shared.ui.utils.ResponsiveUtils)

local Molecules = script.Parent.Parent.molecules
local PlayerInfoBar = require(Molecules.PlayerInfoBar)
local NavBar = require(Molecules.NavBar)

local Organisms = script.Parent
local SeedBank = require(Organisms.SeedBank)

-- Fusion primitives
local Children = Fusion.Children

export type LobbyScreenProps = {
	Scope: Fusion.Scope<any>,
	-- Player data
	Level: any,
	XP: any?,
	XPRequired: any?,
	Coins: any,
	Gems: any,
	-- Deck data
	Deck: any,
	EquippedMutations: any?,
	-- Navigation
	ActiveView: any,
	OnNavigate: (view: string) -> (),
	OnPlantClick: (plantType: string, mutations: { string }) -> (),
}

local function LobbyScreen(props: LobbyScreenProps): ScreenGui
	local scope = props.Scope

	return scope:New("ScreenGui")({
		Name = "LobbyHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,

		[Children] = {
			-- Responsive scaling for all HUD elements
			ResponsiveUtils.CreateUIScale(scope),

			-- Top-left: Player info (avatar, level, resources)
			-- Position: 1% from left, 6% from top (avoids Roblox UI)
			PlayerInfoBar({
				Scope = scope,
				Level = props.Level,
				XP = props.XP,
				XPRequired = props.XPRequired,
				Coins = props.Coins,
				Gems = props.Gems,
				Position = UDim2.fromScale(0.01, 0.06),
				AnchorPoint = Vector2.new(0, 0),
			}),

			-- Right side: Navigation bar
			-- Position: 1% from right edge, centered vertically
			NavBar({
				Scope = scope,
				ActiveView = props.ActiveView,
				OnNavigate = props.OnNavigate,
				Position = UDim2.fromScale(0.99, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
			}),

			-- Bottom center: Seed bank (deck preview)
			-- Position: centered horizontally, 2% from bottom
			SeedBank({
				Scope = scope,
				EquippedPlants = props.Deck,
				EquippedMutations = props.EquippedMutations,
				OnPlantClick = props.OnPlantClick,
				Position = UDim2.fromScale(0.5, 0.98),
				AnchorPoint = Vector2.new(0.5, 1),
			}),
		},
	})
end

return LobbyScreen
