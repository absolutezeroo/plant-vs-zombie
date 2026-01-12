--!strict
--[[
    Lobby Client Bootstrap
    
    Initializes the interactive 3D Lobby:
    - HUD minimal (coins, level, deck)
    - PadUIController for teleport pads (BillboardGui + leave button)
    - ZoneInteractionController for Shop/DeckBuilder/Profile zones
    - Network event handling
    
    The lobby is a 3D interactive world, NOT a full-screen menu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- Disable default Roblox UI elements
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local TeleportData = require(Shared.data.TeleportData)
local ServiceLoader = require(Shared.utils.ServiceLoader)
local LobbySignals = require(Shared.signals.LobbySignals)

-- Get local player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================
-- DEFERRED MODULE REFERENCES
-- ============================================
local ZapClient
local LobbyHUDController
local PadUIController
local ZoneInteractionController
local UIStateManager

-- HUD instance
local lobbyHUD: any = nil

-- Create a scope for Fusion cleanup
local scope = Fusion.scoped(Fusion)

-- ============================================
-- REACTIVE STATE
-- ============================================

type PlayerData = {
	Coins: number,
	Gems: number,
	Level: number,
	XP: number,
	TotalXPForNextLevel: number,
	GamesPlayed: number,
	GamesWon: number,
	ZombiesKilled: number,
	PlantsPlaced: number,
	UnlockedPlants: { string },
	Deck: { string },
}

local playerData = scope:Value(nil :: PlayerData?)
local currentDeck = scope:Value({} :: { string })
local ownedMutations = scope:Value({} :: { [string]: { string } })
local equippedMutations = scope:Value({} :: { [string]: { string } })

-- ============================================
-- LOADER INITIALIZATION
-- ============================================

local loader = ServiceLoader.new({
	stages = {
		{ name = "Modules", tip = "Loading game modules..." },
		{ name = "Network", tip = "Establishing connection..." },
		{ name = "Controllers", tip = "Setting up controllers..." },
		{ name = "UI", tip = "Building interface..." },
		{ name = "PlayerData", tip = "Loading your profile..." },
		{ name = "Ready", tip = "Entering the lobby!" },
	},
})

-- ============================================
-- NETWORK FUNCTIONS
-- ============================================

local function requestPlayerData()
	Logger.Info("LobbyClient", "Requesting player data from server...")
	ZapClient.RequestPlayerData.Fire({})
end

local function purchasePlant(plantType: string)
	Logger.Info("LobbyClient", `Purchasing plant: {plantType}`)
	ZapClient.PurchasePlantRequest.Fire({
		PlantType = plantType,
	})
end

local function saveDeck(deck: { string })
	Logger.Info("LobbyClient", `Saving deck with {#deck} plants`)
	ZapClient.SaveDeck.Fire({
		Deck = deck,
	})
	currentDeck:set(deck)
end

local function purchaseMutation(plantType: string, mutationType: string)
	Logger.Info("LobbyClient", `Purchasing mutation {mutationType} for {plantType}`)
	ZapClient.PurchaseMutationRequest.Fire({
		PlantType = plantType,
		MutationType = mutationType,
	})
end

local function equipMutation(plantType: string, mutationType: string)
	Logger.Info("LobbyClient", `Equipping mutation {mutationType} on {plantType}`)
	ZapClient.EquipMutationRequest.Fire({
		PlantType = plantType,
		MutationType = mutationType,
	})
end

local function unequipMutation(plantType: string, mutationType: string)
	Logger.Info("LobbyClient", `Unequipping mutation {mutationType} from {plantType}`)
	ZapClient.UnequipMutationRequest.Fire({
		PlantType = plantType,
		MutationType = mutationType,
	})
end

-- ============================================
-- CHECK RETURN DATA FROM ARENA
-- ============================================

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
			-- Could show a results popup here
		end
	end
end

-- ============================================
-- NETWORK EVENT LISTENERS SETUP
-- ============================================

local function setupNetworkListeners()
	-- Listen for teleport response
	ZapClient.TeleportToArenaResponse.On(function(response)
		if response.Success then
			Logger.Info("LobbyClient", "Teleport initiated successfully!")
		else
			Logger.Warn("LobbyClient", `Teleport failed: {response.ErrorMessage or "Unknown error"}`)
		end
	end)

	-- Listen for full player data sync
	ZapClient.FullPlayerDataSync.On(function(data)
		Logger.Info("LobbyClient", `Received player data: Level={data.Level}, Coins={data.Coins}`)

		local newData: PlayerData = {
			Coins = data.Coins or 0,
			Gems = data.Gems or 0,
			Level = data.Level or 1,
			XP = data.XP or 0,
			TotalXPForNextLevel = data.TotalXPForNextLevel or 100,
			GamesPlayed = data.GamesPlayed or 0,
			GamesWon = data.GamesWon or 0,
			ZombiesKilled = data.ZombiesKilled or 0,
			PlantsPlaced = data.PlantsPlaced or 0,
			UnlockedPlants = data.UnlockedPlants or {},
			Deck = data.Deck or {},
		}

		playerData:set(newData)
		currentDeck:set(data.Deck or {})

		-- Update HUD controller if mounted
		if lobbyHUD then
			lobbyHUD:UpdatePlayerData(newData)
		end

		-- Fire signal for controllers to react
		LobbySignals.OnPlayerDataSync:Fire(newData)
	end)

	-- Listen for purchase response
	ZapClient.PurchasePlantResponse.On(function(response)
		if response.Success then
			Logger.Info("LobbyClient", `Purchased {response.PlantType}! New balance: {response.NewCoins}`)
			requestPlayerData()
		else
			local errorMsg = response.ErrorCode == 1 and "Already owned"
				or response.ErrorCode == 2 and "Not enough coins"
				or response.ErrorCode == 3 and "Invalid plant"
				or "Unknown error"
			Logger.Warn("LobbyClient", `Purchase failed: {errorMsg}`)
		end
	end)

	-- Listen for unlocked plants sync
	ZapClient.SyncUnlockedPlants.On(function(data)
		Logger.Info("LobbyClient", `Synced {#data.UnlockedPlants} unlocked plants`)

		local current = Fusion.peek(playerData)
		if current then
			current.UnlockedPlants = data.UnlockedPlants
			playerData:set(current)
		end
	end)

	-- Listen for deck changes
	ZapClient.DeckChanged.On(function(data)
		Logger.Info("LobbyClient", `Deck updated: {#data.Deck} plants`)
		currentDeck:set(data.Deck)

		-- Update HUD controller
		if lobbyHUD then
			lobbyHUD:UpdateDeck(data.Deck)
		end

		-- Fire signal for controllers to react
		LobbySignals.OnDeckUpdated:Fire({ Deck = data.Deck })
	end)

	-- Listen for mutation purchase response
	ZapClient.PurchaseMutationResponse.On(function(response)
		if response.Success then
			Logger.Info(
				"LobbyClient",
				`Purchased mutation {response.MutationType} for {response.PlantType}! New balance: {response.NewCoins}`
			)
			requestPlayerData()
		else
			-- Error codes from MutationHandler:
			-- 1 = AlreadyHas, 2 = NotEnoughCoins, 3 = InvalidMutation
			-- 4 = Incompatible, 5 = LevelTooLow, 6 = PlantNotUnlocked
			local errorMsg = response.ErrorCode == 1 and "Already owned"
				or response.ErrorCode == 2 and "Not enough coins"
				or response.ErrorCode == 3 and "Invalid mutation"
				or response.ErrorCode == 4 and "Incompatible mutation"
				or response.ErrorCode == 5 and "Level too low"
				or response.ErrorCode == 6 and "Plant not owned"
				or "Unknown error"
			Logger.Warn("LobbyClient", `Mutation purchase failed: {errorMsg}`)
		end
	end)

	-- Listen for equip mutation response
	ZapClient.EquipMutationResponse.On(function(response)
		if response.Success then
			Logger.Info("LobbyClient", `Equipped mutation {response.MutationType} on {response.PlantType}`)
		else
			local errorMsg = response.ErrorCode == 1 and "Not owned"
				or response.ErrorCode == 2 and "Already equipped"
				or response.ErrorCode == 3 and "Incompatible"
				or "Unknown error"
			Logger.Warn("LobbyClient", `Equip failed: {errorMsg}`)
		end
	end)

	-- Listen for unequip mutation response
	ZapClient.UnequipMutationResponse.On(function(response)
		if response.Success then
			Logger.Info("LobbyClient", `Unequipped mutation {response.MutationType} from {response.PlantType}`)
		else
			Logger.Warn("LobbyClient", `Unequip failed`)
		end
	end)

	-- Listen for plant mutations sync (owned + equipped)
	ZapClient.SyncPlantMutations.On(function(data)
		Logger.Info(
			"LobbyClient",
			`Synced mutations for {data.PlantType}: {#data.OwnedMutations} owned, {#data.EquippedMutations} equipped`
		)

		-- Create new tables to trigger Fusion reactivity
		local newOwned = {}
		for k, v in Fusion.peek(ownedMutations) do
			newOwned[k] = v
		end
		newOwned[data.PlantType] = data.OwnedMutations
		ownedMutations:set(newOwned)

		local newEquipped = {}
		for k, v in Fusion.peek(equippedMutations) do
			newEquipped[k] = v
		end
		newEquipped[data.PlantType] = data.EquippedMutations
		equippedMutations:set(newEquipped)

		-- Update HUD controller
		if lobbyHUD then
			lobbyHUD:UpdateMutations(newEquipped)
		end

		-- Fire signal for controllers to react
		LobbySignals.OnMutationsSync:Fire({
			OwnedMutations = newOwned,
			EquippedMutations = newEquipped,
		})
	end)

	-- Listen for all mutations sync (owned + equipped)
	ZapClient.SyncAllMutations.On(function(data)
		Logger.Info("LobbyClient", "Synced all plant mutations")

		-- Convert owned array to dictionary
		local ownedDict = {}
		for _, entry in data.OwnedMutations do
			ownedDict[entry.PlantType] = entry.Mutations
		end
		ownedMutations:set(ownedDict)

		-- Convert equipped array to dictionary
		local equippedDict = {}
		for _, entry in data.EquippedMutations do
			equippedDict[entry.PlantType] = entry.Mutations
		end
		equippedMutations:set(equippedDict)

		-- Update HUD controller
		if lobbyHUD then
			lobbyHUD:UpdateMutations(equippedDict)
		end

		-- Fire signal for controllers to react
		LobbySignals.OnMutationsSync:Fire({
			OwnedMutations = ownedDict,
			EquippedMutations = equippedDict,
		})
	end)

	-- Listen for battle results
	ZapClient.ShowResults.On(function(results)
		Logger.Info("LobbyClient", "Battle results received", {
			victory = results.Victory,
			stars = results.Stars,
			coins = results.CoinsEarned,
			xp = results.XPEarned,
		})
		requestPlayerData()
	end)
end

-- ============================================
-- LOADER STEPS
-- ============================================

-- Step 1: Load Modules
loader:AddStep("Modules", function()
	ZapClient = require(Shared.network.generated.client)
	LobbyHUDController = require(script:WaitForChild("controllers"):WaitForChild("LobbyHUDController"))
	PadUIController = require(script:WaitForChild("controllers"):WaitForChild("PadUIController"))
	ZoneInteractionController = require(script:WaitForChild("controllers"):WaitForChild("ZoneInteractionController"))
	UIStateManager = require(script:WaitForChild("controllers"):WaitForChild("UIStateManager"))
end, 2)

-- Step 2: Setup Network Events
loader:AddStep("Network", function()
	setupNetworkListeners()
end, 1)

-- Step 3: Initialize Controllers
loader:AddStep("Controllers", function()
	PadUIController.Initialize()
	Logger.Info("LobbyClient", "PadUIController initialized")

	ZoneInteractionController.Initialize()
	ZoneInteractionController.SetOnPurchasePlant(purchasePlant)
	ZoneInteractionController.SetOnSaveDeck(saveDeck)
	ZoneInteractionController.SetOnPurchaseMutation(purchaseMutation)
	ZoneInteractionController.SetOnEquipMutation(equipMutation)
	ZoneInteractionController.SetOnUnequipMutation(unequipMutation)
	Logger.Info("LobbyClient", "ZoneInteractionController initialized")
end, 2)

-- Step 4: Mount HUD
loader:AddStep("UI", function()
	lobbyHUD = LobbyHUDController.new()
	lobbyHUD:Mount()
	Logger.Info("LobbyClient", "LobbyHUDController mounted")
end, 1)

-- Step 5: Request Player Data
loader:AddStep("PlayerData", function()
	checkReturnData()
	requestPlayerData()
	-- Small delay to let initial data sync
	task.wait(0.3)
end, 1)

-- Step 6: Ready
loader:AddStep("Ready", function()
	Logger.Info("LobbyClient", "3D Lobby client fully initialized")
end, 0.5)

-- ============================================
-- RUN LOADER
-- ============================================

loader:Run()
