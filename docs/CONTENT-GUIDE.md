# Guide: Comment Ajouter du Contenu

Ce guide explique comment ajouter des mondes, difficultés, plantes, etc.  
Le système est **DATA-DRIVEN**: modifiez UN SEUL fichier par type de contenu.

---

## 🌍 Ajouter un Monde

**Fichier:** `src/shared/data/WorldData.luau`

Ajouter une entrée dans la table `Worlds`:

```lua
monNouveauMonde = {
    Id = "monNouveauMonde",
    Name = "Mon Nouveau Monde",
    Description = "Description affichée dans l'UI",
    Order = 7,  -- Position dans la liste
    
    MapId = "Map_MonNouveauMonde",  -- Asset ID de la map
    Theme = "custom",
    Icon = "rbxassetid://123456",
    
    IsNight = false,
    HasWater = false,
    HasFog = false,
    IsRoof = false,
    
    ZombiePool = {"Basic", "Cone", "Bucket"},
    BossType = "Gargantuar",
    
    SunStarting = 50,
    RequiredLevel = nil,  -- nil = débloqué dès le début
},
```

**C'est tout !** Le monde apparaîtra automatiquement dans l'UI.

---

## ⚡ Ajouter une Difficulté

**Fichier:** `src/shared/data/DifficultyData.luau`

Ajouter une entrée dans la table `Difficulties`:

```lua
extreme = {
    Id = "extreme",
    Name = "Extrême",
    Description = "Pour les masochistes",
    Order = 6,
    
    Icon = "🔥",
    Color = Color3.fromRGB(255, 0, 0),
    
    WaveCount = 30,
    BaseBudget = 150,
    BudgetPerWave = 75,
    SpawnInterval = 1.0,
    
    ZombieHealthMult = 3.0,
    ZombieSpeedMult = 1.5,
    ZombieDamageMult = 2.0,
    
    HasBoss = true,
    BossWave = 15,
    
    CoinReward = 1000,
    XPReward = 500,
    CoinMultiplier = 3.0,
    
    SunDropInterval = 20,
},
```

---

## 🌱 Ajouter une Plante

> ⚠️ **2 fichiers à modifier** (limitation de Zap pour le réseau)

### Étape 1: Stats (PlantData.luau)

**Fichier:** `src/shared/data/PlantData.luau`

```lua
MaNouvellePlante = {
    Name = "Ma Nouvelle Plante",
    Cost = 150,
    Cooldown = 10,
    Health = 100,
    Damage = 25,
    AttackSpeed = 1.0,
    Range = 0,
    Description = "Description",
    Category = "Attacker",
    CanShoot = true,
},
```

### Étape 2: Réseau (packets.zap)

**Fichiers:** 
- `src/shared/network/packets.zap`
- `src/arena/packets.zap`
- `src/lobby/packets.zap`

Ajouter dans l'enum `PlantType` (ligne ~14):

```zap
type PlantType = enum { 
    -- ... existing plants ...
    MaNouvellePlante  -- Ajouter ici
}
```

### Étape 3 (optionnel): Déblocage

**Fichier:** `src/shared/data/ProgressionData.luau`

```lua
MaNouvellePlante = {
    Cost = 500,
    StarterPlant = false,
    Order = 49,
},
```

---

## 🧟 Ajouter un Zombie

> ⚠️ **2 fichiers à modifier**

### Étape 1: Stats (ZombieData.luau)

**Fichier:** `src/shared/data/ZombieData.luau`

```lua
MonNouveauZombie = {
    Health = 200,
    Speed = 2.0,
    Damage = 30,
    AttackSpeed = 1.0,
    Category = "Special",
    SpawnCost = 25,
},
```

### Étape 2: Réseau (packets.zap)

**Fichier:** `src/shared/network/packets.zap` (ligne ~31)

```zap
type ZombieType = enum { Basic, Cone, ..., MonNouveauZombie }
```

---

## 💎 Ajouter un Skin (Cosmétique)

**Fichier:** `src/shared/data/CosmeticData.luau`

**UN SEUL fichier à modifier:**

```lua
monSkin = {
    Id = "monSkin",
    PlantType = "Peashooter",
    Name = "Mon Super Skin",
    Description = "Trop stylé !",
    Rarity = "Epic",
    GemCost = 100,
    PrimaryColor = Color3.fromRGB(255, 0, 0),
},
```

---

## 🎨 Ajouter un Trail (Projectile)

**Fichier:** `src/shared/data/CosmeticData.luau`

Dans la table `ProjectileTrails`:

```lua
monTrail = {
    Id = "monTrail",
    Name = "Mon Trail",
    Description = "Effet cool",
    Rarity = "Rare",
    GemCost = 75,
    ParticleId = "mon_particle",
    Color = Color3.fromRGB(255, 100, 50),
},
```

---

## 📋 Résumé

| Contenu      | Fichier(s) à modifier                     | Complexité |
|--------------|-------------------------------------------|------------|
| Monde        | `WorldData.luau`                          | 1 fichier  |
| Difficulté   | `DifficultyData.luau`                     | 1 fichier  |
| Skin         | `CosmeticData.luau`                       | 1 fichier  |
| Trail        | `CosmeticData.luau`                       | 1 fichier  |
| Plante       | `PlantData.luau` + `packets.zap` (×3)     | 4 fichiers |
| Zombie       | `ZombieData.luau` + `packets.zap`         | 2 fichiers |

> 💡 Les mondes, difficultés et cosmétiques sont **100% data-driven** (1 fichier).  
> 💡 Les plantes/zombies nécessitent aussi `packets.zap` à cause de la sérialisation réseau Zap.

---

## Pourquoi packets.zap pour Plantes/Zombies ?

Zap utilise des **enums compilés** pour optimiser la bande passante réseau. Au lieu d'envoyer `"Peashooter"` (10 bytes), il envoie `3` (1 byte).

Alternative: Utiliser `string.utf8` au lieu d'enum (plus flexible mais moins performant).

---

## 🎨 Assets Visuels (Modèles & VFX)

Les assets visuels sont dans `ReplicatedStorage/Assets/`. Le code clone ces assets au runtime.

### Structure des Dossiers

```
ReplicatedStorage/Assets/
├── Plants/           # Modèles de plantes
│   ├── Peashooter/
│   ├── Sunflower/
│   └── ...
├── Zombies/          # Modèles de zombies
│   ├── Basic/
│   ├── Cone/
│   └── ...
├── Projectiles/      # Modèles de projectiles (VFX inclus)
│   ├── Pea/
│   ├── FrozenPea/
│   ├── FirePea/
│   └── ...
└── VFX/              # Effets partagés (explosions, etc.)
```

### Structure d'un Modèle de Plante

```
Peashooter (Model)
├── Root (Part) ─────────── PrimaryPart (invisible, anchored)
│   ├── Muzzle (Attachment)    → Position de tir
│   ├── Center (Attachment)    → Centre de masse
│   └── Overhead (Attachment)  → Position barre de vie
├── Visual (Model) ────────── Toutes les parties visibles
│   ├── Head (MeshPart)
│   ├── Body (MeshPart)
│   └── ...
├── VFX (Folder) ──────────── Effets visuels de la plante
│   ├── Shoot (ParticleEmitter)  → Muzzle flash au tir
│   ├── Idle (ParticleEmitter)   → Effet constant (ex: lueur)
│   └── Death (ParticleEmitter)  → Effet à la mort
└── [Attributes]
    ├── EntityType = "Plant"
    └── FeetOffset = 0
```

### Structure d'un Modèle de Projectile

```
Pea (Model)
├── Root (Part) ─────────── PrimaryPart (la balle visible)
│   ├── Attachment0 (Attachment)  → Point arrière du Trail
│   └── Attachment1 (Attachment)  → Point avant du Trail
├── Trail (Trail) ──────────── Effet de traînée (optionnel)
│   ├── Attachment0 → Attachment0
│   ├── Attachment1 → Attachment1
│   ├── Color = ColorSequence
│   ├── Lifetime = 0.2
│   └── WidthScale = NumberSequence
└── Particles (ParticleEmitter) ─ Particules additionnelles (optionnel)
    [Attributes]
    └── Speed = 15  → Vitesse du projectile (override code)
```

### Types de Projectiles (Variants)

| Variant | Description | Effet Visuel |
|---------|-------------|--------------|
| `Pea` | Pois standard | Vert, trail léger |
| `FrozenPea` | Pois glacé (SnowPea) | Bleu, trail glacé, particules glace |
| `FirePea` | Pois enflammé (Torchwood) | Orange/rouge, trail feu, neon |
| `Spore` | Spore champignon (PuffShroom) | Violet clair, petit |
| `Fume` | Fumée (FumeShroom) | Violet foncé, ForceField |
| `Cabbage` | Chou (CabbagePult) | Vert, grosse balle |
| `Kernel` | Maïs (KernelPult) | Jaune, petit |
| `Butter` | Beurre - stun (KernelPult) | Jaune vif, carré |
| `Melon` | Melon (MelonPult) | Vert strié, gros |
| `Star` | Étoile (Starfruit) | Jaune neon, plat |
| `Spike` | Épine (Cactus) | Vert foncé, allongé |
| `Seed` | Graine générique | Marron, petit |

### Fallback Automatique

Si un asset n'existe pas dans `Assets/Projectiles/`, le code crée un **Part simple** avec les propriétés par défaut:
- Couleur basée sur le variant
- Material approprié (Ice, Neon, etc.)
- Pas de Trail

> 💡 **Tip:** Créez d'abord les assets prioritaires (Pea, FrozenPea, FirePea) puis ajoutez les autres progressivement.

### Contrat Spatial (Attachments)

Les Attachments sont le **contrat entre Artistes et Code**:

| Attachment | Usage | Obligatoire |
|------------|-------|-------------|
| `Muzzle` | Position de tir des projectiles | Oui (plantes qui tirent) |
| `Center` | Centre de masse, effets | Oui |
| `Overhead` | Barre de vie, indicateurs | Oui |
| `Torso` | Point de ciblage zombie | Zombies uniquement |

> ⚠️ **INTERDIT:** `Position + Vector3.new(0, 2, 0)` dans le code  
> ✅ **CORRECT:** `AttachmentUtils.GetWorldPosition(model, "Muzzle")`
