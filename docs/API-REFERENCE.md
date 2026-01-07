---
title: 'API Reference'
project: 'plant-vs-zombie'
date: '2026-01-07'
version: '1.0'
purpose: 'Document all service APIs to prevent call mismatches'
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
| `GetUpgradeLevel(player, plantType, upgradeType)` | `Player, string, string` | `number` | Get upgrade level |
| `GetPlantUpgrades(player, plantType)` | `Player, string` | `{Damage, Health, Cooldown}` | Get all upgrades for plant |
| `PurchaseUpgrade(player, plantType, upgradeType)` | `Player, string, string` | `boolean, string?` | Buy upgrade |

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
    StageId: string,
    Deck: {string},
    Timestamp: number,
}

type LobbyReturnData = {
    StageId: string,
    Victory: boolean,
    Stars: number,
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
| `CreateArenaJoinData(stageId, deck)` | `string, {string}` | `ArenaJoinData` | Create teleport data |
| `CreateLobbyReturnData(stageId, victory, stars, coins, xp)` | `...` | `LobbyReturnData` | Create return data |

---

## StageRegistry

**Location:** `src/shared/data/StageRegistry.luau`

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetStage(stageId)` | `string` | `StageConfig?` | Get stage configuration |
| `GetWorldStages(worldNumber)` | `number` | `{StageConfig}` | Get all stages in a world |
| `IsUnlocked(stageId, completedStages)` | `string, {[string]: number}` | `boolean` | Check if stage is unlocked |
| `GetNextStage(stageId)` | `string` | `string?` | Get next stage in sequence |

---

## MapLoader

**Location:** `src/arena/server/services/MapLoader.luau`

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `LoadMap(mapId)` | `string` | `boolean` | Load map into workspace |
| `UnloadCurrentMap()` | - | `void` | Unload current map |
| `GetCurrentMapId()` | - | `string?` | Get loaded map ID |

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
| 1.0 | 2026-01-07 | Initial documentation after API audit |
