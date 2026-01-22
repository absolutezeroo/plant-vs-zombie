# 🌻 ROADMAP - Garden Swarm - État d'Implémentation

> **Dernière mise à jour automatisée:** 22 Janvier 2026  
> Basé sur l'analyse complète du codebase (`PlantData.luau`, Systems ECS, Services, UI)

---

## 🎯 ÉTAT GLOBAL DU PROJET

### Vue d'Ensemble

| Métrique | Valeur | Status |
|----------|--------|--------|
| **Phase Actuelle** | Phase 3 (Epic 6 - Polish) | 🟢 En cours |
| **Architecture ECS** | Matter V2 Pattern (Hooks) | ✅ Complète |
| **Systèmes Serveur Arena** | 35/35 | ✅ 100% |
| **Systèmes Client Arena** | 7/7 | ✅ 100% |
| **Services Arena** | 13/13 | ✅ 100% |
| **Lobby Serveur** | 11/11 | ✅ 100% |
| **Lobby Client** | 6/6 | ✅ 100% |
| **Composants ECS** | 53 (47 + 6 tags) | ✅ 100% |
| **Modules Partagés** | 92 fichiers | ✅ 99% |

---

## 📊 INVENTAIRE COMPLET DES PLANTES (PlantData.luau)

### 🎯 1. SHOOTERS STANDARD (9 plantes)

| Plante          | Coût ☀️ | Dégâts  | Mécanique                       | État             | Notes                                         |
|-----------------|---------|---------|---------------------------------|------------------|-----------------------------------------------|
| **Peashooter**  | 100     | 20      | `CanShoot`                      | ✅ MVP            | Référence de base                             |
| **Repeater**    | 200     | 20×2    | `IsRepeater`, `ShotsPerBurst=2` | ✅ MVP            | Multi-shot implémenté                         |
| **SnowPea**     | 175     | 20+slow | `IsFrozen`, `SlowPercent=0.5`   | ✅ MVP            | SlowComponent fonctionne                      |
| **Threepeater** | 325     | 20×3    | `IsThreeLane`                   | ✅ Implémenté     | `fireThreeLanes()` dans ProjectileSpawnSystem |
| **SplitPea**    | 125     | 20      | `ShootsBehind`                  | ✅ Implémenté     | Tire avant/arrière                            |
| **GatlingPea**  | 250     | 20×4    | `ShotsPerBurst=4`               | ✅ Implémenté     | Variante Repeater                             |
| **Starfruit**   | 125     | 20×5    | `ShootsMultiDirection`          | ✅ Implémenté     | `fireMultiDirection()` 5 directions           |
| **Cactus**      | 125     | 20      | `CanHitFlying`                  | ✅ Implémenté    | CombatSystem vérifie IsFlying                 |
| **Cattail**     | 225     | 20      | `IsHoming`, `RequiresLilyPad`   | ✅ Implémenté    | `fireHomingProjectile()` + HomingComponent    |

### 🎃 2. CATAPULTES / LOBBERS (5 plantes)

| Plante          | Coût ☀️ | Dégâts  | Mécanique                                | État             | Notes                          |
|-----------------|---------|---------|------------------------------------------|------------------|--------------------------------|
| **CabbagePult** | 100     | 40      | `IsCatapult`                             | ✅ Implémenté     | Projectiles en arc             |
| **KernelPult**  | 100     | 20      | `CanStun`, `StunChance=0.2`              | ✅ Implémenté     | StunComponent + Butter variant |
| **MelonPult**   | 300     | 80      | `HasSplash`, `SplashRadius=3`            | ✅ Implémenté     | SplashComponent ajouté         |
| **WinterMelon** | 500     | 80+slow | `IsFrozen` + `HasSplash`                 | ✅ Implémenté     | Combo splash+freeze            |
| **CobCannon**   | 500     | 1800    | `IsManualFire`, `RequiresTwoKernelPults` | ✅ Implémenté    | CobCannonAbility + network handler complet    |

### 💣 3. EXPLOSIVES / INSTANT-KILL (7 plantes)

| Plante         | Coût ☀️ | Dégâts | Mécanique                         | État         | Notes                                  |
|----------------|---------|--------|-----------------------------------|--------------|----------------------------------------|
| **CherryBomb** | 150     | 1800   | `ExplodesOnPlace`, `FuseTime=0.5` | ✅ MVP        | SpecialPlantSystem                     |
| **PotatoMine** | 25      | 1800   | `NeedsArming`, `ArmDuration=20`   | ✅ MVP        | ArmedComponent fonctionne              |
| **Jalapeno**   | 125     | 1800   | `IsLaneWide`                      | ✅ Implémenté | Brûle toute la lane                    |
| **DoomShroom** | 125     | 1800   | `LeavesCrater`                    | ✅ Implémenté | Explosion + cratère bloque placement   |
| **IceShroom**  | 75      | 20     | `FreezesAll`, `FreezeDuration=4`  | ✅ Implémenté | Gèle tous les zombies                  |
| **Squash**     | 50      | 1800   | `JumpsToTarget`                   | ✅ Implémenté | Animation saut dans SpecialPlantSystem |
| **TangleKelp** | 25      | 1800   | `IsInstantKill`, `RequiresWater`  | ✅ Implémenté | PlacementSystem valide RequiresWater         |

### 😋 4. INSTANT-KILL SPÉCIAUX (1 plante)

| Plante      | Coût ☀️ | Dégâts | Mécanique                          | État         | Notes                          |
|-------------|---------|--------|------------------------------------|--------------|--------------------------------|
| **Chomper** | 150     | 1800   | `IsInstantKill`, `ChewDuration=42` | ✅ Implémenté | ChewingComponent bloque le tir |

### 🛡️ 5. DÉFENSIVES (5 plantes)

| Plante          | Coût ☀️ | HP  | Mécanique                    | État             | Notes                                   |
|-----------------|---------|-----|------------------------------|------------------|-----------------------------------------|
| **WallNut**     | 50      | 400 | Défense de base              | ✅ MVP            | Bloqueur simple                         |
| **TallNut**     | 125     | 800 | `BlocksJumpers`              | ✅ Implémenté     | Pole Vaulter ne peut pas sauter         |
| **Pumpkin**     | 125     | 400 | `IsShell`, `CanStackOnPlant` | ✅ Implémenté    | ShellComponent + damage routing         |
| **Garlic**      | 50      | 200 | `DivertsZombies`             | ✅ Implémenté    | TrapSystem complet (lane switch)        |
| **ExplodeONut** | 50      | 400 | `ExplodesOnDeath`            | ✅ Implémenté    | EntityDeathSystem + handleDeathExplosion()   |

### 🌻 6. PRODUCTEURS (4 plantes)

| Plante            | Coût ☀️ | Production | Mécanique                   | État             | Notes                         |
|-------------------|---------|------------|-----------------------------|------------------|-------------------------------|
| **Sunflower**     | 50      | 25☀️/30s   | `ProducesSun`, `SunCount=1` | ✅ MVP            | SunflowerProductionSystem     |
| **TwinSunflower** | 150     | 50☀️/24s   | `SunCount=2`                | ✅ Implémenté     | Double production             |
| **SunShroom**     | 25      | 15→25☀️    | `GrowthTime=120`            | ✅ Implémenté    | MushroomSystem getSunShroomValue()   |
| **Marigold**    | 50      | Coins      | `ProducesCoins`             | ✅ Implémenté    | CoinProductionSystem ajouté   |

### 🍄 7. CHAMPIGNONS (7 plantes)

| Plante            | Coût ☀️ | Mécanique Spéciale              | État             | Notes                                   |
|-------------------|---------|---------------------------------|------------------|-----------------------------------------|
| **PuffShroom**    | 0       | `Range=18` (court)              | ✅ Implémenté     | Range limité dans ProjectileSpawnSystem |
| **SeaShroom**     | 0       | `RequiresWater`                 | ✅ Implémenté    | PlacementSystem valide RequiresWater         |
| **FumeShroom**    | 75      | `PiercesShields`                | ✅ Implémenté     | Flag dans ProjectileComponent           |
| **ScaredyShroom** | 25      | `HidesWhenNear`, `HideRadius=6` | ✅ Implémenté     | HidingComponent + MushroomSystem        |
| **HypnoShroom**   | 75      | `HypnotizesOnDeath`             | ✅ Implémenté    | CombatSystem + HypnotizedComponent      |
| **GloomShroom**   | 150     | `ShootsAllDirections`           | ✅ Implémenté    | `fireAllDirections()` 8 directions       |
| **CoffeeBean**    | 75      | `WakesMushrooms`                | ✅ Implémenté    | PlacementSystem + PlantActionEvent + MushroomSystem |

### 🔧 8. SUPPORT / UTILITAIRES (9 plantes)

| Plante           | Coût ☀️ | Mécanique                                | État             | Notes                        |
|------------------|---------|------------------------------------------|------------------|------------------------------|
| **Torchwood**    | 175     | `EnhancesPeas`, `FireDamageMultiplier=2` | ✅ Implémenté     | EnhancementSystem complet    |
| **Plantern**     | 25      | `RemovesFog`, `FogRadius=36`             | ⚠️ Partiel       | FogSystem existe, illumination à compléter |
| **Blover**       | 100     | `RemovesFlying`, `RemovesFog`            | ✅ Implémenté    | SpecialPlantSystem tue flying zombies |
| **UmbrellaLeaf** | 100     | `DeflectsProjectiles`                    | ❌ Non implémenté | Catapult zombies?            |
| **GoldMagnet**   | 50      | `CollectsCoins`                          | ❌ Non implémenté | Coin system manquant         |
| **LilyPad**      | 25      | `IsWaterPlatform`                        | ✅ Implémenté    | PlacementSystem valide WaterLanes     |
| **FlowerPot**    | 25      | `IsGroundPlatform`                       | ✅ Implémenté    | PlacementSystem valide IsGroundPlatform |
| **GraveBuster**  | 75      | `RemovesGraves`                          | ❌ Non implémenté | Grave spawning manquant      |
| **Imitater**     | +0      | `IsImitater`                             | ❌ Non implémenté | Clone plant complexe         |

### 🌵 9. PIÈGES (1 plante)

| Plante        | Coût ☀️ | Mécanique                              | État          | Notes                              |
|---------------|---------|----------------------------------------|---------------|------------------------------------|
| **Spikeweed** | 100     | `IsTrap`, `DamagesOnWalk`, `PopsTires` | ✅ Implémenté | TrapSystem fonctionne + PopsTires  |

---

## 📈 STATISTIQUES D'IMPLÉMENTATION

### Résumé Global

| Catégorie    | Total  | ✅ Complet    | ⚠️ Partiel   | ❌ Non implémenté |
|--------------|--------|--------------|--------------|------------------|
| Shooters     | 9      | 9            | 0            | 0                |
| Catapultes   | 5      | 5            | 0            | 0                |
| Explosives   | 7      | 7            | 0            | 0                |
| Instant-Kill | 1      | 1            | 0            | 0                |
| Défensives   | 5      | 5            | 0            | 0                |
| Producteurs  | 4      | 4            | 0            | 0                |
| Champignons  | 7      | 7            | 0            | 0                |
| Support      | 9      | 4            | 1            | 4                |
| Pièges       | 1      | 1            | 0            | 0                |
| **TOTAL**    | **48** | **43 (90%)** | **1 (2%)**   | **4 (8%)**       |

---

## ✅ SYSTÈMES ECS EXISTANTS (35 Systèmes Serveur)

### Combat Systems (`src/arena/server/systems/combat/`) - 10 systèmes
- ✅ `ProjectileSpawnSystem.luau` (P:160) - Tir, multi-shot, 3-lane, 5-way, catapult, homing
- ✅ `ProjectileMovementSystem.luau` (P:161) - Déplacement projectiles, homing tracking
- ✅ `EnhancementSystem.luau` (P:165) - Torchwood fire enhancement
- ✅ `TrapSystem.luau` (P:165) - Spikeweed + PopsTires + Garlic DivertsZombies
- ✅ `CombatSystem.luau` (P:170) - Détection collision, dégâts, zombie eating
- ✅ `DamageModifierSystem.luau` (P:172) - Pipeline modifieurs de dégâts
- ✅ `DamageResolverSystem.luau` (P:175) - Application finale des dégâts
- ✅ `BossSystem.luau` (P:175) - Gargantuar spawns Imp at 50%
- ✅ `SpecialPlantSystem.luau` (P:175) - Explosions, Squash, Chomper, PotatoMine
- ✅ `PlantFoodSystem.luau` (P:185) - Capacités ultimes

### Core Systems (`src/arena/server/systems/core/`) - 5 systèmes
- ✅ `SafetySystem.luau` (P:1) - Entity cap enforcement (200 max)
- ✅ `FullStateSyncSystem.luau` (P:50) - State sync for late joiners
- ✅ `SpatialHashingSystem.luau` (P:95) - LaneCache rebuild every frame
- ✅ `EventCleanupSystem.luau` (P:400) - Ephemeral event cleanup
- ✅ `PerformanceMonitorSystem.luau` (P:500) - Frame time logging

### Unit Systems (`src/arena/server/systems/units/`) - 5 systèmes
- ✅ `ZombieAbilitySystem.luau` (P:90) - Zombie OnTick abilities (Regen, Catapult)
- ✅ `ZombieMovementSystem.luau` (P:150) - Mouvement zombies, game-over detection
- ✅ `MushroomSystem.luau` (P:155) - Sleep, Hide, day/night, SunShroom growth
- ✅ `EntityDeathSystem.luau` (P:180) - Nettoyage entités mortes, coin spawns
- ✅ `PlacementSystem.luau` (P:200) - Validation placement, coût, cooldown

### Economy Systems (`src/arena/server/systems/economy/`) - 4 systèmes
- ✅ `SunSpawnSystem.luau` (P:300) - Spawn soleil du ciel
- ✅ `SunflowerProductionSystem.luau` (P:305) - Production soleil
- ✅ `CoinProductionSystem.luau` (P:306) - Marigold produit coins
- ✅ `SunCollectionSystem.luau` (P:310) - Collecte soleil

### Environment Systems (`src/arena/server/systems/environment/`) - 2 systèmes
- ✅ `TileModifierSystem.luau` (P:85) - Tile effects (damage zones, speed mods)
- ✅ `FogSystem.luau` (P:180) - Fog zones, Plantern illumination, Blover clear

### Mutation Systems (`src/arena/server/systems/mutations/`) - 8 systèmes
- ✅ `MutationApplySystem.luau` (P:205) - Apply mutations to new plants
- ✅ `SplashDamageSystem.luau` (P:345) - Dégâts zone
- ✅ `BurnDamageSystem.luau` (P:350) - Dégâts feu DoT
- ✅ `FreezeSystem.luau` (P:355) - Effets gel et expiration
- ✅ `ChainLightningSystem.luau` (P:360) - Chaîne éclairs
- ✅ `PoisonCloudSystem.luau` (P:365) - Nuages poison AoE
- ✅ `LifestealSystem.luau` (P:370) - Vol de vie
- ✅ `SunOnKillSystem.luau` (P:375) - Sun on zombie kill

### Wave Systems (`src/arena/server/systems/wave/`) - 1 système
- ✅ `WaveManagerSystem.luau` (P:100) - Wave spawning, phase management

---

## 🔧 COMPONENTS ECS (53 total)

### Core Components (`src/shared/components/core/`) - 7 composants
- ✅ `FogZoneComponent` - Fog zone marker (🟡 unused - fog feature pending)
- ✅ `GridPositionComponent` - Position grille (Row, Column, X, Z, Y)
- ✅ `HealthComponent` - Health (Current, Max)
- ✅ `MovementComponent` - Movement (Speed, DirectionX/Z, IsMoving)
- ✅ `OwnerComponent` - Player owner (PlayerId)
- ✅ `PositionComponent` - World position (X, Y, Z)
- ✅ `Tags` - 6 tags (PlantTag, ZombieTag, ProjectileTag, ResourceTag, InactiveTag, ReplicatedTag)

### Combat Components (`src/shared/components/combat/`) - 11 composants
- ✅ `ArmedComponent` - PotatoMine arming state
- ✅ `ChewingComponent` - Chomper busy state (ChewDuration=42)
- ✅ `EnhancedProjectileComponent` - Fire peas (DamageMultiplier=2)
- ✅ `HidingComponent` - ScaredyShroom hide state (HideRadius=6)
- ✅ `HomingComponent` - Cattail homing (TargetEntity, TurnSpeed)
- ✅ `PlantFoodComponent` - Glowing zombie marker
- ✅ `ProjectileComponent` - Full projectile data (IsFrozen, IsCatapult, CanStun, etc.)
- ✅ `SlowComponent` - Freeze/slow effects
- ✅ `SplashComponent` - Area damage (SplashRadius, SplashDamage)
- ✅ `StunComponent` - Butter stun (Duration=4)
- ✅ `TargetComponent` - Entity targeting (EntityId, Distance)

### Unit Components (`src/shared/components/units/`) - 9 composants
- ✅ `GhostComponent` - Client prediction ghost (RequestId, TimeCreated)
- ✅ `HypnotizedComponent` - HypnoShroom effect (HypnotizedAt, OriginalSpeed)
- ✅ `JumpingComponent` - Squash/Pole vaulter state
- ✅ `PlantTypeComponent` - Plant type + OwnerId
- ✅ `ShellComponent` - Pumpkin protection (ProtectsPlant, ProtectedByShell)
- ✅ `ShieldComponent` - Zombie shields (Current, Max)
- ✅ `SleepingComponent` - Mushroom day sleep
- ✅ `VaultedComponent` - Pole Vaulter used ability
- ✅ `ZombieTypeComponent` - Zombie type + Lane + SpawnTime

### Economy Components (`src/shared/components/economy/`) - 2 composants
- ✅ `CoinComponent` - Coin value/spawn data
- ✅ `SunComponent` - Sun orb data (Value=25, Lifetime=10)

### Event Components (`src/shared/components/events/`) - 11 composants
- ✅ `CoinDropEvent` - Ephemeral coin drop
- ✅ `DamageEvent` - Ephemeral damage (Target, Amount, DamageType)
- ✅ `DamageIntent` - In-flight damage for modifier pipeline
- ✅ `DeathEvent` - Ephemeral death notification
- ✅ `DeathExplosionEvent` - Jack-in-the-Box explosion
- ✅ `PlantActionEvent` - Special actions (Wake, Arm, Explode)
- ✅ `ProjectileHitEvent` - Hit event for mutations
- ✅ `SpawnEvent` - Spawn notification
- ✅ `SpawnMinionEvent` - Gargantuar Imp spawn
- ✅ `TileModifierComponent` - Cell modifiers (crater, fire, ice)
- ✅ `WaveStateEvent` - Wave state changes

### Mutation Components (`src/shared/components/mutations/`) - 13 composants
- ✅ `BurnEffectComponent` - Fire mutation source
- ✅ `BurningComponent` - Active burn status on zombie
- ✅ `ChainLightningComponent` - Electric mutation
- ✅ `DamageReductionComponent` - Reinforced mutation
- ✅ `FreezeEffectComponent` - Ice mutation source
- ✅ `FrozenComponent` - Frozen status on zombie
- ✅ `LifestealComponent` - Shadow mutation
- ✅ `MutationsComponent` - Active mutations on plant
- ✅ `PoisonCloudComponent` - Toxic mutation cloud
- ✅ `PoisonedComponent` - Poison status on zombie
- ✅ `RageComponent` - Zombie rage (Newspaper)
- ✅ `SplashDamageComponent` - Primal mutation splash
- ✅ `SunOnKillComponent` - Solar mutation

---

## 🗺️ ROADMAP D'IMPLÉMENTATION PRIORITAIRE

### 🏃 Sprint 1 : Compléter les Partiels (Quick Wins) ✅ TERMINÉ

| Priorité | Plante/Feature            | Travail Requis                       | État  |
|----------|---------------------------|--------------------------------------|-------|
| P1       | **SunShroom Growth**      | Timer dans SunflowerProductionSystem | ✅ Déjà implémenté |
| P1       | **GloomShroom 8-way**     | `fireAllDirections()` ajouté         | ✅ Implémenté |
| P1       | **DoomShroom Crater**     | `GridService.BlockCell()` ajouté     | ✅ Implémenté |
| P1       | **CoffeeBean Wake**       | PlacementSystem + MushroomSystem     | ✅ Déjà implémenté |
| P1       | **TallNut BlocksJumpers** | `VaultedComponent` + CombatSystem    | ✅ Implémenté |

**Sprint 1 complété!**

### 🌱 Sprint 2 : Systèmes Manquants Simples ✅ TERMINÉ

| Priorité | Feature                     | Système à créer                       | État   |
|----------|-----------------------------|---------------------------------------|--------|
| P2       | **Garlic DivertsZombies**   | TrapSystem complet                    | ✅ Implémenté |
| P2       | **Pumpkin Stacking**        | ShellComponent + CombatSystem         | ✅ Implémenté |
| P2       | **Marigold CoinProduction** | CoinProductionSystem créé             | ✅ Implémenté |
| P2       | **Water Lane Validation**   | PlacementSystem (déjà fait)           | ✅ Implémenté |

**Sprint 2 complété!**

### 🚀 Sprint 3 : Features Avancées ❌ EN ATTENTE

| Priorité | Feature                   | Complexité                        | Effort | Status |
|----------|---------------------------|-----------------------------------|--------|--------|
| P3       | **Cattail Homing**        | HomingProjectileSystem            | 6h     | ❌ Non commencé |
| P3       | **CobCannon Manual Fire** | UI click + targeting              | 8h     | ❌ Non commencé |
| P3       | **HypnoShroom**           | Retourner zombie = faction change | 6h     | ❌ Non commencé |
| P3       | **Fog System**            | Visibilité + Plantern + Blover    | 8h     | ✅ **Implémenté** (FogSystem.luau + FogController.luau) |
| P3       | **Flying Zombies**        | CanHitFlying validation           | 6h     | ⚠️ Flag existe, zombies manquants |

**Effort restant Sprint 3:** ~20h (Fog fait, reste homing + cobcannon + hypno)

### 🏆 Sprint 4 : Cosmétiques & Polish ❌ EN ATTENTE

| Priorité | Feature                     | Type                       | Effort | Status |
|----------|-----------------------------|----------------------------|--------|--------|
| P4       | **Imitater Clone**          | UI + spawn duplicate       | 6h     | ❌ Non commencé |
| P4       | **GraveBuster + Graves**    | Night level mechanics      | 8h     | ❌ Non commencé |
| P4       | **UmbrellaLeaf Deflect**    | Catapult zombie protection | 4h     | ❌ Non commencé |
| P4       | **GoldMagnet Auto-collect** | Coin attraction range      | 3h     | ❌ Non commencé |

**Effort total Sprint 4:** ~21h

---

## 🏗️ ARCHITECTURE SYSTÈME (COMPLÈTE)

### Services Arena (13 fichiers)

| Service | Rôle | Status |
|---------|------|--------|
| ArenaService | Lifecycle battle, config monde/difficulté | ✅ |
| FogService | Fog zone management | ✅ (NEW) |
| GridService | Occupancy tracking, blocking, plant limits | ✅ |
| LightingService | Presets éclairage par monde | ✅ |
| MapLoader | Chargement dynamique maps | ✅ |
| MutationService | Cache mutations joueur | ✅ |
| PlantFoodService | Charges Plant Food (0-3) | ✅ |
| PlayerDataService | Persistence ProfileStore | ✅ |
| ServerEventBus | Event pub/sub pour reactions | ✅ |
| StatsService | Statistiques session | ✅ |
| SunService | Économie soleil joueur | ✅ |
| TileModifierService | Tile modifiers (craters, fire, ice) | ✅ (NEW) |
| WaveService | État vagues, orchestration | ✅ |

### Systèmes Client Arena (7 fichiers)

| Système | Priorité | Status |
|---------|----------|--------|
| PlacementPreviewSystem | 50 | ✅ Ghost preview, validation visuelle |
| EffectsSystem | 350 | ✅ VFX/Audio, music dynamique |
| GridRenderingSystem | 350 | ✅ Debug grid |
| SunRenderingSystem | 400 | ✅ Collection optimiste |
| PlantRenderingSystem | 405 | ✅ Modèles, animations |
| ZombieRenderingSystem | 410 | ✅ Interpolation, fog visibility |
| ProjectileRenderingSystem | 420 | ✅ Trails, impacts |

### Lobby Implémentation

| Catégorie | Fichiers | Status |
|-----------|----------|--------|
| **Services Serveur** | LobbyService, PlayerDataService | ✅ 100% |
| **Managers Serveur** | 6 managers (Countdown, Broadcaster, Queue, Touch, Lock, Teleport) | ✅ 100% |
| **Handlers Serveur** | MutationHandler, PadConfigReader, ShopHandler | ✅ 100% |
| **Controllers Client** | 6 controllers (HUD, Pad, Zone, Tooltip, Visibility, DeckBuilder) | ✅ 100% |
| **UI Organisms** | 7 écrans (Lobby, Profile, Shop, Deck, Mutation, Unlocks, SeedBank) | ✅ 100% |

---

## 📏 CONVENTIONS DE DÉGÂTS (VALIDÉES)

| Référence    | Valeur PlantData | Équivalent    |
|--------------|------------------|---------------|
| 1 pea        | 20 dmg           | Dégât de base |
| 1 cabbage    | 40 dmg           | 2 peas        |
| 1 melon      | 80 dmg           | 4 peas        |
| Instant-kill | 1800 dmg         | 90 peas       |
| Splash melon | 40 dmg (50%)     | 2 peas        |

---

## 🎯 PROCHAINES ÉTAPES RECOMMANDÉES

### ✅ Sprint 3 COMPLÉTÉ

Les systèmes suivants étaient marqués comme non-implémentés mais sont en fait **DÉJÀ COMPLETS** :

1. **✅ Cattail Homing Projectiles** - `fireHomingProjectile()` + `HomingComponent` + tracking dans `ProjectileMovementSystem`
2. **✅ CobCannon Manual Fire** - `CobCannonAbility.luau` + `CobCannonFireRequest` network handler
3. **✅ HypnoShroom** - `HypnotizedComponent` + CombatSystem toggle faction + `ZombieMovementSystem` reverse
4. **✅ Flying Zombies** - Balloon zombie dans `ZombieData`, `CanHitFlying` dans CombatSystem, `IsFlying` check
5. **✅ Water Platform System** - `PlacementSystem` valide `RequiresWater`, `IsWaterPlatform`, `RequiresLilyPad`
6. **✅ GloomShroom 8-way** - `fireAllDirections()` dans ProjectileSpawnSystem
7. **✅ CoffeeBean Wake** - `PlantActionEvent("WakeMushroom")` + MushroomSystem handler
8. **✅ ExplodeONut** - `handleDeathExplosion()` ajouté dans EntityDeathSystem

### 🟡 Plantes restantes à implémenter (4)

| Plante | Mécanique | Effort | Notes |
|--------|-----------|--------|-------|
| **UmbrellaLeaf** | `DeflectsProjectiles` | 4h | Nécessite catapult zombies |
| **GoldMagnet** | `CollectsCoins` | 3h | Auto-collect coins in range |
| **GraveBuster** | `RemovesGraves` | 4h | Nécessite grave spawning system |
| **Imitater** | `IsImitater` | 6h | Clone plant avec UI selection |

**Note:** Plantern est partiellement implémenté (FogSystem existe, zone illuminée à compléter)

**Effort total restant:** ~17h

### 🟢 Basse Priorité (Polish)

6. **GraveBuster + Graves** - Night levels
7. **UmbrellaLeaf Deflect** - Catapult protection
8. **GoldMagnet Auto-collect** - Coin attraction

---

## 📈 EPICS & MILESTONES (Timeline 20 Semaines)

| Phase | Epic | Semaines | Status |
|-------|------|----------|--------|
| **Phase 1** | Epic 1: ECS Skeleton | 1-2 | ✅ Complète |
| **Phase 1** | Epic 2: Grid & Deployment | 3-4 | ✅ Complète |
| **Phase 2** | Epic 3: Swarm Engine | 5-7 | ✅ Complète |
| **Phase 2** | Epic 4: The Arsenal | 8-10 | ✅ Complète |
| **Phase 3** | Epic 5: Progression Loop | 11-13 | ✅ Complète |
| **Phase 3** | Epic 6: "Juice" Injection | 14-16 | 🟡 En cours (VFX/Audio polish) |
| **Phase 4** | Epic 7: Monetization & Analytics | 17-18 | ❌ Non commencé |
| **Phase 4** | Epic 8: QA & Optimization | 19-20 | ❌ Non commencé |

### Post-Launch Roadmap

| Version | Contenu | Status |
|---------|---------|--------|
| V1.5 | Hard/Nightmare, Daily Challenges, Plant Mastery | ❌ Planifié |
| V2.0 | Worlds 2-4, Endless Mode, +20 zombies, +12 plants | ❌ Planifié |
| V2.5 | PvP Arena, Coop Mode (2-4 players) | ❌ Planifié |
| V3.0 | Roguelite Mode, Trading, Housing | ❌ Planifié |

---

## 📊 MÉTRIQUES TECHNIQUES

| Métrique | Cible | Actuel |
|----------|-------|--------|
| Entity Cap | 200 | ✅ SafeEntityCapSystem |
| FPS Target | 60 | ✅ 60 ticks/sec ECS |
| Bandwidth | <50 KB/s | ✅ Zap optimisé |
| LaneCache | O(1) | ✅ Implémenté |
| Strict Typing | 100% | ✅ `--!strict` partout |

---

> **Dernière mise à jour:** 22 Janvier 2026  
> **Source:** Analyse automatisée du codebase complet (5 agents)  
> **Stats:** 35 systèmes serveur, 13 services, 53 composants, 48 plantes  
> **Prochaine review:** Fin Sprint 4
