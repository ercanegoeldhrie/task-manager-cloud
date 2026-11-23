# Étape 4 : créer l'infra AWS avec Terraform (et la base RDS)

> But : créer ta base PostgreSQL **sur AWS**, avec du code, puis la **détruire** en une commande.
> Prérequis : l'[étape 0](00-compte-aws.md) terminée (compte, MFA, alerte de budget, `aws sso login`).

## ⚠️ Coût de cette étape

| Ressource | Prix indicatif | Comment rester à ~0 € |
|-----------|----------------|-----------------------|
| Base RDS `db.t4g.micro` + 20 Go | ~0,02 $/heure (~15 $/mois si on l'oublie) | couverte par les crédits ; **`terraform destroy` après chaque session** |
| Secret du mot de passe (Secrets Manager) | ~0,40 $/mois | couvert par les crédits, supprimé au `destroy` |
| Registre ECR | gratuit jusqu'à 500 Mo | on garde 3 images maximum |
| IP publique (seulement si tu remplis `my_ip`) | ~0,005 $/heure | laisse `my_ip` vide si tu n'en as pas besoin |

Une session d'une heure coûte donc quelques centimes, pris sur tes crédits. Ton alerte de budget
« Zero spend » t'enverra un e-mail dès le premier centime : c'est normal, et ça prouve qu'elle marche.

## Le concept : l'Infrastructure as Code

Créer une base en cliquant dans la console AWS, c'est facile… une fois. Mais comment la recréer
à l'identique ? Comment savoir ce qui a été créé, et tout supprimer pour ne plus payer ?

**Terraform** décrit l'infrastructure dans des fichiers texte (`.tf`). Il compare ce que tu as
écrit avec ce qui existe chez AWS, puis crée, modifie ou supprime ce qu'il faut. Les avantages :

- **Reproductible** : la même commande donne la même infra, chez toi ou dans une entreprise.
- **Versionné** : l'infra est dans Git, on voit qui a changé quoi (et on peut faire une pull request !).
- **Destructible** : `terraform destroy` supprime tout ce que Terraform a créé, sans rien oublier.

C'est une des compétences les plus demandées dans les offres d'emploi cloud et DevOps.

## Les 4 commandes à retenir

| Commande | Ce qu'elle fait |
|----------|-----------------|
| `terraform init` | télécharge le plugin AWS (une seule fois) |
| `terraform plan` | **montre** ce qui va être créé, sans rien toucher |
| `terraform apply` | crée réellement l'infra (demande confirmation) |
| `terraform destroy` | supprime tout (demande confirmation) |

## Lire le code (dossier `infra/`)

| Fichier | Rôle |
|---------|------|
| `versions.tf` | version de Terraform, connexion à AWS (région Paris, profil `tm`) |
| `variables.tf` | les réglages modifiables |
| `main.tf` | **les ressources** : pare-feu, base RDS, registre ECR (chaque bloc est commenté) |
| `outputs.tf` | les infos affichées à la fin (adresse de la base…) |

Points de sécurité à remarquer dans `main.tf` :
- **Aucun mot de passe dans le code** : `manage_master_user_password = true` demande à AWS de le
  générer et de le ranger dans **Secrets Manager**.
- **La base est privée par défaut** : le pare-feu (security group) ne laisse entrer personne.
- **Les données sont chiffrées** sur le disque (`storage_encrypted = true`).

## À toi de jouer

1. Installe Terraform : https://developer.hashicorp.com/terraform/install puis vérifie :
   ```bash
   terraform version
   ```
2. Connecte-toi à AWS (la session dure quelques heures) :
   ```bash
   aws sso login --profile tm
   ```
3. Prépare et regarde le plan :
   ```bash
   cd infra
   terraform init
   terraform plan
   ```
   Lis la sortie : `+` = sera créé. Tu dois voir **5 ressources à créer**
   (« Plan: 5 to add » ; 6 si tu as rempli `my_ip`).
4. Crée l'infra (la base met **5 à 10 minutes** à démarrer) :
   ```bash
   terraform apply
   ```
   Tape `yes`. À la fin, Terraform affiche `db_endpoint` et `ecr_repository_url`.
5. Va voir dans la console AWS (région Paris) : **RDS ▶ Databases**, ta base `task-manager-db` est là.
   Ouvre aussi **Secrets Manager** : le secret du mot de passe a été créé tout seul.
6. **Détruis tout** :
   ```bash
   terraform destroy
   ```
   Tape `yes`, attends la fin (quelques minutes), puis vérifie dans la console que la base a disparu.

Recommence `apply` / `destroy` autant que tu veux : c'est tout l'intérêt !

## Bonus : connecter ton API à la base AWS

Pour voir tes tâches stockées chez AWS, il faut ouvrir la base à **ta** IP seulement :

1. Trouve ton IP : https://checkip.amazonaws.com
2. Crée `infra/terraform.tfvars` (ignoré par Git) avec : `my_ip = "TON.IP.ICI"`, puis `terraform apply`.
3. Récupère le mot de passe **dans ton terminal** (ne le copie jamais dans un chat ni sur GitHub) :
   ```bash
   aws secretsmanager get-secret-value --profile tm \
     --secret-id "$(terraform output -raw db_secret_arn)" \
     --query SecretString --output text
   ```
4. Lance l'API en local, branchée sur RDS (la connexion AWS est chiffrée, d'où `DATABASE_SSL`) :
   ```bash
   cd ../app
   DATABASE_SSL=true DATABASE_URL="postgres://taskuser:MOT_DE_PASSE@ADRESSE_DB_ENDPOINT/tasks" npm start
   ```
   Si le mot de passe contient des caractères spéciaux (`/`, `@`, `:`…), il faut les encoder
   (par exemple `@` devient `%40`).
5. Ouvre http://localhost:3000 : tes tâches sont maintenant stockées dans le cloud !
6. N'oublie pas : `terraform destroy`.

## Le fichier d'état (`terraform.tfstate`)

Après `apply`, Terraform crée `terraform.tfstate` : sa mémoire de ce qu'il a créé. Il peut contenir
des informations sensibles, il est donc **ignoré par Git**. Ne le supprime pas tant que l'infra
existe, sinon Terraform « oublie » la base (et tu devrais la supprimer à la main dans la console).
À l'étape 5, on le rangera dans un stockage S3 pour que GitHub Actions puisse aussi l'utiliser.

## Ce qu'on a vérifié

- `terraform validate` et `terraform fmt` passent avec Terraform 1.17 et le provider AWS 6.x.
- Je n'ai pas lancé `apply` : c'est ton compte, c'est toi qui crées (et détruis) les ressources.

➡️ Prochaine étape : **GitHub Actions**, pour lancer les tests et construire l'image Docker
automatiquement à chaque push, et se connecter à AWS **sans aucune clé** grâce à OIDC.
