--!strict
--[[
	Utils Index - Central registry for all utility modules
	
	ORGANIZATION:
	├── core/       Fundamental utilities (Logger, Math, Chance, Error)
	├── ecs/        ECS and Matter utilities (EntityPool, LaneCache, SystemManager)
	├── grid/       Grid and spatial utilities (GridUtils, GridDetection, Attachments)
	├── combat/     Combat utilities (DamageModifiers, Validation, PlantStats)
	├── network/    Network utilities (NetworkUtils, ServiceLoader)
	└── vfx/        Visual effects utilities (VFXUtils)
	
	USAGE (recommended - direct require):
		local Logger = require(Shared.utils.core.Logger)
		local ECSUtils = require(Shared.utils.ecs.ECSUtils)
	
	USAGE (legacy - via index):
		local Utils = require(Shared.utils)
		local Logger = Utils.Logger
]]

local Utils = script

-- Subfolders
local Core = Utils.core
local ECS = Utils.ecs
local Grid = Utils.grid
local Combat = Utils.combat
local Network = Utils.network
local VFX = Utils.vfx

return {
	-- ============================================
	-- CORE UTILITIES
	-- ============================================
	Logger = require(Core.Logger),
	ErrorHandler = require(Core.ErrorHandler),
	MathUtils = require(Core.MathUtils),
	ChanceUtils = require(Core.ChanceUtils),
	
	-- ============================================
	-- ECS UTILITIES
	-- ============================================
	ECSUtils = require(ECS.ECSUtils),
	EntityPool = require(ECS.EntityPool),
	LaneCache = require(ECS.LaneCache),
	SystemManager = require(ECS.SystemManager),
	
	-- ============================================
	-- GRID UTILITIES
	-- ============================================
	GridUtils = require(Grid.GridUtils),
	GridDetection = require(Grid.GridDetection),
	AttachmentUtils = require(Grid.AttachmentUtils),
	
	-- ============================================
	-- COMBAT UTILITIES
	-- ============================================
	DamageModifierRegistry = require(Combat.DamageModifierRegistry),
	ValidationMiddleware = require(Combat.ValidationMiddleware),
	PlantStatsHelper = require(Combat.PlantStatsHelper),
	
	-- ============================================
	-- NETWORK UTILITIES
	-- ============================================
	NetworkUtils = require(Network.NetworkUtils),
	ServiceLoader = require(Network.ServiceLoader),
	
	-- ============================================
	-- VFX UTILITIES
	-- ============================================
	VFXUtils = require(VFX.VFXUtils),
}
