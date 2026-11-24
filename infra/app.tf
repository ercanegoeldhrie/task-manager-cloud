# ---------------------------------------------------------------------------
# 5. L'APPLICATION EN LIGNE : Amazon ECS Express Mode
# On donne une image Docker, AWS s'occupe du reste : conteneurs Fargate (serveurs gérés par AWS),
# répartiteur de charge (ALB), adresse publique en HTTPS avec certificat, redémarrage si ça plante.
#
# ⚠️ COÛT quand le service existe : ~0,055 $/heure (~1,30 $/jour) pour le conteneur, le
# répartiteur de charge et les IP publiques. Couvert par les crédits : "terraform destroy" à la fin !
#
# Le service n'est créé que si deploy_app = true, car il faut d'abord une image dans ECR
# (voir docs/06-deploiement.md pour l'ordre des étapes).
# ---------------------------------------------------------------------------

# Un "cluster" ECS est un simple regroupement logique de services. Gratuit.
resource "aws_ecs_cluster" "main" {
  name = var.project
}

# --- Les rôles IAM : qui a le droit de faire quoi -------------------------

# Rôle "d'infrastructure" : permet à ECS de créer pour nous le répartiteur de charge,
# le certificat HTTPS, l'auto-scaling…
resource "aws_iam_role" "ecs_infrastructure" {
  name = "${var.project}-ecs-infrastructure"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_infrastructure" {
  role       = aws_iam_role.ecs_infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"
}

# Rôle "d'exécution" : permet à ECS de télécharger notre image depuis ECR,
# d'écrire les logs, et de lire le mot de passe de la base dans Secrets Manager.
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project}-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Moindre privilège : le droit de lire CE secret-là, et aucun autre.
resource "aws_iam_role_policy" "ecs_execution_db_secret" {
  name = "read-db-secret"
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_db_instance.db.master_user_secret[0].secret_arn
    }]
  })
}

# --- Le service -----------------------------------------------------------

resource "aws_ecs_express_gateway_service" "api" {
  count = var.deploy_app ? 1 : 0

  service_name            = "${var.project}-api"
  cluster                 = aws_ecs_cluster.main.name
  execution_role_arn      = aws_iam_role.ecs_execution.arn
  infrastructure_role_arn = aws_iam_role.ecs_infrastructure.arn

  # La plus petite taille possible : 0,25 processeur et 512 Mo de mémoire. Largement assez.
  cpu    = "256"
  memory = "512"

  # AWS appelle cette adresse régulièrement : si elle ne répond pas, il remplace le conteneur.
  health_check_path = "/health"

  # Un seul conteneur, jamais plus : on maîtrise la facture.
  scaling_target {
    min_task_count            = 1
    max_task_count            = 1
    auto_scaling_metric       = "AVERAGE_CPU"
    auto_scaling_target_value = 60
  }

  primary_container {
    # ":latest" = la dernière image envoyée par GitHub Actions.
    image          = "${aws_ecr_repository.api.repository_url}:latest"
    container_port = 3000

    # Étape 7 : les logs de l'app vont dans NOTRE groupe CloudWatch (observability.tf),
    # celui qui a une durée de conservation, des filtres et des alarmes.
    aws_logs_configuration = [{
      log_group         = aws_cloudwatch_log_group.api.name
      log_stream_prefix = "api"
    }]

    # Configuration NON secrète : variables d'environnement classiques.
    environment {
      name  = "PORT"
      value = "3000"
    }
    environment {
      name  = "PGHOST"
      value = aws_db_instance.db.address
    }
    environment {
      name  = "PGDATABASE"
      value = aws_db_instance.db.db_name
    }
    environment {
      name  = "PGUSER"
      value = aws_db_instance.db.username
    }
    environment {
      name  = "DATABASE_SSL"
      value = "true"
    }

    # Configuration SECRÈTE : ECS lit le mot de passe dans Secrets Manager au démarrage du
    # conteneur et le met dans PGPASSWORD. Il n'apparaît ni dans le code, ni dans Terraform,
    # ni dans GitHub. Le secret RDS est un JSON {"username": …, "password": …} :
    # ":password::" veut dire « seulement la clé password ».
    secret {
      name       = "PGPASSWORD"
      value_from = "${aws_db_instance.db.master_user_secret[0].secret_arn}:password::"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_infrastructure,
    aws_iam_role_policy_attachment.ecs_execution,
    aws_iam_role_policy.ecs_execution_db_secret,
  ]
}
