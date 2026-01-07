--!strict
--[[
    Lobby Client Bootstrap
    
    Initializes the Lobby UI:
    - Mounts LobbyScreen with Fusion
    - Handles stage selection, deck building
    - Sends teleport requests to server
    
    Note: No ECS loop needed in Lobby - it's purely UI-driven
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Fusion imports
local Children = Fusion.Children

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local TeleportData = require(Shared.TeleportData)

-- Import Zap generated network module
local ZapClient = require(script:WaitForChild("network"):WaitForChild("generated"))

-- Import UI components - ui is a child of the init script's container
local LobbyScreen = require(script:WaitForChild("ui"):WaitForChild("LobbyScreen"))

-- Import controllers
local PadUIController = require(script:WaitForChild("controllers"):WaitForChild("PadUIController"))
local DeckBuilderController = require(script:WaitForChild("controllers"):WaitForChild("DeckBuilderController"))

-- Get local player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

Logger.Info("LobbyClient", `Initializing lobby for {LocalPlayer.Name}`)

-- Initialize controllers for 3D lobby
PadUIController.Initialize()
DeckBuilderController.Initialize()

Logger.Info("LobbyClient", "3D Lobby controllers initialized")

-- Create a scope for Fusion cleanup (pass Fusion to get New, Value, etc.)
local scope = Fusion.scoped(Fusion)

-- Reactive state for lobby (kept for optional GUI features)
local lobbyState = {
	SelectedStage = scope:Value(nil :: string?),
	SelectedDeck = scope:Value({} :: { string }),
	IsLoading = scope:Value(false),
	ReturnData = scope:Value(nil :: TeleportData.LobbyReturnData?),
}

-- Check if player returned from Arena with results
local function checkReturnData()
	local joinData = LocalPlayer:GetJoinData()
	if joinData.TeleportData then
		local data = joinData.TeleportData
		local isValid = TeleportData.ValidateLobbyReturnData(data)
		if isValid then
			Logger.Info("LobbyClient", "Returned from Arena with results", {
				victory = data.Victory,
				stars = data.Stars,
			})
			lobbyState.ReturnData:set(data :: TeleportData.LobbyReturnData)
		end
	end
end

checkReturnData()

-- Optional: Mount lobby screen for GUI-based features (Shop, Profile, Results)
-- For now, we skip auto-mounting since it's a 3D lobby
-- Uncomment if you want GUI fallback:
--[[
local screenGui = scope:New "ScreenGui" {
	Name = "LobbyUI",
	Parent = PlayerGui,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	
	[Children] = {
		LobbyScreen({
			SelectedStage = lobbyState.SelectedStage,
			SelectedDeck = lobbyState.SelectedDeck,
			IsLoading = lobbyState.IsLoading,
			ReturnData = lobbyState.ReturnData,
			
			OnPlayClicked = function(stageId: string, deck: { string })
				-- Disabled in 3D lobby mode
			end,
		}),
	},
}
]]--

Logger.Info("LobbyClient", "Lobby UI ready (3D mode)")

-- Listen for teleport response from server
ZapClient.TeleportToArenaResponse.On(function(response)
	if response.Success then
		Logger.Info("LobbyClient", "Teleport initiated successfully!")
		-- Keep loading state - we're teleporting
	else
		Logger.Warn("LobbyClient", `Teleport failed: {response.ErrorMessage or "Unknown error"}`)
		lobbyState.IsLoading:set(false)
		-- TODO: Show error popup to user
	end
end)

-- Listen for battle results from server (after returning from Arena)
ZapClient.ShowResults.On(function(results)
	Logger.Info("LobbyClient", "Battle results received from server", {
		victory = results.Victory,
		stars = results.Stars,
		coins = results.CoinsEarned,
		xp = results.XPEarned,
	})
	
	-- Update ReturnData state to show ResultsPopup
	lobbyState.ReturnData:set({
		StageId = results.StageId,
		Victory = results.Victory,
		Stars = results.Stars,
		CoinsEarned = results.CoinsEarned,
		XPEarned = results.XPEarned,
	} :: TeleportData.LobbyReturnData)
end)
