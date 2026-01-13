# 🌻 ROADMAP - Analyse Globale des Mécaniques de Plantes PvZ

> Référence basée sur les mécaniques officielles de Plants vs Zombies 1 & 2

---

## 📊 Référence des Stats Officielles PvZ 1 & 2

### 🎯 1. PLANTES OFFENSIVES (Shooters)

| Plante | Coût ☀️ | Recharge | Dégâts | Portée | Description Almanac |
|--------|---------|----------|--------|--------|---------------------|
| Peashooter | 100 | 7.5s (fast) | 20 | Lane | "Peashooters are your first line of defense" |
| Repeater | 200 | 7.5s (fast) | 20×2 | Lane | "Repeater fires two peas at a time" |
| Threepeater | 325 | 7.5s (fast) | 20×3 lanes | 3 lanes | "Threepeater's favorite number is 5" - Tire dans 3 allées |
| Gatling Pea | 250 (+200) | 50s (very slow) | 20×4 | Lane | Upgrade sur Repeater, nécessite achat |
| Snow Pea | 175 | 7.5s (fast) | 20 + slow | Lane | Ralentit les zombies |
| Cactus | 125 | 7.5s (fast) | 20 | Ground + Air | S'étire pour toucher les ballons |
| Starfruit | 125 | 7.5s (fast) | 20×5 directions | 5-Way | Tire dans 5 directions différentes |

### 🎃 2. PLANTES LOBBERS (Tir en cloche)

| Plante | Coût ☀️ | Recharge | Dégâts | Spécial | Description |
|--------|---------|----------|--------|---------|-------------|
| Cabbage-pult | 100 | 7.5s (fast) | 40 | Lobbed | "He just doesn't understand how zombies get on the roof" |
| Kernel-pult | 100 | 7.5s (fast) | 20/40 | 25% butter = stun | "Butter immobilizes zombies" |
| Melon-pult | 300 | 7.5s (fast) | 80 + 26 splash | Splash 3×1 | "Sun-for-damage, I deliver the biggest punch" |
| Winter Melon | 200 (+upgrade) | 7.5s | 80 + slow + splash | Upgrade | Version gelée du Melon-pult |

### 💣 3. PLANTES EXPLOSIVES / INSTANT-KILL

| Plante | Coût ☀️ | Recharge | Dégâts | Usage | Mécanique |
|--------|---------|----------|--------|-------|-----------|
| Potato Mine | 25 | 30s (slow) | 1800 | Single-use | 15s armement avant activation |
| Cherry Bomb | 150 | 50s (very slow) | 1800 (3×3) | Single-use | Explosion instantanée en zone |
| Squash | 50 (PvZ2) | 20s | 1800 | Single-use | Saute sur le zombie le plus proche, écrase |
| Jalapeno | 125 | 50s | 1800 (lane) | Single-use | Brûle toute la lane |
| Doom-shroom | 125 | 50s | 1800 (large) | Single-use | Cratère laissé après explosion |

### 🛡️ 4. PLANTES DÉFENSIVES

| Plante | Coût ☀️ | Recharge | HP | Spécial | Description |
|--------|---------|----------|-----|---------|-------------|
| Wall-nut | 50 | 30s (slow) | 4000 | - | Bloque les zombies |
| Tall-nut | 125 | 30s (slow) | 8000 | Block vault | Empêche les sauts |
| Pumpkin | 125 | 30s | 4000 | Protège plante | S'applique sur une autre plante |

### 🌻 5. PLANTES DE PRODUCTION

| Plante | Coût ☀️ | Recharge | Production | Intervalle |
|--------|---------|----------|------------|------------|
| Sunflower | 50 | 7.5s (fast) | 25☀️ | 24s |
| Twin Sunflower | 125 (+upgrade) | 50s | 50☀️ | 24s |
| Sun-shroom | 25 | 7.5s | 15☀️→25☀️→50☀️ | Grandit avec le temps |

### 😋 6. PLANTES INSTANT-KILL SPÉCIALES

| Plante | Coût ☀️ | Mécanique | Limitation |
|--------|---------|-----------|------------|
| Chomper | 150 | Dévore un zombie instantanément | 42s de mastication = vulnérable |
| Tangle Kelp | 25 | Noie un zombie aquatique | Pool uniquement |

---

## 🔧 MÉCANIQUES ESSENTIELLES À IMPLÉMENTER

### Phase 1 - Core Mechanics

#### ☀️ Sun Economy
- Production passive (ciel) + Sunflower
- Coût des plantes
- Recharge (cooldown par plante)

#### 🎯 Targeting System
- Lane-based targeting (LaneCache existant)
- Priorité : zombie le plus proche

#### 💥 Damage System
- Dégâts normaux (pea = 20 dmg base)
- Dégâts massifs (instant-kill = 1800 dmg)
- Splash damage (zone 3×1 pour melons)

### Phase 2 - Plant Behaviors

| Comportement | Plantes concernées | Implémentation |
|--------------|-------------------|----------------|
| Projectile Shooter | Peashooter, Repeater, Cactus | ProjectileSystem + AttackComponent |
| Lobber | Cabbage, Kernel, Melon | LobberSystem avec arc de trajectoire |
| Multi-Lane | Threepeater, Starfruit | Multi-target avec LaneCache |
| Instant-Kill | Squash, Chomper, Potato Mine | OneShotSystem + cleanup |
| Delayed Activation | Potato Mine | ArmingComponent avec timer |
| Stun Effect | Kernel-pult (butter) | StunComponent sur zombies |
| Slow Effect | Snow Pea, Winter Melon | SlowComponent sur zombies |
| Upgrade | Gatling, Twin Sunflower, Winter Melon | PlantUpgradeSystem |

### Phase 3 - Advanced Mechanics

- **Plant Food (PvZ2)** - Capacités ultimes
- **Boosted Plants** - Buffs temporaires
- **Plant Leveling** - Progression des stats

---

## 📋 COMPARAISON AVEC L'IMPLÉMENTATION ACTUELLE

### ✅ Ce qui existe déjà dans le projet

- [x] Architecture ECS avec Matter
- [x] LaneCache pour targeting
- [x] Components de base (Health, Position, etc.)
- [x] Système de dégâts avec ECSUtils

### ❌ Ce qui manque (à implémenter)

- [ ] **PlantData.luau** - Données centralisées par plante
- [ ] **Descriptions d'almanac** pour chaque plante
- [ ] **Mécaniques spéciales :**
  - [ ] Butter stun du Kernel-pult
  - [ ] Multi-direction du Starfruit
  - [ ] Mastication du Chomper (cooldown bloquant)
  - [ ] Armement du Potato Mine (timer)
- [ ] **Système d'upgrade** pour les plantes évolutives
- [ ] **VFX par plante** (particules, sons)

---

## 🗺️ ROADMAP D'IMPLÉMENTATION

### Sprint 1 : Foundation

- [ ] Compléter `PlantData.luau` avec TOUTES les stats officielles
- [ ] Ajouter les descriptions d'almanac (fr/en)
- [ ] Normaliser les valeurs de dégâts (base 20 = 1 pea)

### Sprint 2 : Core Plants

- [ ] **Peashooter** (référence)
- [ ] **Sunflower** (économie)
- [ ] **Wall-nut** (défense)
- [ ] **Potato Mine** (instant-kill delayed)

### Sprint 3 : Variantes Shooter

- [ ] **Repeater** (×2)
- [ ] **Snow Pea** (slow)
- [ ] **Threepeater** (multi-lane)

### Sprint 4 : Lobbers

- [ ] **Cabbage-pult** (basic lobber)
- [ ] **Kernel-pult** (avec stun)
- [ ] **Melon-pult** (avec splash)

### Sprint 5 : Spéciaux

- [ ] **Squash** (jump attack)
- [ ] **Chomper** (devour + cooldown)
- [ ] **Starfruit** (5-way)

### Sprint 6 : Upgrades & Polish

- [ ] **Gatling Pea**
- [ ] **Twin Sunflower**
- [ ] **Winter Melon**
- [ ] **Plant Food system** (PvZ2)

---

## 📏 Conventions de Dégâts

| Référence | Valeur | Équivalent |
|-----------|--------|------------|
| 1 pea | 20 dmg | Dégât de base |
| 1 melon | 80 dmg | 4 peas |
| Instant-kill | 1800 dmg | 90 peas |
| Splash melon | 26 dmg | ~1.3 peas |

---

> **Note:** Cette roadmap est basée sur les mécaniques officielles de PvZ 1 & 2, adaptées à l'architecture ECS Roblox du projet Garden Swarm.
