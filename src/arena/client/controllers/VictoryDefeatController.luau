--!strict
--[[
	VictoryDefeatController.luau - End-game results screen controller
	
	Listens to GameSignals.OnBattleEnded and shows the ResultScreen.
	Handles animation sequencing and teleport countdown.
	
	Follows Atomic Design: Controller → Organisms → Molecules → Atoms
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local GameSignals = require(Shared.signals.GameSignals)
local TeleportData = require(Shared.data.TeleportData)

local UIComponents = script.Parent.Parent.ui.components
local Organisms = UIComponents.organisms
local ResultScreen = require(Organisms.ResultScreen)

-- Audio service (lazy loaded)
local _audioService: any = nil
local function getAudioService()
	if not _audioService then
		local Client = script.Parent.Parent
		local Modules = Client:WaitForChild("modules")
		local success, result = pcall(function()
			return require(Modules.AudioService)
		end)
		if success then
			_audioService = result
		end
	end
	return _audioService
end

-- Types
export type RewardsData = {
	Victory: boolean,
	WaveReached: number,
	StarRating: number,
	CoinsEarned: number,
	XPEarned: number,
	GemsEarned: number,
	ZombiesKilled: number,
	BonusCoins: number?,
	NewLevel: number?,
	LevelsGained: number?,
	IsFirstClear: boolean?,
	IsNewBest: boolean?,
}

-- Constants
local COUNTER_DURATION = 0.6
local TELEPORT_COUNTDOWN = 10

local VictoryDefeatController = {}
VictoryDefeatController.__index = VictoryDefeatController

function VictoryDefeatController.new()
	local self = setmetatable({}, VictoryDefeatController)

	self._scope = Fusion.scoped({})
	self._trove = Trove.new()

	-- State
	self._visible = Fusion.Value(self._scope, false)
	self._victory = Fusion.Value(self._scope, false)
	self._waveReached = Fusion.Value(self._scope, 0)
	self._starCount = Fusion.Value(self._scope, 0)

	-- Animated display values
	self._displayCoins = Fusion.Value(self._scope, 0)
	self._displayXP = Fusion.Value(self._scope, 0)
	self._displayGems = Fusion.Value(self._scope, 0)
	self._displayZombies = Fusion.Value(self._scope, 0)

	-- Target values
	self._targetStars = 0
	self._targetCoins = 0
	self._targetXP = 0
	self._targetGems = 0
	self._targetZombies = 0

	-- Teleport
	self._teleportCountdown = Fusion.Value(self._scope, 0)

	-- Animation state
	self._animating = false
	self._gui = nil :: ScreenGui?

	return self
end

--[[
	Animate a counter from current to target value
]]
function VictoryDefeatController:_animateCounter(valueObj: any, target: number, duration: number)
	local startValue = Fusion.peek(valueObj)
	local startTime = tick()

	task.spawn(function()
		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			-- Ease out quad
			local easedProgress = 1 - (1 - progress) * (1 - progress)
			local current = math.floor(startValue + (target - startValue) * easedProgress)
			valueObj:set(current)
			task.wait()
		end
		valueObj:set(target)
	end)
end

--[[
	Animate stars appearing one by one
]]
function VictoryDefeatController:_animateStars(count: number)
	local audio = getAudioService()

	-- Sequential star reveal
	for i = 1, 3 do
		task.delay(0.4 + (i - 1) * 0.4, function()
			if i <= count then
				self._starCount:set(i)
				if audio then
					pcall(function()
						audio.PlayStarEarned()
					end)
				end
			end
		end)
	end
end

--[[
	Start teleport countdown
]]
function VictoryDefeatController:_startTeleportCountdown()
	task.spawn(function()
		for i = TELEPORT_COUNTDOWN, 0, -1 do
			self._teleportCountdown:set(i)
			if i == 0 then
				self:_teleportToLobby()
			else
				task.wait(1)
			end
		end
	end)
end

--[[
	Teleport player back to lobby
]]
function VictoryDefeatController:_teleportToLobby()
	Logger.Info("VictoryDefeat", "Teleporting to lobby...")
	local player = Players.LocalPlayer
	if player then
		pcall(function()
			TeleportService:Teleport(TeleportData.PlaceIds.Lobby, player)
		end)
	end
end

--[[
	Return to lobby manually
]]
function VictoryDefeatController:_onReturnToLobby()
	self:_teleportToLobby()
end

--[[
	Show the screen with rewards data
]]
function VictoryDefeatController:Show(data: RewardsData)
	if self._animating then
		return
	end
	self._animating = true

	Logger.Info("VictoryDefeat", `Showing {if data.Victory then "VICTORY" else "DEFEAT"} screen`)

	-- Set static values
	self._victory:set(data.Victory)
	self._waveReached:set(data.WaveReached)

	-- Store targets
	self._targetStars = data.StarRating
	self._targetCoins = data.CoinsEarned
	self._targetXP = data.XPEarned
	self._targetGems = data.GemsEarned
	self._targetZombies = data.ZombiesKilled

	-- Reset display values
	self._displayCoins:set(0)
	self._displayXP:set(0)
	self._displayGems:set(0)
	self._displayZombies:set(0)
	self._starCount:set(0)
	self._teleportCountdown:set(0)

	-- Show overlay
	self._visible:set(true)

	-- Play sound
	local audio = getAudioService()
	if audio then
		pcall(function()
			if data.Victory then
				audio.PlayVictory()
			else
				audio.PlayDefeat()
			end
		end)
	end

	-- Start animation sequence
	task.spawn(function()
		-- Wait for panel entrance
		task.wait(0.3)

		-- Animate stars (victory only)
		if data.Victory then
			self:_animateStars(data.StarRating)
		end

		-- Wait then animate counters
		task.wait(0.8)

		-- Zombies killed (fast)
		self:_animateCounter(self._displayZombies, data.ZombiesKilled, 0.4)
		task.wait(0.3)

		-- Coins (medium speed)
		self:_animateCounter(self._displayCoins, data.CoinsEarned, COUNTER_DURATION)
		if audio then
			pcall(function()
				audio.PlayCoinCount()
			end)
		end
		task.wait(0.3)

		-- XP
		self:_animateCounter(self._displayXP, data.XPEarned, COUNTER_DURATION)
		task.wait(0.3)

		-- Gems (if any)
		if data.GemsEarned > 0 then
			self:_animateCounter(self._displayGems, data.GemsEarned, 0.4)
		end

		-- Start teleport countdown after animations
		task.wait(1)
		self:_startTeleportCountdown()

		self._animating = false
	end)
end

--[[
	Hide the screen
]]
function VictoryDefeatController:Hide()
	self._visible:set(false)
	self._animating = false
end

--[[
	Initialize and mount the GUI
]]
function VictoryDefeatController:Init()
	local player = Players.LocalPlayer
	if not player then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	-- Create ScreenGui
	self._gui = Fusion.New(self._scope, "ScreenGui")({
		Name = "VictoryDefeatScreen",
		Parent = playerGui,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			ResultScreen({
				Scope = self._scope,
				Visible = self._visible,
				Victory = self._victory,
				WaveReached = self._waveReached,
				StarCount = self._starCount,
				CoinsEarned = self._displayCoins,
				XPEarned = self._displayXP,
				GemsEarned = self._displayGems,
				ZombiesKilled = self._displayZombies,
				TeleportCountdown = self._teleportCountdown,
				OnReturnToLobby = function()
					self:_onReturnToLobby()
				end,
			}),
		},
	})

	-- Connect to battle ended signal
	self._trove:Connect(GameSignals.OnBattleEnded, function(rewardsData: RewardsData)
		self:Show(rewardsData)
	end)

	Logger.Info("VictoryDefeat", "Controller initialized")
end

--[[
	Cleanup
]]
function VictoryDefeatController:Destroy()
	self._trove:Destroy()
	Fusion.doCleanup(self._scope)

	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

return VictoryDefeatController
