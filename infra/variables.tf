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

variable "deploy_app" {
  description = <<-EOT
    Créer le service qui met l'app en ligne (étape 6) ?
    Mets true seulement APRÈS avoir envoyé une première image dans ECR.
    ⚠️ Le service coûte ~0,055 $/heure tant qu'il existe.
  EOT
  type        = bool
  default     = false
}

variable "alert_email" {
  description = <<-EOT
    Adresse e-mail qui reçoit les alertes (erreurs 500, lenteur, échec de démarrage).
    Laisse vide ("") pour ne créer aucune alarme. Pense à confirmer l'abonnement reçu par e-mail.
  EOT
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Nombre de jours pendant lesquels CloudWatch garde les logs de l'app"
  type        = number
  default     = 7
}
