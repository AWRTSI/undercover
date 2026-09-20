# Image officielle Playwright : Chromium + toutes ses dépendances système sont déjà installés,
# ce qui évite d'avoir à les compiler soi-même sur Render. Le tag DOIT correspondre exactement
# à la version de "playwright" dans package.json (voir README si le build échoue là-dessus).
FROM mcr.microsoft.com/playwright:v1.49.0-jammy

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY server.js ./

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "server.js"]
