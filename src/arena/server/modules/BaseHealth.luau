--!strict
--[[
	BaseHealth.luau - Server module for tracking base/lawn health
	
	The player's house has HP that decreases when zombies reach it.
	When HP reaches 0, the game is over (defeat).
	
	This is a module (not a system) so multiple systems can access it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

-- Network
local Network = require(Shared.network.generated.server)

-- Configuration
local Config = {
	MAX_HEALTH = 1000,
	ZOMBIE_DAMAGE = 100, -- Damage per zombie that reaches house
}

-- State
local _currentHealth = Config.MAX_HEALTH
local _isDefeated = false
local _damageEventCount = 0 -- Track how many times base was hit (for star rating)

local BaseHealth = {}

function BaseHealth.GetHealth(): number
	return _currentHealth
end

function BaseHealth.GetMaxHealth(): number
	return Config.MAX_HEALTH
end

function BaseHealth.IsDefeated(): boolean
	return _isDefeated
end

function BaseHealth.TakeDamage(amount: number)
	if _isDefeated then
		return
	end

	local oldHealth = _currentHealth
	_currentHealth = math.max(0, _currentHealth - amount)
	_damageEventCount += 1 -- Track damage events for star rating

	Logger.Warn("BaseHealth", `Base took {amount} damage! ({oldHealth} -> {_currentHealth}/{Config.MAX_HEALTH})`)

	-- Broadcast to clients
	Network.BaseHealthUpdated.FireAll({
		CurrentHealth = _currentHealth,
		MaxHealth = Config.MAX_HEALTH,
		DamageAmount = amount,
	})

	-- Check for defeat
	if _currentHealth <= 0 and not _isDefeated then
		_isDefeated = true
		Logger.Error("BaseHealth", "💀 BASE DESTROYED - DEFEAT!")

		-- Broadcast game over
		Network.GameOver.FireAll({
			Victory = false,
			WaveReached = 0, -- Will be set by WaveManager
		})
	end
end

function BaseHealth.OnZombieReachedHouse()
	BaseHealth.TakeDamage(Config.ZOMBIE_DAMAGE)
end

-- Star Rating System
-- 3 stars: No damage taken (perfect run)
-- 2 stars: 1-2 damage events (lawn mowers used)
-- 1 star: 3+ damage events (survived)
function BaseHealth.GetStarRating(): number
	if _damageEventCount == 0 then
		return 3
	elseif _damageEventCount <= 2 then
		return 2
	else
		return 1
	end
end

function BaseHealth.GetDamageEventCount(): number
	return _damageEventCount
end

function BaseHealth.Reset()
	_currentHealth = Config.MAX_HEALTH
	_isDefeated = false
	_damageEventCount = 0 -- Reset damage tracking

	Logger.Info("BaseHealth", `Base health reset to {Config.MAX_HEALTH}`)

	-- Broadcast initial state
	Network.BaseHealthUpdated.FireAll({
		CurrentHealth = _currentHealth,
		MaxHealth = Config.MAX_HEALTH,
		DamageAmount = 0,
	})
end

return BaseHealth
