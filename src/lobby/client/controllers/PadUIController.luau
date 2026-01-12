--!strict
--[[
    PadUIController.luau - Manages BillboardGui on teleport pads + Leave UI
    
    Responsibilities:
    - Create/update BillboardGui for each pad
    - Listen for PadStateUpdate from server
    - Display: World info, X/Y players, countdown, status
    - Show Leave button when player is on pad (TDS-style)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)

-- Network (unified Zap schema in shared/network)
local ZapClient = require(Shared.network.generated.client)

-- Import UI State Manager
local UIStateManager = require(script.Parent.UIStateManager)

local New = Fusion.New
local Children = Fusion.Children
local Computed = Fusion.Computed
local Value = Fusion.Value
local OnEvent = Fusion.OnEvent

-- Pad state tracking
type PadUIState = {
	PadId: string,
	Scope: any, -- Store scope to prevent garbage collection
	WorldId: Fusion.Value<string>,
	Difficulty: Fusion.Value<string>,
	PlayersCount: Fusion.Value<number>,
	MaxPlayers: Fusion.Value<number>,
	CountdownRemaining: Fusion.Value<number?>,
	IsLocked: Fusion.Value<boolean>,
	BillboardGui: BillboardGui?,
}

local _padStates: { [string]: PadUIState } = {}
local _scope = Fusion.scoped(Fusion)

-- Track if player is currently on a pad
local _isOnPad = Value(_scope, false)
local _currentPadId = Value(_scope, "")
local _currentWorldId = Value(_scope, "")
local _currentDifficulty = Value(_scope, "")
local _currentCountdown = Value(_scope, nil :: number?)
local _currentPlayerCount = Value(_scope, 0)
local _currentMaxPlayers = Value(_scope, 1)
local _leaveButtonUI: ScreenGui? = nil

local PadUIController = {}

-- Create BillboardGui for a pad (identical to existing BillBoardGui in workspace)
local function createPadUI(scope, state: PadUIState): BillboardGui
	return New(scope, "BillboardGui")({
		Name = "PadUI",
		Size = UDim2.new(8, 0, 8, 0), -- 8x8 studs like original
		StudsOffset = Vector3.new(0, 0, 0),
		AlwaysOnTop = false,
		MaxDistance = math.huge,

		[Children] = {
			-- Frame container
			New(scope, "Frame")({
				Name = "Frame",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,

				[Children] = {
					New(scope, "UIPadding")({
						PaddingTop = UDim.new(0.1, 0),
						PaddingBottom = UDim.new(0.1, 0),
						PaddingLeft = UDim.new(0.1, 0),
						PaddingRight = UDim.new(0.1, 0),
					}),

					-- Players label
					New(scope, "TextLabel")({
						Name = "players",
						Position = UDim2.new(0, 0, 0, 0),
						Size = UDim2.new(1, 0, 0.333, 0),
						BackgroundTransparency = 1,
						Text = Computed(scope, function(use)
							return `Players: {use(state.PlayersCount)}/{use(state.MaxPlayers)}`
						end),
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						Font = Enum.Font.SourceSansBold,
						TextSize = 100,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					-- Time label
					New(scope, "TextLabel")({
						Name = "time",
						Position = UDim2.new(0, 0, 0.333, 0),
						Size = UDim2.new(1, 0, 0.333, 0),
						BackgroundTransparency = 1,
						Text = Computed(scope, function(use)
							local countdown = use(state.CountdownRemaining) or 0
							return `Time: {math.ceil(countdown)}`
						end),
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						Font = Enum.Font.SourceSansBold,
						TextSize = 100,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					-- Status label
					New(scope, "TextLabel")({
						Name = "Status",
						Position = UDim2.new(0, 0, 0.666, 0),
						Size = UDim2.new(1, 0, 0.333, 0),
						BackgroundTransparency = 1,
						Text = Computed(scope, function(use)
							local countdown = use(state.CountdownRemaining) or 0
							local playerCount = use(state.PlayersCount)

							if countdown > 0 then
								return "TELEPORTING..."
							elseif playerCount > 0 then
								return "WAITING"
							else
								return "READY"
							end
						end),
						TextColor3 = Computed(scope, function(use)
							local countdown = use(state.CountdownRemaining) or 0
							local playerCount = use(state.PlayersCount)

							if countdown > 0 then
								return Color3.fromRGB(255, 200, 50) -- Yellow
							elseif playerCount > 0 then
								return Color3.fromRGB(255, 165, 0) -- Orange
							else
								return Color3.fromRGB(85, 255, 0) -- Green
							end
						end),
						TextScaled = true,
						Font = Enum.Font.SourceSansBold,
						TextSize = 100,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),
		},
	})
end

-- Update pad state from server
local function updatePadState(data: any)
	local padId = data.PadId
	local state = _padStates[padId]

	if not state then
		-- Create new state
		local scope = Fusion.scoped(Fusion)
		state = {
			PadId = padId,
			Scope = scope,
			WorldId = Value(scope, data.WorldId),
			Difficulty = Value(scope, data.Difficulty),
			PlayersCount = Value(scope, data.PlayersCount),
			MaxPlayers = Value(scope, data.MaxPlayers),
			CountdownRemaining = Value(scope, data.CountdownRemaining),
			IsLocked = Value(scope, false),
			BillboardGui = nil,
			ExistingGui = nil, -- Reference to existing BillBoardGui in workspace
		}
		_padStates[padId] = state

		-- Find pad model in workspace
		local workspace = game:GetService("Workspace")
		local lobbyTeleports = workspace:FindFirstChild("LobbyTeleports")
		local teleportPadsFolder = lobbyTeleports and lobbyTeleports:FindFirstChild("Workspace")

		if teleportPadsFolder then
			local padModel = teleportPadsFolder:FindFirstChild(padId)

			if padModel and padModel:IsA("Model") then
				-- Look for existing BillBoardGui in the gate
				local existingGui = padModel:FindFirstChild("BillBoardGui", true)
				if existingGui and existingGui:IsA("BillboardGui") then
					state.ExistingGui = existingGui
					Logger.Info("PadUI", `Using existing BillBoardGui for pad {padId}`)
				else
					-- No existing GUI, create one
					local attachPart = padModel:FindFirstChild("Billboard", true)
					if not attachPart or not attachPart:IsA("BasePart") then
						attachPart = padModel:FindFirstChild("Platform", true)
					end

					if attachPart and attachPart:IsA("BasePart") then
						local gui = createPadUI(scope, state)
						gui.Adornee = attachPart
						gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
						state.BillboardGui = gui
						Logger.Info("PadUI", `Created UI for pad {padId}`)
					end
				end
			else
				Logger.Warn("PadUI", `Could not find pad model: {padId}`)
			end
		else
			Logger.Warn("PadUI", "LobbyTeleports/Workspace folder not found")
		end
	end

	-- Update state values
	state.WorldId:set(data.WorldId)
	state.Difficulty:set(data.Difficulty)
	state.PlayersCount:set(data.PlayersCount)
	state.MaxPlayers:set(data.MaxPlayers)
	state.CountdownRemaining:set(data.CountdownRemaining)

	-- Update existing GUI labels if present
	if state.ExistingGui then
		local frame = state.ExistingGui:FindFirstChild("Frame")
		if frame then
			local playersLabel = frame:FindFirstChild("players")
			local timeLabel = frame:FindFirstChild("time")
			local statusLabel = frame:FindFirstChild("Status")

			if playersLabel then
				playersLabel.Text = `Players: {data.PlayersCount}/{data.MaxPlayers}`
			end
			if timeLabel then
				timeLabel.Text = `Time: {math.ceil(data.CountdownRemaining or 0)}`
			end
			if statusLabel then
				if data.CountdownRemaining and data.CountdownRemaining > 0 then
					statusLabel.Text = "TELEPORTING..."
					statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
				elseif data.PlayersCount > 0 then
					statusLabel.Text = "WAITING"
					statusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
				else
					statusLabel.Text = "READY"
					statusLabel.TextColor3 = Color3.fromRGB(85, 255, 0)
				end
			end
		end
	end

	-- Also update current pad info if this is the pad we're on
	if Fusion.peek(_isOnPad) and data.PadId == Fusion.peek(_currentPadId) then
		_currentCountdown:set(data.CountdownRemaining)
		_currentPlayerCount:set(data.PlayersCount)
		_currentMaxPlayers:set(data.MaxPlayers)
	end
end

-- Create Leave Button UI (shown when player is on a pad)
local function createLeaveButtonUI(): ScreenGui
	local worldConfig = Computed(_scope, function(use)
		local worldId = use(_currentWorldId)
		return WorldData.GetWorld(worldId)
	end)

	local difficultyConfig = Computed(_scope, function(use)
		local difficulty = use(_currentDifficulty)
		return DifficultyData.GetDifficulty(difficulty)
	end)

	return New(_scope, "ScreenGui")({
		Name = "PadLeaveUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Children] = {
			-- Container for Leave UI (centered bottom)
			New(_scope, "Frame")({
				Name = "Container",
				Size = UDim2.new(0, 300, 0, 150),
				Position = UDim2.new(0.5, -150, 1, -180),
				BackgroundColor3 = Color3.fromRGB(139, 90, 43),
				BorderSizePixel = 0,
				Visible = Computed(_scope, function(use)
					return use(_isOnPad)
				end),

				[Children] = {
					New(_scope, "UICorner")({
						CornerRadius = UDim.new(0, 16),
					}),

					New(_scope, "UIStroke")({
						Color = Color3.fromRGB(101, 67, 33),
						Thickness = 4,
					}),

					-- World + Difficulty name
					New(_scope, "TextLabel")({
						Size = UDim2.new(1, -20, 0, 40),
						Position = UDim2.new(0, 10, 0, 10),
						BackgroundTransparency = 1,
						Text = Computed(_scope, function(use)
							local world = use(worldConfig)
							local diff = use(difficultyConfig)
							if world and diff then
								return `🌿 {world.Name} ({diff.Name})`
							end
							return "Loading..."
						end),
						TextSize = 22,
						TextScaled = false,
						Font = Enum.Font.GothamBlack,
						TextColor3 = Color3.fromRGB(255, 215, 0),
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					-- Info text
					New(_scope, "TextLabel")({
						Size = UDim2.new(1, -20, 0, 28),
						Position = UDim2.new(0, 10, 0, 52),
						BackgroundTransparency = 1,
						Text = Computed(_scope, function(use)
							local countdown = use(_currentCountdown)
							local playerCount = use(_currentPlayerCount)
							local maxPlayers = use(_currentMaxPlayers)

							if countdown and countdown > 0 then
								return `Teleporting in {math.ceil(countdown)} seconds`
							elseif playerCount >= maxPlayers then
								return "🚀 Ready to teleport!"
							else
								return `Waiting for players... ({playerCount}/{maxPlayers})`
							end
						end),
						TextSize = 16,
						TextScaled = false,
						Font = Enum.Font.Gotham,
						TextColor3 = Computed(_scope, function(use)
							local countdown = use(_currentCountdown)
							if countdown and countdown > 0 then
								return Color3.fromRGB(255, 200, 50) -- Yellow
							else
								return Color3.fromRGB(255, 255, 255)
							end
						end),
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					-- Leave Button
					New(_scope, "TextButton")({
						Name = "LeaveButton",
						Size = UDim2.new(0, 120, 0, 40),
						Position = UDim2.new(0.5, -60, 1, -55),
						BackgroundColor3 = Color3.fromRGB(200, 60, 60),
						Text = "Leave",
						TextSize = 18,
						TextScaled = false,
						Font = Enum.Font.GothamBold,
						TextColor3 = Color3.fromRGB(255, 255, 255),

						[OnEvent("Activated")] = function()
							Logger.Info("PadUI", "Leave button clicked")
							ZapClient.LeavePadRequest.Fire({})
						end,

						[Children] = {
							New(_scope, "UICorner")({
								CornerRadius = UDim.new(0, 8),
							}),
						},
					}),
				},
			}),
		},
	})
end

-- Handle PadJoined event
local function onPadJoined(data: any)
	Logger.Info("PadUI", `Joined pad {data.PadId} (World: {data.WorldId}, Difficulty: {data.Difficulty})`)
	_currentPadId:set(data.PadId)
	_currentWorldId:set(data.WorldId)
	_currentDifficulty:set(data.Difficulty)
	_isOnPad:set(true)

	-- Hide other GUIs when in queue
	UIStateManager.SetQueueMode(true)
end

-- Handle PadLeft event
local function onPadLeft(_data: any)
	Logger.Info("PadUI", "Left pad")
	_isOnPad:set(false)
	_currentPadId:set("")
	_currentWorldId:set("")
	_currentDifficulty:set("")
	_currentCountdown:set(nil)
	_currentPlayerCount:set(0)
	_currentMaxPlayers:set(1)

	-- Show other GUIs when leaving queue
	UIStateManager.SetQueueMode(false)
end

-- Initialize
function PadUIController.Initialize()
	Logger.Info("PadUI", "PadUIController initialized")

	-- Listen for pad state updates
	ZapClient.PadStateUpdate.On(updatePadState)

	-- Listen for join/leave pad events
	ZapClient.PadJoined.On(onPadJoined)
	ZapClient.PadLeft.On(onPadLeft)

	-- Create Leave button UI
	_leaveButtonUI = createLeaveButtonUI()
	_leaveButtonUI.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return PadUIController
