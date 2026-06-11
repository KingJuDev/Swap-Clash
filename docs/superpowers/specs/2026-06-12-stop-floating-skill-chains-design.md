# Swap & Clash — Système STOP, floating et skill chains (refonte étape 3)

## Contexte et décision de design

Les étapes précédentes ont implémenté un moteur de résolution **synchrone et global** :
`_try_swap()` pose `is_resolving = true`, puis `_apply_gravity()` (snap instantané de
tout le plateau vers le bas) et `_resolve_matches()` (récursif : flash → clear →
gravité → re-check) s'enchaînent jusqu'à ce qu'il n'y ait plus de match. Pendant tout
ce temps, **le joueur ne peut rien faire** (input bloqué par `is_resolving`).

Cette spec remplace ce modèle par le modèle **fidèle à Tetris Attack / Panel de Pon** :
chaque bloc est une mini machine à états mise à jour en continu, frame par frame, ce
qui permet le **floating** (délai avant chute), la **chute continue revérifiée** (un
trou peut s'agrandir pendant qu'un bloc le traverse), les **skill chains** (le joueur
peut swapper pendant qu'une cascade se déroule ailleurs), et le **système STOP**
(pause de la montée après un combo/chaîne, prolongée en zone de danger).

**Objectif** : qu'un joueur de Tetris Attack / Pokémon Puzzle retrouve les mêmes
sensations de timing et de chaînes que l'original.

### Légende de fiabilité

- ✅ **confirmé** par sources communautaires (voir Sources).
- 🔶 **reconstruit** : extrapolation cohérente non documentée noir sur blanc → à caler
  en playtest contre une capture émulateur. La frame data précise du STOP et du
  floating n'est **pas publiquement disponible** (pages techniques bloquées/absentes
  au moment de la rédaction) ; seuls les *comportements* sont sourcés, les *valeurs
  numériques* sont toutes 🔶.

---

## Section 1 — Architecture cible : machine à états par cellule

### États `Block` (`scripts/block.gd`)

```gdscript
enum State { IDLE, SWAPPING, FLOATING, FALLING, MATCHED, CLEARING }

var from_chain: bool = false   # true si ce bloc tombe suite à un clear (maillon potentiel)
var float_timer: float = 0.0   # compte à rebours avant de passer en FALLING
```

`FLOATING` est un **nouvel état**. `from_chain` est un **nouveau champ**.

### États `GarbageBlock` (`scripts/garbage_block.gd`)

```gdscript
enum State { IDLE, FLOATING, FALLING, FLASHING }

var float_timer: float = 0.0
```

`FLOATING` est un nouvel état (`FLASHING` existe déjà pour la conversion).

### Transitions

```
IDLE ──(support disparaît)──► FLOATING ──(float_timer expiré)──► FALLING
FALLING ──(atterrit)──► IDLE ──(forme un match)──► MATCHED ──(flash fini)──► CLEARING ──► (case libérée)
IDLE ──(swap joueur)──► SWAPPING ──► IDLE
```

**Invariant clé** : dans ce jeu, la seule façon qu'une case perde son support vertical
est qu'un `clear` (match ou conversion garbage) libère la case du dessous — un swap
est toujours horizontal et ne peut pas créer de trou sous un autre bloc, et l'apparition
de garbage se fait en haut du plateau. **Donc toute transition `IDLE → FLOATING` est
par définition liée à un clear**, et `from_chain = true` est posé systématiquement à ce
moment-là (pas besoin de tracer l'origine plus finement).

---

## Section 2 — Floating et chute continue

✅ confirmé : après un clear, les blocs au-dessus tombent **après un délai** (le
floating), puis se déplacent à une vitesse constante (~1 case par frame côté
original). Le délai est plus court à difficulté élevée (non applicable ici, pas de
difficulté progressive pour l'instant).

### Mécanique

- `IDLE → FLOATING` : quand la case du dessous devient `null` (suite à un clear),
  `float_timer = FLOAT_DELAY`, `from_chain = true`.
- `FLOATING` : `float_timer -= delta` ; à `<= 0`, passage en `FALLING`. **Une seule
  fois** par "épisode de chute" — pas de re-floating entre deux cases pendant une
  chute continue.
- `FALLING` : déplacement **continu** (pixels/frame, pas un snap multi-cases). **Chaque
  frame**, on revérifie si la case suivante en dessous est libre :
  - libre → on continue de descendre (le trou peut s'être agrandi entre-temps si une
    autre chaîne se résout plus bas dans la même colonne — c'est ce qui permet les
    timings de skill chain) ;
  - occupée → atterrissage : snap à la position de grille, `state = IDLE`, déclenche
    la vérification de match (Section 3).
- `GarbageBlock` suit la même logique, appliquée comme bloc multi-cellules (toutes les
  colonnes qu'il couvre doivent avoir leur case libre pour qu'il continue à descendre).

### Conséquence sur `_do_rise_step()`

La montée doit décaler aussi les blocs en `FLOATING`/`FALLING` (comme elle le fait déjà
pour `GarbageBlock.origin`), et — comme aujourd'hui — ne s'exécute que si le plateau
est "stable" (Section 4).

---

## Section 3 — Détection de match continue, chaînes et skill chains

✅ confirmé :
- "Une chaîne se produit quand des blocs qui tombent suite à un clear atterrissent et
  forment immédiatement un nouveau match." Ce nouveau match est le maillon suivant.
- "Construire une chaîne pendant qu'elle est en train de se résoudre" = **skill chain**.
- La chaîne affichée plafonne à **x13** ; au-delà, affichage `x?` sans bonus de score.

### Mécanique

- À chaque frame, dès qu'un `Block` passe `FALLING → IDLE` (atterrissage), on relance
  `_find_matches()` sur tout le plateau (coût négligeable : grille 6×12).
- Si un nouveau match est détecté :
  - S'il contient **au moins une case `from_chain == true`** → c'est un **maillon de
    chaîne** : `chain_count += 1`.
  - Sinon (match provoqué uniquement par un swap joueur, sans bloc en chute liée à un
    clear) → **nouvelle chaîne** : `chain_count = 1` (pas de bonus chaîne, juste le
    combo).
  - `chain_max = max(chain_max, chain_count)`, `combo_max = max(combo_max, combo_size)`
    (`combo_max` est une **nouvelle variable**, comme `chain_max`, pour le calcul STOP
    — Section 4).
  - Les cases matchées passent en `MATCHED` (flash), puis `CLEARING` (clear), puis
    libérées → les blocs au-dessus passent en `FLOATING` avec `from_chain = true`
    (Section 2).
  - Si un bloc atterrit (`FALLING → IDLE`) **sans** faire partie d'un nouveau match,
    `from_chain` repasse à `false` : il est maintenant posé et stable, une future
    chute de ce bloc sera un nouvel "épisode" de chute (Section 2) réévalué
    indépendamment.
- **Fin de chaîne** : quand le plateau est entièrement stable (`_is_board_settled()`,
  Section 4) et qu'aucun match n'est en attente :
  - si `chain_max >= 2` → émettre le pavé garbage de chaîne `{w: GRID_WIDTH, h:
    chain_max - 1}` (mécanique déjà en place, inchangée).
  - calculer `stop_timer` (Section 4).
  - remettre `chain_count = 0`, `chain_max = 0`, `combo_max = 0`.

### Skill chains — découplage des inputs

`_try_swap()` ne vérifie plus `is_resolving`. Une paire de cases est swappable si
chacune est `null` ou un `Block` à l'état `IDLE` (jamais `GarbageBlock`, jamais
`FLOATING`/`FALLING`/`MATCHED`/`CLEARING`). Le swap est **instantané** côté logique
(l'animation `play_swap` reste, mais ne bloque plus le reste du plateau) : un joueur
peut ainsi placer un bloc dans un trou en cours d'ouverture par une chaîne déjà active,
créant un match qui sera reconnu comme maillon suivant (`from_chain` propagé via les
blocs qui tombent autour).

---

## Section 4 — Système STOP et danger zone

✅ confirmé :
- Après un combo/chaîne, la pile **arrête de monter un moment** une fois le clear
  terminé. Pause **annulable** en maintenant la montée rapide (`fast_rise` /
  `RISE_SPEED_FAST`, déjà câblé).
- Si la pile est **à moins d'une case du plafond**, un combo/chaîne stoppe la montée
  **beaucoup plus longtemps** (répit, pas pénalité).
- Chaîne affichée plafonnée à x13 (cf. Section 3).

🔶 reconstruit : formule de durée et multiplicateur danger zone (pas de frame data
publique trouvée).

### État du plateau

```gdscript
func _is_board_settled() -> bool:
    for row in range(VISIBLE_ROWS):
        for col in range(GRID_WIDTH):
            var cell: Variant = grid[row][col]
            if cell is Block and cell.state != Block.State.IDLE:
                return false
            if cell is GarbageBlock and cell.state != GarbageBlock.State.IDLE:
                return false
    return _find_matches().is_empty()
```

### Calcul du STOP (à la fin de la chaîne, Section 3)

```gdscript
var duration: float = STOP_BASE \
    + STOP_PER_CHAIN_LINK * (chain_max - 1) \
    + STOP_PER_COMBO_EXTRA * max(0, combo_max - 3)
duration = min(duration, STOP_MAX)
if _is_in_danger_zone():
    duration *= DANGER_ZONE_STOP_MULTIPLIER
stop_timer = max(stop_timer, duration)
```

`stop_timer = max(stop_timer, duration)` plutôt que `+=` : si une chaîne se termine
pendant qu'un STOP précédent court encore, on prend le plus long des deux plutôt que
de cumuler indéfiniment.

### Effet sur la montée (`_process`)

```gdscript
if _is_board_settled():
    if stop_timer > 0.0:
        stop_timer = max(0.0, stop_timer - delta)
        if _is_fast_rise_pressed():
            stop_timer = 0.0
    else:
        var rise_speed := RISE_SPEED_FAST if _is_fast_rise_pressed() else RISE_SPEED_NORMAL
        rise_offset += rise_speed * delta
        while rise_offset >= CELL_SIZE:
            rise_offset -= CELL_SIZE
            _do_rise_step()
            if game_over_flag:
                break
```

### Zone de danger

```gdscript
func _is_in_danger_zone() -> bool:
    for row in range(DANGER_ZONE_ROWS):
        for col in range(GRID_WIDTH):
            if grid[row][col] != null:
                return true
    return false
```

**Indicateur visuel** (gameplay + UI, demandé) : tant que `_is_in_danger_zone()` est
vrai, `BOARD_FRAME_COLOR` passe progressivement vers une couleur d'alerte (rouge)
pulsante via un `Tween` dans `_draw()`/`_process` — indépendant du `stop_timer`,
c'est un warning permanent tant que la pile est haute.

---

## Section 5 — Intégration garbage

Le moteur continu simplifie l'intégration par rapport à l'étape précédente :

- **`GarbageBlock`** reçoit les états `IDLE`/`FLOATING`/`FALLING` (Section 1), avec la
  même logique de chute continue revérifiée appliquée à toutes les colonnes qu'il
  couvre (`_garbage_drop_distance`/`_move_garbage_block` deviennent incrémentaux,
  appelés chaque frame plutôt qu'une seule fois).
- **`_update_incoming_garbage()`** : dès que la zone d'apparition est libre, on spawn
  le bloc directement en état `FLOATING` (`float_timer = FLOAT_DELAY`) — il tombera
  tout seul via le moteur continu. **Suppression de `_settle_after_garbage_arrival()`**
  (devenu inutile).
- **`_convert_garbage_block(g)`** : le flash et la conversion rangée par rangée
  (bas → haut, ~1s/couche, inchangé de l'étape précédente) restent identiques. Seule
  différence : chaque rangée convertie en `Block` est posée directement en
  `FLOATING` avec `from_chain = true` — le moteur continu (Sections 2-3) gère ensuite
  la chute, la détection de match et le comptage de chaîne **sans appel manuel** à
  `_apply_gravity()`/`_resolve_matches()`.

---

## Section 6 — Changements concrets vs code étape 2

| Élément actuel | Action |
|---|---|
| `is_resolving: bool` | ❌ supprimé — remplacé par `_is_board_settled()` (Section 4) et des checks d'état par cellule |
| `_apply_gravity()` (snap instantané, await) | ♻️ → boucle continue par frame, chute fluide avec re-vérification du support à chaque frame (Section 2) |
| `_resolve_matches()` (récursif, await) | ♻️ → détection de match continue déclenchée à chaque atterrissage (Section 3), plus de récursion ni d'`await` |
| `_try_swap()` (await, verrou `is_resolving`) | ♻️ → swap immédiat si les 2 cases sont éligibles (`null` ou `Block` `IDLE`) — débloque les skill chains |
| `_settle_after_garbage_arrival()` | ❌ supprimé |
| `_convert_garbage_block(g)` | ♻️ simplifié : pose des `Block` `FLOATING`/`from_chain=true`, le moteur continu fait le reste |
| `chain_count` / `chain_max` | ✅ conservés ; mis à jour via `from_chain` au lieu de la récursion |
| *(nouveau)* `combo_max` | ➕ plus gros combo de la cascade en cours, pour le calcul STOP |
| *(nouveau)* `stop_timer` | ➕ pause de montée forcée |
| *(nouveau)* `Block.State.FLOATING`, `Block.from_chain`, `Block.float_timer` | ➕ |
| *(nouveau)* `GarbageBlock.State.FLOATING`, `GarbageBlock.float_timer` | ➕ |
| `_do_rise_step()` | ♻️ adapté : ne s'exécute que si `_is_board_settled() and stop_timer <= 0` ; décale aussi les blocs `FLOATING`/`FALLING` |
| `BOARD_FRAME_COLOR` / `_draw()` | ♻️ ajout indicateur visuel danger zone (couleur pulsante) |
| `chain_label` (match.gd) | ♻️ afficher `x?` au-delà de chain 13 |

**Conservé tel quel** : `_garbage_combo_pieces`, formule du pavé de chaîne, signaux
`garbage_sent`/`receive_garbage`, `incoming_garbage`, visuels `GarbageBlock`
(`play_match_flash`, `play_shatter_row`, `shrink_to`), `_score_for`, `_find_matches`
(réutilisé tel quel pour la détection continue), inputs clavier/manette.

---

## Section 7 — Constantes (toutes 🔶, calage playtest)

| Constante | Valeur par défaut | Rôle |
|---|---|---|
| `FLOAT_DELAY` | 0.2s | délai avant qu'un bloc sans support commence à tomber |
| `STOP_BASE` | 0.5s | pause minimale après tout combo ≥4 ou chaîne ≥2 |
| `STOP_PER_CHAIN_LINK` | 0.3s | bonus par maillon de chaîne au-delà du 1er |
| `STOP_PER_COMBO_EXTRA` | 0.1s | bonus par panneau au-delà de 3 dans le plus gros combo de la cascade |
| `STOP_MAX` | 5.0s | plafond avant multiplicateur danger zone |
| `DANGER_ZONE_ROWS` | 1 | nb de rangées du haut définissant la zone de danger (✅ "moins d'une case du plafond") |
| `DANGER_ZONE_STOP_MULTIPLIER` | 3.0 | multiplicateur de `stop_timer` en zone de danger |

Les constantes existantes `FALL_DURATION_PER_CELL`, `FLASH_DURATION`, `CLEAR_DURATION`,
`CONVERSION_*`, `RISE_SPEED_*` restent (réutilisées par le moteur continu).

---

## Section 8 — Phasage recommandé

Refonte du cœur du moteur — plus risquée que le garbage. À découper en phases livrées
et testées séparément :

1. **Moteur continu par-cellule** (le plus gros morceau) : ajout de `FLOATING`/
   `from_chain`/`float_timer` sur `Block` et `GarbageBlock`, boucle de gravité continue
   par frame, détection de match continue, pipeline flash→clear. Remplace
   `_apply_gravity`/`_resolve_matches` récursifs et `is_resolving`.
2. **Découplage des inputs** : `_try_swap()` sans verrou global (skill chains).
3. **Système STOP + danger zone** : `stop_timer`, `_is_in_danger_zone()`, indicateur
   visuel, `chain_label` `x?` au-delà de 13.
4. **Intégration garbage** : adapter `_update_incoming_garbage`/`_convert_garbage_block`
   /chute garbage au moteur continu.
5. **Tests** : réécriture complète de la suite (la quasi-totalité des tests actuels
   suppose un modèle synchrone par `await`/`is_resolving`).

Chaque phase doit être validée par la suite de tests avant de passer à la suivante.

---

## Hors scope / à caler en playtest

- Valeurs numériques exactes (`FLOAT_DELAY`, formule STOP, multiplicateur danger zone)
  — toutes 🔶, à ajuster contre une capture émulateur de référence.
- Difficulté progressive (le floating delay diminue avec la difficulté dans
  l'original — pas de système de difficulté dans Swap & Clash pour l'instant).
- Multijoueur en ligne (étape ultérieure).
- Animation détaillée du clignotement "danger zone" (couleur/courbe exactes laissées
  à l'implémentation, dans l'esprit de `NeonTheme`).

---

## Sources

- [Tetris Attack — Hard Drop Tetris Wiki](https://harddrop.com/wiki/Tetris_Attack)
- [Tetris Attack — Wikipedia](https://en.wikipedia.org/wiki/Tetris_Attack)
- [Panel de Pon — Panel de Pon Wiki (Fandom)](https://paneldepon.fandom.com/wiki/Panel_de_Pon)
- [Gameplay Guide — Tetris Attack](https://tetrisattack.com/gameplay)
- [Chains — Tetris Attack](https://tetrisattack.com/chains)
- [Pokemon Puzzle League/Tetris Attack/Panel de Pon Chains](https://www.slack.net/~ant/tetris_attack/)
- [Tetris Attack — Skill Chains FAQ (GameFAQs)](https://gamefaqs.gamespot.com/snes/588787-tetris-attack/faqs/27303)
