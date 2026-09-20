# Image officielle Playwright : Chromium + toutes ses dépendances système sont déjà installés,
# ce qui évite d'avoir à les compiler soi-même sur Render. Le tag DOIT correspondre EXACTEMENT
# à la version verrouillée dans package-lock.json (`node_modules/playwright`.version) — un
# simple "^1.49.0" dans package.json avait dérivé vers 1.63.0 lors d'un `npm install`, alors que
# cette image n'avait que les navigateurs de la 1.49.0 : Chromium introuvable au lancement,
# échec silencieux de chaque scrape en production alors que tout fonctionnait en local (où les
# deux versions avaient été installées ensemble, sans le décalage image/paquet).
FROM mcr.microsoft.com/playwright:v1.63.0-jammy

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY server.js ./

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "server.js"]
