# 🗡️ Refactoring Battle Plan

**Generated:** 2026-01-10  
**Target Standard:** `docs/SYSTEM-STANDARD.md` (V2.0)  
**Scope:** All systems in `src/arena/server/systems/`

---

## 📊 Executive Summary

| Batch | Systems | Risk | Strategy |
|-------|---------|------|----------|
| 🟢 BATCH 1 | 12 | Low | Immediate refactor (isolated) |
| 🟠 BATCH 2 | 8 | Medium | Verify dependencies first |
| 🔴 BATCH 3 | 8 | High | Decouple before refactor |

**Total:** 28 systems analyzed

---

## 🟢 BATCH 1: Quick Wins (Isolated Systems)

These systems have **NO external hard dependencies** on other Systems. They only use:
- `Shared` modules (Components, Config, Data, Utils)
- Network (Zap generated)
- Pure ECS logic

| # | System | Coupling | State Leakage | Config Leakage | Decoupling Action |
|---|--------|----------|---------------|----------------|-------------------|
| 1 | `core/EventCleanupSystem` | ✅ None | ❌ None | ❌ None | ✅ **DONE** (refactored to V2) |
| 2 | `core/SpatialHashingSystem` | ✅ None | ✅ None | ✅ None | ✅ **DONE** (refactored to V2) |
| 3 | `combat/BossSystem` | ✅ None | `_hasSpawnedMinion` | ✅ Uses `ZombieData` | ✅ **DONE** (refactored to V2) |
| 4 | `combat/EnhancementSystem` | ✅ None | `_enhancedProjectiles` | `EnhancementConfig` not frozen | ✅ **DONE** (refactored to V2) |
| 5 | `mutations/BurnDamageSystem` | ✅ None | ❌ None | ✅ None | ✅ **DONE** (refactored to V2) |
| 6 | `mutations/FreezeSystem` | ✅ None | ❌ None | ✅ Uses `GameConstants` | ✅ **DONE** (refactored to V2) |
| 7 | `mutations/LifestealSystem` | ✅ None | ❌ None | ✅ None | ✅ **DONE** (refactored to V2) |
| 8 | `mutations/SunOnKillSystem` | ✅ None | ❌ None | Magic: `15` (lifetime) | ✅ **DONE** (refactored to V2) |
| 9 | `mutations/SplashDamageSystem` | ✅ None | ❌ None | ✅ Uses `GridConfig` | ✅ **DONE** (refactored to V2) |
| 10 | `mutations/ChainLightningSystem` | ✅ None | ❌ None | ✅ Uses `GridConfig` | ✅ **DONE** (refactored to V2) |
| 11 | `economy/SunflowerProductionSystem` | ✅ None* | `_productionTimers` | `ProductionDefaults` not frozen | ✅ **DONE** (refactored to V2) |
| 12 | `units/ZombieMovementSystem` | ✅ None* | `_lastBatchTime`, `_positionUpdates`, `_reachedHouse` | `MovementConfig` not frozen | ✅ **DONE** (refactored to V2) |

> *Uses `BaseHealth` module (not a System) - acceptable dependency

**Estimated Effort:** 30 min each (structure alignment)

---

## 🟠 BATCH 2: The Core (Shared Dependencies)

These systems depend on **Managers** or **Services** but NOT other Systems.  
Must verify the Manager is stateless/pure before refactoring.

| # | System | Dependencies | State Leakage | Config Leakage | Decoupling Action |
|---|--------|--------------|---------------|----------------|-------------------|
| 1 | `core/SafetySystem` | ✅ None | `lastWarningTime` | `WARNING_THRESHOLD`, `WARNING_COOLDOWN` magic numbers | ✅ **DONE** (refactored to V2) |
| 2 | `core/PerformanceMonitorSystem` | ✅ None | 6 loose locals | `SPIKE_THRESHOLD`, `LOG_INTERVAL` | ✅ **DONE** (refactored to V2) |
| 3 | `core/FullStateSyncSystem` | `BaseHealth` (module) | `_trove`, `_pendingSync`, `_world` | ❌ None | ✅ **DONE** (refactored to V2) |
| 4 | `combat/CombatSystem` | `GridService` (service) | `_zombieAttackTimes`, `_frameStats` | `CombatConfig` not frozen | ✅ **DONE** (refactored to V2) |
| 5 | `combat/ProjectileSystem` | `LaneCache` (util) | `_plantFireTimes`, `_pendingMultiShots` | `ProjectileDefaults` not frozen | ✅ **DONE** (refactored to V2) |
| 6 | `combat/TrapSystem` | `GridService`, `LaneCache` | `_trapDamageTimes`, `_garlicBites` | ✅ Uses `GameConstants.Trap` | ✅ **DONE** (refactored to V2, API removed) |
| 7 | `economy/SunSpawnSystem` | **WaveManagerSystem** ⚠️ | `_lastSpawnTime`, `_nextSpawnDelay` | `SunConfig` not frozen | ✅ **DONE** (refactored to V2) |
| 8 | `units/EntityDeathSystem` | `PlayerDataService`, `GridService`, `StatsService` | Uses StatsService | ❌ None | ✅ **DONE** (refactored to V2, uses StatsService) |

**Risk:** Medium - Verify Services/Managers are pure before proceeding.

---

## 🔴 BATCH 3: Spaghetti Monsters (Highly Coupled)

These systems have **hard dependencies on other Systems** or expose **public APIs** that other systems call.  
⚠️ **MUST DECOUPLE FIRST** before applying V2 standard.

| # | System | Hard Dependencies | API Exports | State Leakage | Decoupling Strategy |
|---|--------|-------------------|-------------|---------------|---------------------|
| 1 | **`wave/WaveManagerSystem`** | 4 Managers, `PlayerDataService`, `EntityDeathSystem`, `PlantFoodService` | **15+ methods** (`WaveManager.*`) | 15+ loose locals | ✅ **DONE** - Split into `WaveService` + `WaveManagerSystem` (V2) |
| 2 | **`units/PlacementSystem`** | `GridService`, `WaveService`, `MutationService` | ✅ None (API removed) | `State.PlayerCooldowns` | ✅ **DONE** - Uses `SunService`, follows V2 |
| 3 | **`units/MushroomSystem`** | `WaveService` | ✅ None (uses Service) | `State.SunShroomPlanted` | ✅ **DONE** - Uses WaveService.IsDay() directly |
| 4 | **`combat/SpecialPlantSystem`** | `GridService`, `LaneCache` | ✅ None (API removed) | `State.FusePlants`, `State.SquashJumps` | ✅ **DONE** - Uses `SpawnEvent` query, follows V2 |
| 5 | **`combat/PlantFoodSystem`** | `PlantFoodService` | ✅ None (API removed) | `State.PendingRequests` | ✅ **DONE** - Uses `PlantFoodService`, follows V2 |
| 6 | **`mutations/MutationApplySystem`** | `MutationService` | ✅ None (API removed) | ✅ None (uses Service) | ✅ **DONE** - Uses `MutationService`, follows V2 |
| 7 | **`mutations/PoisonCloudSystem`** | `LaneCache` | ✅ None (API removed) | `State.ActiveClouds` | ✅ **DONE** - Uses `queryChanged(HealthComponent)`, follows V2 |
| 8 | **`economy/SunCollectionSystem`** | `SunService` | ✅ None | `State.CollectionQueue` | ✅ **DONE** - Uses `SunService`, follows V2 |

---

## 📋 Recommended Execution Order

### Phase 1: Low-Risk Quick Wins (Day 1)
```
1. ✅ core/EventCleanupSystem (DONE)
2. ✅ core/SpatialHashingSystem (DONE)
3. ✅ mutations/LifestealSystem (DONE)
4. ✅ mutations/BurnDamageSystem (DONE)
5. ✅ mutations/FreezeSystem (DONE)
6. ✅ mutations/SunOnKillSystem (DONE)
7. ✅ mutations/SplashDamageSystem (DONE)
8. ✅ mutations/ChainLightningSystem (DONE)
```

### Phase 2: Combat Systems (Day 1-2)
```
9. combat/BossSystem
10. combat/EnhancementSystem
11. core/SafetySystem
12. core/PerformanceMonitorSystem
```

### Phase 3: Core Systems (Day 2)
```
13. core/FullStateSyncSystem
14. units/ZombieMovementSystem
15. economy/SunflowerProductionSystem
16. combat/ProjectileSystem
17. combat/CombatSystem
```

### Phase 4: API Removal Sprint (Day 3)
**Prerequisite:** Create shared Services first

| System | Current API | Target Service |
|--------|-------------|----------------|
| `PlacementSystem` | `PlacementAPI.AddSun`, `GetPlayerSun` | `SunService` |
| `EntityDeathSystem` | `API.GetSessionStats` | `StatsService` |
| `TrapSystem` | `TrapAPI.OnGarlicEaten` | Event-driven (query `EatingComponent`) |
| `MushroomSystem` | `MushroomAPI.*` | Event-driven + injected WorldConfig |
| `SpecialPlantSystem` | `SpecialPlantAPI.OnPlantPlaced` | Query `SpawnEvent` in system loop |

### Phase 5: The Big Split (Day 4-5)
**CRITICAL: Do these together to avoid breaking dependencies**

```
1. Create WaveService (extract WaveManager API)
2. Refactor WaveManagerSystem (pure ECS loop)
3. Update all consumers of WaveManager.*
4. Create SunService (extract from PlacementSystem)
5. Refactor PlacementSystem (pure ECS loop)
6. Update SunCollectionSystem, SunSpawnSystem
```

### Phase 6: Mutation Systems (Day 5)
```
1. Refactor MutationApplySystem (remove API, use Components)
2. Refactor PoisonCloudSystem (react to DeathEvent)
3. Refactor PlantFoodSystem (extract PlantFoodService)
```

---

## 🚨 Dependency Graph (Critical Paths)

```
WaveManagerSystem ←── SunSpawnSystem
         ↑            MushroomSystem
         └── PlacementSystem ←── SunCollectionSystem
                    ↑
         MutationApplySystem

[Services - Decoupled Architecture]
WaveService ←── WaveManagerSystem, MushroomSystem, SunSpawnSystem
SunService ←── PlacementSystem, SunCollectionSystem
MutationService ←── MutationApplySystem, ProgressionHandler
PlantFoodService ←── PlantFoodSystem, WaveSpawner
StatsService ←── EntityDeathSystem, WaveService
```

**Breaking Change Risk:** ✅ MITIGATED
- All System APIs have been removed
- Shared state now lives in Services
- Systems are pure ECS loops

---

## ✅ Definition of Done (Per System)

- [ ] File follows `SYSTEM-STANDARD.md` template exactly
- [ ] All state in `local State = {}` table
- [ ] All magic numbers in `local CONFIG = table.freeze({})`
- [ ] No `_name` in export (removed)
- [ ] No `API` export (Systems MUST NOT have public APIs)
- [ ] Uses `Components` index module (not individual requires)
- [ ] Passes `selene` linting with no warnings
- [ ] Game still runs after change (integration test)

---

## 📈 Progress Tracker

| Batch | Total | Done | % |
|-------|-------|------|---|
| 🟢 BATCH 1 | 12 | 12 | 100% |
| 🟠 BATCH 2 | 8 | 8 | 100% |
| 🔴 BATCH 3 | 8 | 8 | 100% |
| **TOTAL** | **28** | **28** | **100%** |

---

## 🔧 Service Extraction Candidates

These new Services need to be created to decouple Systems:

| Service Name | Extracted From | Methods | Status |
|--------------|----------------|---------|--------|
| `WaveService` | `WaveManagerSystem` | `StartGame`, `GetGameState`, `SetGameState`, `GetCurrentWorldConfig`, `GetCurrentWave` | ✅ DONE |
| `SunService` | `PlacementSystem` | `AddSun`, `GetSun`, `SpendSun`, `BroadcastSunUpdate` | ✅ DONE |
| `MutationService` | `MutationApplySystem` | `LoadPlayerMutations`, `GetPlantMutations`, `ClearPlayerMutations` | ✅ DONE |
| `PlantFoodService` | `PlantFoodSystem` | `GetCharges`, `AddCharge`, `UseCharge`, `ShouldZombieBeGlowing` | ✅ DONE |
| `StatsService` | `EntityDeathSystem` | `GetSessionStats`, `AddZombieKill`, `AddCoinsEarned`, `ResetAllSessionStats` | ✅ DONE |

---

## ✅ Migration Complete

**Date Completed:** 2026-01-10

All 28 systems have been refactored to V2.0 standard:
- ✅ No public APIs on any system
- ✅ All state encapsulated in `State = {}` tables
- ✅ All config in frozen `CONFIG = table.freeze({})` tables
- ✅ 5 Services created to hold shared state
- ✅ System names passed to `SystemManager.Register()` for proper logging

---

*Generated by architectural analysis. Update this document as systems are refactored.*
