# Swap & Clash — Étape 2 : Garbage blocks + multijoueur local

## Contexte

Suite de l'étape 1 (moteur de puzzle solo, terminé). Cette étape ajoute :

1. Les blocs "garbage" (gris, multi-cases) envoyés à l'adversaire via combos/chaînes
2. Le multijoueur local à 2 (manettes), avec deux `Board` côte à côte

Étape 3 (multijoueur en ligne) reste pour plus tard.

Règles de matching de l'étape 1 (alignements horizontaux/verticaux ≥3, fusionnés s'ils se
croisent) sont déjà conformes à Tetris Attack et ne changent pas.

## Architecture générale

- `Board.tscn` / `board.gd` : reste le composant de plateau réutilisable. Reçoit
  `@export var input_device: int` pour lire l'input manette du joueur correspondant.
- Nouveau `GarbageBlock.tscn` / `garbage_block.gd` : bloc gris multi-cases.
- Nouveau `Match.tscn` / `match.gd` (remplace `Game.tscn` comme scène principale) : instancie
  2 `Board` (devices 0 et 1) côte à côte, gère le routage du garbage entre les deux, la
  détection de victoire/défaite et l'écran de fin.
- `Game.tscn` / `game.gd` (étape 1, mode solo single-board) sont conservés tels quels pour
  pouvoir continuer à tester un plateau seul.

## Blocs garbage

### Représentation

- `GarbageBlock` (`class_name GarbageBlock extends Node2D`) représente un rectangle de
  `width x height` cases.
- Rendu : un `ColorRect` gris unique de taille `width*CELL_SIZE x height*CELL_SIZE`, avec un
  `_draw()` simple ajoutant des séparations de grille entre les cases pour la lisibilité.
- États : `IDLE`, `FALLING`, `FLASHING` (ligne du bas en train de "casser"), `SHRINKING`.
- Dans `grid[row][col]`, toutes les cases occupées par le bloc pointent vers la même instance.
  L'instance connaît son `origin: Vector2i` (coin haut-gauche, en coordonnées `Vector2i(col,row)`)
  et `width` / `height`.

### Cassage (déclenché par un match adjacent)

1. Après `_find_matches()`, pour chaque case matchée on regarde ses 4 voisines (haut/bas/
   gauche/droite). Tout `GarbageBlock` touché est ajouté à un set `garbage_to_shatter`.
2. Pendant `FLASH_DURATION`, la ligne du bas de chaque bloc touché clignote (réutilise
   `play_match_flash()`).
3. La ligne du bas est retirée du `GarbageBlock` et remplacée dans `grid` par des `Block`
   colorés aléatoires normaux (état `FALLING`), qui pourront retomber et prolonger la chaîne.
4. `height -= 1`. Si `height == 0`, l'instance est libérée (`queue_free`) et retirée de la
   grille. Sinon le `ColorRect` est redimensionné en conséquence (le bloc garde son `origin`,
   seule sa hauteur diminue).
5. Cette étape se déroule **avant** l'appel à `_apply_gravity()` dans `_resolve_matches()`,
   au même moment que la suppression des blocs matchés.

### Gravité avec garbage

`_apply_gravity()` est étendu :

1. Compaction des `Block` normaux par colonne, comme aujourd'hui, mais une case occupée par un
   `GarbageBlock` est traitée comme un obstacle solide infranchissable.
2. Pour chaque `GarbageBlock` (une seule fois, après l'étape 1) : la distance de chute possible
   = le minimum, sur toutes les colonnes couvertes par sa largeur, du nombre de cases vides
   directement sous sa ligne du bas avant de rencontrer un obstacle ou le fond de la grille
   visible. Le bloc entier est déplacé de cette distance d'un coup (mise à jour de toutes les
   cases `grid` qu'il occupe + animation de chute groupée).
3. Les étapes 1-2 sont répétées en boucle jusqu'à ce qu'aucun bloc (normal ou garbage) ne
   bouge — pour gérer le cas où un garbage qui tombe libère de la place pour des blocs
   au-dessus.

`_find_matches()` ne change pas : seules les cases contenant un `Block` (avec `color_id`) sont
considérées pour les alignements. Les cases `GarbageBlock` sont ignorées par le scan de
matchs (mais détectées via le check de voisinage du cassage, étape précédente).

## Calcul du garbage envoyé

À la fin de chaque palier de `_resolve_matches()` (un "palier" = une vague de matchs +
résolution) :

- **Combo** (`chain_count == 1`, taille du match ≥ 4) → `width = min(taille - 1, 6)`,
  `height = 1`, `power = width` (combo 4 → 3, combo 5 → 4, combo 6 → 5, combo 7+ → 6,
  conforme à la table confirmée)
- **Chaîne** (`chain_count >= 2`) → `width = 6`, `height = min(chain_count - 1, 12)`,
  `power = width * height`

Au lieu d'émettre `garbage_sent` directement, `_resolve_matches()` appelle une méthode interne
`_send_garbage(power)` (voir ci-dessous), qui gère le counter avant d'éventuellement émettre
le signal.

## File d'attente, télégraphe & counter

Chaque `Board` a :

```gdscript
var pending_garbage: Array = []  # éléments: {power: int, telegraph_time: float, columns: Vector2i}
const TELEGRAPH_DURATION := 2.0
const MAX_GARBAGE_HEIGHT := VISIBLE_ROWS - 1  # 11, marge de sécurité
```

Deux opérations distinctes :

### Envoi avec counter (`_send_garbage(power)`, interne)

Appelée quand **ce** board produit `power` via son propre combo/chaîne :

1. `power` annule en priorité (FIFO, le plus ancien d'abord) la `power` des items de **son
   propre** `pending_garbage` (le garbage que l'adversaire est en train de nous envoyer) —
   réduction ou suppression des items dont la power tombe à 0. `power` est décrémenté du
   montant annulé à chaque étape.
2. S'il reste de la `power` après avoir vidé toute la file (ou si la file était déjà vide) :
   `garbage_sent.emit(power_restant)` est émis — `match.gd` route ce signal vers
   `receive_garbage(power_restant)` du board **adverse**.
3. Si `power` a été entièrement absorbé par l'annulation, rien n'est émis (le garbage que
   l'adversaire nous envoyait a été contré, totalement ou partiellement).

### Réception (`receive_garbage(power)`, public)

Appelée par `match.gd` quand **l'adversaire** nous envoie du garbage (via son propre
`_send_garbage`). Ajoute simplement un nouvel item
`{power: power, telegraph_time: TELEGRAPH_DURATION, columns: ...}` à `pending_garbage`.

`columns` est tiré aléatoirement à la création de l'item : `c0 = randi() % (GRID_WIDTH - width + 1)`
pour la largeur du moment (`width = min(power, 6)`). Cette plage sert pour l'indicateur visuel ;
la largeur réelle de livraison est recalculée à partir de la `power` finale au moment de la
livraison (voir ci-dessous), donc `columns` peut être réajustée si la largeur change suite à un
counter partiel.

### Indicateur visuel (télégraphe)

Au-dessus de chaque `Board`, une rangée de petits rectangles gris (un par item de
`pending_garbage`), dont la largeur est proportionnelle à `power` et qui se vide
progressivement (`telegraph_time / TELEGRAPH_DURATION`) pour indiquer le temps restant avant
impact.

### Livraison

Dans `_process`, chaque item de `pending_garbage` voit son `telegraph_time` décrémenté de
`delta`. Quand il atteint 0 :

1. Conversion `power` → forme : `height = ceil(power / 6.0)` (capé à `MAX_GARBAGE_HEIGHT`),
   les `height - 1` premières lignes ont `width = 6`, la dernière ligne a
   `width = power - (height - 1) * 6` (ou 6 si `power` est un multiple de 6). Pour simplifier
   l'implémentation initiale, seule la **première ligne** (la plus basse, celle qui touchera
   la pile en premier) utilise cette largeur réduite ; les lignes au-dessus sont en 6 de large
   (forme en "drapeau" plutôt qu'en escalier — acceptable visuellement pour des placeholders).
2. Si la zone `rows 0..height-1` × `columns` (largeur de la ligne du bas) n'est pas
   entièrement vide dans `grid`, la livraison est reportée (re-vérifiée chaque frame, l'item
   reste avec `telegraph_time = 0` jusqu'à ce que la zone se libère).
3. Sinon : un `GarbageBlock` est instancié à `origin = Vector2i(columns.x, 0)` avec les
   dimensions calculées, placé dans `grid`, et l'item est retiré de `pending_garbage`. La
   gravité (appelée juste après, dans le flux normal de `_process`/`_try_swap`) le fait tomber
   sur la pile existante.

## Multijoueur local (manettes)

- `Board` : tout l'input clavier (`Input.is_key_pressed`) est remplacé par de l'input manette
  via `input_device` :
  - Déplacement du curseur : stick gauche (axes `JOY_AXIS_LEFT_X`/`JOY_AXIS_LEFT_Y`, deadzone
    0.5) ou D-pad — réutilise la logique de répétition (`_key_held_time`) existante, adaptée
    aux directions manette.
  - Swap : `JOY_BUTTON_A`
  - Montée rapide (maintien) : `JOY_BUTTON_B`
- `Match.tscn` / `match.gd` :
  - Fenêtre : 920x800 (vs 620x800 pour 1 joueur).
  - Deux instances de `Board` : `input_device = 0` (gauche, x=20) et `input_device = 1`
    (droite, x=520).
  - Au démarrage : si `Input.get_connected_joypads()` contient moins de 2 manettes, affichage
    d'un message "En attente de manettes (X/2 connectées)" en plein écran ; la partie démarre
    dès que les 2 sont détectées (poll chaque frame).
  - Connecte `garbage_sent(power)` de chaque board vers `receive_garbage(power)` de l'autre.
  - Sur `game_over` d'un board : l'autre board est figé (`is_resolving = true`,
    `game_over_flag = true` pour stopper son `_process`), affichage "Joueur 1 gagne !" /
    "Joueur 2 gagne !" + bouton "Rejouer" qui recharge `Match.tscn`.
  - Affichage par joueur : score, compteur de chaîne, indicateur de garbage entrant (cf.
    ci-dessus).

## Hors scope (étape 2)

- Multijoueur en ligne (étape 3)
- Équilibrage fin des formules de garbage (vitesses de montée, valeurs de power exactes du jeu
  original au-delà des points de table confirmés) — ajustable en playtest
- Power-ups, blocs spéciaux autres que garbage gris
