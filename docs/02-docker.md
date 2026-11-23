# Étape 2 : emballer l'API dans un conteneur Docker

> But : que l'API tourne **exactement pareil** sur ton PC et chez AWS. Tout se passe en local. Coût : 0 €.

## Le problème que Docker résout

« Ça marche sur ma machine ! » : sur un autre ordinateur, la version de Node.js, le système ou une
bibliothèque peuvent être différents, et l'application plante. Docker emballe **l'application avec
tout ce dont elle a besoin** (Node.js, dépendances, code) dans un paquet unique.

## Les 3 mots à connaître

| Mot | Image simple | Dans notre projet |
|-----|--------------|-------------------|
| **Dockerfile** | la recette | `app/Dockerfile` |
| **Image** | le plat préparé et surgelé, identique partout | `task-manager:local` |
| **Conteneur** | le plat réchauffé et servi : l'image en train de tourner | l'API qui répond sur le port 3000 |

On peut lancer plusieurs conteneurs à partir de la même image. C'est ce que fera AWS si beaucoup
de monde utilise l'app.

## Lire le Dockerfile

Ouvre [`app/Dockerfile`](../app/Dockerfile) : chaque ligne est commentée. Les idées importantes :

1. **`FROM node:22-alpine`** : on part d'une image officielle qui contient déjà Node.js.
2. **On copie `package.json` avant le code** : Docker garde en cache chaque étape. Si tu modifies
   seulement ton code, il ne réinstalle pas les dépendances, et la construction prend 2 secondes au
   lieu de 30.
3. **`USER node`** : l'app ne tourne pas en administrateur. Si un pirate trouvait une faille, il
   aurait beaucoup moins de pouvoir.
4. **`.dockerignore`** : on n'envoie pas `node_modules`, les tests ni un éventuel fichier `.env`
   (qui pourrait contenir des secrets) dans l'image.

## À toi de jouer

1. Installe **Docker Desktop** : https://www.docker.com/products/docker-desktop/ (gratuit pour un
   usage personnel et l'apprentissage). Lance-le, puis vérifie dans un terminal :
   ```bash
   docker --version
   ```
2. Construis l'image (le `.` veut dire « la recette est dans ce dossier ») :
   ```bash
   cd app
   docker build -t task-manager:local .
   ```
3. Lance un conteneur :
   ```bash
   docker run --rm -p 8080:3000 task-manager:local
   ```
   `-p 8080:3000` relie le port 8080 de ton PC au port 3000 du conteneur.
   Ouvre http://localhost:8080 : c'est ton app, mais elle tourne dans un conteneur !
4. Change le port de l'app **sans toucher au code**, grâce à la variable d'environnement :
   ```bash
   docker run --rm -p 8080:4000 -e PORT=4000 task-manager:local
   ```
5. Explore :
   ```bash
   docker images     # les images sur ton PC
   docker ps         # les conteneurs qui tournent (dans un autre terminal)
   ```
   Ctrl+C arrête le conteneur ; `--rm` le supprime automatiquement ensuite.

## Ce qu'on a vérifié

- L'image se construit et le conteneur répond sur `/health`.
- Dans le conteneur, l'app tourne bien avec l'utilisateur `node` (pas `root`).
- Taille de l'image : environ 250 Mo, presque tout vient de Node.js lui-même.

## Et dans le cloud ?

À l'étape 6, on enverra cette image dans **Amazon ECR** (le « Docker Hub » privé d'AWS), puis AWS
lancera des conteneurs à partir d'elle. Ce sera la même image, au bit près, que celle que tu viens
de tester.

➡️ Prochaine étape : **PostgreSQL**, pour que les tâches ne disparaissent plus au redémarrage.
On commencera en local avec Docker (gratuit), avant de passer à AWS RDS.
