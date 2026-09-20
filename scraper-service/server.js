import express from 'express';
import { chromium } from 'playwright';

const app = express();
const PORT = process.env.PORT || 3000;

// FUTBIN n'a pas d'API publique : ce serveur charge ses pages avec un vrai navigateur headless
// (un simple fetch/axios se prend un 403, confirmé en testant) puis parse le tableau de joueurs.
// Les prix affichés sont le PRIX DE RÉFÉRENCE agrégé de FUTBIN (pas des annonces individuelles
// du marché EA) — voir README.md pour ce que ça implique côté détection d'opportunités.
const FUTBIN_BASE = 'https://www.futbin.com/27/players';
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

// Pages 1-5 couvrent les cartes les plus haut cotées (les plus suivies) ; 40-45 et 90-95
// ajoutent une tranche de cartes "gold" plus abordables pour varier les fourchettes de prix.
// FUTBIN a ~757 pages au total (tout le catalogue) : on ne scrape volontairement qu'un
// sous-ensemble raisonnable pour rester léger et respectueux du site.
const PAGES_TO_SCRAPE = [1, 2, 3, 4, 5, 40, 41, 42, 90, 91, 92];

const STALE_AFTER_MS = 20 * 60 * 1000; // 20 minutes
const MAX_HISTORY_POINTS = 300;

/** État en mémoire — repart de zéro à chaque redémarrage du service (voir README, limite du tier gratuit). */
const state = {
  playersById: new Map(), // id -> dernière fiche scrapée
  historyById: new Map(), // id -> [{ timestamp, price }]
  lastScrapedAt: null,
  isScraping: false,
};

function parseAmount(raw) {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed === '0' || trimmed === '-' || trimmed === '') return null;
  const match = trimmed.match(/^([\d.,]+)\s*([KM]?)$/i);
  if (!match) return null;
  const value = parseFloat(match[1].replace(',', ''));
  if (Number.isNaN(value)) return null;
  const suffix = match[2].toUpperCase();
  if (suffix === 'K') return Math.round(value * 1_000);
  if (suffix === 'M') return Math.round(value * 1_000_000);
  return Math.round(value);
}

/** FUTBIN a des dizaines de libellés de carte (TOTW, TOTS, Icon, Hero, Rare Gold...) ;
 * on les ramène aux 5 raretés que l'app iOS connaît déjà. */
function mapRarity(cardTypeLabel) {
  const label = (cardTypeLabel || '').toLowerCase();
  if (label.includes('icon')) return 'icon';
  if (label.includes('hero')) return 'hero';
  if (label.includes('rare')) return 'rare';
  if (label.includes('common')) return 'common';
  return 'special'; // TOTW, TOTS, promo, etc.
}

async function scrapePage(browser, pageNumber) {
  const page = await browser.newPage({ userAgent: USER_AGENT });
  const results = [];
  try {
    await page.goto(`${FUTBIN_BASE}?page=${pageNumber}`, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForSelector('table tbody tr.player-row', { timeout: 15000 });

    const rows = await page.$$eval('table tbody tr.player-row', (trs) =>
      trs.map((tr) => {
        const link = tr.querySelector('a.player-row-playercard');
        const nameCell = tr.querySelector('td.table-name');
        const posCell = tr.querySelector('td.table-pos');
        const psCell = tr.querySelector('td.table-price.platform-ps-only');
        const pcCell = tr.querySelector('td.table-price.platform-pc-only');
        return {
          href: link ? link.getAttribute('href') : null,
          nameCellText: nameCell ? nameCell.innerText : '',
          posCellText: posCell ? posCell.innerText : '',
          psCellText: psCell ? psCell.innerText : '',
          pcCellText: pcCell ? pcCell.innerText : '',
        };
      })
    );

    for (const row of rows) {
      if (!row.href) continue;
      // Format attendu : /27/player/{id}/{slug}
      const idMatch = row.href.match(/\/27\/player\/(\d+)\//);
      if (!idMatch) continue;
      const id = idMatch[1];

      const nameLines = row.nameCellText.split('\n').map((l) => l.trim()).filter(Boolean);
      const [ratingLine, nameLine, cardTypeLine] = nameLines;
      // Deux lignes = position "boostée" par un style de chimie (ex. "CAM++") suivie de la
      // position de base réelle ; une seule ligne = pas d'altération, juste le "++" à retirer.
      const posLines = row.posCellText.split('\n').map((l) => l.trim()).filter(Boolean);
      const basePosition = (posLines.length > 1 ? posLines[posLines.length - 1] : posLines[0] || '').replace(/\+/g, '');

      const psLines = row.psCellText.split('\n').map((l) => l.trim()).filter(Boolean);
      const pcLines = row.pcCellText.split('\n').map((l) => l.trim()).filter(Boolean);

      results.push({
        id,
        name: nameLine || 'Inconnu',
        overall: parseInt(ratingLine, 10) || 0,
        rarity: mapRarity(cardTypeLine),
        position: basePosition,
        pricePS: parseAmount(psLines[0]),
        pricePC: parseAmount(pcLines[0]),
      });
    }
  } finally {
    await page.close();
  }
  return results;
}

async function runScrape() {
  if (state.isScraping) return;
  state.isScraping = true;
  const browser = await chromium.launch({ headless: true });
  try {
    for (const pageNumber of PAGES_TO_SCRAPE) {
      const rows = await scrapePage(browser, pageNumber);
      const scrapedAt = Date.now();

      for (const row of rows) {
        state.playersById.set(row.id, { ...row, updatedAt: scrapedAt });

        // Le marché "console" (PS5/Xbox partagent le même prix chez EA) est celui qu'on
        // retient par défaut pour l'historique — voir GamingPlatform.swift côté app.
        const trackedPrice = row.pricePS ?? row.pricePC;
        if (trackedPrice == null) continue;

        const history = state.historyById.get(row.id) ?? [];
        history.push({ timestamp: scrapedAt, price: trackedPrice });
        if (history.length > MAX_HISTORY_POINTS) history.shift();
        state.historyById.set(row.id, history);
      }

      // Pause courte entre deux pages pour rester raisonnable vis-à-vis de FUTBIN.
      await new Promise((resolve) => setTimeout(resolve, 1500));
    }
    state.lastScrapedAt = Date.now();
  } finally {
    await browser.close();
    state.isScraping = false;
  }
}

async function ensureFreshData() {
  const isStale = !state.lastScrapedAt || Date.now() - state.lastScrapedAt > STALE_AFTER_MS;
  if (isStale) {
    await runScrape();
  }
}

app.get('/health', (_req, res) => {
  res.json({ ok: true, lastScrapedAt: state.lastScrapedAt, trackedPlayers: state.playersById.size });
});

app.get('/players', async (_req, res) => {
  try {
    await ensureFreshData();
    // On embarque la moyenne mobile et l'historique directement ici : ça évite à l'app d'avoir
    // à faire un appel /players/:id/history par carte (des dizaines de requêtes séparées), vu
    // que le serveur les a déjà en mémoire de toute façon.
    const players = Array.from(state.playersById.values()).map((player) => {
      const history = state.historyById.get(player.id) ?? [];
      const rollingAveragePrice = history.length
        ? Math.round(history.reduce((sum, point) => sum + point.price, 0) / history.length)
        : null;
      return { ...player, rollingAveragePrice, history };
    });
    res.json({ lastScrapedAt: state.lastScrapedAt, players });
  } catch (error) {
    res.status(502).json({ error: 'scrape_failed', message: String(error) });
  }
});

app.get('/players/:id/history', async (req, res) => {
  const history = state.historyById.get(req.params.id) ?? [];
  res.json({ id: req.params.id, history });
});

app.post('/refresh', async (_req, res) => {
  try {
    await runScrape();
    res.json({ ok: true, lastScrapedAt: state.lastScrapedAt, trackedPlayers: state.playersById.size });
  } catch (error) {
    res.status(502).json({ error: 'scrape_failed', message: String(error) });
  }
});

app.listen(PORT, () => {
  console.log(`FUT market scraper listening on port ${PORT}`);
});
