# Étape 3 : une vraie base de données PostgreSQL

> But : que les tâches **survivent** au redémarrage de l'API.
> Cette étape se fait **en local avec Docker** (0 €). Le passage sur AWS RDS se fera avec
> Terraform à l'étape 4, car c'est là qu'on apprend à créer de l'infra proprement (et à la détruire).

## Pourquoi une base de données ?

Jusqu'ici, les tâches étaient dans la **mémoire** du programme : on arrête l'API, tout est perdu.
Dans le cloud, c'est encore pire : AWS peut redémarrer ou remplacer un conteneur à tout moment,
et si on lance 3 conteneurs, chacun aurait sa propre liste !

La règle d'or du cloud : **les conteneurs sont jetables (« stateless »), les données vivent ailleurs**,
dans une base de données partagée.

## Les concepts

- **PostgreSQL** : une base de données relationnelle, gratuite et très utilisée en entreprise.
  Les données sont rangées dans des **tables** (comme un tableur), qu'on interroge en **SQL**.
- **Base managée (AWS RDS)** : AWS installe PostgreSQL, fait les sauvegardes, les mises à jour et
  la surveillance pour toi. Tu ne gères plus de serveur : c'est tout l'intérêt du cloud.
- **Docker Compose** : lance plusieurs conteneurs ensemble (ici l'API + la base) avec une seule commande.
- **Chaîne de connexion** : `postgres://utilisateur:motdepasse@hote:5432/base`. On la donne à l'API
  via la variable d'environnement `DATABASE_URL`. En local, l'hôte est `db` ; sur AWS, ce sera
  l'adresse de RDS. **Le code ne change pas.**

## Ce qui a changé dans le code

| Fichier | Rôle |
|---------|------|
| `app/src/store-postgres.js` | **nouveau** : lit et écrit les tâches dans PostgreSQL |
| `app/src/store-memory.js` | l'ancien stockage en mémoire, gardé pour coder vite |
| `app/src/store.js` | choisit l'un ou l'autre selon `DATABASE_URL` |
| `app/src/app.js` | routes `async` (la base répond en quelques millisecondes, pas instantanément) |
| `docker-compose.yml` | **nouveau** : la base + l'API, reliées par un réseau privé |

Deux bonnes pratiques à retenir dans `store-postgres.js` :
1. **Requêtes paramétrées** (`$1`, `$2`) : protègent contre les injections SQL, une des failles
   les plus courantes au monde.
2. **Pool de connexions** : on réutilise les connexions au lieu d'en ouvrir une par requête.

## À toi de jouer

1. Lance tout (la base et l'API) :
   ```bash
   docker compose up --build
   ```
   Attends le message `API démarrée … (stockage : PostgreSQL)`, puis ouvre http://localhost:8080
   et ajoute des tâches.
2. **Le test qui compte** : arrête tout avec Ctrl+C, relance `docker compose up`, recharge la page.
   Tes tâches sont toujours là ! Elles sont rangées dans le volume `db-data`.
3. Regarde directement dans la base, en SQL :
   ```bash
   docker compose exec db psql -U taskuser -d tasks -c "SELECT * FROM tasks;"
   ```
4. Lance les tests sur la vraie base (dans un autre terminal, pendant que Compose tourne) :
   ```bash
   cd app
   DATABASE_URL=postgres://taskuser:devpassword@localhost:5432/tasks npm test
   ```
   ⚠️ Les tests vident la table : tes tâches de démo seront effacées.
   (Sous Windows PowerShell : `$env:DATABASE_URL="postgres://..."; npm test`.)
5. Pour tout effacer, données comprises : `docker compose down -v`.

## Et le mot de passe `devpassword` dans le fichier ?

Il ne sert **que sur ton PC**, pour une base qui contient des tâches de test. Sur AWS, le mot de
passe sera généré automatiquement et rangé dans **AWS Secrets Manager** (étape 7). Il n'apparaîtra
jamais dans le code ni sur GitHub.

## Ce qu'on a vérifié

- Les 6 tests passent, en mémoire et sur un vrai PostgreSQL 17.
- Une tâche créée est toujours là après un redémarrage de l'API.
- `docker compose up` démarre la base, attend qu'elle soit prête, puis l'API s'y connecte.

## Combien coûtera RDS sur AWS ?

Une petite base `db.t4g.micro` avec 20 Go de disque est couverte par les crédits du plan gratuit.
Mais une base RDS **coûte dès qu'elle est allumée**, même si personne ne l'utilise. On la créera
avec Terraform pour pouvoir la détruire en une commande à la fin de chaque session.

➡️ Prochaine étape : **Terraform**, pour créer (et détruire) la base RDS et le reste de l'infra AWS
avec du code.
