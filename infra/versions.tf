# Versions de Terraform et du "provider" AWS (le plugin qui sait parler à AWS).
# On les fixe pour que tout le monde obtienne le même résultat.
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile # le profil créé avec "aws configure sso" (étape 0)

  # Ces étiquettes sont posées sur TOUTES les ressources : pratique pour retrouver
  # ce qui appartient au projet dans la console et sur la facture.
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
