--!strict
--[[
	LoadingScreen.luau - Loading Screen (Toon Pop Style)
	
	Unified loading screen with progress bar.
	Uses the same Toon Pop aesthetic as ShopScreen, DeckBuilderScreen, etc.
	
	Usage:
		local LoadingScreen = require(Shared.ui.components.organisms.LoadingScreen)
		local loader = LoadingScreen.new({
			title = "🌻 Garden Swarm 🧟",
			subtitle = "Loading...",
		})
		loader:SetStage(1, "Initializing...")
		loader:SetProgress(0.5)
		loader:Complete()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.ui.design.Theme)
local ChanceUtils = require(Shared.utils.ChanceUtils)
local BlurManager = require(Shared.ui.utils.BlurManager)

-- Fusion primitives
local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local Spring = Fusion.Spring
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

-- Constants
local SHADOW_OFFSET = 4
local BAR_HEIGHT = 50
local CONTAINER_WIDTH = 500

-- Loading tips
local TIPS = {
	"💡 Place sunflowers early to maximize sun production!",
	"💡 Use wall-nuts to slow down zombie waves!",
	"💡 Combine mutations for powerful effects!",
	"💡 Save coins for rare plants in the shop!",
	"💡 Build your deck before entering the arena!",
	"💡 Different plants are better for different lanes!",
	"💡 Watch out for special zombie abilities!",
}

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

local LoadingScreen = {}
LoadingScreen.__index = LoadingScreen

function LoadingScreen.new(config: LoaderConfig?)
	local self = setmetatable({}, LoadingScreen)
	
	config = config or {}
	
	-- Create a Fusion scope
	local scope = Fusion.scoped(Fusion)
	self._scope = scope
	
	self._stages = config.stages or DEFAULT_STAGES
	self._title = config.title or "🌻 Garden Swarm 🧟"
	self._subtitle = config.subtitle or "Roblox Edition"
	self._currentStage = Value(scope, 1)
	self._stageProgress = Value(scope, 0)
	self._statusText = Value(scope, "Loading...")
	self._isVisible = Value(scope, true)
	self._isFadingOut = Value(scope, false)
	
	-- Store references
	local currentStage = self._currentStage
	local stageProgress = self._stageProgress
	local stagesRef = self._stages
	
	-- Calculate total progress (0-1)
	self._totalProgress = Computed(scope, function(use)
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
	self._animatedProgress = Spring(scope, self._totalProgress, 25, 0.8)
	
	-- Percentage text
	local animatedProgress = self._animatedProgress
	self._percentText = Computed(scope, function(use)
		return string.format("%d%%", math.floor(use(animatedProgress) * 100))
	end)
	
	-- Create UI
	self:_createUI()
	
	return self
end

function LoadingScreen:_createUI()
	local scope = self._scope
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Enable blur effect
	BlurManager.Enable()
	
	-- Animated dots for loading text
	local dotCount = Value(scope, 0)
	local isVisible = self._isVisible
	
	task.spawn(function()
		while peek(isVisible) do
			task.wait(0.4)
			dotCount:set((peek(dotCount) + 1) % 4)
		end
	end)
	
	local dotsText = Computed(scope, function(use)
		return string.rep(".", use(dotCount))
	end)
	
	-- Main overlay opacity (for fade out)
	local isFadingOut = self._isFadingOut
	local overlayTransparency = Computed(scope, function(use)
		return if use(isFadingOut) then 1 else 0
	end)
	
	local animatedOverlayTransparency = Spring(scope, overlayTransparency, 15, 1)
	
	-- Store references
	local statusText = self._statusText
	local animatedProgress = self._animatedProgress
	local percentText = self._percentText
	local title = self._title
	local subtitle = self._subtitle
	
	-- Random tip
	local tip = ChanceUtils.PickRandom(TIPS) or TIPS[1]
	
	self._screenGui = New(scope, "ScreenGui") {
		Name = "LoadingScreen",
		Parent = PlayerGui,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		
		[Children] = {
			-- Dark overlay background
			New(scope, "Frame") {
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(30, 35, 45),
				BackgroundTransparency = animatedOverlayTransparency,
				BorderSizePixel = 0,
				
				[Children] = {
					-- Center container
					New(scope, "Frame") {
						Name = "Container",
						Size = UDim2.fromOffset(CONTAINER_WIDTH, 350),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						
						[Children] = {
							-- Main panel shadow
							New(scope, "Frame") {
								Name = "PanelShadow",
								Size = UDim2.new(1, 0, 0, 220),
								Position = UDim2.fromOffset(0, 70 + SHADOW_OFFSET),
								BackgroundColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 1,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
								},
							},
							
							-- Main panel
							New(scope, "Frame") {
								Name = "Panel",
								Size = UDim2.new(1, 0, 0, 220),
								Position = UDim2.fromOffset(0, 70),
								BackgroundColor3 = Theme.Colors.Surface.Main,
								ZIndex = 2,
								
								[Children] = {
									New(scope, "UICorner") {
										CornerRadius = Theme.Layout.CornerRadius,
									},
									
									New(scope, "UIStroke") {
										Color = Theme.Colors.Surface.Stroke :: Color3,
										Thickness = Theme.Layout.StrokeThickness,
									},
									
									New(scope, "UIPadding") {
										PaddingTop = UDim.new(0, 20),
										PaddingBottom = UDim.new(0, 20),
										PaddingLeft = UDim.new(0, 24),
										PaddingRight = UDim.new(0, 24),
									},
									
									-- Progress bar container (shadow)
									New(scope, "Frame") {
										Name = "ProgressShadow",
										Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
										Position = UDim2.fromOffset(0, 10 + SHADOW_OFFSET),
										BackgroundColor3 = Theme.Colors.Surface.Shadow,
										ZIndex = 1,
										
										[Children] = {
											New(scope, "UICorner") {
												CornerRadius = UDim.new(0, 12),
											},
										},
									},
									
									-- Progress bar container
									New(scope, "Frame") {
										Name = "ProgressContainer",
										Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
										Position = UDim2.fromOffset(0, 10),
										BackgroundColor3 = Theme.Colors.Surface.Shadow,
										ZIndex = 2,
										
										[Children] = {
											New(scope, "UICorner") {
												CornerRadius = UDim.new(0, 12),
											},
											
											New(scope, "UIStroke") {
												Color = Theme.Colors.Surface.Stroke :: Color3,
												Thickness = 2,
											},
											
											-- Progress bar fill
											New(scope, "Frame") {
												Name = "ProgressFill",
												Size = Computed(scope, function(use)
													return UDim2.new(use(animatedProgress), -8, 1, -8)
												end),
												Position = UDim2.fromOffset(4, 4),
												BackgroundColor3 = Theme.Colors.Action.Main,
												ZIndex = 3,
												
												[Children] = {
													New(scope, "UICorner") {
														CornerRadius = UDim.new(0, 8),
													},
												},
											},
											
											-- Percentage text
											New(scope, "TextLabel") {
												Name = "Percentage",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = percentText,
												TextColor3 = Color3.new(1, 1, 1),
												TextSize = 20,
												Font = Theme.Typography.Fonts.Title,
												ZIndex = 4,
											},
										},
									},
									
									-- Status text
									New(scope, "TextLabel") {
										Name = "Status",
										Size = UDim2.new(1, 0, 0, 30),
										Position = UDim2.fromOffset(0, BAR_HEIGHT + 30),
										BackgroundTransparency = 1,
										Text = Computed(scope, function(use)
											local status = use(statusText)
											local dots = use(dotsText)
											if status:sub(-1) == "!" or status:sub(-1) == "." then
												return status
											end
											return status .. dots
										end),
										TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
										TextSize = 18,
										Font = Theme.Typography.Fonts.Body,
										ZIndex = 2,
									},
									
									-- Tip text
									New(scope, "TextLabel") {
										Name = "Tip",
										Size = UDim2.new(1, 0, 0, 24),
										Position = UDim2.fromOffset(0, BAR_HEIGHT + 70),
										BackgroundTransparency = 1,
										Text = tip,
										TextColor3 = Color3.new(1, 1, 1),
										TextSize = 14,
										Font = Theme.Typography.Fonts.Body,
										TextTransparency = 0.2,
										ZIndex = 2,
									},
									
									-- Decorative emojis
									New(scope, "TextLabel") {
										Size = UDim2.fromOffset(40, 40),
										Position = UDim2.new(0, -10, 1, -10),
										AnchorPoint = Vector2.new(0, 1),
										BackgroundTransparency = 1,
										Text = "🌱",
										TextSize = 28,
										TextTransparency = 0.4,
										ZIndex = 2,
									},
									
									New(scope, "TextLabel") {
										Size = UDim2.fromOffset(40, 40),
										Position = UDim2.new(1, 10, 1, -10),
										AnchorPoint = Vector2.new(1, 1),
										BackgroundTransparency = 1,
										Text = "🌿",
										TextSize = 28,
										TextTransparency = 0.4,
										ZIndex = 2,
									},
								},
							},
							
							-- Game logo/title
							New(scope, "TextLabel") {
								Name = "Title",
								Size = UDim2.new(1, 0, 0, 50),
								Position = UDim2.fromOffset(0, 0),
								BackgroundTransparency = 1,
								Text = title,
								TextColor3 = Theme.Colors.Surface.Stroke :: Color3,
								TextSize = 36,
								Font = Theme.Typography.Fonts.Title,
								TextStrokeTransparency = 0.7,
								TextStrokeColor3 = Theme.Colors.Surface.Shadow,
								ZIndex = 10,
							},
							
							-- Subtitle
							New(scope, "TextLabel") {
								Name = "Subtitle",
								Size = UDim2.new(1, 0, 0, 25),
								Position = UDim2.fromOffset(0, 45),
								BackgroundTransparency = 1,
								Text = subtitle,
								TextColor3 = Theme.Colors.Surface.Shadow,
								TextSize = 18,
								Font = Theme.Typography.Fonts.Body,
								ZIndex = 10,
							},
						},
					},
				},
			},
		},
	}
end

-- Set the current loading stage
function LoadingScreen:SetStage(stageIndex: number, statusOverride: string?)
	if stageIndex < 1 or stageIndex > #self._stages then
		return
	end
	
	self._currentStage:set(stageIndex)
	self._stageProgress:set(0)
	self._statusText:set(statusOverride or self._stages[stageIndex].Name)
end

-- Update progress within current stage (0-1)
function LoadingScreen:SetProgress(progress: number)
	self._stageProgress:set(math.clamp(progress, 0, 1))
end

-- Set custom status text
function LoadingScreen:SetStatus(text: string)
	self._statusText:set(text)
end

-- Complete current stage and move to next
function LoadingScreen:CompleteStage()
	self._stageProgress:set(1)
	
	local nextStage = peek(self._currentStage) + 1
	if nextStage <= #self._stages then
		task.delay(0.1, function()
			self:SetStage(nextStage)
		end)
	end
end

-- Complete all loading and fade out
function LoadingScreen:Complete(callback: (() -> ())?)
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
			
			-- Disable blur
			BlurManager.Disable()
			
			-- Clean up scope (destroys all Fusion objects)
			if self._scope then
				doCleanup(self._scope)
				self._scope = nil
			end
			
			if callback then
				callback()
			end
		end)
	end)
end

-- Immediately hide (no animation)
function LoadingScreen:Hide()
	self._isVisible:set(false)
	
	-- Disable blur
	BlurManager.Disable()
	
	-- Clean up scope
	if self._scope then
		doCleanup(self._scope)
		self._scope = nil
	end
end

-- Get current stage count
function LoadingScreen:GetStageCount(): number
	return #self._stages
end

return LoadingScreen
