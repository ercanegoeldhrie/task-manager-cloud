# ---------------------------------------------------------------------------
# 6. OBSERVER L'APPLICATION (étape 7) : logs, métriques, alertes, tableau de bord
#
# Le principe :
#   l'app écrit des logs JSON ─▶ CloudWatch Logs les garde ─▶ des "filtres" en tirent des
#   métriques (nombre de requêtes, d'erreurs, temps de réponse) ─▶ des alarmes surveillent ces
#   métriques ─▶ SNS t'envoie un e-mail quand ça va mal.
#
# 💰 Coût : quasi nul pour ce projet. Le niveau gratuit de CloudWatch couvre 5 Go de logs,
# 10 métriques personnalisées, 10 alarmes et 3 tableaux de bord par mois.
# Ces ressources ne coûtent rien quand l'app est éteinte : on peut les laisser.
# ---------------------------------------------------------------------------

locals {
  metrics_namespace = "TaskManager" # le "dossier" de nos métriques dans CloudWatch
  alarms_enabled    = var.alert_email != ""
}

# --- Les logs --------------------------------------------------------------

# Le "groupe de logs" : le classeur où ECS range tout ce que l'app écrit (console.log…).
# Sans durée de conservation, AWS garde les logs POUR TOUJOURS et la facture grossit
# lentement. On les garde quelques jours, c'est assez pour enquêter.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project}-api"
  retention_in_days = var.log_retention_days
}

# --- Des logs aux métriques ------------------------------------------------
# Un "metric filter" lit chaque ligne de log JSON et met à jour une métrique.
# La syntaxe { $.champ = valeur } interroge directement le JSON écrit par app/src/logger.js.

resource "aws_cloudwatch_log_metric_filter" "requests" {
  name           = "${var.project}-requests"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.type = \"request\" }"

  metric_transformation {
    name          = "Requests"
    namespace     = local.metrics_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "server_errors" {
  name           = "${var.project}-5xx"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.type = \"request\" && $.status >= 500 }"

  metric_transformation {
    name          = "ServerErrors"
    namespace     = local.metrics_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "latency" {
  name           = "${var.project}-latency"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.type = \"request\" }"

  metric_transformation {
    name      = "LatencyMs"
    namespace = local.metrics_namespace
    value     = "$.durationMs" # la valeur vient du champ durationMs du log
    unit      = "Milliseconds"
  }
}

# Un démarrage d'API qui échoue (base injoignable, mot de passe refusé…)
resource "aws_cloudwatch_log_metric_filter" "startup_failures" {
  name           = "${var.project}-startup-failures"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.type = \"startup\" && $.level = \"error\" }"

  metric_transformation {
    name          = "StartupFailures"
    namespace     = local.metrics_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# --- Les alertes par e-mail ------------------------------------------------

# SNS est un service de "notifications" : un sujet (topic) auquel on s'abonne.
resource "aws_sns_topic" "alerts" {
  count = local.alarms_enabled ? 1 : 0
  name  = "${var.project}-alerts"
}

# ⚠️ AWS envoie d'abord un e-mail "AWS Notification - Subscription Confirmation" :
# il faut cliquer sur le lien "Confirm subscription", sinon aucune alerte n'arrivera.
resource "aws_sns_topic_subscription" "email" {
  count     = local.alarms_enabled ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarme 1 : au moins 5 erreurs serveur (500) en 5 minutes.
resource "aws_cloudwatch_metric_alarm" "server_errors" {
  count               = local.alarms_enabled ? 1 : 0
  alarm_name          = "${var.project}-erreurs-500"
  alarm_description   = "L'API a renvoyé au moins 5 erreurs 500 en 5 minutes. Regarde les logs : ${aws_cloudwatch_log_group.api.name}"
  namespace           = local.metrics_namespace
  metric_name         = "ServerErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching" # pas de trafic = pas de problème
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  ok_actions          = [aws_sns_topic.alerts[0].arn] # prévient aussi quand ça revient à la normale
}

# Alarme 2 : l'app devient lente (95 % des requêtes en plus de 1 seconde, 3 minutes de suite).
resource "aws_cloudwatch_metric_alarm" "slow" {
  count               = local.alarms_enabled ? 1 : 0
  alarm_name          = "${var.project}-lenteur"
  alarm_description   = "Le temps de réponse (p95) dépasse 1 seconde depuis 3 minutes."
  namespace           = local.metrics_namespace
  metric_name         = "LatencyMs"
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  ok_actions          = [aws_sns_topic.alerts[0].arn]
}

# Alarme 3 : l'API n'arrive pas à démarrer (souvent un problème de base de données).
resource "aws_cloudwatch_metric_alarm" "startup_failures" {
  count               = local.alarms_enabled ? 1 : 0
  alarm_name          = "${var.project}-echec-demarrage"
  alarm_description   = "L'API n'arrive pas à démarrer. ECS va réessayer en boucle : regarde les logs."
  namespace           = local.metrics_namespace
  metric_name         = "StartupFailures"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
}

# --- Le tableau de bord ----------------------------------------------------
# Une page dans la console CloudWatch qui montre tout d'un coup d'œil.

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.project
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Requêtes et erreurs 500 (par minute)"
          region = var.region
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
          metrics = [
            [local.metrics_namespace, "Requests", { label = "Requêtes" }],
            [local.metrics_namespace, "ServerErrors", { label = "Erreurs 500", color = "#d62728" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Temps de réponse (ms)"
          region = var.region
          period = 60
          view   = "timeSeries"
          metrics = [
            [local.metrics_namespace, "LatencyMs", { stat = "Average", label = "Moyenne" }],
            [local.metrics_namespace, "LatencyMs", { stat = "p95", label = "95 % des requêtes en moins de" }],
          ]
        }
      },
      {
        type = "log", x = 0, y = 6, width = 24, height = 8
        properties = {
          title  = "Dernières erreurs et avertissements"
          region = var.region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.api.name}' | fields @timestamp, level, method, path, status, durationMs, error.message | filter level != \"info\" | sort @timestamp desc | limit 50"
        }
      },
    ]
  })
}
