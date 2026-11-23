# ---------------------------------------------------------------------------
# 4. CONNEXION SANS CLÉ ENTRE GITHUB ACTIONS ET AWS (OIDC)
# Gratuit. On dit à AWS : « fais confiance aux jetons signés par GitHub »,
# puis on crée un rôle que SEUL le workflow de notre dépôt, sur main, peut utiliser.
# ---------------------------------------------------------------------------

# AWS fait confiance au fournisseur d'identité de GitHub.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Le numéro de ton compte AWS (lu automatiquement).
data "aws_caller_identity" "current" {}

# Le rôle que GitHub Actions va "endosser".
resource "aws_iam_role" "github_deploy" {
  name = "${var.project}-github-deploy"

  # La "trust policy" : QUI a le droit d'utiliser ce rôle.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Uniquement NOTRE dépôt, et uniquement la branche main.
          # Une pull request ou un autre dépôt ne peut pas obtenir ce rôle.
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Ce que le rôle a le droit de FAIRE : envoyer des images dans NOTRE registre, rien d'autre.
resource "aws_iam_role_policy" "github_deploy_ecr" {
  name = "push-to-ecr"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*" # cette action ne peut pas être limitée à un registre précis
      },
      {
        Sid    = "PushToOurRepository"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = aws_ecr_repository.api.arn
      },
      {
        # Étape 6 : relancer le service pour qu'il prenne la nouvelle image.
        Sid      = "RedeployOurService"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
        Resource = "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${var.project}/*"
      },
    ]
  })
}
