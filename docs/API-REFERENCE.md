---
title: 'API Reference'
project: 'plant-vs-zombie'
date: '2026-01-12'
version: '2.0'
purpose: 'Document all service APIs to prevent call mismatches'
status: 'Post-Refactoring V2 - All services use isolated state pattern'
---

# API Reference: Services & Managers

This document lists all public functions for each service module to prevent calling non-existent functions.

---

## PlayerDataService (Arena)

**Location:** `src/arena/server/services/PlayerDataService.luau`

### Profile Management
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize()` | - | `void` | Initializes ProfileStore and player connections |
| `GetProfile(player)` | `Player` | `ProfileData?` | Get player's full profile data |

### Currency: Coins
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetCoins(player)` | `Player` | `number` | Get current coins |
| `AddCoins(player, amount)` | `Player, number` | `boolean` | Add coins |
| `SpendCoins(player, amount)` | `Player, number` | `boolean` | Spend coins (fails if insufficient) |

### Currency: Gems
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetGems(player)` | `Player` | `number` | Get current gems |
| `AddGems(player, amount)` | `Player, number` | `boolean` | Add gems |
| `SpendGems(player, amount)` | `Player, number` | `boolean` | Spend gems (fails if insufficient) |

### XP & Leveling
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetXP(player)` | `Player` | `number` | Get total XP |
| `GetLevel(player)` | `Player` | `number` | Get current level |
| `AddXP(player, amount)` | `Player, number` | `number` | Add XP, returns levels gained |
| `GetLevelProgress(player)` | `Player` | `number` | Get 0-1 progress to next level |

### Plants & Unlocks
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `IsPlantUnlocked(player, plantType)` | `Player, string` | `boolean` | Check if plant is unlocked |
| `GetUnlockedPlants(player)` | `Player` | `{string}` | Get list of unlocked plant types |
| `UnlockPlant(player, plantType)` | `Player, string` | `boolean, string?` | Unlock plant (spends coins) |

### Plant Mutations
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetPlantMutations(player, plantType)` | `Player, string` | `{string}` | Get mutations for a plant |
| `HasMutation(player, plantType, mutationType)` | `Player, string, string` | `boolean` | Check if plant has mutation |
| `PurchaseMutation(player, plantType, mutationType)` | `Player, string, string` | `boolean, string?` | Buy mutation |
| `RemoveMutation(player, plantType, mutationType)` | `Player, string, string` | `boolean` | Remove mutation |

### Deck Management
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetDeck(player)` | `Player` | `{string}` | Get current deck |
| `SaveDeck(player, deck)` | `Player, {string}` | `boolean, string?` | Save deck (validates unlocks) |

### Stage Progression
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetCurrentStage(player)` | `Player` | `string` | Get last selected stage |
| `SetCurrentStage(player, stageId)` | `Player, string` | `boolean` | Set current stage |
| `GetCompletedStages(player)` | `Player` | `{[string]: number}` | Get all completed stages with stars |
| `GetStageStars(player, stageId)` | `Player, string` | `number` | Get stars for specific stage |
| `CompleteStage(player, stageId, stars)` | `Player, string, number` | `boolean, boolean` | Complete stage (isFirstClear, isNewBest) |

### Statistics
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `IncrementStat(player, statName, amount)` | `Player, string, number` | `boolean` | Increment a stat |
| `GetStats(player)` | `Player` | `StatsTable?` | Get all stats |

---

## PlayerDataService (Lobby)

**Location:** `src/lobby/server/services/PlayerDataService.luau`

⚠️ **Note:** This is a SIMPLIFIED version for the Lobby place. It shares the same ProfileStore but has fewer functions.

### Profile Management
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize()` | - | `void` | Initializes ProfileStore |
| `LoadProfile(player)` | `Player` | `void` | Load player profile |
| `ReleaseProfile(player)` | `Player` | `void` | Release profile on leave |
| `GetProfile(player)` | `Player` | `Profile?` | Get raw profile object |
| `GetData(player)` | `Player` | `ProfileData?` | Get profile data |

### Deck Management
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetDeck(player)` | `Player` | `{string}?` | Get current deck |
| `SetDeck(player, deck)` | `Player, {string}` | `boolean` | Save deck |

### Stage Progression
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `CompleteStage(player, stageId, stars)` | `Player, string, number` | `boolean, boolean` | Mark stage complete |
| `GetStageStars(player, stageId)` | `Player, string` | `number` | Get stars for stage |

### Currency
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetCoins(player)` | `Player` | `number` | Get current coins |
| `AddCoins(player, amount)` | `Player, number` | `boolean` | Add coins |

### XP/Level
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetLevel(player)` | `Player` | `number` | Get current level |
| `GetXP(player)` | `Player` | `number` | Get total XP |
| `AddXP(player, amount)` | `Player, number` | `number` | Add XP, returns levels gained |

---

## ArenaService

**Location:** `src/arena/server/services/ArenaService.luau`

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize(world, loop)` | `Matter.World, Matter.Loop` | `void` | Initialize with ECS world |
| `StartBattle(player, stageId, deck)` | `Player, string, {string}` | `void` | Start a battle |
| `EndBattle(player, victory)` | `Player, boolean` | `void` | End the current battle |
| `GetPlayerState(player)` | `Player` | `PlayerState?` | Get current battle state |

---

## WaveService

**Location:** `src/arena/server/services/WaveService.luau`

Manages game state and wave progression. Decoupled from WaveManagerSystem (service owns state, system runs ECS loop).

### Game State
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetGameState()` | - | `GameState` | Get current game state (`"Idle"`, `"Preparation"`, `"Playing"`, `"Victory"`, `"Defeat"`) |
| `SetGameState(state)` | `GameState` | `void` | Set game state (triggers `handleGameEnd` on Victory/Defeat) |
| `IsPlaying()` | - | `boolean` | Check if game is in Playing state |
| `IsGameOver()` | - | `boolean` | Check if game ended (Victory or Defeat) |
| `CanStartGame()` | - | `boolean` | Check if game can be started |
| `IsDay()` | - | `boolean` | Check if current world is daytime (from WorldConfig.Mechanics) |

### Wave Management
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetCurrentWave()` | - | `number` | Get current wave number |
| `GetTotalWaves()` | - | `number` | Get total waves in level |
| `StartGame(worldId?, difficulty?)` | `string?, string?` | `boolean` | Start a new game with world/difficulty config |
| `StartWaves()` | - | `boolean` | Transition from Preparation to Playing state |
| `ResetGameState()` | - | `void` | Reset all wave state for new game |
| `OnZombieDied()` | - | `void` | Hook called by EntityDeathSystem |

### Auto-Start
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `SetAutoStart(enabled)` | `boolean` | `void` | Enable/disable auto-start waves |
| `GetAutoStartEnabled()` | - | `boolean` | Check if auto-start is enabled |

### Configuration
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetCurrentWorldId()` | - | `string` | Get current world ID |
| `GetCurrentDifficulty()` | - | `string` | Get current difficulty ID |
| `GetCurrentWorldConfig()` | - | `WorldConfig?` | Get current world configuration |
| `GetCurrentDifficultyConfig()` | - | `DifficultyConfig?` | Get current difficulty configuration |

### Internal (WaveManagerSystem)
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetState()` | - | `State` | Get internal state table (for WaveManagerSystem) |
| `GetSpawner()` | - | `WaveSpawner?` | Get spawner manager instance |
| `GetBroadcaster()` | - | `WaveBroadcaster?` | Get broadcaster manager instance |
| `GetPlantFoodService()` | - | `PlantFoodService` | Get PlantFoodService (lazy loaded) |
| `IsStudioDebug()` | - | `boolean` | Check if running in Studio |

---

## SunService

**Location:** `src/arena/server/services/SunService.luau`

Manages player sun economy. Auto-initializes on first API call.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetSun(player)` | `Player` | `number` | Get player's current sun (0 if not tracked) |
| `AddSun(player, amount)` | `Player, number` | `void` | Add sun to player (can be negative) |
| `SpendSun(player, amount)` | `Player, number` | `boolean` | Spend sun (returns false if insufficient) |
| `SetSun(player, amount)` | `Player, number` | `void` | Set sun to specific amount (min 0) |
| `ResetPlayer(player)` | `Player` | `void` | Reset player to starting sun (50) |
| `BroadcastSunUpdate(player, sunEntityId?)` | `Player, number?` | `void` | Sync sun to client via network |
| `Dispose()` | - | `void` | Clean up and reset state |

**Starting Sun:** 50 (configured in service)

---

## MutationService

**Location:** `src/arena/server/services/MutationService.luau`

Manages player mutation cache for combat bonuses. Stateful singleton.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `LoadPlayerMutations(userId, mutations)` | `number, {[string]: {string}}` | `void` | Load mutations from teleport data |
| `LoadMutationsFromProfile(player, profileData)` | `Player, any` | `void` | Load mutations from profile (Studio debug mode) |
| `ClearPlayerMutations(userId)` | `number` | `void` | Clear cache on leave |
| `GetPlayerMutations(userId)` | `number` | `{[string]: {string}}` | Get all mutations for player (PlantType -> {MutationIds}) |
| `GetPlantMutations(userId, plantType)` | `number, string` | `{string}` | Get mutations for specific plant |
| `Dispose()` | - | `void` | Clear all caches |

---

## PlantFoodService

**Location:** `src/arena/server/services/PlantFoodService.luau`

Manages Plant Food charges and glowing zombie spawning. Auto-initializes on first API call.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetCharges(player)` | `Player` | `number` | Get current Plant Food charges (0-3) |
| `AddCharge(player, amount?)` | `Player, number?` | `number` | Add charge(s) capped at MAX_CHARGES, returns new total |
| `UseCharge(player)` | `Player` | `boolean` | Use one charge (returns false if none available) |
| `ShouldZombieBeGlowing()` | - | `boolean` | Check if next zombie should be glowing (guaranteed first per wave, then random) |
| `ResetWaveTracking()` | - | `void` | Reset glowing spawn tracker for new wave |
| `Dispose()` | - | `void` | Clean up and reset state |

**Config:** Uses `GameConstants.PlantFood` for MAX_CHARGES, GUARANTEED_PER_WAVE, GLOWING_ZOMBIE_CHANCE

---

## StatsService

**Location:** `src/arena/server/services/StatsService.luau`

Manages session statistics (reset each game). Requires explicit `Initialize()` call.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize()` | - | `void` | Initialize service (call once at arena start) |
| `GetSessionStats(player)` | `Player` | `SessionStats` | Get session stats (creates default if not exists) |
| `AddZombieKill(player, count?)` | `Player, number?` | `void` | Increment zombie kill count (default 1) |
| `AddCoinsEarned(player, amount)` | `Player, number` | `void` | Add coins earned this session |
| `AddPlantPlaced(player, count?)` | `Player, number?` | `void` | Increment plants placed (default 1) |
| `ResetSessionStats(player)` | `Player` | `void` | Reset stats for one player to zeros |
| `ResetAllSessionStats()` | - | `void` | Reset stats for all tracked players |
| `Dispose()` | - | `void` | Clean up trove and reset state |

### SessionStats Type
```lua
type SessionStats = {
    ZombiesKilled: number,
    CoinsEarned: number,
    PlantsPlaced: number,
}
```

---

## LobbyService

**Location:** `src/lobby/server/services/LobbyService.luau`

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize(zapServer)` | `ZapServer` | `void` | Initialize with Zap |

---

## TeleportData

**Location:** `src/shared/data/TeleportData.luau`

### Types
```lua
type ArenaJoinData = {
    WorldId: string,       -- "day", "night", "pool", "fog", "roof", "boss"
    Difficulty: string,    -- "easy", "normal", "hard", "nightmare", "endless"
    Deck: {string},
    Timestamp: number,
}

type LobbyReturnData = {
    WorldId: string,
    Difficulty: string,
    Victory: boolean,
    WavesSurvived: number,
    CoinsEarned: number,
    XPEarned: number,
    Timestamp: number,
}
```

### Functions
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `ValidateArenaJoinData(data)` | `any` | `boolean, string?` | Validate teleport data to Arena |
| `ValidateLobbyReturnData(data)` | `any` | `boolean, string?` | Validate return data to Lobby |
| `CreateArenaJoinData(worldId, difficulty, deck)` | `string, string, {string}` | `ArenaJoinData` | Create teleport data |
| `CreateLobbyReturnData(worldId, difficulty, victory, waves, coins, xp)` | `...` | `LobbyReturnData` | Create return data |

---

## WorldData (NEW)

**Location:** `src/shared/data/WorldData.luau`

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetAllWorlds()` | - | `{WorldConfig}` | Get all worlds sorted by order |
| `GetWorld(worldId)` | `string` | `WorldConfig?` | Get a specific world |
| `IsUnlocked(worldId, playerLevel)` | `string, number` | `boolean` | Check if world is unlocked for player level |
| `GetUnlockedWorlds(playerLevel)` | `number` | `{WorldConfig}` | Get all unlocked worlds |

### WorldConfig Type
```lua
{
    Id: string,            -- "day", "night", "pool", etc.
    Name: string,
    Description: string,
    MapId: string,
    IsNight: boolean,
    HasWater: boolean,
    HasFog: boolean,
    IsRoof: boolean,
    ZombiePool: {string},
    SunStarting: number,
    RequiredLevel: number?, -- nil = unlocked from start
}
```

---

## DifficultyData (NEW)

**Location:** `src/shared/data/DifficultyData.luau`

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetAll()` | - | `{DifficultyConfig}` | Get all difficulties sorted |
| `GetDifficulty(difficultyId)` | `string` | `DifficultyConfig?` | Get a specific difficulty |
| `CalculateEndlessRewards(wavesSurvived)` | `number` | `number, number` | Calculate coins & XP for endless mode |
| `GetEndlessMultipliers(waveNumber)` | `number` | `number, number, number` | Get health/speed/damage multipliers |

### DifficultyConfig Type
```lua
{
    Id: string,            -- "easy", "normal", "hard", "nightmare", "endless"
    Name: string,
    WaveCount: number,
    BaseBudget: number,
    BudgetPerWave: number,
    ZombieHealthMult: number,
    ZombieSpeedMult: number,
    CoinReward: number,
    XPReward: number,
    HasBoss: boolean,
}
```

---

## CosmeticData (NEW)

**Location:** `src/shared/data/CosmeticData.luau`

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetSkinsForPlant(plantType)` | `string` | `{PlantSkin}` | Get all skins for a plant |
| `GetSkin(skinId)` | `string` | `PlantSkin?` | Get a specific skin |
| `GetAllSkins()` | - | `{PlantSkin}` | Get all skins |
| `GetAllTrails()` | - | `{TrailEffect}` | Get all projectile trails |
| `GetTrail(trailId)` | `string` | `TrailEffect?` | Get a specific trail |
| `GetRarityColor(rarity)` | `SkinRarity` | `Color3` | Get color for rarity tier |
| `CanPurchase(skinId, playerLevel)` | `string, number` | `boolean` | Check level requirement |

---

## ⚠️ DEPRECATED: StageRegistry

**Location:** `src/shared/data/stages/StageRegistry.luau`

> **This module is deprecated.** Use `WorldData` + `DifficultyData` instead.
> The old stage system (1-1, 1-2, etc.) has been replaced with World + Difficulty selection.

---

## GridService

**Location:** `src/arena/server/services/GridService.luau`

Server-authoritative grid occupancy tracking singleton. Single source of truth for plant placement.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `IsOccupied(column, lane)` | `number, number` | `boolean` | Check if cell has a plant |
| `GetEntityAt(column, lane)` | `number, number` | `number?` | Get entity ID at cell |
| `GetEntity(column, lane)` | `number, number` | `number?` | Alias for GetEntityAt |
| `Occupy(column, lane, entityId)` | `number, number, number` | `boolean` | Mark cell occupied (fails if already occupied) |
| `Clear(column, lane)` | `number, number` | `void` | Clear a cell |
| `ClearByEntity(entityId)` | `number` | `boolean` | Find and clear cell by entity ID |
| `Reset()` | - | `void` | Reset entire grid (new game) |
| `GetPlantCount()` | - | `number` | Count of occupied cells |
| `GetAllOccupied()` | - | `{{Column, Lane, EntityId}}` | Get all occupied cells |

---

## MapLoader

**Location:** `src/arena/server/services/MapLoader.luau`

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `LoadMap(mapId)` | `string` | `boolean` | Load map into workspace |
| `UnloadCurrentMap()` | - | `void` | Unload current map |
| `GetCurrentMapId()` | - | `string?` | Get loaded map ID |

---

## ChanceUtils (NEW)

**Location:** `src/shared/utils/ChanceUtils.luau`

Centralized RNG and probability utilities. Use instead of raw `math.random()`.

### Probability
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Roll(chance)` | `number (0-1)` | `boolean` | Roll chance (0.3 = 30% chance) |
| `RollPercent(percent)` | `number (0-100)` | `boolean` | Roll percentage (30 = 30%) |

### Grid Random
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `RandomLane()` | - | `number` | Random lane (1 to GRID_LANES) |
| `RandomColumn()` | - | `number` | Random column (1 to GRID_COLUMNS) |
| `RandomGridCell()` | - | `number, number` | Random (column, lane) |

### Offsets & Signs
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `RandomDirection()` | - | `number` | Random 1 or -1 |
| `RandomSign(positiveChance?)` | `number?` | `number` | Random sign with bias |
| `RandomPitch(base?, variance?)` | `number?, number?` | `number` | Audio pitch variance |
| `RandomOffset(maxOffset)` | `number` | `number` | Random -max to +max |

### Collections
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `PickRandom(array)` | `{T}` | `T?` | Pick random element |
| `WeightedPick(items)` | `{{Value: T, Weight: number}}` | `T?` | Weighted random pick |
| `Shuffle(array)` | `{T}` | `{T}` | Fisher-Yates shuffle |

### Numbers
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `RandomInt(min, max)` | `number, number` | `number` | Random integer |
| `RandomFloat(min, max)` | `number, number` | `number` | Random float |

---

## ECSUtils (NEW)

**Location:** `src/shared/utils/ECSUtils.luau`

Entity Component System manipulation helpers. Centralizes health/damage patterns.

### Health Manipulation
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `DamageEntity(world, entityId, damage, Components)` | `...` | `number, boolean` | Apply damage, returns (actualDamage, isDead) |
| `HealEntity(world, entityId, healAmount, Components)` | `...` | `number` | Apply heal, returns actual heal |
| `ModifyHealth(world, entityId, delta, Components)` | `...` | `number, boolean` | Modify health (+/-), returns (newHealth, isDead) |
| `KillEntity(world, entityId, Components)` | `...` | `boolean` | Instant kill, returns wasAlive |
| `BoostHealth(world, entityId, bonusHealth, Components)` | `...` | `boolean` | Add to current AND max health |
| `ScaleHealth(world, entityId, multiplier, Components)` | `...` | `boolean` | Scale both current and max |
| `SetMaxHealth(world, entityId, newMax, adjustCurrent?, Components)` | `...` | `void` | Set max health |

### Entity Type Checks
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `IsPlant(world, entityId, Components)` | `...` | `boolean` | Has PlantTypeComponent |
| `IsZombie(world, entityId, Components)` | `...` | `boolean` | Has ZombieTypeComponent |
| `IsAlive(world, entityId, Components)` | `...` | `boolean` | Has health > 0 |
| `Exists(world, entityId)` | `any, number` | `boolean` | Entity exists in world |

### Status Effects
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `ApplyOrRefreshEffect(world, entityId, Component, newData, strategy?, ...)` | `...` | `boolean` | Apply/refresh status effect |

**RefreshStrategy:** `"Longest"` | `"Strongest"` | `"Replace"` | `"Stack"`

### Component Helpers
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetOrDefault(world, entityId, Component, defaultValue)` | `...` | `T` | Get component or default |
| `HasAllComponents(world, entityId, components)` | `...` | `boolean` | Has all listed components |
| `HasAnyComponent(world, entityId, components)` | `...` | `boolean` | Has any listed component |

---

## VFXUtils (NEW)

**Location:** `src/shared/utils/VFXUtils.luau`

Visual effects utilities. Eliminates duplicate clone/emit patterns.

### Anchor Creation
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `CreateVFXAnchor(position, name?)` | `Vector3, string?` | `Part` | Create invisible anchor Part |

### Emission
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetEmitCount(emitter, defaultCount?)` | `ParticleEmitter, number?` | `number` | Get EmitCount attribute or default |
| `Emit(emitter, count?)` | `ParticleEmitter, number?` | `void` | Emit particles |
| `CloneEmitAndCleanup(sourceEmitter, parent, emitCount?, cleanupDelay?)` | `...` | `ParticleEmitter` | Clone, emit, auto-cleanup |
| `CloneAndEmit(sourceEmitter, position, emitCount?, cleanupDelay?)` | `...` | `Part, ParticleEmitter` | Create anchor, clone, emit, cleanup |

### Folder/Model Based
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `PlayFromFolder(vfxFolder, position, colorOverride?, cleanupDelay?)` | `...` | `Part?` | Play all emitters in folder |
| `PlayFromModel(model, vfxName, position?, defaultEmitCount?)` | `...` | `boolean` | Play from model's VFX folder |

### Light Effects
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `CloneAndFadeLight(sourceLight, parent, fadeTime?)` | `...` | `Light` | Clone light with fade-out |

### Idle VFX (Persistent)
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `AttachIdleVFX(model, vfxName?)` | `Model, string?` | `ParticleEmitter?` | Attach persistent VFX |
| `DetachIdleVFX(model)` | `Model` | `void` | Remove and clean attached VFX |

---

## Component Index

**Location:** `src/shared/components/init.luau`

### Core Components
- `GridPositionComponent` - Grid coordinates (Column, Lane)
- `HealthComponent` - Health (Current, Max)
- `MovementComponent` - Movement data (Speed, Direction)
- `OwnerComponent` - Player owner
- `PositionComponent` - World position (Vector3)
- `Tags` - Entity tags (PlantTag, ZombieTag, etc.)

### Combat Components
- `ArmedComponent` - Attack capability (Damage, Range, Cooldown)
- `ChewingComponent` - Zombie eating state
- `EnhancedProjectileComponent` - Special projectile effects
- `HidingComponent` - Plant hiding state
- `PlantFoodComponent` - Plant food ability state
- `ProjectileComponent` - Projectile data
- `SlowComponent` - Slow effect
- `SplashComponent` - AoE damage
- `StunComponent` - Stun effect
- `TargetComponent` - Current target entity

### Unit Components
- `GhostComponent` - Client-side prediction ghost
- `JumpingComponent` - Zombie jumping state
- `PlantTypeComponent` - Plant type enum
- `SleepingComponent` - Mushroom sleeping state
- `ZombieTypeComponent` - Zombie type enum

### Economy Components
- `CoinComponent` - Coin value
- `SunComponent` - Sun value and state

### Event Components (Ephemeral)
- `DamageEvent` - Damage instance
- `DeathEvent` - Death notification
- `SpawnEvent` - Spawn request

---

## Common Mistakes to Avoid

### ❌ Wrong Function Names
```lua
-- WRONG: GetProfileData doesn't exist
local data = PlayerDataService.GetProfileData(player)

-- CORRECT: Use GetProfile (Arena) or GetData (Lobby)
local data = PlayerDataService.GetProfile(player)
```

### ❌ Using Arena API in Lobby
```lua
-- WRONG: IncrementStat only exists in Arena version
PlayerDataService.IncrementStat(player, "GamesWon", 1)

-- CORRECT: Lobby has simplified API, use Arena for full functionality
```

### ❌ Accessing teleportData before cast
```lua
-- WRONG: teleportData is 'any' type before validation
local stageId = teleportData.StageId  -- Type error!

-- CORRECT: Cast after validation
if TeleportData.ValidateArenaJoinData(teleportData) then
    local validData = teleportData :: TeleportData.ArenaJoinData
    local stageId = validData.StageId  -- ✓ Type safe
end
```

### ❌ Using deprecated APIs
```lua
-- WRONG: SetPrimaryPartCFrame is deprecated
model:SetPrimaryPartCFrame(cframe)

-- CORRECT: Use PivotTo
model:PivotTo(cframe)
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.1 | 2026-01-12 | Operation Swarm Cleanup: Added complete GridService API documentation. System priority corrections. |
| 2.0 | 2026-01-12 | Post-Refactoring V2 sync: Updated all service APIs to match isolated state pattern. WaveService now includes Preparation state, auto-start, and internal accessors. SunService includes ResetPlayer. MutationService includes LoadMutationsFromProfile. |
| 1.2 | 2026-01-10 | Added ECS Services (WaveService, SunService, MutationService, PlantFoodService, StatsService) |
| 1.1 | 2026-01-10 | Added ChanceUtils, ECSUtils, VFXUtils documentation |
| 1.0 | 2026-01-07 | Initial documentation after API audit |
