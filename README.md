# Task Manager Cloud ☁️

Un gestionnaire de tâches construit **pas à pas** pour apprendre le cloud moderne sur **AWS** :
API, conteneurs, base de données managée, infrastructure as code, CI/CD, monitoring et sécurité.

Chaque étape ajoute **un seul nouveau concept**, avec une explication simple dans `docs/`.

## 🗺️ Feuille de route

| # | Étape | Concept appris | Coût AWS |
|---|-------|----------------|----------|
| 0 | [Créer son compte AWS en sécurité](docs/00-compte-aws.md) | IAM, MFA, alerte de budget | 0 € |
| 1 | [Petite API + interface web](docs/01-api-et-frontend.md) ✅ | API REST, HTTP, JSON, tests | 0 € (tout en local) |
| 2 | [Conteneuriser avec Docker](docs/02-docker.md) ✅ | Image, conteneur, Dockerfile | 0 € (local) |
| 3 | Base PostgreSQL managée (AWS RDS) | Base de données managée, réseau (VPC) | Crédits gratuits ⚠️ |
| 4 | Toute l'infra avec Terraform | Infrastructure as Code | 0 € (l'outil est gratuit) |
| 5 | CI/CD avec GitHub Actions | Intégration et déploiement continus, OIDC | 0 € (minutes GitHub gratuites) |
| 6 | Déployer sur AWS (App Runner ou ECS Fargate) | Hébergement de conteneurs, registre ECR | Crédits gratuits ⚠️ |
| 7 | Logs, secrets, HTTPS | CloudWatch, Secrets Manager, certificats | Crédits gratuits ⚠️ |

⚠️ = la ressource coûte de l'argent si elle reste allumée. Les nouveaux comptes AWS reçoivent des
crédits gratuits qui couvrent ce projet, mais **on détruira toujours l'infra après chaque session**
(`terraform destroy`) et l'alerte de budget de l'étape 0 nous préviendra au moindre centime.

## 🏗️ Architecture visée (à la fin)

```
Navigateur ──HTTPS──▶ App Runner / Fargate (conteneur Docker de l'API)
                              │
                              ├──▶ RDS PostgreSQL (les tâches)
                              ├──▶ Secrets Manager (mot de passe de la base)
                              └──▶ CloudWatch (logs et alertes)

GitHub ──push──▶ GitHub Actions ──(OIDC, sans clé)──▶ build Docker ▶ ECR ▶ déploiement
Terraform ──▶ crée et détruit toute l'infra AWS
```

## 🚀 Lancer le projet en local (étape 1)

Prérequis : [Node.js 20 ou plus](https://nodejs.org/).

```bash
cd app
npm install     # installe Express (le framework web)
npm test        # lance les tests automatiques
npm start       # démarre l'API sur http://localhost:3000
```

Ouvre ensuite http://localhost:3000 dans ton navigateur.

## 🐳 Lancer le projet avec Docker (étape 2)

```bash
cd app
docker build -t task-manager:local .
docker run --rm -p 8080:3000 task-manager:local
```

Ouvre ensuite http://localhost:8080.

## 📁 Structure

```
app/
  Dockerfile      recette de l'image Docker
  src/app.js      routes de l'API
  src/store.js    stockage des tâches (mémoire, puis PostgreSQL à l'étape 3)
  src/server.js   démarrage du serveur
  public/         interface web (HTML, CSS, JavaScript)
  test/           tests automatiques
docs/             explications de chaque étape
```
