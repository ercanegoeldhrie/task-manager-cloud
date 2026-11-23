# Étape 0 : créer son compte AWS en sécurité

> But : avoir un compte AWS prêt à l'emploi, **protégé**, et qui **te prévient avant toute dépense**.
> Durée : environ 30 minutes. Coût : 0 €.

## Pourquoi tant de précautions ?

Un compte AWS est relié à ta carte bancaire. Si quelqu'un vole tes accès, il peut lancer des
serveurs à tes frais. Les 4 réflexes ci-dessous sont ceux que font les pros dès le premier jour.

## 1. Créer le compte

1. Va sur https://aws.amazon.com/free et clique sur « Créer un compte ».
2. Choisis le **plan gratuit (Free plan)**. Avec ce plan, AWS donne jusqu'à 200 $ de crédits
   et **ne te facture rien** tant que tu ne passes pas toi-même au plan payant.
   (Les règles changent parfois : relis la page « Free Tier » le jour où tu t'inscris.)
3. Une carte bancaire est demandée pour vérifier ton identité. C'est normal.
4. Région : on utilisera **Europe (Paris) `eu-west-3`** dans tout le projet.

Ce premier compte s'appelle le **compte root** (le « super-administrateur »). On ne l'utilisera
presque jamais ensuite.

## 2. Protéger le compte root avec la MFA

La MFA (authentification à deux facteurs) demande un code sur ton téléphone en plus du mot de passe.

1. En haut à droite : ton nom ▶ **Security credentials**.
2. Section **Multi-factor authentication (MFA)** ▶ **Assign MFA device**.
3. Choisis une application (Google Authenticator, Microsoft Authenticator, Authy…) et scanne le QR code.

## 3. Créer une alerte de budget (le filet de sécurité)

1. Cherche **Billing and Cost Management** ▶ **Budgets** ▶ **Create budget**.
2. Choisis le modèle **Zero spend budget** : tu reçois un e-mail dès qu'un seul centime est dépensé.
3. Mets ton adresse e-mail et valide.

Optionnel : crée un deuxième budget mensuel de 5 € pour avoir une alerte « si ça dérape ».

## 4. Créer ton utilisateur de travail (et arrêter d'utiliser root)

On utilise **IAM Identity Center**, la méthode recommandée aujourd'hui par AWS : pas de clé
d'accès permanente à stocker sur ton ordinateur.

1. Cherche **IAM Identity Center** ▶ **Enable**.
2. **Users** ▶ **Add user** : ton prénom, ton e-mail. Tu recevras une invitation.
3. **Permission sets** ▶ **Create** ▶ modèle **AdministratorAccess**.
4. **AWS accounts** ▶ coche ton compte ▶ **Assign users** ▶ ton utilisateur + le permission set.
5. Accepte l'invitation reçue par e-mail, choisis un mot de passe et **active la MFA**.
6. Note l'**URL du portail d'accès** (elle ressemble à `https://d-xxxxxxxxxx.awsapps.com/start`).
   C'est par là que tu te connecteras désormais.

## 5. Installer l'outil en ligne de commande (AWS CLI)

1. Installe AWS CLI v2 : https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
2. Dans un terminal :
   ```bash
   aws configure sso
   # SSO start URL : l'URL du portail notée plus haut
   # SSO region    : la région où tu as activé Identity Center
   # Default region: eu-west-3
   # Profile name  : tm   (pour "task manager")
   ```
3. Vérifie que ça marche :
   ```bash
   aws sts get-caller-identity --profile tm
   ```
   Tu dois voir ton numéro de compte. Pour te reconnecter plus tard : `aws sso login --profile tm`.

## 🔐 Règles d'or pour la suite

- **Ne colle jamais** un mot de passe, une clé d'accès ou un secret dans un chat, un e-mail ou un
  fichier envoyé sur GitHub. Ton numéro de compte AWS (12 chiffres) n'est pas un secret.
- Pour GitHub Actions (étape 5), on utilisera **OIDC** : GitHub prouve son identité à AWS à chaque
  exécution, **sans aucune clé stockée**.
- Après chaque session de travail sur AWS : `terraform destroy` pour tout éteindre.

## ✅ Checklist

- [ ] Compte créé avec le plan gratuit, région `eu-west-3`
- [ ] MFA activée sur le compte root
- [ ] Budget « Zero spend » créé
- [ ] Utilisateur IAM Identity Center créé, avec MFA
- [ ] `aws sts get-caller-identity --profile tm` fonctionne
