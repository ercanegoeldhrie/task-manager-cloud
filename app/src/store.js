// Choisit le stockage selon la configuration (encore une variable d'environnement !) :
// - DATABASE_URL définie   -> PostgreSQL
// - DATABASE_URL absente   -> mémoire (pratique pour coder vite)
module.exports = process.env.DATABASE_URL ? require('./store-postgres') : require('./store-memory');
