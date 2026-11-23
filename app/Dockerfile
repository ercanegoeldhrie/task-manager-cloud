# Dockerfile : la "recette" pour fabriquer l'image de notre API.
# Chaque ligne crée une couche ; Docker réutilise les couches qui n'ont pas changé (cache).

# 1. On part d'une image officielle qui contient déjà Node.js 22.
#    "alpine" = une version Linux minuscule (image plus légère, plus rapide à envoyer chez AWS).
FROM node:22-alpine

# 2. Le dossier de travail à l'intérieur du conteneur.
WORKDIR /app

# 3. On copie d'abord SEULEMENT la liste des dépendances, puis on les installe.
#    Astuce de cache : tant que package.json ne change pas, Docker saute cette étape.
#    --omit=dev : on n'installe pas les outils de développement en production.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# 4. Ensuite on copie notre code.
COPY src ./src
COPY public ./public

# 5. Sécurité : on n'exécute pas l'app en "root" (administrateur) mais avec l'utilisateur
#    "node", prévu pour ça dans l'image officielle.
USER node

# 6. Configuration par variables d'environnement (modifiables au lancement).
ENV NODE_ENV=production
ENV PORT=3000

# 7. Documentation : l'app écoute sur le port 3000.
EXPOSE 3000

# 8. La commande lancée au démarrage du conteneur.
CMD ["node", "src/server.js"]
