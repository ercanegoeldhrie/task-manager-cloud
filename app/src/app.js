// L'application Express : elle décrit les routes (les "adresses") de notre API.
// On la sépare de server.js pour pouvoir la tester sans démarrer de vrai serveur.
const path = require('path');
const express = require('express');
const store = require('./store');

const app = express();
app.use(express.json()); // lit le corps JSON des requêtes
app.use(express.static(path.join(__dirname, '..', 'public'))); // sert l'interface web

// Route de santé : AWS l'appellera régulièrement pour vérifier que l'app tourne.
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Lister les tâches
app.get('/api/tasks', (req, res) => res.json(store.list()));

// Créer une tâche
app.post('/api/tasks', (req, res) => {
  const title = (req.body && req.body.title || '').trim();
  if (!title) return res.status(400).json({ error: 'Le titre est obligatoire' });
  if (title.length > 200) return res.status(400).json({ error: 'Titre trop long (200 max)' });
  res.status(201).json(store.create(title));
});

// Modifier une tâche (titre ou "faite / pas faite")
app.patch('/api/tasks/:id', (req, res) => {
  const task = store.update(Number(req.params.id), req.body || {});
  if (!task) return res.status(404).json({ error: 'Tâche introuvable' });
  res.json(task);
});

// Supprimer une tâche
app.delete('/api/tasks/:id', (req, res) => {
  if (!store.remove(Number(req.params.id))) return res.status(404).json({ error: 'Tâche introuvable' });
  res.status(204).end();
});

module.exports = app;
