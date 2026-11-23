// Tests automatiques de l'API, avec le lanceur de tests intégré à Node (node --test).
// À l'étape 5, GitHub Actions lancera ces tests à chaque push.
const { test, beforeEach, after } = require('node:test');
const assert = require('node:assert');
const app = require('../src/app');
const store = require('../src/store');

const server = app.listen(0); // port 0 = un port libre au hasard
const base = () => `http://localhost:${server.address().port}`;
const call = (method, path, body) =>
  fetch(base() + path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });

beforeEach(() => store.reset());
after(() => server.close());

test('GET /health répond ok', async () => {
  const res = await call('GET', '/health');
  assert.strictEqual(res.status, 200);
  assert.deepStrictEqual(await res.json(), { status: 'ok' });
});

test('créer puis lister une tâche', async () => {
  const created = await call('POST', '/api/tasks', { title: 'Apprendre Docker' });
  assert.strictEqual(created.status, 201);
  const tasks = await (await call('GET', '/api/tasks')).json();
  assert.strictEqual(tasks.length, 1);
  assert.strictEqual(tasks[0].title, 'Apprendre Docker');
  assert.strictEqual(tasks[0].done, false);
});

test('refuser une tâche sans titre', async () => {
  const res = await call('POST', '/api/tasks', { title: '   ' });
  assert.strictEqual(res.status, 400);
});

test('marquer une tâche comme faite', async () => {
  const { id } = await (await call('POST', '/api/tasks', { title: 'Tâche' })).json();
  const res = await call('PATCH', `/api/tasks/${id}`, { done: true });
  assert.strictEqual((await res.json()).done, true);
});

test('supprimer une tâche', async () => {
  const { id } = await (await call('POST', '/api/tasks', { title: 'Tâche' })).json();
  assert.strictEqual((await call('DELETE', `/api/tasks/${id}`)).status, 204);
  assert.strictEqual((await call('DELETE', `/api/tasks/${id}`)).status, 404);
});
