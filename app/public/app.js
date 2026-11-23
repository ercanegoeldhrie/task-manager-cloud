// Le "frontend" : il appelle notre API avec fetch() et affiche le résultat.
const list = document.getElementById('list');
const empty = document.getElementById('empty');

async function load() {
  const tasks = await (await fetch('/api/tasks')).json();
  list.innerHTML = '';
  empty.hidden = tasks.length > 0;
  for (const t of tasks) {
    const li = document.createElement('li');
    li.className = t.done ? 'done' : '';
    const box = document.createElement('input');
    box.type = 'checkbox';
    box.checked = t.done;
    box.onchange = () => send('PATCH', t.id, { done: box.checked });
    const span = document.createElement('span');
    span.textContent = t.title; // textContent (et pas innerHTML) évite les failles XSS
    const del = document.createElement('button');
    del.textContent = 'Supprimer';
    del.onclick = () => send('DELETE', t.id);
    li.append(box, span, del);
    list.append(li);
  }
}

async function send(method, id, body) {
  await fetch(`/api/tasks/${id}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  load();
}

document.getElementById('form').onsubmit = async (e) => {
  e.preventDefault();
  const input = document.getElementById('title');
  await fetch('/api/tasks', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: input.value }),
  });
  input.value = '';
  load();
};

load();
