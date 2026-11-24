# Étape 7 : logs, alertes et HTTPS

> But : **savoir ce qui se passe** dans ton app en ligne, et **être prévenu** quand ça va mal,
> sans avoir à surveiller la console AWS toute la journée.
> Prérequis : étape 6 faite (l'app tourne sur ECS).

## Les concepts, simplement

- **Observabilité** : pouvoir répondre à « que se passe-t-il dans mon app ? » sans ajouter de code
  au moment de la panne. Elle repose sur trois choses : les **logs**, les **métriques** et les **alertes**.
- **Un log** est une ligne écrite par l'app : « requête GET /api/tasks, 200, 12 ms ».
- **Un log structuré** est un log en **JSON**. Un humain le lit aussi bien, et une machine peut le
  filtrer et le compter.
- **CloudWatch Logs** range les logs de tous tes conteneurs au même endroit, même ceux d'un
  conteneur arrêté depuis longtemps.
- **Une métrique** est un nombre qui évolue dans le temps : requêtes par minute, temps de réponse…
- **Une alarme** surveille une métrique : « plus de 5 erreurs en 5 minutes ? ». Si oui, elle
  passe en état `ALARM` et prévient **SNS**, qui t'envoie un e-mail.
- **HTTPS** chiffre la connexion entre le visiteur et ton site. Le répartiteur créé à l'étape 6
  s'en occupe déjà (avec un certificat gratuit). Cette étape **force** son usage.

```
app (logs JSON) ──▶ CloudWatch Logs ──filtres──▶ métriques ──▶ alarmes ──▶ SNS ──▶ 📧 ton e-mail
                          │                         │
                          └──── Logs Insights        └──── tableau de bord
                               (requêtes SQL-like)
```

## Ce qui a changé

| Fichier | Changement |
|---------|------------|
| `app/src/logger.js` | **nouveau** : écrit les logs en JSON, une ligne par événement |
| `app/src/middleware.js` | **nouveau** : un log par requête, redirection HTTP → HTTPS, en-têtes de sécurité |
| `app/src/app.js` | branche les middlewares ; un JSON mal formé renvoie 400 au lieu de 500 |
| `app/src/server.js` | logs JSON au démarrage, arrêt propre quand ECS envoie `SIGTERM` |
| `app/test/observability.test.js` | **nouveau** : 8 tests (logs, en-têtes, redirection) |
| `infra/observability.tf` | **nouveau** : groupe de logs, 4 métriques, 3 alarmes, e-mail, tableau de bord |
| `infra/app.tf` | les logs de l'app vont dans notre groupe CloudWatch |
| `infra/variables.tf` | `alert_email` et `log_retention_days` |

### Les logs, avant et après

Avant : `API démarrée sur le port 3000`. Après :

```json
{"time":"2026-11-24T15:00:00.000Z","level":"info","type":"request","method":"GET","path":"/api/tasks","status":200,"durationMs":12}
{"time":"2026-11-24T15:00:01.000Z","level":"error","type":"exception","method":"GET","path":"/api/tasks","error":{"message":"Connection terminated"}}
```

Le champ `level` vaut `info`, `warn` (erreur du client : 400, 404…) ou `error` (panne de notre côté : 500).
`/health` n'est pas loggé : le répartiteur l'appelle toutes les quelques secondes, ce serait du bruit.

### Les métriques et les alarmes

`infra/observability.tf` crée des **filtres** qui lisent les logs JSON et en tirent 4 métriques
(espace de noms `TaskManager`) :

| Métrique | Calcul | Alarme (si `alert_email` est rempli) |
|----------|--------|--------------------------------------|
| `Requests` | +1 par requête | - |
| `ServerErrors` | +1 par réponse 500 | ≥ 5 en 5 minutes |
| `LatencyMs` | durée de chaque requête | p95 > 1 seconde pendant 3 minutes |
| `StartupFailures` | +1 par démarrage raté | dès le premier |

« **p95** » veut dire : 95 % des requêtes sont plus rapides que cette valeur. C'est plus parlant
qu'une moyenne, qu'une seule requête très lente ou très rapide peut fausser.

### HTTPS forcé et en-têtes de sécurité

- Quelqu'un tape `http://…` : l'app le renvoie vers `https://…` (code 308).
- **HSTS** : le navigateur retient pendant un an qu'il ne doit venir qu'en HTTPS.
- **Content-Security-Policy** : le navigateur n'exécute que **nos** scripts. Un script injecté par
  un pirate serait bloqué.
- `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy` : petites protections classiques.
- `X-Powered-By: Express` n'est plus envoyé : inutile d'annoncer sa technologie aux curieux.

Tu peux tester en local : `curl -i -H "X-Forwarded-Proto: http" http://localhost:3000/` répond `308`.

### Et les secrets ?

C'est déjà fait depuis l'étape 6 : le mot de passe de la base vit dans **Secrets Manager**, et ECS
le donne au conteneur au démarrage. Il n'apparaît ni dans le code, ni dans les logs, ni dans GitHub.

## 💰 Coût

Pratiquement **0 €** : le niveau gratuit de CloudWatch couvre 5 Go de logs, 10 métriques
personnalisées, 10 alarmes et 3 tableaux de bord par mois. On en utilise 4, 3 et 1. Ces ressources
ne coûtent rien quand l'app est éteinte. Les logs sont effacés après 7 jours (`log_retention_days`).

## À toi de jouer

1. Ajoute ton adresse dans `infra/terraform.tfvars` :
   ```hcl
   alert_email = "toi@exemple.com"
   deploy_app  = true
   ```
2. Applique :
   ```bash
   aws sso login --profile tm
   cd infra
   terraform apply
   ```
3. **Ouvre ta boîte mail** : clique sur **Confirm subscription** dans le message d'AWS.
   Sans ce clic, aucune alerte n'arrivera.
4. Après le merge sur `main`, GitHub Actions déploie la nouvelle version (étape 5). Utilise un peu
   l'app en ligne : ajoute, coche, supprime des tâches.
5. Ouvre le lien `dashboard_url` affiché par Terraform : requêtes, temps de réponse, dernières erreurs.
6. Joue avec **CloudWatch ▶ Logs Insights** (groupe `/ecs/task-manager-api`) :
   ```
   fields @timestamp, method, path, status, durationMs
   | filter type = "request"
   | sort durationMs desc
   | limit 10
   ```
   Les 10 requêtes les plus lentes. Ou bien, le nombre de requêtes par route :
   ```
   filter type = "request" | stats count(*) as total, avg(durationMs) as moyenne_ms by path
   ```
7. **Déclenche une vraie alerte** : dans la console AWS, **RDS ▶ ta base ▶ Actions ▶ Arrêter
   temporairement**. L'app ne peut plus lire les tâches et renvoie des 500. Recharge la page une
   dizaine de fois : quelques minutes plus tard, tu reçois l'e-mail « ALARM: task-manager-erreurs-500 ».
   Redémarre la base : un e-mail « OK » suit.
8. Vérifie HTTPS : `curl -I http://<app_endpoint>/` (si le répartiteur accepte le HTTP, il répond
   `308` vers `https://`), puis `curl -I https://<app_endpoint>/` et repère les en-têtes de sécurité.
9. ⚠️ **Fin de session** : `terraform destroy`.

## Si ça ne marche pas

- **Pas d'e-mail d'alerte** : as-tu confirmé l'abonnement ? Console **SNS ▶ Subscriptions** :
  le statut doit être `Confirmed`, pas `Pending confirmation`.
- **Le tableau de bord est vide** : les métriques n'apparaissent qu'après les premières requêtes,
  avec 1 à 2 minutes de délai.
- **Aucun log dans `/ecs/task-manager-api`** : le service a été créé avant cette étape. Un
  `terraform apply` le met à jour ; ECS redémarre alors le conteneur avec la nouvelle configuration.

## Ce qu'on a vérifié

- Tests : 14 sur 14, dont 8 nouveaux (logs JSON, niveaux, `/health` ignoré, JSON mal formé → 400,
  panne → 500 sans détail, en-têtes de sécurité, redirection HTTPS, HSTS).
- L'interface web fonctionne avec la nouvelle `Content-Security-Policy` (aucune erreur dans le navigateur).
- `terraform validate` et `fmt` passent avec le provider AWS 6.74.
- Rien n'a été créé sur AWS : c'est toi qui appliqueras.

🎉 **C'est la dernière étape de la feuille de route.** Ton app est conteneurisée, sa base est
managée, son infra est du code, elle se déploie toute seule, et tu sais quand elle va mal.
