---
title: 'API Reference'
project: 'plant-vs-zombie'
date: '2026-01-22'
version: '2.4'
purpose: 'Document all service APIs to prevent call mismatches'
status: 'Production - 13 Arena services, 11 Lobby server modules'
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

⚠️ **Note:** This is the FULL version for the Lobby place. It manages player profiles, currencies, unlocks, mutations, and deck management.

### Profile Management
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize()` | - | `void` | Initializes ProfileStore |
| `LoadProfile(player)` | `Player` | `Promise` | Load player profile |
| `ReleaseProfile(player)` | `Player` | `void` | Release profile on leave |
| `GetProfile(player)` | `Player` | `Profile?` | Get raw profile object |
| `GetData(player)` | `Player` | `ProfileData?` | Get profile data |
| `WaitForProfile(player, timeout?)` | `Player, number?` | `any` | Wait for profile to load |
| `OnDataChanged(callback)` | `function` | `() -> ()` | Subscribe to data changes |

### Currency: Coins
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetCoins(player)` | `Player` | `number` | Get current coins |
| `AddCoins(player, amount)` | `Player, number` | `boolean` | Add coins |
| `SpendCoins(player, amount)` | `Player, number` | `boolean` | Spend coins |

### Currency: Gems
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetGems(player)` | `Player` | `number` | Get current gems |
| `AddGems(player, amount)` | `Player, number` | `boolean` | Add gems |
| `SpendGems(player, amount)` | `Player, number` | `boolean` | Spend gems |

### XP/Level
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetLevel(player)` | `Player` | `number` | Get current level |
| `GetXP(player)` | `Player` | `number` | Get total XP |
| `GetLevelProgress(player)` | `Player` | `number` | Get 0-1 progress to next level |
| `GetXPForNextLevel(player)` | `Player` | `number` | XP needed for next level |
| `AddXP(player, amount)` | `Player, number` | `number` | Add XP, returns levels gained |

### Plants & Unlocks
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `HasPlant(player, plantType)` | `Player, string` | `boolean` | Check if plant unlocked |
| `GetUnlockedPlants(player)` | `Player` | `{string}` | Get unlocked plants |
| `UnlockPlant(player, plantType)` | `Player, string` | `boolean` | Unlock plant |
| `PurchasePlant(player, plantType, cost)` | `Player, string, number` | `boolean, string?` | Purchase plant |

### Deck Management
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetDeck(player)` | `Player` | `{string}?` | Get current deck |
| `SetDeck(player, deck)` | `Player, {string}` | `boolean` | Set deck |
| `SaveDeck(player, deck)` | `Player, {string}` | `boolean, string?` | Save deck with validation |

### Statistics
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetStats(player)` | `Player` | `StatsTable` | Get all stats |
| `IncrementStat(player, statName, amount?)` | `Player, string, number?` | `void` | Increment stat |

### Mutations (Lobby Only)
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetOwnedMutations(player, plantType)` | `Player, string` | `{string}` | Get owned mutations for plant |
| `GetAllOwnedMutations(player)` | `Player` | `{[string]: {string}}` | Get all owned mutations |
| `OwnsMutation(player, plantType, mutationType)` | `Player, string, string` | `boolean` | Check if owns mutation |
| `GetEquippedMutations(player, plantType)` | `Player, string` | `{string}` | Get equipped mutations |
| `GetAllEquippedMutations(player)` | `Player` | `{[string]: {string}}` | Get all equipped |
| `HasMutationEquipped(player, plantType, mutationType)` | `Player, string, string` | `boolean` | Check if equipped |
| `PurchaseMutation(player, plantType, mutationType)` | `Player, string, string` | `boolean, string?, number?` | Purchase mutation |
| `EquipMutation(player, plantType, mutationType)` | `Player, string, string` | `boolean, string?` | Equip mutation |
| `UnequipMutation(player, plantType, mutationType)` | `Player, string, string` | `boolean` | Unequip mutation |

### Sync / Debug (Admin)
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `SyncToClient(player)` | `Player` | `void` | Sync all data to client |
| `ResetProfile(player)` | `Player` | `boolean` | Reset to defaults |
| `MaxResources(player)` | `Player` | `boolean` | Max all resources |
| `SetLevel(player, level)` | `Player, number` | `boolean` | Set level |
| `SetCoins(player, amount)` | `Player, number` | `boolean` | Set coins |
| `SetGems(player, amount)` | `Player, number` | `boolean` | Set gems |
| `Dispose()` | - | `void` | Cleanup |

---

## ArenaService

**Location:** `src/arena/server/services/ArenaService.luau`

Manages battle sessions per player.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetBattleData(player)` | `Player` | `BattleData?` | Get battle data for a player |
| `StartBattle(player, worldId, difficulty, deck)` | `Player, string, string, {string}` | `boolean` | Start a battle (returns success) |
| `EndBattle(player, victory, wavesSurvived, coins, xp)` | `Player, boolean, number, number, number` | `void` | End the current battle |
| `OnPlayerRemoving(player)` | `Player` | `void` | Clean up when player leaves |
| `GetWorldConfig(player)` | `Player` | `WorldConfig?` | Get world config for player's active battle |
| `GetDifficultyConfig(player)` | `Player` | `DifficultyConfig?` | Get difficulty config for player's active battle |

### BattleData Type
```lua
type BattleData = {
    WorldId: string,
    Difficulty: string,
    Deck: {string},
}
```

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
| `SpendSun(player, amount, reason?)` | `Player, number, string?` | `boolean` | Spend sun (returns false if insufficient) |
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

Orchestrates teleport pad functionality. Thin facade delegating to managers.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize(zapServer)` | `ZapServer` | `void` | Initialize with Zap network |
| `GetPadConfig(padId)` | `string` | `PadConfig?` | Get pad config (debugging) |
| `PlayerJoinedPad(player, padModel)` | `Player, Model` | `void` | Manual join (testing) |
| `PlayerLeftPad(player)` | `Player` | `void` | Manual leave (testing) |

---

## LightingService

**Location:** `src/arena/server/services/LightingService.luau`

Manages lighting presets per world theme with smooth transitions.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize()` | - | `void` | Initialize service |
| `ApplyPreset(theme, instant?)` | `string, boolean?` | `void` | Apply lighting preset (instant = skip transition) |
| `ApplyFromWorld(worldId, instant?)` | `string, boolean?` | `void` | Apply lighting from world config |
| `GetCurrentTheme()` | - | `string` | Get current lighting theme name |
| `IsTransitioning()` | - | `boolean` | Check if currently transitioning |

### Preset Types
- `"Day"` - Bright outdoor lighting
- `"Night"` - Dark with ambient lighting
- `"Pool"` - Daylight with water reflections
- `"Fog"` - Reduced visibility, atmospheric
- `"Roof"` - Evening/sunset lighting

---

## MapLoader

**Location:** `src/arena/server/services/MapLoader.luau`

Handles dynamic map loading from ReplicatedStorage.Maps.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Initialize()` | - | `void` | Initialize the MapLoader |
| `GetCurrentMapId()` | - | `string?` | Get loaded map ID |
| `GetCurrentMap()` | - | `Model?` | Get loaded map model |
| `LoadMap(mapId)` | `string` | `boolean` | Load map into workspace |
| `UnloadMap()` | - | `void` | Unload current map |
| `MapExists(mapId)` | `string` | `boolean` | Check if map exists |
| `GetAvailableMaps()` | - | `{string}` | Get available map IDs |
| `PreloadMapAssets(mapId, player?)` | `string, Player?` | `boolean, number` | Preload map assets |
| `LoadMapWithPreload(mapId, player?)` | `string, Player?` | `boolean` | Load with preloading |
| `SyncConfigToPlayer(player)` | `Player` | `void` | Sync config to late joiner |

---

## FogService (NEW)

**Location:** `src/arena/server/services/FogService.luau`

Manages fog visibility zones for night/fog worlds.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `IsFogActive()` | - | `boolean` | Check if fog is currently active |
| `GetFoggyColumns()` | - | `{number}` | Get current foggy columns |
| `EnableFog(foggyColumns?)` | `{number}?` | `void` | Enable fog (optionally specify columns) |
| `EnableFogFromBounds()` | - | `boolean` | Enable fog using MapConfig FogBounds |
| `DisableFog()` | - | `void` | Disable fog |
| `Dispose()` | - | `void` | Reset state |

---

## TileModifierService (NEW)

**Location:** `src/arena/server/services/TileModifierService.luau`

Manages tile/cell modifiers (craters, fire zones, ice zones, tombstones).

### Lifecycle
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Init(world)` | `any` | `void` | Initialize with world reference |
| `Dispose()` | - | `void` | Dispose and cleanup |

### Modifier Management
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `AddModifier(column, lane, data)` | `number, number, ModifierData` | `number?` | Add a tile modifier, returns entity ID |
| `RemoveModifier(entityId)` | `number` | `boolean` | Remove modifier by entity ID |
| `GetModifiers(column, lane)` | `number, number` | `{any}` | Get all modifiers on a cell |
| `GetModifiersByStackGroup(column, lane, stackGroup)` | `number, number, string` | `{number}` | Get modifiers by stack group |

### Cell Queries
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `HasBlockingModifier(column, lane)` | `number, number` | `boolean` | Check if placement blocked |
| `AllowsAquatic(column, lane)` | `number, number` | `boolean` | Check if allows aquatic plants |
| `GetSpeedMultiplier(column, lane)` | `number, number` | `number` | Get effective speed multiplier |
| `GetZombieDamagePerSecond(column, lane)` | `number, number` | `number` | Get zombie DPS on cell |
| `GetPlantDamagePerSecond(column, lane)` | `number, number` | `number` | Get plant DPS on cell |

### Cleanup
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `ClearCell(column, lane)` | `number, number` | `void` | Clear all modifiers on cell |
| `ClearByType(modifierType)` | `string` | `void` | Clear modifiers by type |
| `ClearAll()` | - | `void` | Clear all modifiers |

### Preset Helpers
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `AddCrater(column, lane)` | `number, number` | `number?` | Add permanent crater |
| `AddFireZone(column, lane, duration, dps)` | `number, number, number, number` | `number?` | Add fire zone |
| `AddIceZone(column, lane, duration, slowPercent)` | `number, number, number, number` | `number?` | Add ice zone |
| `AddTombstone(column, lane)` | `number, number` | `number?` | Add tombstone

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
| `IsOccupied(column, lane)` | `number, number` | `boolean` | Check if cell has a plant or is blocked |
| `IsBlocked(column, lane)` | `number, number` | `boolean` | Check if cell is blocked (crater/obstacle) |
| `GetEntityAt(column, lane)` | `number, number` | `number?` | Get entity ID occupying a cell |
| `GetEntity(column, lane)` | `number, number` | `number?` | Alias for GetEntityAt |
| `Occupy(column, lane, entityId, ownerId?)` | `number, number, number, number?` | `boolean` | Mark cell occupied with optional owner |
| `Clear(column, lane)` | `number, number` | `void` | Clear a cell |
| `BlockCell(column, lane)` | `number, number` | `void` | Block a cell (crater/obstacle) |
| `UnblockCell(column, lane)` | `number, number` | `void` | Unblock a cell |
| `ClearByEntity(entityId)` | `number` | `boolean` | Find and clear cell by entity ID |
| `Reset()` | - | `void` | Reset entire grid (new game) |
| `GetPlayerPlantCount(playerId)` | `number` | `number` | Get plant count for a player |
| `ClearPlayerData(playerId)` | `number` | `void` | Clear a player's tracking data |
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

## 🎮 God Mode Architecture

### ValidationMiddleware (Level 1 - Pre-Action)

**Location:** `src/shared/utils/combat/ValidationMiddleware.luau`

Blocks or allows player actions BEFORE they execute. All player actions should validate here first.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Register(action, callback)` | `string, (context) -> (boolean, string?)` | `string` | Register hook, returns hookId |
| `Unregister(action, hookId)` | `string, string` | `boolean` | Remove hook by ID |
| `Validate(action, context)` | `string, table` | `boolean, string?` | Validate action, returns allowed + reason |
| `ClearAll()` | - | `void` | Clear all registered hooks (testing) |
| `GetRegisteredActions()` | - | `{string}` | List all actions with hooks |

**Supported Actions:**
| Action | Context Fields |
|--------|---------------|
| `PlacePlant` | `Player, PlantType, Row, Column` |
| `ShovelPlant` | `Player, PlantId, Row, Column` |
| `SpendSun` | `Player, Amount` |
| `UsePlantFood` | `Player, PlantId` |
| `StartWave` | `Player?` |
| `CollectSun` | `Player, Amount` |

---

### ServerEventBus (Level 3 - Post-Action)

**Location:** `src/arena/server/services/ServerEventBus.luau`

Signal-based event bus for reacting to game events AFTER they happen.

| Event | Payload Type | Description |
|-------|--------------|-------------|
| `OnEntityDied` | `EntityDiedPayload` | Entity was killed |
| `OnPlantPlaced` | `PlantPlacedPayload` | Plant was placed |
| `OnPlantShoveled` | `PlantShoveledPayload` | Plant was shoveled |
| `OnSunSpent` | `SunSpentPayload` | Sun was spent |
| `OnSunCollected` | `SunCollectedPayload` | Sun was collected |
| `OnWaveStarted` | `WaveStartedPayload` | Wave began |
| `OnWaveCompleted` | `WaveCompletedPayload` | Wave finished |
| `OnGameStateChanged` | `GameStateChangedPayload` | Game state changed |
| `OnDamageDealt` | `DamageDealtPayload` | Damage was dealt |
| `OnPlantFoodUsed` | `PlantFoodUsedPayload` | Plant food activated |
| `OnMutationTriggered` | `MutationTriggeredPayload` | Mutation effect triggered |

**Payload Types:**
```lua
type EntityDiedPayload = { EntityId: number, EntityType: string, Position: Vector3, KillerId: number?, KillerType: string? }
type PlantPlacedPayload = { PlantId: number, PlantType: string, Row: number, Column: number, PlayerId: number }
type SunSpentPayload = { PlayerId: number, Amount: number, NewBalance: number, Reason: string }
type DamageDealtPayload = { TargetId: number, SourceId: number, Amount: number, DamageType: string, IsCritical: boolean }
```

---

### DamageModifierRegistry (Level 2 - In-Flight)

**Location:** `src/shared/utils/combat/DamageModifierRegistry.luau`

Registry for damage modifiers that transform DamageIntent components.

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `Register(modifier)` | `DamageModifier` | `string` | Register modifier, returns ID |
| `Unregister(modifierId)` | `string` | `boolean` | Remove modifier |
| `ApplyModifiers(intent, world)` | `DamageIntentData, World` | `DamageIntentData` | Apply all modifiers |
| `SetEnabled(modifierId, enabled)` | `string, boolean` | `void` | Enable/disable modifier |
| `IsEnabled(modifierId)` | `string` | `boolean` | Check if enabled |
| `GetModifiers()` | - | `{DamageModifier}` | Get all modifiers |
| `Clear()` | - | `void` | Clear all modifiers |

**DamageModifier Type:**
```lua
type DamageModifier = {
    Id: string,           -- Unique identifier
    Priority: number,     -- Lower = runs first (default 100)
    Enabled: boolean?,    -- Default true
    Apply: (intent: DamageIntentData, world: World) -> DamageIntentData,
}
```

---

### DamageIntent Component

**Location:** `src/shared/components/events/DamageIntent.luau`

Ephemeral component for in-flight damage modification.

| Field | Type | Description |
|-------|------|-------------|
| `TargetId` | `number` | Entity receiving damage |
| `SourceId` | `number?` | Entity dealing damage |
| `Amount` | `number` | Base damage amount |
| `FinalAmount` | `number?` | Modified damage (set by modifiers) |
| `DamageType` | `string` | `"Normal"`, `"Fire"`, `"Ice"`, etc. |
| `IsCritical` | `boolean?` | Critical hit flag |
| `Multiplier` | `number?` | Damage multiplier (default 1.0) |
| `FlatBonus` | `number?` | Flat damage bonus |
| `ModifiersApplied` | `boolean?` | Has passed through modifiers |
| `Resolved` | `boolean?` | Has been applied to target |

**Pipeline Flow:**
1. `CombatSystem (P:170)` spawns DamageIntent
2. `DamageModifierSystem (P:172)` applies all modifiers
3. `DamageResolverSystem (P:175)` applies damage via ECSUtils
4. `EntityDeathSystem (P:180)` handles deaths

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
| 2.4 | 2026-01-22 | **Major Update:** Added FogService, TileModifierService. Updated ArenaService API (new signatures). Updated GridService (blocking, player tracking). Updated LightingService (renamed functions). Updated MapLoader (7 new functions). Expanded PlayerDataService (Lobby) with mutations, gems, sync, debug APIs. Updated ServerEventBus with typed fire methods. Fixed 35 arena server systems count. |
| 2.3 | 2026-01-19 | Added God Mode Architecture: ValidationMiddleware, ServerEventBus, DamageModifierRegistry, DamageIntent pipeline documentation |
| 2.2 | 2026-01-18 | Added LightingService and MapService documentation. Updated to Argon toolchain. |
| 2.1 | 2026-01-12 | Operation Swarm Cleanup: Added complete GridService API documentation. System priority corrections. |
| 2.0 | 2026-01-12 | Post-Refactoring V2 sync: Updated all service APIs to match isolated state pattern. WaveService now includes Preparation state, auto-start, and internal accessors. SunService includes ResetPlayer. MutationService includes LoadMutationsFromProfile. |
| 1.2 | 2026-01-10 | Added ECS Services (WaveService, SunService, MutationService, PlantFoodService, StatsService) |
| 1.1 | 2026-01-10 | Added ChanceUtils, ECSUtils, VFXUtils documentation |
| 1.0 | 2026-01-07 | Initial documentation after API audit |
