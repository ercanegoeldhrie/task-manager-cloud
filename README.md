# Task Manager Cloud ☁️

[![CI](https://github.com/ercanegoeldhrie/task-manager-cloud/actions/workflows/ci.yml/badge.svg)](https://github.com/ercanegoeldhrie/task-manager-cloud/actions/workflows/ci.yml)

Un gestionnaire de tâches construit **pas à pas** pour apprendre le cloud moderne sur **AWS** :
API, conteneurs, base de données managée, infrastructure as code, CI/CD, monitoring et sécurité.

Chaque étape ajoute **un seul nouveau concept**, avec une explication simple dans `docs/`.

## 🗺️ Feuille de route

| # | Étape | Concept appris | Coût AWS |
|---|-------|----------------|----------|
| 0 | [Créer son compte AWS en sécurité](docs/00-compte-aws.md) | IAM, MFA, alerte de budget | 0 € |
| 1 | [Petite API + interface web](docs/01-api-et-frontend.md) ✅ | API REST, HTTP, JSON, tests | 0 € (tout en local) |
| 2 | [Conteneuriser avec Docker](docs/02-docker.md) ✅ | Image, conteneur, Dockerfile | 0 € (local) |
| 3 | [Base PostgreSQL](docs/03-postgresql.md) ✅ (en local ; RDS créé à l'étape 4) | Base de données, Docker Compose, SQL | 0 € (local) |
| 4 | [Toute l'infra avec Terraform (dont la base AWS RDS)](docs/04-terraform.md) ✅ | Infrastructure as Code, base managée, réseau (VPC) | Crédits gratuits ⚠️ |
| 5 | [CI/CD avec GitHub Actions](docs/05-ci-cd.md) ✅ | Intégration et déploiement continus, OIDC | 0 € (minutes GitHub gratuites) |
| 6 | [Mettre l'app en ligne (ECS Express Mode)](docs/06-deploiement.md) ✅ | Conteneurs Fargate, répartiteur de charge, HTTPS, déploiement continu | Crédits gratuits ⚠️ (~1,80 $/jour tout allumé) |
| 7 | [Logs, alertes et HTTPS](docs/07-observabilite.md) ✅ | CloudWatch (logs, métriques, alarmes), SNS, en-têtes de sécurité | ~0 € (niveau gratuit CloudWatch) |

⚠️ = la ressource coûte de l'argent si elle reste allumée. Les nouveaux comptes AWS reçoivent des
crédits gratuits qui couvrent ce projet, mais **on détruira toujours l'infra après chaque session**
(`terraform destroy`) et l'alerte de budget de l'étape 0 nous préviendra au moindre centime.

## 🏗️ Architecture visée (à la fin)

```
Navigateur ──HTTPS──▶ Répartiteur de charge ──▶ ECS Fargate (conteneur Docker de l'API)
                              │
                              ├──▶ RDS PostgreSQL (les tâches)
                              ├──▶ Secrets Manager (mot de passe de la base)
                              └──▶ CloudWatch (logs, métriques, alarmes ──▶ SNS ──▶ e-mail)

GitHub ──merge──▶ GitHub Actions ──(OIDC, sans clé)──▶ build Docker ▶ ECR ▶ redéploiement ECS
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

## 🐘 Lancer avec la base PostgreSQL (étape 3)

```bash
docker compose up --build     # la base + l'API, sur http://localhost:8080
docker compose down           # tout arrêter (les tâches sont conservées)
```

## 📁 Structure

```
app/
  Dockerfile      recette de l'image Docker
  src/app.js      routes de l'API
  src/store*.js   stockage des tâches (PostgreSQL, ou mémoire sans DATABASE_URL)
  src/server.js   démarrage du serveur (et arrêt propre)
  src/logger.js   logs JSON (étape 7)
  src/middleware.js  log par requête, HTTPS forcé, en-têtes de sécurité (étape 7)
  public/         interface web (HTML, CSS, JavaScript)
  test/           tests automatiques
infra/            code Terraform (base RDS, registre ECR, rôle OIDC, service ECS, CloudWatch)
.github/workflows/  CI (tests) et CD (envoi de l'image vers AWS)
docs/             explications de chaque étape
docker-compose.yml  la base + l'API en local
```
