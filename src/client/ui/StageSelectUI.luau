--!strict
--[[
	StageSelectUI.luau - Stage/Level selection UI component
	
	Displays:
	- World tabs (Day, Night, Pool, Fog, Roof)
	- Stage buttons with star ratings and lock states
	- Stage info panel with details and play button
	
	Uses PvZ theme for consistent styling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StageData = require(Shared.data.StageData)
local Logger = require(Shared.utils.Logger)

local Client = script.Parent.Parent
local PlayerDataClient = require(Client.modules.PlayerDataClient)
local PvZTheme = require(script.Parent.PvZTheme)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local ForValues = Fusion.ForValues
local peek = Fusion.peek

local StageSelectUI = {}

-- World icons
local WORLD_ICONS = {
	[1] = "☀️",  -- Day
	[2] = "🌙",  -- Night
	[3] = "🏊",  -- Pool
	[4] = "🌫️", -- Fog
	[5] = "🏠",  -- Roof
}

-- World button component
local function WorldTab(scope, props: {
	World: number,
	IsSelected: any,
	IsUnlocked: any,
	OnClick: () -> (),
})
	local isHovered = Value(scope, false)
	local worldName = StageData.WorldNames[props.World] or `World {props.World}`
	
	return New(scope, "TextButton") {
		Size = UDim2.new(1/StageData.WORLD_COUNT, -4, 1, 0),
		BackgroundColor3 = Computed(scope, function(use)
			if not use(props.IsUnlocked) then
				return PvZTheme.Colors.Disabled
			elseif use(props.IsSelected) then
				return PvZTheme.Colors.GrassGreen
			elseif use(isHovered) then
				return PvZTheme.Colors.WoodLight
			else
				return PvZTheme.Colors.WoodBrown
			end
		end),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		
		[OnEvent "Activated"] = function()
			if peek(props.IsUnlocked) then
				props.OnClick()
			end
		end,
		[OnEvent "MouseEnter"] = function()
			isHovered:set(true)
		end,
		[OnEvent "MouseLeave"] = function()
			isHovered:set(false)
		end,
		
		[Children] = {
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
			
			New(scope, "UIStroke") {
				Color = Computed(scope, function(use)
					return if use(props.IsSelected) 
						then PvZTheme.Colors.SunYellow 
						else PvZTheme.Colors.WoodDark
				end),
				Thickness = 2,
			},
			
			-- World icon
			New(scope, "TextLabel") {
				Size = UDim2.new(1, 0, 0, 24),
				Position = UDim2.new(0, 0, 0, 4),
				BackgroundTransparency = 1,
				Text = WORLD_ICONS[props.World] or "🌍",
				TextSize = 20,
			},
			
			-- World name
			New(scope, "TextLabel") {
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.new(0, 0, 1, -20),
				BackgroundTransparency = 1,
				Text = worldName,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextColor3 = Computed(scope, function(use)
					return if use(props.IsUnlocked) 
						then PvZTheme.Colors.TextWhite 
						else PvZTheme.Colors.Disabled
				end),
			},
			
			-- Lock icon
			Computed(scope, function(use)
				if not use(props.IsUnlocked) then
					return New(scope, "TextLabel") {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 0.6,
						Text = PvZTheme.Icons.Lock,
						TextSize = 20,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 8),
							},
						},
					}
				end
				return nil
			end),
		},
	}
end

-- Stars display component
local function StarsDisplay(scope, stars: number, maxStars: number?)
	local max = maxStars or 3
	local starIcons = {}
	
	for i = 1, max do
		table.insert(starIcons, New(scope, "TextLabel") {
			Size = UDim2.new(0, 16, 0, 16),
			BackgroundTransparency = 1,
			Text = if i <= stars then "⭐" else "☆",
			TextSize = 14,
			TextColor3 = if i <= stars then PvZTheme.Colors.SunYellow else PvZTheme.Colors.Disabled,
			LayoutOrder = i,
		})
	end
	
	return New(scope, "Frame") {
		Size = UDim2.new(0, max * 18, 0, 16),
		BackgroundTransparency = 1,
		
		[Children] = {
			New(scope, "UIListLayout") {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 2),
			},
			starIcons,
		},
	}
end

-- Stage button component
local function StageButton(scope, props: {
	StageId: string,
	Config: any,
	IsSelected: any,
	OnClick: () -> (),
})
	local isHovered = Value(scope, false)
	local config = props.Config
	
	-- Get unlock and completion state
	local isUnlocked = Computed(scope, function(use)
		local completedStages = use(PlayerDataClient.GetCompletedStagesValue())
		local playerLevel = use(PlayerDataClient.GetLevelValue())
		return StageData.IsStageUnlocked(props.StageId, completedStages, playerLevel)
	end)
	
	local stars = Computed(scope, function(use)
		local completedStages = use(PlayerDataClient.GetCompletedStagesValue())
		return completedStages[props.StageId] or 0
	end)
	
	return New(scope, "TextButton") {
		Size = UDim2.new(0, 100, 0, 80),
		BackgroundColor3 = Computed(scope, function(use)
			if not use(isUnlocked) then
				return PvZTheme.Colors.Disabled
			elseif use(props.IsSelected) then
				return PvZTheme.Colors.GrassGreen
			elseif use(isHovered) then
				return PvZTheme.Colors.WoodLight
			else
				return PvZTheme.Colors.WoodBrown
			end
		end),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = config.Level,
		
		[OnEvent "Activated"] = function()
			if peek(isUnlocked) then
				props.OnClick()
			end
		end,
		[OnEvent "MouseEnter"] = function()
			isHovered:set(true)
		end,
		[OnEvent "MouseLeave"] = function()
			isHovered:set(false)
		end,
		
		[Children] = {
			New(scope, "UICorner") {
				CornerRadius = UDim.new(0, 10),
			},
			
			New(scope, "UIStroke") {
				Color = Computed(scope, function(use)
					if use(props.IsSelected) then
						return PvZTheme.Colors.SunYellow
					elseif use(stars) >= 3 then
						return PvZTheme.Colors.GrassGreen
					else
						return PvZTheme.Colors.WoodDark
					end
				end),
				Thickness = 3,
			},
			
			-- Level number
			New(scope, "TextLabel") {
				Size = UDim2.new(1, 0, 0, 28),
				Position = UDim2.new(0, 0, 0, 5),
				BackgroundTransparency = 1,
				Text = `{config.World}-{config.Level}`,
				TextSize = 22,
				Font = Enum.Font.GothamBlack,
				TextColor3 = Computed(scope, function(use)
					return if use(isUnlocked) 
						then PvZTheme.Colors.TextWhite 
						else PvZTheme.Colors.Disabled
				end),
			},
			
			-- Stage name
			New(scope, "TextLabel") {
				Size = UDim2.new(1, -8, 0, 16),
				Position = UDim2.new(0, 4, 0, 32),
				BackgroundTransparency = 1,
				Text = config.Name,
				TextSize = 10,
				TextScaled = true,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Computed(scope, function(use)
					return if use(isUnlocked) 
						then PvZTheme.Colors.TextGold 
						else PvZTheme.Colors.Disabled
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
			},
			
			-- Stars container
			New(scope, "Frame") {
				Size = UDim2.new(1, 0, 0, 20),
				Position = UDim2.new(0, 0, 1, -22),
				BackgroundTransparency = 1,
				
				[Children] = Computed(scope, function(use)
					if use(isUnlocked) then
						local s = use(stars)
						return {
							New(scope, "UIListLayout") {
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 2),
							},
							New(scope, "TextLabel") {
								Size = UDim2.new(0, 16, 0, 16),
								BackgroundTransparency = 1,
								Text = if s >= 1 then "⭐" else "☆",
								TextSize = 14,
								LayoutOrder = 1,
							},
							New(scope, "TextLabel") {
								Size = UDim2.new(0, 16, 0, 16),
								BackgroundTransparency = 1,
								Text = if s >= 2 then "⭐" else "☆",
								TextSize = 14,
								LayoutOrder = 2,
							},
							New(scope, "TextLabel") {
								Size = UDim2.new(0, 16, 0, 16),
								BackgroundTransparency = 1,
								Text = if s >= 3 then "⭐" else "☆",
								TextSize = 14,
								LayoutOrder = 3,
							},
						}
					else
						return {
							New(scope, "TextLabel") {
								Size = UDim2.new(1, 0, 1, 0),
								BackgroundTransparency = 1,
								Text = PvZTheme.Icons.Lock,
								TextSize = 16,
							},
						}
					end
				end),
			},
		},
	}
end

-- Create the StageSelectUI
function StageSelectUI.Create(scope, props: {
	Visible: any, -- Fusion.Value<boolean>
	OnClose: () -> (),
	OnStartStage: (stageId: string) -> (),
})
	-- State
	local selectedWorld = Value(scope, 1)
	local selectedStage = Value(scope, "1-1")
	
	-- Get stages for selected world
	local worldStages = Computed(scope, function(use)
		return StageData.GetWorldStages(use(selectedWorld))
	end)
	
	-- Get selected stage config
	local selectedConfig = Computed(scope, function(use)
		return StageData.GetStage(use(selectedStage))
	end)
	
	-- Check if selected stage is unlocked
	local isSelectedUnlocked = Computed(scope, function(use)
		local completedStages = use(PlayerDataClient.GetCompletedStagesValue())
		local playerLevel = use(PlayerDataClient.GetLevelValue())
		return StageData.IsStageUnlocked(use(selectedStage), completedStages, playerLevel)
	end)
	
	-- Check if world is unlocked (first stage of world is unlocked)
	local function isWorldUnlocked(world: number)
		return Computed(scope, function(use)
			local firstStage = `{world}-1`
			local completedStages = use(PlayerDataClient.GetCompletedStagesValue())
			local playerLevel = use(PlayerDataClient.GetLevelValue())
			return StageData.IsStageUnlocked(firstStage, completedStages, playerLevel)
		end)
	end
	
	return New(scope, "Frame") {
		Name = "StageSelectUI",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = PvZTheme.Colors.OverlayDark,
		BackgroundTransparency = 0.4,
		Visible = props.Visible,
		ZIndex = 100,
		
		[Children] = {
			-- Main panel
			PvZTheme.WoodPanel(scope, {
				Size = UDim2.new(0, 650, 0, 450),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				
				[Children] = {
					-- Header banner
					PvZTheme.Banner(scope, {
						Size = UDim2.new(1, 20, 0, 50),
						Position = UDim2.new(0.5, 0, 0, -25),
						AnchorPoint = Vector2.new(0.5, 0),
						Text = "🗺️ SELECT STAGE",
						TextSize = 24,
					}),
					
					-- Close button
					New(scope, "TextButton") {
						Name = "CloseButton",
						Size = UDim2.new(0, 36, 0, 36),
						Position = UDim2.new(1, -8, 0, 8),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundColor3 = PvZTheme.Colors.HealthRed,
						Text = "X",
						TextColor3 = PvZTheme.Colors.TextWhite,
						TextSize = 20,
						Font = Enum.Font.GothamBold,
						AutoButtonColor = true,
						
						[OnEvent "Activated"] = props.OnClose,
						
						[Children] = {
							New(scope, "UICorner") { CornerRadius = UDim.new(0, 8) },
							New(scope, "UIStroke") {
								Color = Color3.fromRGB(180, 40, 40),
								Thickness = 2,
							},
						},
					},
					
					-- World tabs
					New(scope, "Frame") {
						Name = "WorldTabs",
						Size = UDim2.new(1, -20, 0, 50),
						Position = UDim2.new(0, 10, 0, 45),
						BackgroundTransparency = 1,
						
						[Children] = {
							New(scope, "UIListLayout") {
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 4),
							},
							
							-- Generate world tabs
							WorldTab(scope, {
								World = 1,
								IsSelected = Computed(scope, function(use) return use(selectedWorld) == 1 end),
								IsUnlocked = isWorldUnlocked(1),
								OnClick = function() selectedWorld:set(1) end,
							}),
							WorldTab(scope, {
								World = 2,
								IsSelected = Computed(scope, function(use) return use(selectedWorld) == 2 end),
								IsUnlocked = isWorldUnlocked(2),
								OnClick = function() selectedWorld:set(2) end,
							}),
							WorldTab(scope, {
								World = 3,
								IsSelected = Computed(scope, function(use) return use(selectedWorld) == 3 end),
								IsUnlocked = isWorldUnlocked(3),
								OnClick = function() selectedWorld:set(3) end,
							}),
							WorldTab(scope, {
								World = 4,
								IsSelected = Computed(scope, function(use) return use(selectedWorld) == 4 end),
								IsUnlocked = isWorldUnlocked(4),
								OnClick = function() selectedWorld:set(4) end,
							}),
							WorldTab(scope, {
								World = 5,
								IsSelected = Computed(scope, function(use) return use(selectedWorld) == 5 end),
								IsUnlocked = isWorldUnlocked(5),
								OnClick = function() selectedWorld:set(5) end,
							}),
						},
					},
					
					-- Stage grid
					New(scope, "Frame") {
						Name = "StageGrid",
						Size = UDim2.new(0, 540, 0, 100),
						Position = UDim2.new(0.5, 0, 0, 105),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.5,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 8),
							},
							
							New(scope, "UIListLayout") {
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 10),
							},
							
							New(scope, "UIPadding") {
								PaddingLeft = UDim.new(0, 10),
								PaddingRight = UDim.new(0, 10),
								PaddingTop = UDim.new(0, 10),
								PaddingBottom = UDim.new(0, 10),
							},
							
							-- Generate stage buttons
							ForValues(scope, worldStages, function(use, btnScope, config)
								local stageId = `{config.World}-{config.Level}`
								return StageButton(btnScope, {
									StageId = stageId,
									Config = config,
									IsSelected = Computed(btnScope, function(use2)
										return use2(selectedStage) == stageId
									end),
									OnClick = function()
										selectedStage:set(stageId)
									end,
								})
							end),
						},
					},
					
					-- Stage info panel
					New(scope, "Frame") {
						Name = "StageInfo",
						Size = UDim2.new(1, -30, 0, 180),
						Position = UDim2.new(0, 15, 0, 215),
						BackgroundColor3 = PvZTheme.Colors.WoodDark,
						BackgroundTransparency = 0.3,
						
						[Children] = {
							New(scope, "UICorner") {
								CornerRadius = UDim.new(0, 10),
							},
							
							-- Stage name header
							PvZTheme.StrokedText(scope, {
								Name = "StageName",
								Size = UDim2.new(1, 0, 0, 30),
								Position = UDim2.new(0, 0, 0, 10),
								Text = Computed(scope, function(use)
									local config = use(selectedConfig)
									if config then
										return `{config.World}-{config.Level}: {config.Name}`
									end
									return "Select a Stage"
								end),
								TextColor3 = PvZTheme.Colors.TextGold,
								TextSize = 22,
								Font = Enum.Font.GothamBold,
							}),
							
							-- Info grid
							New(scope, "Frame") {
								Name = "InfoGrid",
								Size = UDim2.new(1, -20, 0, 100),
								Position = UDim2.new(0, 10, 0, 45),
								BackgroundTransparency = 1,
								
								[Children] = {
									-- Left column - Wave info
									New(scope, "Frame") {
										Size = UDim2.new(0.5, -5, 1, 0),
										BackgroundTransparency = 1,
										
										[Children] = {
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 0, 22),
												Position = UDim2.new(0, 0, 0, 0),
												BackgroundTransparency = 1,
												Text = Computed(scope, function(use)
													local config = use(selectedConfig)
													return if config then `🌊 Waves: {config.WaveCount}` else ""
												end),
												TextSize = 16,
												Font = Enum.Font.GothamMedium,
												TextColor3 = PvZTheme.Colors.TextWhite,
												TextXAlignment = Enum.TextXAlignment.Left,
											},
											
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 0, 22),
												Position = UDim2.new(0, 0, 0, 25),
												BackgroundTransparency = 1,
												Text = Computed(scope, function(use)
													local config = use(selectedConfig)
													if not config then return "" end
													local diff = (config.ZombieHealthMult or 1) * (config.ZombieSpeedMult or 1)
													if diff >= 2 then return "💀 Difficulty: MASTER"
													elseif diff >= 1.5 then return "⚠️ Difficulty: HARD"
													elseif diff >= 1.2 then return "⚔️ Difficulty: MEDIUM"
													else return "✅ Difficulty: EASY"
													end
												end),
												TextSize = 16,
												Font = Enum.Font.GothamMedium,
												TextColor3 = PvZTheme.Colors.TextWhite,
												TextXAlignment = Enum.TextXAlignment.Left,
											},
											
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 0, 22),
												Position = UDim2.new(0, 0, 0, 50),
												BackgroundTransparency = 1,
												Text = Computed(scope, function(use)
													local config = use(selectedConfig)
													return if config then `☀️ Starting Sun: {config.SunStarting or 50}` else ""
												end),
												TextSize = 16,
												Font = Enum.Font.GothamMedium,
												TextColor3 = PvZTheme.Colors.TextWhite,
												TextXAlignment = Enum.TextXAlignment.Left,
											},
										},
									},
									
									-- Right column - Rewards
									New(scope, "Frame") {
										Size = UDim2.new(0.5, -5, 1, 0),
										Position = UDim2.new(0.5, 5, 0, 0),
										BackgroundTransparency = 1,
										
										[Children] = {
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 0, 22),
												Position = UDim2.new(0, 0, 0, 0),
												BackgroundTransparency = 1,
												Text = Computed(scope, function(use)
													local config = use(selectedConfig)
													return if config then `🪙 Coins: {config.CoinReward}` else ""
												end),
												TextSize = 16,
												Font = Enum.Font.GothamMedium,
												TextColor3 = PvZTheme.Colors.CoinGold,
												TextXAlignment = Enum.TextXAlignment.Left,
											},
											
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 0, 22),
												Position = UDim2.new(0, 0, 0, 25),
												BackgroundTransparency = 1,
												Text = Computed(scope, function(use)
													local config = use(selectedConfig)
													return if config then `⭐ XP: {config.XPReward}` else ""
												end),
												TextSize = 16,
												Font = Enum.Font.GothamMedium,
												TextColor3 = PvZTheme.Colors.XPPurple,
												TextXAlignment = Enum.TextXAlignment.Left,
											},
											
											New(scope, "TextLabel") {
												Size = UDim2.new(1, 0, 0, 22),
												Position = UDim2.new(0, 0, 0, 50),
												BackgroundTransparency = 1,
												Text = Computed(scope, function(use)
													local config = use(selectedConfig)
													local completedStages = use(PlayerDataClient.GetCompletedStagesValue())
													local stageId = use(selectedStage)
													local isFirstClear = (completedStages[stageId] or 0) == 0
													if config and isFirstClear and config.FirstClearBonus then
														return `🎁 First Clear: +{config.FirstClearBonus} coins`
													end
													return ""
												end),
												TextSize = 16,
												Font = Enum.Font.GothamMedium,
												TextColor3 = PvZTheme.Colors.SunYellow,
												TextXAlignment = Enum.TextXAlignment.Left,
											},
										},
									},
								},
							},
							
							-- Best score
							New(scope, "TextLabel") {
								Size = UDim2.new(1, -20, 0, 25),
								Position = UDim2.new(0, 10, 1, -30),
								BackgroundTransparency = 1,
								Text = Computed(scope, function(use)
									local completedStages = use(PlayerDataClient.GetCompletedStagesValue())
									local stageId = use(selectedStage)
									local stars = completedStages[stageId] or 0
									if stars > 0 then
										local starsText = string.rep("⭐", stars) .. string.rep("☆", 3 - stars)
										return `Best: {starsText}`
									else
										return "Not yet completed"
									end
								end),
								TextSize = 18,
								Font = Enum.Font.GothamBold,
								TextColor3 = PvZTheme.Colors.TextWhite,
								TextXAlignment = Enum.TextXAlignment.Center,
							},
						},
					},
					
					-- Play button
					PvZTheme.WoodButton(scope, {
						Size = UDim2.new(0, 200, 0, 50),
						Position = UDim2.new(0.5, 0, 1, -15),
						AnchorPoint = Vector2.new(0.5, 1),
						Text = Computed(scope, function(use)
							if use(isSelectedUnlocked) then
								return "▶️ PLAY"
							else
								return PvZTheme.Icons.Lock .. " LOCKED"
							end
						end),
						BackgroundColor = Computed(scope, function(use)
							return if use(isSelectedUnlocked) 
								then PvZTheme.Colors.GrassGreen 
								else PvZTheme.Colors.Disabled
						end),
						OnClick = function()
							if peek(isSelectedUnlocked) then
								local stageId = peek(selectedStage)
								Logger.Info("StageSelect", `Starting stage: {stageId}`)
								props.OnStartStage(stageId)
								props.OnClose()
							end
						end,
					}),
				},
			}),
		},
	}
end

return StageSelectUI
