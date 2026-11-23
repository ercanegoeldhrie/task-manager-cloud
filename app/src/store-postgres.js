// Stockage dans PostgreSQL : les tâches sont gardées sur disque, même après un redémarrage.
// En local, la base tourne dans Docker. Dans le cloud, ce sera AWS RDS : le code ne changera pas,
// seule l'adresse de connexion (DATABASE_URL) sera différente.
const { Pool } = require('pg');

// Un "pool" garde quelques connexions ouvertes et les réutilise (plus rapide qu'en ouvrir une
// à chaque requête). DATABASE_URL ressemble à : postgres://utilisateur:motdepasse@hote:5432/base
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Sur AWS RDS, la connexion est chiffrée (SSL). On l'activera avec DATABASE_SSL=true.
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

// Transforme une ligne SQL (colonnes en snake_case) en objet JavaScript (camelCase).
const toTask = (row) => ({
  id: row.id,
  title: row.title,
  done: row.done,
  createdAt: row.created_at.toISOString(),
});

// Crée la table si elle n'existe pas encore. Appelé une fois au démarrage.
async function init() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS tasks (
      id         SERIAL PRIMARY KEY,
      title      VARCHAR(200) NOT NULL,
      done       BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function list() {
  const { rows } = await pool.query('SELECT * FROM tasks ORDER BY id');
  return rows.map(toTask);
}

// Les $1, $2… sont des "requêtes paramétrées" : la valeur est envoyée à part du texte SQL.
// C'est ce qui protège contre les injections SQL. Ne jamais coller une valeur dans le SQL !
async function create(title) {
  const { rows } = await pool.query('INSERT INTO tasks (title) VALUES ($1) RETURNING *', [title]);
  return toTask(rows[0]);
}

async function update(id, changes) {
  const title = typeof changes.title === 'string' ? changes.title : null;
  const done = typeof changes.done === 'boolean' ? changes.done : null;
  // COALESCE(nouvelle valeur, ancienne) : on ne change que ce qui a été envoyé.
  const { rows } = await pool.query(
    'UPDATE tasks SET title = COALESCE($2, title), done = COALESCE($3, done) WHERE id = $1 RETURNING *',
    [id, title, done],
  );
  return rows[0] ? toTask(rows[0]) : null;
}

async function remove(id) {
  const { rowCount } = await pool.query('DELETE FROM tasks WHERE id = $1', [id]);
  return rowCount > 0;
}

// Vide la table (utilisé seulement par les tests).
async function reset() {
  await pool.query('TRUNCATE tasks RESTART IDENTITY');
}

async function close() {
  await pool.end();
}

module.exports = { init, list, create, update, remove, reset, close };
