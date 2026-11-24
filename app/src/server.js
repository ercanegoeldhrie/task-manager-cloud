// Point d'entrée : prépare le stockage, puis démarre le serveur HTTP.
// Le port vient d'une VARIABLE D'ENVIRONNEMENT : c'est une bonne pratique cloud
// (la même image tournera partout, seule la configuration change).
const app = require('./app');
const store = require('./store');
const logger = require('./logger');

const PORT = process.env.PORT || 3000;

store
  .init()
  .then(() => {
    const server = app.listen(PORT, () =>
      logger.info({ type: 'startup', message: `API démarrée sur le port ${PORT}`, storage: store.mode }),
    );

    // Étape 7 : arrêt propre. Quand ECS remplace le conteneur (nouveau déploiement), il envoie
    // SIGTERM : on finit les requêtes en cours et on ferme la base avant de quitter.
    process.on('SIGTERM', () => {
      logger.info({ type: 'shutdown', message: 'SIGTERM reçu : arrêt propre' });
      server.close(() => store.close().finally(() => process.exit(0)));
    });
  })
  .catch((err) => {
    logger.error({ type: 'startup', message: 'Impossible de préparer le stockage', error: err });
    process.exit(1);
  });
