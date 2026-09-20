# FUT Market Scraper

Petit serveur Node.js qui charge les pages joueurs de FUTBIN (FC 27) avec un vrai navigateur
headless (Playwright) et expose les prix de référence récupérés en JSON, pour que l'app iOS
FUT Market Watch puisse s'en servir à la place des données mock.

## Ce que ça fait — et ce que ça ne fait pas

FUTBIN n'a pas d'API publique et bloque les requêtes HTTP basiques (testé : 403 avec un simple
fetch). Un vrai navigateur headless passe en revanche sans problème — c'est ce que fait ce
service, testé en conditions réelles pendant le développement (vrais prix récupérés : Maradona
Icon à 6,12M, Zidane à 3M, etc. sur le marché Console).

Point important : **les prix récupérés sont le "prix de référence" agrégé de FUTBIN, pas des
annonces individuelles du vrai marché EA**. Concrètement, ça permet de suivre l'évolution d'un
prix dans le temps (tendance, dynamique haussière) mais pas de repérer une annonce précise
sous-évaluée en direct — voir la discussion dans la conversation qui a mené à ce service.

## ⚠️ À savoir avant de déployer

- **Contraire aux CGU de FUTBIN.** Pas illégal pour un usage personnel à faible volume, mais
  FUTBIN peut faire évoluer sa protection anti-bot et bloquer l'IP du serveur à tout moment —
  c'est fragile par nature, pas un partenariat officiel.
- **État en mémoire, non persistant.** L'historique de prix est gardé en RAM, pas en base de
  données. Sur le tier gratuit de Render, le service s'endort après 15 minutes sans requête
  entrante et repart de zéro à son réveil — l'historique de prix ne survit pas à ces cycles de
  veille. Pour un historique qui persiste vraiment, il faudrait ajouter une vraie base de
  données (hors scope de cette première version).
- **Sous-ensemble du catalogue.** FUTBIN a ~757 pages de joueurs au total ; ce service n'en
  scrape qu'une douzaine par défaut (`PAGES_TO_SCRAPE` dans `server.js`) pour rester léger et
  raisonnable — les cartes les plus cotées plus une tranche de cartes "gold" plus abordables.
  Ajuste cette liste si tu veux couvrir d'autres joueurs.
- **Club/nation/ligue non récupérés.** La page de liste FUTBIN ne montre pas ces infos
  directement (elles sont dans une carte au survol, chargée séparément) ; pour rester simple et
  limiter le nombre de requêtes, ce service ne les récupère pas pour l'instant.

## Déployer sur Render (gratuit)

1. Va sur [render.com](https://render.com) et crée un compte (gratuit).
2. **New +** → **Web Service**.
3. Connecte le dépôt GitHub `AWRTSI/undercover`.
4. Configure :
   - **Root Directory** : `scraper-service`
   - **Environment** : `Docker` (Render détecte le `Dockerfile` automatiquement)
   - **Instance Type** : `Free`
5. Clique **Create Web Service**. Le premier build prend quelques minutes (l'image Playwright
   fait plusieurs centaines de Mo).
6. Une fois déployé, Render te donne une URL du type `https://fut-market-scraper.onrender.com`.
   Note-la : c'est celle à entrer dans les Réglages de l'app iOS (URL de l'API de marché).

## Tester une fois déployé

```bash
curl https://TON-SERVICE.onrender.com/health
curl https://TON-SERVICE.onrender.com/players
```

Le premier appel à `/players` peut prendre 20-30 secondes (le service scrape en direct si les
données sont absentes ou vieilles de plus de 20 minutes) ; les suivants sont quasi instantanés
tant que le cache est frais.

## Endpoints

- `GET /health` — état du service, nombre de cartes suivies, date du dernier scrape.
- `GET /players` — liste des cartes avec prix Console (PS/Xbox) et PC.
- `GET /players/:id/history` — historique des prix enregistrés pour une carte (id FUTBIN).
- `POST /refresh` — force un nouveau scrape immédiatement (utile pour tester).

## Tester en local

```bash
npm install
npx playwright install chromium
node server.js
curl http://localhost:3000/players
```
