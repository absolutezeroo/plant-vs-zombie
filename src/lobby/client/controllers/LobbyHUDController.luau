--!strict
--[[
	LobbyHUDController.luau - Main lobby HUD controller
	
	Controller that:
	- Creates and mounts the LobbyScreen organism
	- Manages player data state (coins, gems, level, deck)
	- Handles navigation between views
	- Connects to PlayerDataClient for reactive updates
	
	Follows Atomic Design: Controller → Organisms → Molecules → Atoms
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Controllers = script.Parent
local PlantTooltipController = require(Controllers.PlantTooltipController)
local ZoneInteractionController = require(Controllers.ZoneInteractionController)

local Organisms = script.Parent.Parent.ui.components.organisms
local LobbyScreen = require(Organisms.LobbyScreen)

-- Types
export type PlayerData = {
	Coins: number,
	Gems: number,
	Level: number,
	XP: number,
	TotalXPForNextLevel: number,
	Deck: {string},
	EquippedMutations: {[string]: {string}},
}

local LobbyHUDController = {}
LobbyHUDController.__index = LobbyHUDController

function LobbyHUDController.new()
	local self = setmetatable({}, LobbyHUDController)
	
	self._scope = Fusion.scoped(Fusion)
	self._trove = Trove.new()
	
	-- State (using scope:Value() syntax)
	self._level = self._scope:Value(1)
	self._xp = self._scope:Value(0)
	self._xpRequired = self._scope:Value(100)
	self._coins = self._scope:Value(0)
	self._gems = self._scope:Value(0)
	self._deck = self._scope:Value({} :: {string})
	self._equippedMutations = self._scope:Value({} :: {[string]: {string}})
	
	-- Navigation state
	self._activeView = self._scope:Value("")  -- Empty = no view open
	
	-- GUI instance
	self._gui = nil :: ScreenGui?
	
	return self
end

--[[
	Update player data from external source
]]
function LobbyHUDController:UpdatePlayerData(data: PlayerData)
	self._level:set(data.Level or 1)
	self._xp:set(data.XP or 0)
	self._xpRequired:set(data.TotalXPForNextLevel or 100)
	self._coins:set(data.Coins or 0)
	self._gems:set(data.Gems or 0)
	self._deck:set(data.Deck or {})
	if data.EquippedMutations then
		self._equippedMutations:set(data.EquippedMutations)
	end
end

--[[
	Update deck only
]]
function LobbyHUDController:UpdateDeck(deck: {string})
	self._deck:set(deck)
end

--[[
	Update equipped mutations only
]]
function LobbyHUDController:UpdateMutations(mutations: {[string]: {string}})
	self._equippedMutations:set(mutations)
end

--[[
	Set active navigation view and open corresponding UI
]]
function LobbyHUDController:SetActiveView(view: string)
	local current = Fusion.peek(self._activeView)
	if current == view then
		-- Toggle off if same view
		self._activeView:set("")
		ZoneInteractionController.CloseUI()
	else
		self._activeView:set(view)
		-- Open the corresponding view via ZoneInteractionController
		if view == "Profile" then
			ZoneInteractionController.OpenProfile()
		elseif view == "Shop" then
			ZoneInteractionController.OpenShop()
		elseif view == "Deck" then
			ZoneInteractionController.OpenDeckBuilder()
		elseif view == "Mutation" then
			ZoneInteractionController.OpenMutations()
		elseif view == "Unlocks" then
			ZoneInteractionController.OpenUnlocks()
		end
	end
	Logger.Debug("LobbyHUD", `Active view: {Fusion.peek(self._activeView)}`)
end

--[[
	Get active view value (for external binding)
]]
function LobbyHUDController:GetActiveView(): any
	return self._activeView
end

--[[
	Get deck value (for external binding)
]]
function LobbyHUDController:GetDeck(): any
	return self._deck
end

--[[
	Get equipped mutations value (for external binding)
]]
function LobbyHUDController:GetEquippedMutations(): any
	return self._equippedMutations
end

--[[
	Initialize and mount the HUD
]]
function LobbyHUDController:Mount()
	local player = Players.LocalPlayer
	if not player then return end
	
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Initialize tooltip controller
	PlantTooltipController.Initialize()
	
	-- Connect to ZoneInteractionController for UI close events
	ZoneInteractionController.SetOnUIClose(function()
		self._activeView:set("")
		Logger.Debug("LobbyHUD", "Active view cleared (UI closed)")
	end)
	
	self._gui = LobbyScreen({
		Scope = self._scope,
		-- Player data
		Level = self._level,
		XP = self._xp,
		XPRequired = self._xpRequired,
		Coins = self._coins,
		Gems = self._gems,
		-- Deck data
		Deck = self._deck,
		EquippedMutations = self._equippedMutations,
		-- Navigation
		ActiveView = self._activeView,
		OnNavigate = function(view: string)
			self:SetActiveView(view)
		end,
		OnPlantClick = function(plantType: string, mutations: {string})
			Logger.Debug("LobbyHUD", `Plant {plantType} clicked, showing tooltip`)
			PlantTooltipController.ShowForPlant(plantType, mutations)
		end,
	})
	
	self._gui.Parent = playerGui
	
	Logger.Info("LobbyHUD", "Controller mounted")
end

--[[
	Unmount and cleanup
]]
function LobbyHUDController:Unmount()
	self._trove:Destroy()
	Fusion.doCleanup(self._scope)
	
	-- Dispose tooltip controller
	PlantTooltipController.Dispose()
	
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	
	Logger.Info("LobbyHUD", "Controller unmounted")
end

return LobbyHUDController
