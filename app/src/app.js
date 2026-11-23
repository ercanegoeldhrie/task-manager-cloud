// L'application Express : elle décrit les routes (les "adresses") de notre API.
// On la sépare de server.js pour pouvoir la tester sans démarrer de vrai serveur.
const path = require('path');
const express = require('express');
const store = require('./store');

const app = express();
app.use(express.json()); // lit le corps JSON des requêtes
app.use(express.static(path.join(__dirname, '..', 'public'))); // sert l'interface web

// Les accès à la base prennent du temps : les routes sont donc "async".
// Ce petit utilitaire envoie toute erreur au gestionnaire d'erreurs en bas du fichier.
const wrap = (fn) => (req, res, next) => fn(req, res).catch(next);

// Route de santé : AWS l'appellera régulièrement pour vérifier que l'app tourne.
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Lister les tâches
app.get('/api/tasks', wrap(async (req, res) => res.json(await store.list())));

// Créer une tâche
app.post('/api/tasks', wrap(async (req, res) => {
  const title = String((req.body && req.body.title) || '').trim();
  if (!title) return res.status(400).json({ error: 'Le titre est obligatoire' });
  if (title.length > 200) return res.status(400).json({ error: 'Titre trop long (200 max)' });
  res.status(201).json(await store.create(title));
}));

// Modifier une tâche (titre ou "faite / pas faite")
app.patch('/api/tasks/:id', wrap(async (req, res) => {
  const task = await store.update(Number(req.params.id), req.body || {});
  if (!task) return res.status(404).json({ error: 'Tâche introuvable' });
  res.json(task);
}));

// Supprimer une tâche
app.delete('/api/tasks/:id', wrap(async (req, res) => {
  if (!(await store.remove(Number(req.params.id)))) {
    return res.status(404).json({ error: 'Tâche introuvable' });
  }
  res.status(204).end();
}));

// Gestionnaire d'erreurs : on écrit le détail dans les logs (pour nous),
// et on renvoie un message neutre au client (pour ne rien révéler de l'intérieur).
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Erreur interne du serveur' });
});

module.exports = app;
