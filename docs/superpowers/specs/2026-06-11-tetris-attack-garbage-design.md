# Swap & Clash — Garbage fidèle à Tetris Attack (refonte étape 2)

## Contexte et décision de design

L'étape 2 a introduit un système de garbage avec **file d'attente invisible + télégraphe +
annulation numérique + counter** (`pending_garbage`, `_send_garbage` avec cancel FIFO,
`TELEGRAPH_DURATION`). Cette spec **remplace** ce système par le modèle de garbage **fidèle à
Tetris Attack / Panel de Pon**.

### Pourquoi ce changement (vérifié par recherche)

La mécanique d'offsetting (réduire le garbage entrant avec sa propre chaîne, renvoyer le
surplus) **ne vient pas de Tetris Attack**. C'est l'**offsetting (相殺 *sōsai*)**, introduit
par **Puyo Puyo Tsu (Puyo Puyo 2), 1994** (Compile), puis repris dans le Tetris compétitif
moderne (Tetris Friends, **Tetris 99**, Puyo Puyo Tetris). Le premier Puyo Puyo (1991) ne
l'avait pas.

**Tetris Attack (1995)** et toute la famille **Panel de Pon** — qui inclut **Pokémon Puzzle
League (N64)** et **Pokémon Puzzle Challenge (GBC)**, même moteur — utilisent un modèle
**différent** : le garbage **tombe** sur le plateau adverse, et la défense passe par la
**conversion** (casser le garbage le transforme en panneaux) + le **timing** des attaques. Le
"counter" émerge naturellement : on convertit le garbage reçu en une chaîne qui renvoie une
attaque.

**Objectif** : qu'un joueur de Tetris Attack / Pokémon Puzzle retrouve exactement le même jeu
et les mêmes sensations, au plus près du frame-perfect.

### Légende de fiabilité

- ✅ **confirmé** par sources communautaires (voir Sources).
- 🔶 **reconstruit** : extrapolation cohérente non documentée noir sur blanc → à caler en
  playtest contre une capture émulateur.

---

## Section 1 — Calcul du garbage envoyé

Le board calcule le garbage à partir des matchs résolus. Deux types coexistent et peuvent être
envoyés ensemble dans une même cascade.

### Garbage de COMBO (blocs plats, hauteur 1)

Un **combo** = `N` panneaux effacés en une seule vague de résolution (`N ≥ 4`). La largeur
totale de garbage est `W = N − 1`. Si `W ≤ 6` (largeur du plateau) → un seul bloc `W×1`. Si
`W > 6` → deux blocs aussi égaux que possible : `floor(W/2)×1` et `ceil(W/2)×1`.

| Combo | Garbage | Statut |
|---|---|---|
| 4 | `3×1` | ✅ |
| 5 | `4×1` | ✅ |
| 6 | `5×1` | ✅ |
| 7 | `6×1` | ✅ |
| 8 | `3×1` + `4×1` | ✅ |
| 9 | `4×1` + `4×1` | ✅ |
| 10 | `4×1` + `5×1` | 🔶 |
| 11 | `5×1` + `5×1` | 🔶 |
| 12 | `5×1` + `6×1` | 🔶 |
| 13 | `6×1` + `6×1` | 🔶 |

Règle générale (combo `N ≥ 4`) :

```
W = N - 1
si W <= 6 : [ {w: W, h: 1} ]
sinon     : [ {w: floor(W/2), h: 1}, {w: ceil(W/2), h: 1} ]
```

Pour `W > 12` (combo ≥ 14, très rare) : étendre à 3 blocs ou plus, chacun ≤ 6, répartis aussi
également que possible. 🔶 (non observé en jeu, garde-fou).

### Garbage de CHAÎNE (pavés pleine largeur, 6 colonnes)

Une **chaîne** de longueur `X` (`X ≥ 2`) → **un seul** pavé `6 × (X − 1)`, dimensionné sur la
longueur **finale** de la chaîne et envoyé **une seule fois**, quand la chaîne se termine (pas
un pavé par maillon).

| Chaîne | Garbage | Statut |
|---|---|---|
| x2 | `6×1` | ✅ |
| x3 | `6×2` | ✅ |
| x4 | `6×3` | ✅ |
| xN | `6×(N−1)` | ✅ (formule) |

Hauteur plafonnée à `VISIBLE_ROWS − 1` (marge de sécurité).

### Combo ET chaîne simultanés

Une même cascade de résolution peut produire les deux :

- **Combos** : pour **chaque vague** de la cascade où `combo_size ≥ 4`, on émet immédiatement
  le(s) bloc(s) plat(s) correspondant(s).
- **Chaîne** : on suit la longueur max atteinte ; à la **fin** de la cascade, si `chain_max ≥
  2`, on émet **un** pavé `6×(chain_max − 1)`.

C'est ce qui produit l'image des grosses parties : plusieurs blocs gris distincts (plats +
pavé) arrivant chez l'adversaire.

---

## Section 2 — Arrivée et chute du garbage

**Pas de file d'attente, pas de télégraphe, pas d'annulation.** Le garbage produit par un board
est routé vers l'adversaire et **apparaît directement en haut de son plateau, puis tombe**.

- **Apparition** : chaque bloc surgit dans les rangées du haut (au-dessus de la pile visible)
  et **descend par gravité** (réutilise la gravité multi-cellules existante) jusqu'à se poser
  sur la pile.
- **Pavés de chaîne** (largeur 6) : occupent toute la largeur, pas de choix de colonne.
- **Blocs plats de combo** (étroits) : se posent à une position horizontale tirée au sort
  (`c0 = randi() % (GRID_WIDTH - w + 1)`). 🔶 Le placement exact du jeu original n'est pas
  documenté ; le hasard est le défaut, ajustable.
- **Blocs multiples** : s'empilent en haut dans l'ordre d'arrivée.
- **Zone d'apparition occupée** : si les rangées du haut nécessaires sont occupées, le bloc
  **attend juste au-dessus** qu'une place se libère, puis tombe. Ce n'est **pas** une file
  d'offsetting : aucun timer, aucune annulation — c'est uniquement de la place qui manque.
- **Délai sensoriel** : court délai entre le clear de l'envoyeur et l'apparition chez
  l'adversaire (`GARBAGE_ARRIVAL_DELAY_FRAMES`, quelques frames), pas un télégraphe de 2 s.

### Structure d'état (remplace `pending_garbage`)

```gdscript
# Blocs reçus en attente d'apparition (faute de place en haut uniquement).
var incoming_garbage: Array = []  # éléments: {w: int, h: int}
```

`_update_incoming_garbage()` (appelé dans `_process`, hors `is_resolving`) tente de faire
apparaître le plus ancien bloc en tête de `incoming_garbage` dès que sa zone d'apparition est
libre, puis le retire de la liste. Aucun décompte de temps, aucune annulation.

---

## Section 3 — Conversion (cœur défensif de TA)

Quand un match de panneaux normaux est **adjacent** (4-voisinage) à un bloc garbage :

1. Tout le bloc garbage en contact **clignote** (`CONVERSION_FLASH_FRAMES`).
2. Il se **transforme en panneaux colorés normaux**, **rangée par rangée, du bas vers le
   haut**, à raison de `CONVERSION_FRAMES_PER_LAYER` (~1 s/couche ✅).
3. Au fur et à mesure, chaque rangée révélée **devient active, tombe et peut enchaîner** → le
   garbage adverse devient une **ressource** pour la contre-attaque.
4. **Un seul match déclencheur convertit le bloc entier** (progressivement), pas une couche par
   match.

### Changement vs code actuel

`_shatter_garbage_bottom_row(g)` ne convertit qu'**une** rangée par match (il faut 3 matchs
pour vider un `6×3`). On le remplace par `_convert_garbage_block(g)` qui convertit **tout le
bloc** progressivement (bas → haut), chaque rangée devenant des `Block` de couleur aléatoire en
état `FALLING` susceptibles de prolonger la chaîne.

🔶 Ambiguïté de source : une formulation wiki dit « multiple layers must be cleared one by one »
tandis qu'une autre décrit « all the garbage in contact transforms bottom to top » depuis un
seul trigger. On retient **un seul trigger convertit tout** (comportement qui fait du garbage un
fuel, signature de TA) — à confirmer en playtest.

---

## Section 4 — Changements concrets vs code étape 2

| Élément actuel | Action |
|---|---|
| `pending_garbage: Array` + `TELEGRAPH_DURATION` | ❌ supprimer |
| `_send_garbage(power)` (cancel FIFO) | ❌ supprimer l'annulation |
| `_update_garbage_queue(delta)` | ♻️ → `_update_incoming_garbage()` (apparition dès place libre) |
| `_garbage_power_for(combo, chain) -> int` | ♻️ → `_garbage_combo_pieces(combo_size) -> Array` + logique chaîne en fin de cascade |
| `_garbage_shape_for_power(power)` | ❌ supprimer (plus de notion de « power ») |
| `signal garbage_sent(power: int)` | ♻️ → `signal garbage_sent(pieces: Array)` (Array de `{w, h}`) |
| `receive_garbage(power)` | ♻️ → `receive_garbage(pieces: Array)` (empile dans `incoming_garbage`) |
| `_shatter_garbage_bottom_row(g)` | ♻️ → `_convert_garbage_block(g)` (bloc entier, progressif) |
| `_resolve_matches` : combo **OU** chain | ♻️ combo par vague **ET** pavé chaîne en fin de cascade |
| `match.gd` : `garbage_sent` → `receive_garbage` | ♻️ adapter à la signature `Array` |

**Conservé** : intégration `GarbageBlock` dans `grid`, gravité multi-cellules
(`_garbage_drop_distance`, `_move_garbage_block`), montée (`_do_rise_step`), visuels.

### Émission combo/chaîne dans `_resolve_matches`

```
_resolve_matches():
  matches = _find_matches()
  si vide:
     # fin de cascade
     si chain_max >= 2: garbage_sent.emit([ {w:6, h: chain_max-1} ])
     chain_count = 0 ; chain_max = 0
     return
  chain_count += 1
  chain_max = max(chain_max, chain_count)
  combo_size = matches.size()
  ... score, flash, clear ...
  si combo_size >= 4:
     garbage_sent.emit(_garbage_combo_pieces(combo_size))   # blocs plats, cette vague
  ... conversion des garbage adjacents (bloc entier) ...
  await _apply_gravity()
  await _resolve_matches()
```

`chain_max` est une nouvelle variable d'instance, remise à 0 en même temps que `chain_count`
(début de cascade dans `_try_swap`, et fin de cascade ci-dessus).

> Note : combo et chaîne sont émis comme **deux signaux séparés** (un par vague pour les combos,
> un en fin de cascade pour la chaîne). `match.gd` route chaque émission vers
> `receive_garbage` de l'adversaire, qui empile les pièces.

---

## Section 5 — Constantes de timing (frames @60fps)

Le jeu original tourne à 60 FPS. Les délais sont exprimés en **frames**, convertis pour Godot
par `frames / 60.0`. ⚠️ Aucune source wiki ne donne le frame data exact : ces valeurs sont des
points de départ à **caler sur capture émulateur** en playtest.

| Constante | Défaut (frames) | Statut |
|---|---|---|
| `CONVERSION_FRAMES_PER_LAYER` | 60 (~1 s) | ✅ « roughly 1s/layer » |
| `CONVERSION_FLASH_FRAMES` | 36 | 🔶 |
| `GARBAGE_FALL_FRAMES_PER_CELL` | 4 | 🔶 |
| `GARBAGE_ARRIVAL_DELAY_FRAMES` | 6 | 🔶 |

Les constantes existantes (`FLASH_DURATION`, `CLEAR_DURATION`, `FALL_DURATION_PER_CELL`,
`RISE_SPEED_*`, `SWAP_DURATION`) restent ; idéalement on les réexprime aussi en frames pour la
cohérence, mais ce n'est pas bloquant pour cette refonte.

---

## Hors scope / à caler en playtest

- Valeurs 🔶 reconstruites des combos 10–13 et des combos ≥ 14.
- Placement horizontal exact des blocs plats de combo à l'arrivée (défaut : aléatoire).
- Frame data exact de la conversion, de la chute et du délai d'arrivée (calibrer sur émulateur).
- Comportement exact « un trigger convertit tout » vs « couche par couche » (retenu : tout).
- Multijoueur en ligne (étape ultérieure).
- Vitesse de montée / difficulté progressive façon TA (équilibrage séparé).

---

## Sources

- [Garbage Blocks — Tetris Attack Wiki (Fandom)](https://tetrisattack.fandom.com/wiki/Garbage_Blocks)
- [Tetris Attack — Hard Drop Tetris Wiki](https://harddrop.com/wiki/Tetris_Attack)
- [Gameplay Guide — Tetris Attack](https://tetrisattack.com/gameplay)
- [Tetris Attack/Combos — StrategyWiki](https://strategywiki.org/wiki/Tetris_Attack/Combos)
- [Garbage — TetrisWiki](https://tetris.wiki/Garbage)
- [Offset rule — Puyo Nexus Wiki](https://puyonexus.com/wiki/Offset_rule)
- [Puyo Puyo 2 (Puyo Puyo Tsu) — Wikipedia](https://en.wikipedia.org/wiki/Puyo_Puyo_2)
- [Pokémon Puzzle League — Bulbapedia](https://bulbapedia.bulbagarden.net/wiki/Pok%C3%A9mon_Puzzle_League)
- [Pokémon Puzzle Challenge — Wikipedia](https://en.wikipedia.org/wiki/Pok%C3%A9mon_Puzzle_Challenge)
