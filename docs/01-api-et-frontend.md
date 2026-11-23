# Étape 1 : une petite API et une interface web

> But : comprendre ce qu'on va déployer dans le cloud. Tout tourne **sur ton ordinateur**. Coût : 0 €.

## Les concepts, simplement

- **Une API** est un programme qui répond à des demandes envoyées par Internet. Ici, elle gère une
  liste de tâches.
- **HTTP** est la langue de ces demandes. Chaque demande a une **méthode** (le verbe) et une
  **adresse** (la route) :

  | Méthode | Route | Ce que ça fait |
  |---------|-------|----------------|
  | `GET` | `/api/tasks` | lister les tâches |
  | `POST` | `/api/tasks` | créer une tâche |
  | `PATCH` | `/api/tasks/1` | modifier la tâche n°1 |
  | `DELETE` | `/api/tasks/1` | supprimer la tâche n°1 |
  | `GET` | `/health` | « es-tu vivante ? » (servira à AWS) |

- **JSON** est le format des données échangées : `{"id": 1, "title": "Apprendre Docker", "done": false}`.
- **Le frontend** (dossier `public/`) est la page web qui appelle l'API avec `fetch()`.
- **Les tests** (dossier `test/`) vérifient automatiquement que l'API marche. Dans le cloud, on ne
  déploie que du code testé : c'est la base de la CI/CD de l'étape 5.

## Deux choix « pensés cloud » déjà présents

1. **Le port vient d'une variable d'environnement** (`PORT`). Dans le cloud, c'est la plateforme qui
   choisit le port : le même code doit marcher partout sans être modifié.
2. **Le stockage est isolé dans `store.js`**. Pour l'instant les tâches sont en mémoire (elles
   disparaissent au redémarrage). À l'étape 3, on remplacera uniquement ce fichier par PostgreSQL.

## À toi de jouer

```bash
cd app
npm install
npm test
npm start
```

1. Ouvre http://localhost:3000, ajoute quelques tâches, coches-en une.
2. Dans un autre terminal, parle directement à l'API :
   ```bash
   curl http://localhost:3000/api/tasks
   curl -X POST http://localhost:3000/api/tasks -H "Content-Type: application/json" -d '{"title":"Depuis curl"}'
   ```
3. Arrête le serveur (Ctrl+C), relance-le : les tâches ont disparu. C'est le problème que résoudra
   la base de données de l'étape 3.

## Petit exercice (facultatif)

Ajoute une route `GET /api/tasks/:id` qui renvoie une seule tâche (ou une erreur 404), puis un
test dans `test/api.test.js`. Lance `npm test` pour vérifier.

➡️ Prochaine étape : **Docker**, pour emballer cette API dans un conteneur qui tournera à
l'identique sur ton PC et chez AWS.
