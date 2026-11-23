# Étape 5 : CI/CD avec GitHub Actions (et connexion à AWS sans clé)

> But : que GitHub **teste** chaque changement tout seul, puis **envoie l'image Docker chez AWS**
> quand le code arrive sur `main`. Coût : 0 € (GitHub offre 2 000 minutes par mois aux dépôts
> privés, et c'est illimité pour un dépôt public ; ECR est gratuit jusqu'à 500 Mo).

## Les concepts

- **CI (Intégration Continue)** : à chaque push ou pull request, une machine de GitHub télécharge le
  code, installe tout, lance les tests et construit l'image. Une croix rouge ❌ sur la pull request =
  on ne merge pas. Fini le « ça marchait chez moi ».
- **CD (Déploiement Continu)** : quand le code testé arrive sur `main`, il part automatiquement en
  production. Personne ne déploie « à la main » depuis son PC.
- **GitHub Actions** : l'outil de CI/CD intégré à GitHub. On le décrit dans des fichiers YAML du
  dossier `.github/workflows/`. Un **workflow** contient des **jobs**, qui contiennent des **steps**.
- **OIDC** : la manière moderne et sûre de connecter GitHub à AWS. Au lieu de stocker une clé AWS
  dans GitHub (qui peut fuiter et reste valable pour toujours), GitHub présente à AWS un **jeton
  d'identité signé** : « je suis le workflow du dépôt `ercanegoeldhrie/task-manager-cloud`, sur la
  branche `main` ». AWS vérifie la signature et prête un **rôle temporaire** valable une heure.
  Aucune clé à voler.

## Les deux workflows

| Fichier | Quand | Ce qu'il fait |
|---------|-------|---------------|
| `.github/workflows/ci.yml` | chaque push et pull request | tests (mémoire + vrai PostgreSQL), `docker build`, `terraform fmt` et `validate` |
| `.github/workflows/deploy.yml` | après une CI réussie sur `main` | se connecte à AWS par OIDC, envoie l'image dans ECR |

Le déploiement est **désactivé** tant que tu n'as pas configuré AWS : le job est simplement ignoré.

## Ce qu'on a ajouté côté AWS (Terraform, gratuit)

Le fichier `infra/github-oidc.tf` crée :
1. un **fournisseur d'identité OIDC** : AWS fait confiance aux jetons signés par GitHub ;
2. un **rôle IAM** `task-manager-github-deploy` que **seul** ton dépôt, sur `main`, peut utiliser ;
3. une **politique** qui donne à ce rôle le droit d'envoyer des images dans **ton** registre ECR, et
   rien d'autre. C'est le **principe du moindre privilège** : on donne le strict nécessaire.

## À toi de jouer

### Partie 1 : la CI (tout de suite, sans AWS)

1. Ouvre une de tes pull requests sur GitHub, onglet **Checks** : les 3 jobs tournent tout seuls.
2. Clique sur un job pour lire ses logs, étape par étape.
3. Expérience : sur une branche, casse un test exprès (par exemple remplace `201` par `200` dans
   `app/test/api.test.js`), pousse, et regarde la croix rouge apparaître. Puis répare.

### Partie 2 : le déploiement (quand ton compte AWS est prêt)

1. Crée l'infra (elle inclut maintenant le rôle OIDC) :
   ```bash
   aws sso login --profile tm
   cd infra
   terraform apply
   ```
2. Copie la valeur `github_deploy_role_arn` affichée à la fin. Elle ressemble à
   `arn:aws:iam::123456789012:role/task-manager-github-deploy`. Ce n'est **pas** un secret.
3. Sur GitHub : ton dépôt ▶ **Settings** ▶ **Secrets and variables** ▶ **Actions** ▶ onglet
   **Variables** ▶ **New repository variable** :
   - Name : `AWS_ROLE_ARN`
   - Value : l'ARN copié
4. Onglet **Actions** ▶ workflow **Deploy** ▶ **Run workflow**. Après une minute, va dans la
   console AWS ▶ **ECR** ▶ `task-manager-api` : ton image est là, étiquetée avec l'identifiant du commit.
5. Désormais, chaque merge sur `main` envoie automatiquement une nouvelle image.
6. ⚠️ Fin de session : `terraform destroy` (ECR est vidé et supprimé aussi). Après un nouvel
   `apply`, l'ARN du rôle reste le même : pas besoin de changer la variable GitHub.

## Le fichier `.terraform.lock.hcl`

Après ton premier `terraform init`, ce fichier apparaît dans `infra/`. Il fige la version exacte du
plugin AWS : **ajoute-le à Git** (`git add infra/.terraform.lock.hcl`) pour que tout le monde, CI
comprise, utilise la même.

## Ce qu'on a vérifié

- Les workflows sont lus correctement par GitHub, et la CI tourne sur la pull request de cette étape.
- `terraform validate` passe avec le rôle OIDC.
- Le déploiement n'a pas été testé de bout en bout : il attend ton compte AWS.

➡️ Prochaine étape : **déployer l'API sur AWS**, pour qu'elle ait une adresse publique sur Internet.
