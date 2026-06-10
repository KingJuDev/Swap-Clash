# Swap & Clash — Étape 1 : Moteur de puzzle solo

## Contexte

Recréer un jeu dans l'esprit de **Tetris Attack** (Panel de Pon, SNES), avec à terme un mode
multijoueur en ligne. Projet découpé en plusieurs étapes :

1. **Moteur de puzzle solo** (cette étape) : grille, swap, matchs, chaînes/combos, pile montante
2. Blocs "garbage" + multijoueur local à 2
3. Multijoueur en ligne

Stack : Godot 4 / GDScript. Visuels en placeholders simples (ColorRect). Règles fidèles à
Tetris Attack classique (grille 6x12, swap horizontal de 2 blocs, pile montante en continu,
game over si la pile atteint le sommet).

## Architecture générale

- `Block.tscn` / `block.gd` : un bloc, machine à états (`IDLE`, `SWAPPING`, `FALLING`, `MATCHED`, `CLEARING`)
- `Board.tscn` / `board.gd` : encapsule toute la logique de grille (réutilisable pour instancier
  2 plateaux côte à côte à l'étape 2)
- `Game.tscn` / `game.gd` : instancie le `Board`, gère l'UI (score, game over) et la boucle de partie

## Grille & blocs

- Grille de 6 colonnes x 12 lignes visibles + 1 ligne tampon cachée en haut (d'où arrivent les
  nouvelles lignes avant que la pile monte)
- 5 couleurs de blocs, représentées par des `ColorRect` colorés
- Génération de nouvelles lignes en évitant tout alignement de 3+ involontaire dès l'apparition

## Curseur & swap

- Curseur de 2x1 cases déplaçable aux flèches (pas de wrap aux bords)
- Touche "swap" (Espace) échange horizontalement les 2 blocs sous le curseur, y compris si une
  case est vide (un bloc peut glisser dans le vide)
- Petite animation de swap sur quelques frames

## Détection des matchs, gravité, chaînes & combos

- Après chaque swap ou atterrissage : recherche d'alignements de 3+ blocs de même couleur
  (ligne ou colonne)
- Les blocs matchés clignotent puis disparaissent ; les blocs au-dessus tombent par gravité
- Une chute provoquant un nouveau match sans action du joueur → incrément du compteur de
  "chaîne" (multiplie le score)
- Plusieurs matchs simultanés sur une même résolution → "combo"

## Pile montante & game over

- La pile monte d'une ligne à intervalle régulier (vitesse configurable), nouvelle ligne générée
  en bas
- Touche "remonter" (maintien) pour accélérer manuellement la montée
- La montée se met en pause pendant qu'il y a des blocs en train de tomber/matcher/swap
- Game over si un bloc dépasse le sommet de la grille visible

## UI & test

- Affichage du score et du compteur de chaîne pendant les chaînes
- Écran de game over avec relance rapide
- Test principalement manuel (jouer la scène) ; logique de détection de matchs écrite en
  fonctions pures pour faciliter les tests
