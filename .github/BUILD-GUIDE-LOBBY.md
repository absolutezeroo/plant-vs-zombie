# Guide de Construction - Lobby 3D

## 📦 Structure Required dans Workspace

```
Workspace/
├── TeleportPads/           -- Folder contenant tous les pads
│   ├── Stage_1-1/          -- Un pad (nommez comme vous voulez)
│   │   ├── Platform        -- Part (touch detection)
│   │   ├── Billboard       -- Part (optionnel, point d'attache UI)
│   │   └── Configuration/  -- Folder avec configuration
│   │       ├── StageId     -- StringValue = "1-1"
│   │       ├── MinPlayers  -- IntValue = 1 (optionnel, default: 1)
│   │       └── MaxPlayers  -- IntValue = 4 (optionnel, default: 4)
│   ├── Stage_1-2/
│   └── Stage_1-3/
│
├── DeckBuilderZone/        -- Zone pour changer le deck (optionnel MVP)
│   └── ProximityPrompt     -- Prompt "Change Deck"
│
├── SpawnLocation           -- Spawn point joueur
│
└── [Votre map/décor]
```

---

## 🛠️ Instructions de Construction

### 1. Créer le Folder TeleportPads

1. Dans **Workspace**, créez un **Folder** nommé `TeleportPads`
2. C'est là que vous mettrez tous vos pads

---

### 2. Créer un Teleport Pad (Exemple: Stage 1-1)

#### Étape A : Créer le Model

1. Dans `TeleportPads`, insérez un **Model**
2. Nommez-le `Stage_1-1` (ou n'importe quel nom descriptif)

#### Étape B : Créer la Platform

1. Dans le Model, créez une **Part** nommée `Platform`
2. **Propriétés recommandées :**
   - Size: `(12, 1, 12)` (ajustez selon vos besoins)
   - Material: `Plastic` ou `SmoothPlastic`
   - Color: Vert pour débloqué, Rouge pour locked
   - CanCollide: `true`
   - Anchored: `true`
   - Transparency: `0` ou `0.2` (légèrement transparent)

#### Étape C : Créer la Configuration

1. Dans le Model, créez un **Folder** nommé `Configuration`
2. **Dans Configuration, créez :**

   **StageId (Required):**
   - Type: `StringValue`
   - Name: `StageId`
   - Value: `"1-1"` (correspond à un stage dans StageData)

   **MinPlayers (Optional):**
   - Type: `IntValue`
   - Name: `MinPlayers`
   - Value: `1` (nombre minimum pour start countdown)

   **MaxPlayers (Optional):**
   - Type: `IntValue`
   - Name: `MaxPlayers`
   - Value: `4` (nombre max de joueurs par match)

#### Étape D : Point d'Attache UI (Optional)

**Option 1 : Part séparée (recommandé)**
1. Dans le Model, créez une **Part** nommée `Billboard`
2. Propriétés:
   - Size: `(1, 1, 1)` (petite, invisible)
   - Transparency: `1` (invisible)
   - CanCollide: `false`
   - Anchored: `true`
   - Position: Au-dessus de la platform (Y + 5 studs)
3. Ajoutez une **Attachment** dans cette Part (le script la créera automatiquement si absente)

**Option 2 : Automatique**
- Si vous ne créez pas de Part "Billboard", le script utilisera la Platform et créera une Attachment 5 studs au-dessus

---

### 3. Dupliquer pour Autres Stages

1. Dupliquez le Model `Stage_1-1`
2. Renommez en `Stage_1-2`, `Stage_1-3`, etc.
3. **Dans chaque Configuration/StageId**, changez la valeur :
   - Stage_1-2 → `"1-2"`
   - Stage_1-3 → `"1-3"`
4. Positionnez les pads dans votre map

---

### 4. Créer DeckBuilderZone (Optional pour MVP)

1. Créez un **Model** ou **Part** nommé `DeckBuilderZone`
2. Ajoutez un **ProximityPrompt** dedans :
   - ActionText: `"Change Deck"`
   - ObjectText: `"Deck Builder"`
   - MaxActivationDistance: `10`
   - HoldDuration: `0`

**Note :** Pour MVP, cette fonctionnalité affichera juste un log. La vraie GUI Deck Builder viendra après.

---

### 5. SpawnLocation

1. Assurez-vous d'avoir un **SpawnLocation** dans votre map
2. Propriétés:
   - Neutral: `true` (tous les joueurs spawn ici)
   - Duration: `0` (pas de force respawn)

---

## 🎨 Conseils de Design

### Visuels des Pads

**Pad Standard (unlocked) :**
- Color: `Color3.fromRGB(50, 205, 50)` (Vert)
- Material: `Neon` ou `ForceField` pour effet brillant
- Add Particles (SparkleParticles) pour effet magique

**Pad Locked :**
- Color: `Color3.fromRGB(200, 50, 50)` (Rouge)
- Add chains/locks models pour visuels

**Pad Active (countdown) :**
- Animation: Glow pulsing (script fera ça plus tard)

### Layout des Pads

**Recommandations :**
- Espacement: 20-30 studs entre pads
- Organisation par monde (1-1, 1-2, 1-3 groupés ensemble)
- Signage : Ajoutez des SurfaceGuis avec le nom du stage
- Paths: Guidez les joueurs avec des chemins visibles

### Décor Optionnel

- **Shop Area** : Bâtiment avec panneau "Shop"
- **Profile Area** : Panneau "Player Stats"
- **Leaderboard** : Board avec top players (V2)
- **NPCs** : Zombies/Plants décoratifs (aucun script)

---

## ✅ Checklist Avant Test

### Minimum Viable (1 Pad Test)

- [ ] Folder `TeleportPads` existe dans Workspace
- [ ] Un Model avec `Platform` (Part)
- [ ] Configuration/StageId = `"1-1"`
- [ ] SpawnLocation existe

### Test Complet (3+ Pads)

- [ ] 3+ pads configurés (1-1, 1-2, 1-3)
- [ ] Chaque pad a un StageId différent
- [ ] MinPlayers/MaxPlayers configurés (ou defaults utilisés)
- [ ] Pads bien espacés et accessibles
- [ ] SpawnLocation bien positionné

---

## 🧪 Testing

### Test Solo

1. Play test dans Studio
2. Vous devriez spawn dans le monde (pas de GUI)
3. Marchez sur un pad
4. BillboardGui devrait apparaître : "Stage 1-1 | 1/4 Players"
5. Après 10 secondes : "Starting in 10..." countdown
6. À 0 : Téléportation vers Arena

### Test Multiplayer

1. Publiez le lobby place
2. Rejoignez avec 2 comptes
3. Les deux sur le même pad
4. Countdown devrait démarrer quand MinPlayers atteint
5. Téléportation groupée

---

## 🐛 Troubleshooting

### "No TeleportPads folder found"
- Vérifiez que le Folder `TeleportPads` existe dans Workspace (pas dans autre endroit)

### "Pad missing Platform part"
- Chaque Model doit avoir une Part nommée exactement `Platform`

### "Invalid StageId"
- Le StageId doit correspondre à un stage dans `StageData.luau`
- Vérifiez les typos : `"1-1"` pas `"1_1"` ou `"11"`

### "No BillboardGui appears"
- Vérifiez Output pour logs du PadUIController
- La Platform doit être accessible (pas dans un autre container)
- Essayez d'ajouter une Part "Billboard" avec Attachment

### "Countdown doesn't start"
- Vérifiez MinPlayers (default: 1)
- Regardez Output serveur pour logs LobbyService
- Le joueur doit rester sur le pad (pas AFK)

---

## 📝 Configuration Examples

### Pad Solo (Testing)
```
StageId = "1-1"
MinPlayers = 1
MaxPlayers = 1
```

### Pad Multiplayer Normal
```
StageId = "1-2"
MinPlayers = 2
MaxPlayers = 4
```

### Pad Hard Mode (V2+)
```
StageId = "1-1-hard"
MinPlayers = 2
MaxPlayers = 4
```

---

## 🚀 Prochaines Étapes

Après avoir construit la map :

1. **Test basic** : Un pad fonctionne
2. **Régénérer Zap** : `zap src/lobby/packets.zap`
3. **Test multiplayer** : Plusieurs pads
4. **Ajouter décor** : Ambiance, signs
5. **Polish UI** : Améliorer BillboardGui style
6. **Deck Builder** : Implémenter GUI de sélection
7. **Shop/Profile zones** : ProximityPrompts

---

**Besoin d'aide ?** Vérifiez Output dans Studio pour les logs détaillés de chaque système.
