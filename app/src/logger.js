// Étape 7 : des logs "structurés" en JSON, une ligne par événement.
//
// Pourquoi du JSON plutôt que du texte libre ? Parce que CloudWatch sait le lire :
// on peut ensuite filtrer ({ $.status >= 500 }), compter les erreurs, calculer des temps
// de réponse moyens, déclencher des alertes… sans jamais ouvrir un fichier à la main.
//
// Exemple de ligne produite :
// {"time":"2026-11-24T15:00:00.000Z","level":"info","type":"request","method":"GET","path":"/api/tasks","status":200,"durationMs":12}

let sink = (line) => process.stdout.write(line + '\n');

function log(level, fields) {
  const entry = { time: new Date().toISOString(), level, ...fields };
  if (entry.error instanceof Error) {
    // Une erreur JavaScript ne se convertit pas en JSON toute seule : on garde l'utile.
    entry.error = { message: entry.error.message, stack: entry.error.stack };
  }
  sink(JSON.stringify(entry));
}

module.exports = {
  info: (fields) => log('info', fields),
  warn: (fields) => log('warn', fields),
  error: (fields) => log('error', fields),
  // Pour les tests : capturer les lignes au lieu de les écrire dans la console.
  setSink: (fn) => { sink = fn; },
};
