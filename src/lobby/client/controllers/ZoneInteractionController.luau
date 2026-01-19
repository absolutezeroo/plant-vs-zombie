--!strict
--[[
    ZoneInteractionController.luau - Handles ProximityPrompt interactions
    
    RESPONSIBILITY: Route ProximityPrompt triggers to appropriate UI views.
    This controller is LEAN - it delegates UI creation to separate View modules.
    
    Listens for ProximityPrompts:
    - ShopPrompt → Opens ShopView
    - DeckPrompt → Opens DeckBuilderView
    - ProfilePrompt → Opens ProfileView
    - MutationPrompt → Opens MutationView
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)
local LobbySignals = require(Shared.signals.LobbySignals)
local BlurManager = require(Shared.ui.utils.BlurManager)

-- Atomic Design components (organisms)
local ProfileScreen = require(script.Parent.Parent.ui.components.organisms.ProfileScreen)
local ShopScreen = require(script.Parent.Parent.ui.components.organisms.ShopScreen)
local DeckBuilderScreen = require(script.Parent.Parent.ui.components.organisms.DeckBuilderScreen)
local MutationScreen = require(script.Parent.Parent.ui.components.organisms.MutationScreen)
local UnlocksScreen = require(script.Parent.Parent.ui.components.organisms.UnlocksScreen)

-- Trove for connection cleanup
local _trove = Trove.new()

local New = Fusion.New
local Value = Fusion.Value
local Computed = Fusion.Computed
local Children = Fusion.Children
local peek = Fusion.peek

local ZoneInteractionController = {}

-- ============================================
-- STATE (Reactive values shared with views)
-- ============================================
local _scope = Fusion.scoped(Fusion)
local _currentUI: ScreenGui? = nil
local _currentUIScope: Fusion.Scope<any>? = nil -- Scope for current UI (cleaned on close)

-- Reactive state values
local _playerData = Value(_scope, nil :: any?)
local _currentDeck = Value(_scope, {} :: { string })
local _ownedMutations = Value(_scope, {} :: { [string]: { string } })
local _equippedMutations = Value(_scope, {} :: { [string]: { string } })

-- Callbacks (set by init.client.luau)
local _onPurchasePlant: ((string) -> ())? = nil
local _onSaveDeck: (({ string }) -> ())? = nil
local _onPurchaseMutation: ((string, string) -> ())? = nil
local _onEquipMutation: ((string, string) -> ())? = nil
local _onUnequipMutation: ((string, string) -> ())? = nil
local _onUIClose: (() -> ())? = nil -- Called when any UI is closed

-- ============================================
-- UI MANAGEMENT
-- ============================================

local function closeCurrentUI()
	-- Clean up the UI-specific scope first (this cleans ViewportFrames, etc.)
	if _currentUIScope then
		Fusion.doCleanup(_currentUIScope)
		_currentUIScope = nil
	end

	if _currentUI then
		_currentUI:Destroy()
		_currentUI = nil
		-- Disable blur when UI closes
		BlurManager.Disable()
		-- Notify listeners that UI was closed
		if _onUIClose then
			_onUIClose()
		end
	end
end

-- Wrap a view Frame in a ScreenGui
local function wrapInScreenGui(name: string, viewFrame: Frame): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true -- Fullscreen
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	viewFrame.Parent = screenGui
	return screenGui
end

local function showUI(name: string, viewFrame: Frame)
	-- Note: closeCurrentUI() must be called BEFORE creating the new UI scope
	-- Enable blur when UI opens
	BlurManager.Enable()
	_currentUI = wrapInScreenGui(name, viewFrame)
	_currentUI.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================
-- VIEW FACTORIES (delegate to View modules)
-- ============================================

local function openShopView()
	Logger.Info("ZoneInteraction", "Opening Shop")

	-- Close any existing UI first (before creating new scope)
	closeCurrentUI()

	-- Create a sub-scope for this UI (cleaned on close)
	_currentUIScope = Fusion.scoped(Fusion)
	local uiScope = _currentUIScope

	-- Create Computed values for ShopScreen
	local coins = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.Coins else 0
	end)

	local unlockedPlants = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.UnlockedPlants else {}
	end)

	local viewFrame = ShopScreen({
		Scope = uiScope,
		Coins = coins,
		UnlockedPlants = unlockedPlants,
		OnClose = closeCurrentUI,
		OnPurchase = function(plantType: string)
			if _onPurchasePlant then
				_onPurchasePlant(plantType)
			end
		end,
	})

	showUI("ShopUI", viewFrame)
end

local function openDeckBuilderView()
	Logger.Info("ZoneInteraction", "Opening Deck Builder")

	-- Close any existing UI first (before creating new scope)
	closeCurrentUI()

	-- Create a sub-scope for this UI (cleaned on close)
	_currentUIScope = Fusion.scoped(Fusion)
	local uiScope = _currentUIScope

	local viewFrame = DeckBuilderScreen({
		Scope = uiScope,
		SelectedDeck = _currentDeck,
		PlayerData = _playerData,
		PlantMutations = _equippedMutations, -- Show equipped mutations
		OnBack = closeCurrentUI,
		OnPlay = function()
			closeCurrentUI()
		end,
		OnSaveDeck = function(deck: { string })
			if _onSaveDeck then
				_onSaveDeck(deck)
			end
			-- Don't close UI - auto-save should be seamless
		end,
	})

	showUI("DeckBuilderUI", viewFrame)
end

local function openProfileView()
	Logger.Info("ZoneInteraction", "Opening Profile")

	-- Close any existing UI first (before creating new scope)
	closeCurrentUI()

	-- Create a sub-scope for this UI (cleaned on close)
	_currentUIScope = Fusion.scoped(Fusion)
	local uiScope = _currentUIScope

	-- Create Computed values that extract from _playerData
	local level = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.Level else 1
	end)

	local xp = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.XP else 0
	end)

	local xpRequired = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.TotalXPForNextLevel else 100
	end)

	local coins = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.Coins else 0
	end)

	local gems = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.Gems else 0
	end)

	local gamesPlayed = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.GamesPlayed else 0
	end)

	local gamesWon = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.GamesWon else 0
	end)

	local zombiesKilled = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.ZombiesKilled else 0
	end)

	local plantsPlaced = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.PlantsPlaced else 0
	end)

	local viewFrame = ProfileScreen({
		Scope = uiScope,
		Level = level,
		XP = xp,
		XPRequired = xpRequired,
		Coins = coins,
		Gems = gems,
		GamesPlayed = gamesPlayed,
		GamesWon = gamesWon,
		ZombiesKilled = zombiesKilled,
		PlantsPlaced = plantsPlaced,
		OnClose = closeCurrentUI,
	})

	showUI("ProfileUI", viewFrame)
end

local function openMutationView()
	Logger.Info("ZoneInteraction", "Opening Mutations")

	-- Close any existing UI first (before creating new scope)
	closeCurrentUI()

	-- Create a sub-scope for this UI (cleaned on close)
	_currentUIScope = Fusion.scoped(Fusion)
	local uiScope = _currentUIScope

	local viewFrame = MutationScreen({
		Scope = uiScope,
		PlayerData = _playerData,
		OwnedMutations = _ownedMutations,
		EquippedMutations = _equippedMutations,
		OnBack = closeCurrentUI,
		OnPurchaseMutation = function(plantType: string, mutationType: string)
			if _onPurchaseMutation then
				_onPurchaseMutation(plantType, mutationType)
			end
		end,
		OnEquipMutation = function(plantType: string, mutationType: string)
			if _onEquipMutation then
				_onEquipMutation(plantType, mutationType)
			end
		end,
		OnUnequipMutation = function(plantType: string, mutationType: string)
			if _onUnequipMutation then
				_onUnequipMutation(plantType, mutationType)
			end
		end,
	})

	showUI("MutationUI", viewFrame)
end

-- ============================================
-- PROMPT HANDLER
-- ============================================

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer then
		return
	end

	local promptName = prompt.Name

	if promptName == "ShopPrompt" then
		openShopView()
	elseif promptName == "DeckPrompt" then
		openDeckBuilderView()
	elseif promptName == "ProfilePrompt" then
		openProfileView()
	elseif promptName == "MutationPrompt" then
		openMutationView()
	end
end

-- ============================================
-- PUBLIC API
-- ============================================

function ZoneInteractionController.Initialize()
	Logger.Info("ZoneInteraction", "Initializing ZoneInteractionController")
	_trove:Connect(ProximityPromptService.PromptTriggered, onPromptTriggered)

	-- Connect to LobbySignals (observer pattern)
	_trove:Connect(LobbySignals.OnPlayerDataSync, function(data)
		ZoneInteractionController.SetPlayerData(data)
	end)

	_trove:Connect(LobbySignals.OnDeckUpdated, function(data)
		ZoneInteractionController.UpdateDeck(data.Deck)
	end)

	_trove:Connect(LobbySignals.OnMutationsSync, function(data)
		ZoneInteractionController.UpdateOwnedMutations(data.OwnedMutations)
		ZoneInteractionController.UpdateEquippedMutations(data.EquippedMutations)
	end)

	Logger.Debug("ZoneInteraction", "Signal listeners connected")
end

-- Cleanup
function ZoneInteractionController.Dispose()
	_trove:Destroy()
end

-- State setters (called by init.client.luau)
function ZoneInteractionController.SetPlayerData(data: any)
	_playerData:set(data)
	if data then
		_currentDeck:set(data.Deck or {})
	end
end

function ZoneInteractionController.UpdateDeck(deck: { string })
	_currentDeck:set(deck)
end

function ZoneInteractionController.UpdateOwnedMutations(mutations: { [string]: { string } })
	-- Shallow copy to ensure Fusion detects the change
	_ownedMutations:set(table.clone(mutations))
end

function ZoneInteractionController.UpdateEquippedMutations(mutations: { [string]: { string } })
	-- Shallow copy to ensure Fusion detects the change
	_equippedMutations:set(table.clone(mutations))
end

-- Callback setters
function ZoneInteractionController.SetOnPurchasePlant(callback: (string) -> ())
	_onPurchasePlant = callback
end

function ZoneInteractionController.SetOnSaveDeck(callback: ({ string }) -> ())
	_onSaveDeck = callback
end

function ZoneInteractionController.SetOnPurchaseMutation(callback: (string, string) -> ())
	_onPurchaseMutation = callback
end

function ZoneInteractionController.SetOnEquipMutation(callback: (string, string) -> ())
	_onEquipMutation = callback
end

function ZoneInteractionController.SetOnUnequipMutation(callback: (string, string) -> ())
	_onUnequipMutation = callback
end

function ZoneInteractionController.SetOnUIClose(callback: () -> ())
	_onUIClose = callback
end

-- Manual UI opening (for testing or keybinds)
function ZoneInteractionController.OpenShop()
	openShopView()
end

function ZoneInteractionController.OpenDeckBuilder()
	openDeckBuilderView()
end

function ZoneInteractionController.OpenProfile()
	openProfileView()
end

function ZoneInteractionController.OpenMutations()
	openMutationView()
end

function ZoneInteractionController.OpenUnlocks()
	Logger.Info("ZoneInteraction", "Opening Unlocks")

	-- Close any existing UI first (before creating new scope)
	closeCurrentUI()

	-- Create a sub-scope for this UI (cleaned on close)
	_currentUIScope = Fusion.scoped(Fusion)
	local uiScope = _currentUIScope

	local playerLevel = Computed(uiScope, function(use)
		local data = use(_playerData)
		return if data then data.Level else 1
	end)

	local viewFrame = UnlocksScreen({
		Scope = uiScope,
		PlayerLevel = playerLevel,
		OnClose = closeCurrentUI,
	})

	showUI("UnlocksUI", viewFrame)
end

function ZoneInteractionController.CloseUI()
	closeCurrentUI()
end

return ZoneInteractionController
