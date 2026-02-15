# Zone 1 — Réalité stable : géométrie orthogonale

Ce document formalise une définition exploitable en **génération procédurale** et en **design atmosphérique** pour la Zone 1.

## 1) Définition géométrique stricte

### A. Grille purement orthogonale

- Toutes les salles sont des rectangles axis-aligned.
- Tous les murs sont alignés sur X/Y.
- Aucun angle différent de 90°.
- Aucun mur oblique.
- Aucun couloir diagonal.
- Pas de rotation de salles.
- Pas de forme irrégulière.

Structure de donnée de salle attendue :

```lua
room = {
  x = integer,
  y = integer,
  width = integer,
  height = integer,
  doors = {}
}
```

Contraintes de validation :

- `allowDiagonal = false`
- `allowIrregularRooms = false`
- `rotation = 0`

### B. Connectivité rationnelle

- Couloirs rectilignes uniquement.
- Jonctions en L autorisées.
- Pas de boucle illogique.
- Pas de salle anormalement enclavée.

Topologie de référence lisible :

`Entrée → Bureau → Couloir → Bureau → Salle centrale → Sortie vers Zone 2`

Règles procédurales :

- Graphe connecté à 100%.
- Une route principale identifiable de l’entrée au connecteur Zone 2.
- Nombre de boucles faible (minimal loops).

### C. Proportions réalistes

- Largeur couloir : `2..4` tiles.
- Taille salle moyenne : `6x6..12x12`.
- Ratio couloir/salle équilibré.
- Peu de très grandes pièces.

Objectif : le plan doit être lisible mentalement rapidement.

---

## 2) Définition atmosphérique

La Zone 1 est le **point de référence psychologique**.

Le joueur doit ressentir :

- Le monde obéit à des règles stables.
- Les distances sont fiables.
- Les lignes de vue sont cohérentes.
- Les angles morts sont prévisibles.
- Les morts paraissent compréhensibles (lisibilité cause/effet).

---

## 3) Lisibilité compatible jeu rapide (type Hotline)

### A. Lignes de tir claires

- Couloirs rectilignes.
- Peu de colonnes.
- Peu d’obstacles organiques.

### B. Décision instantanée

- Lecture immédiate de la pièce.
- Ambiguïté spatiale minimale.

---

## 4) Rôle narratif dans la progression

Zone 1 sert de :

- base comparative,
- ancrage mental,
- étalon de normalité.

La rupture perceptive en Zone 2/3 dépend de cette normalité initiale.

---

## 5) Interdits explicites en Zone 1

- Pas de géométrie non-euclidienne.
- Pas de reconnecteurs impossibles.
- Pas de salle impossible.
- Pas de symétrie cassée “inexplicable”.
- Pas d’effets visuels instables.

Même dans un univers lovecraftien, Zone 1 doit paraître architecturée rationnellement.

---

## 6) Paramètres procéduraux recommandés (profil Zone1)

```lua
zone1 = {
  gridSize = random(50, 70),
  roomCount = random(8, 15),
  minRoomSize = 6,
  maxRoomSize = 12,
  corridorWidth = random(2, 4),
  allowDiagonal = false,
  allowIrregularRooms = false,
  connectivity = 1.0,
  loops = "minimal"
}
```

### Invariants de validation technique

- Toutes les salles sont des rectangles entiers.
- Toutes les arêtes de couloir sont horizontales/verticales.
- Flood fill entrée → toutes les salles = vrai.
- Connecteur Zone 1 → Zone 2 présent et accessible.

---

## 7) Importance psychologique

Progression émotionnelle visée :

1. Normalité
2. Légère incohérence
3. Rupture
4. Effondrement

Zone 1 correspond à la normalité stricte.

---

## 8) Résumé opérationnel

Zone 1 – Réalité stable =

- rectangles uniquement,
- axes X/Y uniquement,
- couloirs droits (ou L),
- plan mental immédiatement compréhensible,
- aucune anomalie géométrique,
- architecture rationnelle et lisible.
