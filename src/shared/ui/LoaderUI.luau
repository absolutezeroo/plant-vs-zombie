--!strict
--[[
    LoaderUI.luau - Generic Loading Screen with Progress Bar
    
    Unified loading screen using ModernTheme.
    
    Uses Fusion 0.3 scoped API.
    
    Usage:
        local LoaderUI = require(shared.ui.LoaderUI)
        local loader = LoaderUI.new({
            stages = { ... },  -- optional custom stages
        })
        loader:SetStage(1, "Loading...")
        loader:SetProgress(0.5)
        loader:Complete()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModernTheme = require(Shared.ui.ModernTheme)
local ChanceUtils = require(Shared.utils.ChanceUtils)

local LoaderUI = {}
LoaderUI.__index = LoaderUI

local Colors = ModernTheme.Colors
local Fonts = ModernTheme.Fonts

export type LoadingStage = {
    Name: string,
    Weight: number, -- How much of the total progress this stage represents
}

export type LoaderConfig = {
    stages: {LoadingStage}?,
    title: string?,
    subtitle: string?,
}

-- Default loading stages
local DEFAULT_STAGES: {LoadingStage} = {
    { Name = "Initializing...", Weight = 0.10 },
    { Name = "Loading packages...", Weight = 0.15 },
    { Name = "Setting up systems...", Weight = 0.20 },
    { Name = "Preparing UI...", Weight = 0.20 },
    { Name = "Syncing with server...", Weight = 0.30 },
    { Name = "Ready!", Weight = 0.05 },
}

-- Loading tips
local TIPS = {
    "💡 Tip: Place sunflowers early to maximize sun production!",
    "💡 Tip: Use wall-nuts to slow down zombie waves!",
    "💡 Tip: Combine mutations for powerful effects!",
    "💡 Tip: Save coins for rare plants in the shop!",
    "💡 Tip: Build your deck before entering the arena!",
}

function LoaderUI.new(config: LoaderConfig?)
    local self = setmetatable({}, LoaderUI)
    
    config = config or {}
    
    -- Create a Fusion scope for this loader
    local scope = Fusion.scoped(Fusion)
    self._scope = scope
    
    self._stages = config.stages or DEFAULT_STAGES
    self._title = config.title or "🌻 Plants vs Zombies 🧟"
    self._subtitle = config.subtitle or "Roblox Edition"
    self._currentStage = scope:Value(1)
    self._stageProgress = scope:Value(0)
    self._statusText = scope:Value("Loading...")
    self._isVisible = scope:Value(true)
    self._isFadingOut = scope:Value(false)
    
    -- Store references for computed
    local currentStage = self._currentStage
    local stageProgress = self._stageProgress
    local stagesRef = self._stages
    
    -- Calculate total progress (0-1)
    self._totalProgress = scope:Computed(function(use)
        local stageIndex = use(currentStage)
        local progress = use(stageProgress)
        
        -- Sum up completed stages
        local completed = 0
        for i = 1, stageIndex - 1 do
            if stagesRef[i] then
                completed = completed + stagesRef[i].Weight
            end
        end
        
        -- Add current stage progress
        local stage = stagesRef[stageIndex]
        if stage then
            completed = completed + (stage.Weight * progress)
        end
        
        return math.clamp(completed, 0, 1)
    end)
    
    -- Smooth animated progress
    self._animatedProgress = scope:Spring(self._totalProgress, 25, 0.8)
    
    -- Percentage text
    local animatedProgress = self._animatedProgress
    self._percentText = scope:Computed(function(use)
        return string.format("%d%%", math.floor(use(animatedProgress) * 100))
    end)
    
    -- Create UI
    self:_createUI()
    
    return self
end

function LoaderUI:_createUI()
    local scope = self._scope
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Animated dots for loading text
    local dotCount = scope:Value(0)
    local isVisible = self._isVisible
    
    task.spawn(function()
        while Fusion.peek(isVisible) do
            task.wait(0.4)
            dotCount:set((Fusion.peek(dotCount) + 1) % 4)
        end
    end)
    
    local dotsText = scope:Computed(function(use)
        return string.rep(".", use(dotCount))
    end)
    
    -- Main overlay opacity (for fade out)
    local isFadingOut = self._isFadingOut
    local overlayTransparency = scope:Computed(function(use)
        return if use(isFadingOut) then 1 else 0
    end)
    
    local animatedOverlayTransparency = scope:Spring(overlayTransparency, 15, 1)
    
    -- Store references
    local statusText = self._statusText
    local animatedProgress = self._animatedProgress
    local percentText = self._percentText
    local title = self._title
    local subtitle = self._subtitle
    
    -- Random tip
    local tip = ChanceUtils.PickRandom(TIPS) or TIPS[1]
    
    self._screenGui = scope:New "ScreenGui" {
        Name = "LoaderUI",
        Parent = PlayerGui,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        
        [Fusion.Children] = {
            -- Dark overlay background
            scope:New "Frame" {
                Name = "Overlay",
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Colors.Background,
                BackgroundTransparency = animatedOverlayTransparency,
                BorderSizePixel = 0,
                
                [Fusion.Children] = {
                    -- Gradient overlay for depth
                    scope:New "UIGradient" {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Colors.BackgroundLight),
                            ColorSequenceKeypoint.new(0.5, Colors.Background),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 20)),
                        }),
                        Rotation = 90,
                    },
                    
                    -- Center container
                    scope:New "Frame" {
                        Name = "Container",
                        Size = UDim2.fromOffset(500, 300),
                        Position = UDim2.fromScale(0.5, 0.5),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        
                        [Fusion.Children] = {
                            -- Game logo/title
                            scope:New "TextLabel" {
                                Name = "Title",
                                Size = UDim2.new(1, 0, 0, 60),
                                Position = UDim2.fromOffset(0, 0),
                                BackgroundTransparency = 1,
                                Text = title,
                                TextColor3 = Colors.TextWhite,
                                TextSize = 42,
                                Font = Fonts.Title,
                                TextStrokeTransparency = 0.5,
                                TextStrokeColor3 = Color3.new(0, 0, 0),
                            },
                            
                            -- Subtitle
                            scope:New "TextLabel" {
                                Name = "Subtitle",
                                Size = UDim2.new(1, 0, 0, 30),
                                Position = UDim2.fromOffset(0, 60),
                                BackgroundTransparency = 1,
                                Text = subtitle,
                                TextColor3 = Colors.TextMuted,
                                TextSize = 24,
                                Font = Enum.Font.GothamMedium,
                                TextTransparency = 0.2,
                            },
                            
                            -- Progress bar container
                            scope:New "Frame" {
                                Name = "ProgressContainer",
                                Size = UDim2.new(1, 0, 0, 40),
                                Position = UDim2.fromScale(0, 0.55),
                                AnchorPoint = Vector2.new(0, 0),
                                BackgroundColor3 = Colors.Card,
                                BorderSizePixel = 0,
                                
                                [Fusion.Children] = {
                                    scope:New "UICorner" { CornerRadius = UDim.new(0, 12) },
                                    scope:New "UIStroke" { 
                                        Color = Colors.Border,
                                        Thickness = 2,
                                    },
                                    
                                    -- Progress bar fill
                                    scope:New "Frame" {
                                        Name = "ProgressFill",
                                        Size = scope:Computed(function(use)
                                            return UDim2.new(use(animatedProgress), -8, 1, -8)
                                        end),
                                        Position = UDim2.fromOffset(4, 4),
                                        BackgroundColor3 = Colors.Success,
                                        BorderSizePixel = 0,
                                        
                                        [Fusion.Children] = {
                                            scope:New "UICorner" { CornerRadius = UDim.new(0, 8) },
                                            scope:New "UIGradient" {
                                                Color = ColorSequence.new({
                                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 100)),
                                                    ColorSequenceKeypoint.new(0.5, Colors.Success),
                                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 140, 60)),
                                                }),
                                                Rotation = 90,
                                            },
                                        },
                                    },
                                    
                                    -- Percentage text
                                    scope:New "TextLabel" {
                                        Name = "Percentage",
                                        Size = UDim2.fromScale(1, 1),
                                        BackgroundTransparency = 1,
                                        Text = percentText,
                                        TextColor3 = Colors.TextWhite,
                                        TextSize = 18,
                                        Font = Fonts.Header,
                                        TextStrokeTransparency = 0.3,
                                        TextStrokeColor3 = Color3.new(0, 0, 0),
                                    },
                                },
                            },
                            
                            -- Status text
                            scope:New "TextLabel" {
                                Name = "Status",
                                Size = UDim2.new(1, 0, 0, 30),
                                Position = UDim2.fromScale(0, 0.75),
                                BackgroundTransparency = 1,
                                Text = scope:Computed(function(use)
                                    local status = use(statusText)
                                    local dots = use(dotsText)
                                    if status:sub(-1) == "!" or status:sub(-1) == "." then
                                        return status
                                    end
                                    return status .. dots
                                end),
                                TextColor3 = Colors.TextLight,
                                TextSize = 20,
                                Font = Fonts.Body,
                                TextTransparency = 0.3,
                            },
                            
                            -- Tip text
                            scope:New "TextLabel" {
                                Name = "Tip",
                                Size = UDim2.new(1, 0, 0, 24),
                                Position = UDim2.fromScale(0, 0.9),
                                BackgroundTransparency = 1,
                                Text = tip,
                                TextColor3 = Colors.Gold,
                                TextSize = 16,
                                Font = Fonts.Body,
                                TextTransparency = 0.4,
                            },
                        },
                    },
                    
                    -- Decorative plant icons (corners)
                    scope:New "TextLabel" {
                        Size = UDim2.fromOffset(60, 60),
                        Position = UDim2.new(0, 30, 1, -30),
                        AnchorPoint = Vector2.new(0, 1),
                        BackgroundTransparency = 1,
                        Text = "🌱",
                        TextSize = 40,
                        TextTransparency = 0.6,
                    },
                    scope:New "TextLabel" {
                        Size = UDim2.fromOffset(60, 60),
                        Position = UDim2.new(1, -30, 1, -30),
                        AnchorPoint = Vector2.new(1, 1),
                        BackgroundTransparency = 1,
                        Text = "🌿",
                        TextSize = 40,
                        TextTransparency = 0.6,
                    },
                },
            },
        },
    }
end

-- Set the current loading stage
function LoaderUI:SetStage(stageIndex: number, statusOverride: string?)
    if stageIndex < 1 or stageIndex > #self._stages then
        return
    end
    
    self._currentStage:set(stageIndex)
    self._stageProgress:set(0)
    self._statusText:set(statusOverride or self._stages[stageIndex].Name)
end

-- Update progress within current stage (0-1)
function LoaderUI:SetProgress(progress: number)
    self._stageProgress:set(math.clamp(progress, 0, 1))
end

-- Set custom status text
function LoaderUI:SetStatus(text: string)
    self._statusText:set(text)
end

-- Complete current stage and move to next
function LoaderUI:CompleteStage()
    self._stageProgress:set(1)
    
    local nextStage = Fusion.peek(self._currentStage) + 1
    if nextStage <= #self._stages then
        task.delay(0.1, function()
            self:SetStage(nextStage)
        end)
    end
end

-- Complete all loading and fade out
function LoaderUI:Complete(callback: (() -> ())?)
    -- Set to 100%
    self._currentStage:set(#self._stages)
    self._stageProgress:set(1)
    self._statusText:set("Ready!")
    
    -- Wait a moment then fade out
    task.delay(0.5, function()
        self._isFadingOut:set(true)
        
        -- Wait for fade animation
        task.delay(0.8, function()
            self._isVisible:set(false)
            
            -- Clean up scope (destroys all Fusion objects)
            if self._scope then
                Fusion.doCleanup(self._scope)
                self._scope = nil
            end
            
            if callback then
                callback()
            end
        end)
    end)
end

-- Immediately hide (no animation)
function LoaderUI:Hide()
    self._isVisible:set(false)
    
    -- Clean up scope
    if self._scope then
        Fusion.doCleanup(self._scope)
        self._scope = nil
    end
end

-- Get current stage count
function LoaderUI:GetStageCount(): number
    return #self._stages
end

return LoaderUI
