// Point d'entrée : prépare le stockage, puis démarre le serveur HTTP.
// Le port vient d'une VARIABLE D'ENVIRONNEMENT : c'est une bonne pratique cloud
// (la même image tournera partout, seule la configuration change).
const app = require('./app');
const store = require('./store');

const PORT = process.env.PORT || 3000;

store
  .init()
  .then(() => {
    app.listen(PORT, () => console.log(`API démarrée sur le port ${PORT} (stockage : ${store.mode})`));
  })
  .catch((err) => {
    console.error('Impossible de préparer le stockage :', err.message);
    process.exit(1);
  });
