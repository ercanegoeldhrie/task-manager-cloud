// Choisit le stockage selon la configuration (encore une variable d'environnement !) :
// - DATABASE_URL ou PGHOST définie -> PostgreSQL
//     DATABASE_URL : tout en une ligne (pratique en local, avec Docker Compose)
//     PGHOST, PGUSER, PGPASSWORD, PGDATABASE : variables séparées (sur AWS, le mot de passe
//     arrive tout seul depuis Secrets Manager dans PGPASSWORD, sans jamais être écrit nulle part)
// - sinon -> mémoire (pratique pour coder vite)
const usePostgres = Boolean(process.env.DATABASE_URL || process.env.PGHOST);

module.exports = usePostgres ? require('./store-postgres') : require('./store-memory');
module.exports.mode = usePostgres ? 'PostgreSQL' : 'mémoire';
