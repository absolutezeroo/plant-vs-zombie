# 🌻 ROADMAP - Garden Swarm - État d'Implémentation des Plantes

> Roadmap basée sur l'analyse complète de `PlantData.luau` (49 plantes) et des Systems existants

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
| **Cactus**      | 125     | 20      | `CanHitFlying`                  | ⚠️ Partiel       | Flag existe, flying zombies?                  |
| **Cattail**     | 225     | 20      | `IsHoming`, `RequiresLilyPad`   | ❌ Non implémenté | Système homing manquant                       |

### 🎃 2. CATAPULTES / LOBBERS (5 plantes)

| Plante          | Coût ☀️ | Dégâts  | Mécanique                                | État             | Notes                          |
|-----------------|---------|---------|------------------------------------------|------------------|--------------------------------|
| **CabbagePult** | 100     | 40      | `IsCatapult`                             | ✅ Implémenté     | Projectiles en arc             |
| **KernelPult**  | 100     | 20      | `CanStun`, `StunChance=0.2`              | ✅ Implémenté     | StunComponent + Butter variant |
| **MelonPult**   | 300     | 80      | `HasSplash`, `SplashRadius=3`            | ✅ Implémenté     | SplashComponent ajouté         |
| **WinterMelon** | 500     | 80+slow | `IsFrozen` + `HasSplash`                 | ✅ Implémenté     | Combo splash+freeze            |
| **CobCannon**   | 500     | 1800    | `IsManualFire`, `RequiresTwoKernelPults` | ❌ Non implémenté | UI click-to-fire manquant      |

### 💣 3. EXPLOSIVES / INSTANT-KILL (7 plantes)

| Plante         | Coût ☀️ | Dégâts | Mécanique                         | État         | Notes                                  |
|----------------|---------|--------|-----------------------------------|--------------|----------------------------------------|
| **CherryBomb** | 150     | 1800   | `ExplodesOnPlace`, `FuseTime=0.5` | ✅ MVP        | SpecialPlantSystem                     |
| **PotatoMine** | 25      | 1800   | `NeedsArming`, `ArmDuration=20`   | ✅ MVP        | ArmedComponent fonctionne              |
| **Jalapeno**   | 125     | 1800   | `IsLaneWide`                      | ✅ Implémenté | Brûle toute la lane                    |
| **DoomShroom** | 125     | 1800   | `LeavesCrater`                    | ✅ Implémenté | Explosion + cratère bloque placement   |
| **IceShroom**  | 75      | 20     | `FreezesAll`, `FreezeDuration=4`  | ✅ Implémenté | Gèle tous les zombies                  |
| **Squash**     | 50      | 1800   | `JumpsToTarget`                   | ✅ Implémenté | Animation saut dans SpecialPlantSystem |
| **TangleKelp** | 25      | 1800   | `IsInstantKill`, `RequiresWater`  | ⚠️ Partiel   | Logique OK, placement eau à valider    |

### 😋 4. INSTANT-KILL SPÉCIAUX (1 plante)

| Plante      | Coût ☀️ | Dégâts | Mécanique                          | État         | Notes                          |
|-------------|---------|--------|------------------------------------|--------------|--------------------------------|
| **Chomper** | 150     | 1800   | `IsInstantKill`, `ChewDuration=42` | ✅ Implémenté | ChewingComponent bloque le tir |

### 🛡️ 5. DÉFENSIVES (5 plantes)

| Plante          | Coût ☀️ | HP  | Mécanique                    | État             | Notes                                   |
|-----------------|---------|-----|------------------------------|------------------|-----------------------------------------|
| **WallNut**     | 50      | 400 | Défense de base              | ✅ MVP            | Bloqueur simple                         |
| **TallNut**     | 125     | 800 | `BlocksJumpers`              | ✅ Implémenté     | Pole Vaulter ne peut pas sauter         |
| **Pumpkin**     | 125     | 400 | `IsShell`, `CanStackOnPlant` | ❌ Non implémenté | Système stacking manquant               |
| **Garlic**      | 50      | 200 | `DivertsZombies`             | ⚠️ Partiel       | TODO dans TrapSystem (lane switch)      |
| **ExplodeONut** | 50      | 400 | `ExplodesOnDeath`            | ⚠️ Partiel       | Logique dans SpecialPlantSystem         |

### 🌻 6. PRODUCTEURS (4 plantes)

| Plante            | Coût ☀️ | Production | Mécanique                   | État             | Notes                         |
|-------------------|---------|------------|-----------------------------|------------------|-------------------------------|
| **Sunflower**     | 50      | 25☀️/30s   | `ProducesSun`, `SunCount=1` | ✅ MVP            | SunflowerProductionSystem     |
| **TwinSunflower** | 150     | 50☀️/24s   | `SunCount=2`                | ✅ Implémenté     | Double production             |
| **SunShroom**     | 25      | 15→25☀️    | `GrowthTime=120`            | ⚠️ Partiel       | Croissance à implémenter      |
| **Marigold**      | 50      | Coins      | `ProducesCoins`             | ❌ Non implémenté | CoinProductionSystem manquant |

### 🍄 7. CHAMPIGNONS (7 plantes)

| Plante            | Coût ☀️ | Mécanique Spéciale              | État             | Notes                                   |
|-------------------|---------|---------------------------------|------------------|-----------------------------------------|
| **PuffShroom**    | 0       | `Range=18` (court)              | ✅ Implémenté     | Range limité dans ProjectileSpawnSystem |
| **SeaShroom**     | 0       | `RequiresWater`                 | ⚠️ Partiel       | Validation eau à compléter              |
| **FumeShroom**    | 75      | `PiercesShields`                | ✅ Implémenté     | Flag dans ProjectileComponent           |
| **ScaredyShroom** | 25      | `HidesWhenNear`, `HideRadius=6` | ✅ Implémenté     | HidingComponent + MushroomSystem        |
| **HypnoShroom**   | 75      | `HypnotizesOnDeath`             | ❌ Non implémenté | Retourne zombie = complexe              |
| **GloomShroom**   | 150     | `ShootsAllDirections`           | ⚠️ Partiel       | 8 directions à implémenter              |
| **CoffeeBean**    | 75      | `WakesMushrooms`                | ⚠️ Partiel       | SleepingComponent existe                |

### 🔧 8. SUPPORT / UTILITAIRES (9 plantes)

| Plante           | Coût ☀️ | Mécanique                                | État             | Notes                        |
|------------------|---------|------------------------------------------|------------------|------------------------------|
| **Torchwood**    | 175     | `EnhancesPeas`, `FireDamageMultiplier=2` | ✅ Implémenté     | EnhancementSystem complet    |
| **Plantern**     | 25      | `RemovesFog`                             | ❌ Non implémenté | Fog system manquant          |
| **Blover**       | 100     | `RemovesFlying`                          | ⚠️ Partiel       | Flying zombies à implémenter |
| **UmbrellaLeaf** | 100     | `DeflectsProjectiles`                    | ❌ Non implémenté | Catapult zombies?            |
| **GoldMagnet**   | 50      | `CollectsCoins`                          | ❌ Non implémenté | Coin system manquant         |
| **LilyPad**      | 25      | `IsWaterPlatform`                        | ⚠️ Partiel       | Platform system basique      |
| **FlowerPot**    | 25      | `IsGroundPlatform`                       | ⚠️ Partiel       | Pour niveaux roof            |
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
| Shooters     | 9      | 7            | 1            | 1                |
| Catapultes   | 5      | 4            | 0            | 1                |
| Explosives   | 7      | 5            | 2            | 0                |
| Instant-Kill | 1      | 1            | 0            | 0                |
| Défensives   | 5      | 1            | 3            | 1                |
| Producteurs  | 4      | 2            | 1            | 1                |
| Champignons  | 7      | 3            | 2            | 2                |
| Support      | 9      | 1            | 3            | 5                |
| Pièges       | 1      | 1            | 0            | 0                |
| **TOTAL**    | **48** | **25 (52%)** | **12 (25%)** | **11 (23%)**     |

---

## ✅ SYSTÈMES ECS EXISTANTS

### Combat Systems (`src/arena/server/systems/combat/`)
- ✅ `ProjectileSpawnSystem.luau` - Tir, multi-shot, 3-lane, 5-way, catapult
- ✅ `ProjectileMovementSystem.luau` - Déplacement projectiles
- ✅ `CombatSystem.luau` - Détection collision, dégâts
- ✅ `SpecialPlantSystem.luau` - Explosions, Squash, Chomper, PotatoMine
- ✅ `EnhancementSystem.luau` - Torchwood fire enhancement
- ✅ `PlantFoodSystem.luau` - Capacités ultimes
- ✅ `TrapSystem.luau` - Spikeweed + PopsTires fonctionnent, Garlic TODO
- ⚠️ `BossSystem.luau` - Pour zombies boss

### Unit Systems (`src/arena/server/systems/units/`)
- ✅ `MushroomSystem.luau` - Sleep, Hide, day/night cycle
- ✅ `PlacementSystem.luau` - Validation placement, coût, cooldown
- ✅ `EntityDeathSystem.luau` - Nettoyage entités mortes
- ✅ `ZombieMovementSystem.luau` - Mouvement zombies

### Economy Systems (`src/arena/server/systems/economy/`)
- ✅ `SunflowerProductionSystem.luau` - Production soleil
- ✅ `SunSpawnSystem.luau` - Spawn soleil du ciel
- ✅ `SunCollectionSystem.luau` - Collecte soleil

### Mutation Systems (`src/arena/server/systems/mutations/`)
- ✅ `FreezeSystem.luau` - Effets gel
- ✅ `BurnDamageSystem.luau` - Dégâts feu
- ✅ `SplashDamageSystem.luau` - Dégâts zone
- ✅ `ChainLightningSystem.luau` - Chaîne éclairs
- ✅ `LifestealSystem.luau` - Vol de vie
- ✅ `PoisonCloudSystem.luau` - Nuages poison

---

## 🔧 COMPONENTS DISPONIBLES

### Combat Components
- ✅ `ProjectileComponent` - IsFrozen, IsCatapult, CanStun, PiercesShields, CanHitFlying
- ✅ `ArmedComponent` - PotatoMine arming state
- ✅ `ChewingComponent` - Chomper busy state
- ✅ `HidingComponent` - ScaredyShroom hide state
- ✅ `SlowComponent` - Freeze/slow effects
- ✅ `StunComponent` - Butter stun
- ✅ `SplashComponent` - Area damage
- ✅ `EnhancedProjectileComponent` - Fire peas

### Unit Components
- ✅ `SleepingComponent` - Mushroom day sleep
- ✅ `PlantTypeComponent` - Plant type + lane
- ✅ `ShieldComponent` - Zombie shields
- ✅ `JumpingComponent` - Pole vaulter state

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

### 🌱 Sprint 2 : Systèmes Manquants Simples

| Priorité | Feature                     | Système à créer                       | Effort |
|----------|-----------------------------|---------------------------------------|--------|
| P2       | **Garlic DivertsZombies**   | Compléter TODO dans TrapSystem        | 3h     |
| P2       | **Pumpkin Stacking**        | CanStackOnPlant validation            | 4h     |
| P2       | **Marigold CoinProduction** | Nouveau CoinProductionSystem          | 3h     |
| P2       | **Water Lane Validation**   | RequiresWater, RequiresLilyPad        | 3h     |

**Effort total Sprint 2:** ~13h

### 🚀 Sprint 3 : Features Avancées

| Priorité | Feature                   | Complexité                        | Effort |
|----------|---------------------------|-----------------------------------|--------|
| P3       | **Cattail Homing**        | HomingProjectileSystem            | 6h     |
| P3       | **CobCannon Manual Fire** | UI click + targeting              | 8h     |
| P3       | **HypnoShroom**           | Retourner zombie = faction change | 6h     |
| P3       | **Fog System**            | Visibilité + Plantern + Blover    | 8h     |
| P3       | **Flying Zombies**        | CanHitFlying validation           | 6h     |

**Effort total Sprint 3:** ~34h

### 🏆 Sprint 4 : Cosmétiques & Polish

| Priorité | Feature                     | Type                       | Effort |
|----------|-----------------------------|----------------------------|--------|
| P4       | **Imitater Clone**          | UI + spawn duplicate       | 6h     |
| P4       | **GraveBuster + Graves**    | Night level mechanics      | 8h     |
| P4       | **UmbrellaLeaf Deflect**    | Catapult zombie protection | 4h     |
| P4       | **GoldMagnet Auto-collect** | Coin attraction range      | 3h     |

**Effort total Sprint 4:** ~21h

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

1. **Valider les plantes MVP** - Tester Sunflower, Peashooter, WallNut, PotatoMine, CherryBomb, Repeater, SnowPea
2. **Compléter Sprint 1** - Quick wins pour passer de 50% à 65% d'implémentation
3. **Ajouter ZombieData** - Balancer les plantes en fonction des zombies
4. **PlantFood polish** - Tester toutes les abilities dans PlantFoodData.luau
5. **VFX par plante** - Particules, sons, animations client

---

> **Dernière mise à jour:** Janvier 2026
> **Source:** Analyse de `src/shared/data/PlantData.luau` + Systems ECS
