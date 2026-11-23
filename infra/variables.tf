# Les "variables" sont les réglages de notre infra. On peut les changer sans toucher au reste.

variable "region" {
  description = "Région AWS (Paris)"
  type        = string
  default     = "eu-west-3"
}

variable "aws_profile" {
  description = "Profil AWS CLI à utiliser (créé à l'étape 0)"
  type        = string
  default     = "tm"
}

variable "project" {
  description = "Nom du projet, utilisé dans le nom des ressources"
  type        = string
  default     = "task-manager"
}

variable "my_ip" {
  description = <<-EOT
    Ton adresse IP publique (ex : 102.244.10.20), pour te connecter à la base depuis ton PC.
    Laisse vide ("") pour garder la base privée, inaccessible depuis Internet (recommandé).
    ⚠️ Une base accessible depuis Internet reçoit une IP publique, facturée environ 3,6 $/mois.
  EOT
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "Dépôt GitHub autorisé à déployer (propriétaire/nom)"
  type        = string
  default     = "ercanegoeldhrie/task-manager-cloud"
}
