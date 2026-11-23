// Point d'entrée : démarre le serveur HTTP.
// Le port vient d'une VARIABLE D'ENVIRONNEMENT : c'est une bonne pratique cloud
// (la même image tournera partout, seule la configuration change).
const app = require('./app');

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`API démarrée sur http://localhost:${PORT}`));
