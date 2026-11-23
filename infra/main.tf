# ---------------------------------------------------------------------------
# 1. LE RÉSEAU
# Chaque compte AWS a un réseau privé par défaut (le "VPC par défaut") dans chaque région.
# On le réutilise : c'est gratuit et suffisant pour apprendre.
# "data" = on LIT quelque chose qui existe déjà, on ne le crée pas.
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Un "security group" est un pare-feu : il dit qui a le droit de parler à la base.
# Par défaut, PERSONNE ne peut entrer. On ouvre seulement ce qui est nécessaire.
resource "aws_security_group" "db" {
  name        = "${var.project}-db"
  description = "Acces a la base PostgreSQL"
  vpc_id      = data.aws_vpc.default.id
}

# L'application (étape 6) tourne dans le même réseau privé (VPC) : on autorise ce réseau,
# et lui seul, à parler à la base. La base reste invisible depuis Internet.
resource "aws_vpc_security_group_ingress_rule" "db_from_vpc" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = data.aws_vpc.default.cidr_block
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "PostgreSQL depuis le VPC (application)"
}

# Règle optionnelle : autoriser TON adresse IP (et elle seule) sur le port PostgreSQL 5432.
# "count = 0" veut dire "ne pas créer" : la règle n'existe que si my_ip est rempli.
resource "aws_vpc_security_group_ingress_rule" "db_from_my_ip" {
  count             = var.my_ip == "" ? 0 : 1
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = "${var.my_ip}/32" # /32 = exactement une adresse
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "PostgreSQL depuis mon PC"
}

# La base doit savoir dans quels sous-réseaux (zones du datacenter) elle peut vivre.
resource "aws_db_subnet_group" "db" {
  name       = "${var.project}-db"
  subnet_ids = data.aws_subnets.default.ids
}

# ---------------------------------------------------------------------------
# 2. LA BASE DE DONNÉES (AWS RDS PostgreSQL)
# ⚠️ C'EST LA RESSOURCE QUI COÛTE : elle est facturée à l'heure tant qu'elle existe,
# même si personne ne l'utilise. Couverte par les crédits du plan gratuit, mais pense
# à "terraform destroy" à la fin de chaque session.
# ---------------------------------------------------------------------------
resource "aws_db_instance" "db" {
  identifier     = "${var.project}-db"
  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro" # la plus petite machine (2 processeurs, 1 Go de RAM)

  allocated_storage = 20 # Go de disque
  storage_type      = "gp2"
  storage_encrypted = true # données chiffrées sur le disque

  db_name  = "tasks"
  username = "taskuser"
  # Pas de mot de passe dans le code ! AWS le génère et le range lui-même
  # dans Secrets Manager (≈ 0,40 $/mois, couvert par les crédits). On s'en servira à l'étape 7.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = var.my_ip != ""

  # Réglages "apprentissage" pour rester gratuit et pouvoir tout détruire facilement.
  # En entreprise, on ferait l'inverse (sauvegardes, haute dispo, protection).
  multi_az                = false # une seule copie (la haute dispo double le prix)
  backup_retention_period = 0     # pas de sauvegardes automatiques (limite du plan gratuit)
  skip_final_snapshot     = true  # pas de sauvegarde finale au "destroy"
  deletion_protection     = false
  apply_immediately       = true
}

# ---------------------------------------------------------------------------
# 3. LE REGISTRE D'IMAGES DOCKER (Amazon ECR)
# C'est là qu'on enverra l'image de l'étape 2, pour qu'AWS puisse la lancer (étape 6).
# Gratuit jusqu'à 500 Mo de stockage par mois avec le plan gratuit.
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "api" {
  name                 = "${var.project}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # permet "terraform destroy" même s'il reste des images

  image_scanning_configuration {
    scan_on_push = true # AWS cherche des failles connues dans chaque image envoyée
  }
}

# On ne garde que les 3 dernières images, pour rester sous les 500 Mo gratuits.
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Garder seulement les 3 dernieres images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = { type = "expire" }
    }]
  })
}
