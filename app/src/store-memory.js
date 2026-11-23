// Stockage EN MÉMOIRE : les tâches disparaissent au redémarrage.
// On le garde pour développer ou tester vite, sans base de données.
// Les fonctions sont "async" pour avoir exactement la même forme que store-postgres.js.

let tasks = [];
let nextId = 1;

async function init() {}

async function list() {
  return tasks;
}

async function create(title) {
  const task = { id: nextId++, title, done: false, createdAt: new Date().toISOString() };
  tasks.push(task);
  return task;
}

async function update(id, changes) {
  const task = tasks.find((t) => t.id === id);
  if (!task) return null;
  if (typeof changes.title === 'string') task.title = changes.title;
  if (typeof changes.done === 'boolean') task.done = changes.done;
  return task;
}

async function remove(id) {
  const before = tasks.length;
  tasks = tasks.filter((t) => t.id !== id);
  return tasks.length < before;
}

async function reset() {
  tasks = [];
  nextId = 1;
}

async function close() {}

module.exports = { init, list, create, update, remove, reset, close };
