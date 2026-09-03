# Underlight — Design

## Setting

**Cobalt Bay** is a working port city that grew up around a mineral seam. Its
underground economy is **Lumen**: bio-luminescent crystal light, cultured from
spore and mineral, that burns for weeks without power or flame. Licensed Lumen
exists and is expensive. Unlicensed Lumen is what everyone actually has in
their window.

The **Civic Standards Bureau** regulates it — officially on safety grounds,
practically because untaxed light is untaxed money. The Bureau fines, seizes
and shutters. It does not shoot at you. Getting caught costs you a night, a
fine and your stock; it never costs you the run.

Opposing you is the **Tidewell Syndicate**, who had the trade before you turned
up and who own several inspectors outright.

### The five products

| Product | Tier | Base | Character |
|---|---|---|---|
| Pale Shard | 1 | $34 | Soft white, a fortnight. Every bedsit has one. |
| Cobalt Bloom | 2 | $72 | Deep blue, slow. The Bay's signature. |
| Aurora Prism | 3 | $145 | Shifts colour as it burns. Collectors' item. |
| Solar Halo | 4 | $290 | A month of gold. A statement. |
| Midnight Veil | 5 | $520 | Light folded until a room reads as empty. |

### The nine materials

Ferro-Silt and Tide Ash are the cheap skeleton. Bloomspore threads the light.
Binder Resin holds a lattice while it sets. Chromatic Salt, Cryo-Gel, Harbour
Solvent, Voltaic Dust and Prism Flake are additives — each buys quality at a
different price in money, time and attention.

---

## The districts

The city is a 3×2 grid of 120 m districts on a bay to the north.

| District | Wealth | Footfall | Patrol | Opens |
|---|---|---|---|---|
| Dockside | 0.25 | 0.55 | 0.35 | Start |
| Ironworks Flats | 0.38 | 0.70 | 0.50 | Start |
| Old Town Rows | 0.45 | 0.85 | 0.60 | Dockside standing 25 |
| Market Row | 0.55 | 1.15 | 0.75 | Chapter 3 |
| Meridian Core | 0.85 | 1.30 | 1.35 | Chapter 8 |
| Hillcrest | 1.00 | 0.60 | 1.10 | Chapter 6 |

Each district has its own demand curve per product, so the same Pale Shard that
sells briskly on the pier is nearly worthless on the hill, and an Aurora Prism
is the reverse. Moving product to where it is wanted is the map's whole reason
to exist.

---

## Systems

### Quality

Quality is one number, rolled once when a job starts, then bucketed into five
named tiers with steep price multipliers:

| Tier | Dull | Clear | Vivid | Radiant | Immaculate |
|---|---|---|---|---|---|
| Multiplier | 0.60 | 0.85 | 1.15 | 1.60 | 2.30 |

The score comes from the recipe's floor, the station's tier, additives, your
Craft skills, whoever is operating the bench, and a small random wobble. The
production screen shows the whole breakdown *before* you commit materials, so
the decision is informed and the outcome is yours.

### Price

Unit price is the product of eleven factors, and the phone can show you all of
them: base value, quality, packaging, district wealth, live demand, a slow
price drift, your reputation, rival market share, the buyer's archetype, your
Hustle skills, prestige from owning showpiece property, active world events,
and a night premium.

Demand falls as you sell into a district (0.035 per unit) and recovers hourly.
Flooding a market is a real and reversible mistake.

### Risk

Two meters. **Suspicion** is immediate and local: it rises while an officer can
see contraband on you, and while you do conspicuous things. It falls quickly
when nobody is watching and faster when you crouch out of sight. **Heat** is
slow and per-district: it accumulates from sales and stock and decays daily. A
property's own heat drives investigations and eventually raids.

Four wanted levels escalate fines, seizure fraction and shutdown length:

| Level | Fine | Seized | Shutdown |
|---|---|---|---|
| 1 | $360 | 35% | — |
| 2 | $600 | 60% | 4h |
| 3 | $840 | 85% | 10h |
| 4 | $1,080 | 100% | 20h |

Every one of those is reduced by the Nerve tree, by packaging, and by choosing
where you deal.

### Property

Seven properties, four independent upgrade ladders each — Storage, Production,
Staff Quarters, Security. Upgrades add daily running cost equal to about 1.2%
of their price, so growth you cannot feed is growth that bankrupts you. The
Market Row stall is a legitimate front: it sells slowly and safely on its own,
and it cuts your laundering fee.

### Staff

Five archetypes from Yard Hand to Site Fixer. Assign each to Production, Street
Sales, Supply Runs or Security. They work on the hourly tick whether or not you
are there: starting jobs, moving stock, buying materials, suppressing heat.
They also need paying. Two unpaid days at low loyalty and they walk out, and
sometimes take stock with them.

### Progression

Levels come from every action that matters. Each gives a skill point across
four trees:

- **Hustle** — price, loyalty, customer density, bulk rates, live market data.
- **Craft** — quality, yield, material savings, speed, a third additive slot.
- **Nerve** — suspicion resistance, carry heat, wanted decay, bust mitigation,
  and finally near-invisibility while crouched.
- **Empire** — upkeep, employee output, wages, storage and front throughput.

### Story

Ten chapters, from Mira Vance handing you a key to deciding what kind of owner
you are. Along the way: Odette Sang teaches you lattices the Bureau classified,
Grip Halloran taxes you on behalf of Tidewell, Inspector Calder makes it clear
he is choosing not to arrest you, and Ivo Brandt writes everything down.

### Endings

Five, all live simultaneously, all trackable in the phone:

| Path | Requirement |
|---|---|
| The Quiet Fortune | $2,000,000 banked |
| The Long Table | Full city influence |
| Total Market | Control all six districts and break Tidewell |
| The Bay's Own | Standing 90+ everywhere |
| Landlord | Own all seven properties |

---

## Balance intent

- **The first ten minutes should pay.** Starting kit crafts two Pale Shards
  immediately; Dockside demand for them is 1.25, the highest in the city.
- **Every upgrade should have a downside.** Storage attracts raids. Staff cost
  wages. Voltaic Dust makes better product and more heat.
- **Getting caught should sting and end.** No death, no run loss, no
  unrecoverable state. The worst outcome is a shut site and a bad week.
- **The map should be a decision.** Wealth, demand, patrol density and travel
  time should never all point the same way.
