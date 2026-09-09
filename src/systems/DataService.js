/** Loads and indexes every static data file. All other systems read through this. */

class DataService {
  teams = []; players = []; boxes = [];
  rarityTiers = []; parallels = []; cardTypes = []; hitTypes = []; insertSets = [];
  odds = null; economy = null;

  #teamById = new Map();
  #playerById = new Map();
  #boxById = new Map();
  #parallelById = new Map();
  #rarityById = new Map();
  #hitById = new Map();
  #insertById = new Map();
  #cardTypeById = new Map();
  #playersBySport = new Map();

  async load(base = '') {
    const j = (p) => fetch(`${base}data/${p}`).then((r) => r.json());
    const [teams, players, boxes, cardtypes, odds, economy] = await Promise.all([
      j('teams.json'), j('players.json'), j('boxes.json'), j('cardtypes.json'), j('odds.json'), j('economy.json'),
    ]);

    this.teams = teams.teams;
    this.players = players.players;
    this.boxes = boxes.boxes;
    this.rarityTiers = cardtypes.rarityTiers;
    this.parallels = cardtypes.parallels;
    this.cardTypes = cardtypes.cardTypes;
    this.hitTypes = cardtypes.hitTypes;
    this.insertSets = cardtypes.insertSets;
    this.odds = odds;
    this.economy = economy;

    for (const t of this.teams) this.#teamById.set(t.id, t);
    for (const p of this.players) {
      this.#playerById.set(p.id, p);
      if (!this.#playersBySport.has(p.sport)) this.#playersBySport.set(p.sport, []);
      this.#playersBySport.get(p.sport).push(p);
    }
    for (const b of this.boxes) this.#boxById.set(b.id, b);
    for (const p of this.parallels) this.#parallelById.set(p.id, p);
    for (const r of this.rarityTiers) this.#rarityById.set(r.id, r);
    for (const hd of this.hitTypes) this.#hitById.set(hd.id, hd);
    for (const i of this.insertSets) this.#insertById.set(i.id, i);
    for (const c of this.cardTypes) this.#cardTypeById.set(c.id, c);

    // Stable jersey numbers so a player looks the same on every card.
    this.players.forEach((p, i) => { p.jersey = ((i * 17 + 3) % 98) + 1; });
    return this;
  }

  team(id) { return this.#teamById.get(id); }
  player(id) { return this.#playerById.get(id); }
  box(id) { return this.#boxById.get(id); }
  parallel(id) { return this.#parallelById.get(id) || this.#parallelById.get('none'); }
  rarity(id) { return this.#rarityById.get(id) || this.#rarityById.get('common'); }
  hitType(id) { return this.#hitById.get(id); }
  insertSet(id) { return this.#insertById.get(id); }
  cardType(id) { return this.#cardTypeById.get(id); }
  playersFor(sport) { return this.#playersBySport.get(sport) ?? []; }
  profile(id) { return this.odds.profiles[id]; }
  parallelTable(id) { return this.odds.parallelTables[id]; }
  hitTable(id) { return this.odds.hitTables[id]; }

  rarityOrder(id) { return this.rarity(id).order; }
  sports() { return ['NFL', 'NBA', 'MLB']; }
  sportLabel(s) { return { NFL: 'Football', NBA: 'Basketball', MLB: 'Baseball' }[s] ?? s; }
  teamsFor(sport) { return this.teams.filter((t) => t.sport === sport); }
}

export const Data = new DataService();
