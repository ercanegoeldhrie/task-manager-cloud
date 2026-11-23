# Les "outputs" sont les informations utiles affichées à la fin de "terraform apply".

output "db_endpoint" {
  description = "Adresse de la base (hôte:port)"
  value       = aws_db_instance.db.endpoint
}

output "db_secret_arn" {
  description = "Identifiant du secret qui contient le mot de passe de la base"
  value       = aws_db_instance.db.master_user_secret[0].secret_arn
}

output "ecr_repository_url" {
  description = "Adresse du registre où envoyer l'image Docker"
  value       = aws_ecr_repository.api.repository_url
}

output "github_deploy_role_arn" {
  description = "Rôle à mettre dans la variable GitHub AWS_ROLE_ARN (ce n'est pas un secret)"
  value       = aws_iam_role.github_deploy.arn
}
