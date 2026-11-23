// Stockage des tâches EN MÉMOIRE (étape 1).
// Les données disparaissent quand le serveur redémarre : c'est voulu pour l'instant.
// À l'étape 3, on remplacera ce fichier par une vraie base PostgreSQL (AWS RDS)
// en gardant exactement les mêmes fonctions : le reste du code ne changera pas.

let tasks = [];
let nextId = 1;

function list() {
  return tasks;
}

function create(title) {
  const task = { id: nextId++, title, done: false, createdAt: new Date().toISOString() };
  tasks.push(task);
  return task;
}

function update(id, changes) {
  const task = tasks.find((t) => t.id === id);
  if (!task) return null;
  if (typeof changes.title === 'string') task.title = changes.title;
  if (typeof changes.done === 'boolean') task.done = changes.done;
  return task;
}

function remove(id) {
  const before = tasks.length;
  tasks = tasks.filter((t) => t.id !== id);
  return tasks.length < before;
}

function reset() {
  tasks = [];
  nextId = 1;
}

module.exports = { list, create, update, remove, reset };
