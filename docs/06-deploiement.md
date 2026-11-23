# Étape 6 : mettre l'app en ligne sur AWS (ECS Express Mode)

> But : ton gestionnaire de tâches accessible par tout le monde, en **HTTPS**, avec la base RDS,
> et mis à jour **automatiquement** à chaque merge sur `main`.
> Prérequis : étapes 0, 4 et 5 faites (compte AWS, `terraform apply` testé, variable `AWS_ROLE_ARN`).

## ⚠️ Coût de cette étape

| Ressource | Prix indicatif |
|-----------|----------------|
| Conteneur Fargate (0,25 processeur, 512 Mo) | ~0,013 $/heure |
| Répartiteur de charge (ALB) | ~0,025 $/heure |
| IP publiques (répartiteur + conteneur) | ~0,015 $/heure |
| Base RDS (étape 4) | ~0,02 $/heure |
| **Total, tout allumé** | **~0,075 $/heure, soit ~1,80 $ par jour** |

C'est pris sur tes crédits du plan gratuit. Une session de 2 heures coûte environ 0,15 $. Mais
**oublier de détruire pendant un mois coûterait ~55 $** : `terraform destroy` à la fin, toujours.

## Pourquoi ECS Express Mode ?

On avait prévu **App Runner**, mais AWS l'a fermé aux nouveaux clients et recommande à la place
**Amazon ECS Express Mode**. C'est une bonne nouvelle : ECS est **le** service de conteneurs
le plus utilisé sur AWS en entreprise.

Les concepts :
- **ECS** (Elastic Container Service) : le service qui lance et surveille tes conteneurs.
- **Fargate** : tu ne gères aucun serveur. Tu dis « 0,25 processeur et 512 Mo », AWS trouve la place.
- **Service** : « garde toujours 1 conteneur de cette image en marche ». S'il plante, ECS le remplace.
- **Répartiteur de charge (ALB)** : la porte d'entrée publique. Il reçoit les visiteurs en HTTPS et
  les envoie vers les conteneurs en bonne santé (il appelle `/health` régulièrement).
- **Express Mode** : ECS crée tout ça pour toi (répartiteur, certificat HTTPS, adresse publique,
  règles réseau) à partir d'une image et de deux rôles. Ce mode est gratuit : on ne paie que les
  ressources créées.

## Ce qui a changé

| Fichier | Changement |
|---------|------------|
| `infra/app.tf` | **nouveau** : le cluster, les 2 rôles IAM, le service Express |
| `infra/main.tf` | la base accepte les connexions venant du réseau privé (VPC) de l'app |
| `infra/github-oidc.tf` | GitHub a le droit de relancer **notre** service, et rien d'autre |
| `.github/workflows/deploy.yml` | après l'envoi de l'image, relance le service (sans coupure) |
| `app/src/store.js` | accepte `PGHOST`, `PGUSER`, `PGPASSWORD`… en plus de `DATABASE_URL` |

### Le mot de passe de la base n'est écrit nulle part

Regarde le bloc `secret` dans `infra/app.tf` : au démarrage du conteneur, ECS lit le mot de passe
dans **Secrets Manager** et le met dans la variable `PGPASSWORD`. Le rôle d'exécution a le droit de
lire **ce secret-là uniquement**. Le mot de passe n'est ni dans le code, ni dans GitHub, ni dans
la configuration Terraform. C'est exactement comme ça qu'on fait en entreprise.

## À toi de jouer

L'ordre compte : le service a besoin d'une image dans ECR pour démarrer.

1. Crée (ou mets à jour) l'infra de base, **sans** l'app :
   ```bash
   aws sso login --profile tm
   cd infra
   terraform apply
   ```
2. Envoie une première image : sur GitHub, onglet **Actions** ▶ **Deploy** ▶ **Run workflow**
   (sur `main`). Attends la coche verte ✅ (environ 1 minute).
3. Crée le service :
   ```bash
   terraform apply -var deploy_app=true
   ```
   Compte **5 à 10 minutes**. À la fin, Terraform affiche `app_endpoint`.
4. Ouvre `https://` suivi de cette adresse dans ton navigateur. Ton app est sur Internet, en HTTPS,
   avec ses tâches stockées dans RDS ! Envoie le lien à un ami pour tester.
5. Teste le déploiement continu : change le titre `Mes tâches` dans `app/public/index.html`, fais
   une pull request, merge-la. Regarde l'onglet **Actions** : CI, puis Deploy. Deux minutes plus tard,
   recharge la page : ton changement est en ligne, sans que tu aies rien déployé à la main.
6. Explore la console AWS (région Paris) : **ECS ▶ Clusters ▶ task-manager** (ton service, ses
   déploiements, ses logs) et **EC2 ▶ Load Balancers** (le répartiteur créé pour toi).
7. ⚠️ **Fin de session** : `terraform destroy`.

Pour la session suivante : `terraform apply -var deploy_app=true` directement (après avoir relancé
**Deploy** une fois si le registre ECR a été détruit, car il était vide).

Astuce : pour ne pas retaper `-var deploy_app=true`, ajoute `deploy_app = true` dans
`infra/terraform.tfvars`.

## Si ça ne marche pas

- **Le service ne démarre pas** : console ECS ▶ ton service ▶ onglet **Logs** ou **Tasks** ▶
  « Stopped reason ». Le message dit presque toujours ce qui manque.
- **`CannotPullContainerError`** : l'image `:latest` n'existe pas dans ECR. Relance **Deploy** (étape 2).
- **AWS refuse 0,25 processeur / 512 Mo** : dans `infra/app.tf`, mets `cpu = "512"` et
  `memory = "1024"` (le coût du conteneur double, ~0,025 $/heure).
- Colle-moi le message d'erreur (jamais de mot de passe), et on regarde ensemble.

## Ce qu'on a vérifié

- `terraform validate` et `fmt` passent avec le provider AWS 6.73 (qui gère ECS Express Mode).
- Les tests passent avec `DATABASE_URL` comme avec les variables `PGHOST`, `PGUSER`, `PGPASSWORD`.
- Rien n'a été créé sur AWS : le premier vrai déploiement sera le tien.

➡️ Prochaine étape : **logs, alertes et secrets** avec CloudWatch, pour savoir ce qui se passe en
production et être prévenu en cas de problème.
