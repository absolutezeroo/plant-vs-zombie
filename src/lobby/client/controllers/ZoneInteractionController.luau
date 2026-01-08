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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Import View modules (SRP: each view handles its own UI)
-- Views are functions: (scope, props) -> Frame
local createShopView = require(script.Parent.Parent.ui.ShopView)
local createDeckBuilderView = require(script.Parent.Parent.ui.DeckBuilderView)
local createProfileView = require(script.Parent.Parent.ui.ProfileView)
local createMutationView = require(script.Parent.Parent.ui.MutationView)

local New = Fusion.New
local Value = Fusion.Value
local Children = Fusion.Children
local peek = Fusion.peek

local ZoneInteractionController = {}

-- ============================================
-- STATE (Reactive values shared with views)
-- ============================================
local _scope = Fusion.scoped(Fusion)
local _currentUI: ScreenGui? = nil

-- Reactive state values
local _playerData = Value(_scope, nil :: any?)
local _currentDeck = Value(_scope, {} :: {string})
local _ownedMutations = Value(_scope, {} :: {[string]: {string}})
local _equippedMutations = Value(_scope, {} :: {[string]: {string}})

-- Callbacks (set by init.client.luau)
local _onPurchasePlant: ((string) -> ())? = nil
local _onSaveDeck: (({string}) -> ())? = nil
local _onPurchaseMutation: ((string, string) -> ())? = nil
local _onEquipMutation: ((string, string) -> ())? = nil
local _onUnequipMutation: ((string, string) -> ())? = nil

-- ============================================
-- UI MANAGEMENT
-- ============================================

local function closeCurrentUI()
    if _currentUI then
        _currentUI:Destroy()
        _currentUI = nil
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
    closeCurrentUI()
    _currentUI = wrapInScreenGui(name, viewFrame)
    _currentUI.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================
-- VIEW FACTORIES (delegate to View modules)
-- ============================================

local function openShopView()
    Logger.Info("ZoneInteraction", "Opening Shop")
    
    local viewFrame = createShopView(_scope, {
        PlayerData = _playerData,
        OnBack = closeCurrentUI,
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
    
    local viewFrame = createDeckBuilderView(_scope, {
        SelectedDeck = _currentDeck,
        PlayerData = _playerData,
        PlantMutations = _equippedMutations, -- Show equipped mutations
        OnBack = closeCurrentUI,
        OnPlay = function()
            closeCurrentUI()
        end,
        OnSaveDeck = function(deck: {string})
            if _onSaveDeck then
                _onSaveDeck(deck)
            end
            closeCurrentUI()
        end,
    })
    
    showUI("DeckBuilderUI", viewFrame)
end

local function openProfileView()
    Logger.Info("ZoneInteraction", "Opening Profile")
    
    local viewFrame = createProfileView(_scope, {
        PlayerData = _playerData,
        OnBack = closeCurrentUI,
    })
    
    showUI("ProfileUI", viewFrame)
end

local function openMutationView()
    Logger.Info("ZoneInteraction", "Opening Mutations")
    
    local viewFrame = createMutationView(_scope, {
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
    if player ~= Players.LocalPlayer then return end
    
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
    ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
end

-- State setters (called by init.client.luau)
function ZoneInteractionController.SetPlayerData(data: any)
    _playerData:set(data)
    if data then
        _currentDeck:set(data.Deck or {})
    end
end

function ZoneInteractionController.UpdateDeck(deck: {string})
    _currentDeck:set(deck)
end

function ZoneInteractionController.UpdateOwnedMutations(mutations: {[string]: {string}})
    -- Create shallow copy to ensure Fusion detects the change
    local copy = {}
    for k, v in mutations do
        copy[k] = v
    end
    _ownedMutations:set(copy)
end

function ZoneInteractionController.UpdateEquippedMutations(mutations: {[string]: {string}})
    -- Create shallow copy to ensure Fusion detects the change
    local copy = {}
    for k, v in mutations do
        copy[k] = v
    end
    _equippedMutations:set(copy)
end

-- Callback setters
function ZoneInteractionController.SetOnPurchasePlant(callback: (string) -> ())
    _onPurchasePlant = callback
end

function ZoneInteractionController.SetOnSaveDeck(callback: ({string}) -> ())
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

function ZoneInteractionController.CloseUI()
    closeCurrentUI()
end

return ZoneInteractionController
