// Étape 7 : trois "middlewares", des fonctions qui s'exécutent pour CHAQUE requête.
const logger = require('./logger');

// 1. HTTPS obligatoire.
// En ligne, le visiteur parle en HTTPS au répartiteur de charge (ALB), qui transmet ensuite la
// requête au conteneur en HTTP, dans le réseau privé. L'ALB indique le protocole d'origine dans
// l'en-tête X-Forwarded-Proto. Si quelqu'un arrive en HTTP simple, on le renvoie vers HTTPS.
// En local, cet en-tête n'existe pas : rien ne change sur ton PC.
function forceHttps(req, res, next) {
  if (req.get('x-forwarded-proto') === 'http') {
    return res.redirect(308, `https://${req.get('host')}${req.originalUrl}`);
  }
  next();
}

// 2. En-têtes de sécurité : des consignes que le navigateur applique à notre site.
function securityHeaders(req, res, next) {
  // "Pendant 1 an, ne viens sur ce site qu'en HTTPS" (HSTS). Envoyé seulement en HTTPS.
  if (req.get('x-forwarded-proto') === 'https') {
    res.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  }
  res.set({
    // Seuls nos propres fichiers (scripts, styles, appels à l'API) sont autorisés :
    // un script injecté par un attaquant serait bloqué par le navigateur.
    'Content-Security-Policy':
      "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; " +
      "connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
    'X-Content-Type-Options': 'nosniff', // ne pas "deviner" le type d'un fichier
    'X-Frame-Options': 'DENY', // interdit d'afficher notre site dans une iframe (clickjacking)
    'Referrer-Policy': 'strict-origin-when-cross-origin',
  });
  next();
}

// 3. Un log par requête, écrit quand la réponse est partie (on connaît alors le statut et la durée).
// On ignore /health : le répartiteur l'appelle toutes les quelques secondes, ce serait du bruit.
function requestLogger(req, res, next) {
  if (req.path === '/health') return next();
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const fields = {
      type: 'request',
      method: req.method,
      path: req.originalUrl.split('?')[0],
      status: res.statusCode,
      durationMs: Math.round(Number(process.hrtime.bigint() - start) / 1e6),
    };
    if (res.statusCode >= 500) logger.error(fields);
    else if (res.statusCode >= 400) logger.warn(fields);
    else logger.info(fields);
  });
  next();
}

module.exports = { forceHttps, securityHeaders, requestLogger };
