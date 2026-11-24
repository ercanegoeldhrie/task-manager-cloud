// Étape 7 : tests des logs JSON, des en-têtes de sécurité et de la redirection HTTPS.
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const app = require('../src/app');
const store = require('../src/store');
const logger = require('../src/logger');

const server = app.listen(0);
const base = () => `http://localhost:${server.address().port}`;

let lines = [];
before(() => store.init());
beforeEach(async () => {
  await store.reset();
  lines = [];
  logger.setSink((line) => lines.push(JSON.parse(line)));
});
after(async () => {
  server.close();
  await store.close();
});

// Le log est écrit à la fin de la réponse : on laisse un instant à l'événement "finish".
const tick = () => new Promise((r) => setTimeout(r, 20));

test('chaque requête produit une ligne de log JSON', async () => {
  await fetch(base() + '/api/tasks?debug=1');
  await tick();
  assert.strictEqual(lines.length, 1);
  const [log] = lines;
  assert.strictEqual(log.level, 'info');
  assert.strictEqual(log.type, 'request');
  assert.strictEqual(log.method, 'GET');
  assert.strictEqual(log.path, '/api/tasks'); // sans les paramètres d'URL
  assert.strictEqual(log.status, 200);
  assert.strictEqual(typeof log.durationMs, 'number');
  assert.ok(!Number.isNaN(Date.parse(log.time)));
});

test('/health ne pollue pas les logs', async () => {
  await fetch(base() + '/health');
  await tick();
  assert.strictEqual(lines.length, 0);
});

test('une erreur client est loggée en "warn"', async () => {
  await fetch(base() + '/api/tasks/999', { method: 'DELETE' });
  await tick();
  assert.strictEqual(lines[0].level, 'warn');
  assert.strictEqual(lines[0].status, 404);
});

test('un JSON mal formé renvoie 400, pas 500', async () => {
  const res = await fetch(base() + '/api/tasks', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{pas du json',
  });
  assert.strictEqual(res.status, 400);
});

test('une panne interne renvoie 500 sans détail et logge l\'erreur', async () => {
  const original = store.list;
  store.list = async () => { throw new Error('base injoignable'); };
  try {
    const res = await fetch(base() + '/api/tasks');
    assert.strictEqual(res.status, 500);
    assert.deepStrictEqual(await res.json(), { error: 'Erreur interne du serveur' });
    await tick();
    const exception = lines.find((l) => l.type === 'exception');
    assert.strictEqual(exception.level, 'error');
    assert.strictEqual(exception.error.message, 'base injoignable');
    assert.strictEqual(lines.find((l) => l.type === 'request').status, 500);
  } finally {
    store.list = original;
  }
});

test('en-têtes de sécurité présents', async () => {
  const res = await fetch(base() + '/');
  assert.match(res.headers.get('content-security-policy'), /default-src 'self'/);
  assert.strictEqual(res.headers.get('x-content-type-options'), 'nosniff');
  assert.strictEqual(res.headers.get('x-frame-options'), 'DENY');
  assert.strictEqual(res.headers.get('x-powered-by'), null);
  assert.strictEqual(res.headers.get('strict-transport-security'), null); // pas en HTTP local
});

test('HTTP derrière le répartiteur est redirigé vers HTTPS', async () => {
  // fetch() interdit de changer l'en-tête Host : on utilise le module http de Node.
  const res = await new Promise((resolve, reject) => {
    http
      .get(
        {
          port: server.address().port,
          path: '/api/tasks?x=1',
          headers: { 'X-Forwarded-Proto': 'http', Host: 'tm.example.com' },
        },
        resolve,
      )
      .on('error', reject);
  });
  res.resume();
  assert.strictEqual(res.statusCode, 308);
  assert.strictEqual(res.headers.location, 'https://tm.example.com/api/tasks?x=1');
});

test('HSTS envoyé quand la requête arrive en HTTPS', async () => {
  const res = await fetch(base() + '/health', { headers: { 'X-Forwarded-Proto': 'https' } });
  assert.strictEqual(res.status, 200);
  assert.match(res.headers.get('strict-transport-security'), /max-age=31536000/);
});
