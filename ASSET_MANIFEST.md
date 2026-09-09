# Asset manifest

Every image the game can display is listed here. The runtime never builds a path
by hand: `src/core/assets.js` loads `data/assets.manifest.json` and resolves art
by key, so replacing a file is a drop-in operation.

- **Total assets:** 151
- **Required:** 120
- **Optional:** 31
- **Card artboard:** 750 x 1050 (2.5:3.5 trading card ratio)
- **Slab artboard:** 820 x 1300, card window 700 x 980 at (60, 282)

## Replacing artwork

1. **Same path, same name.** Drop a new `.svg` over the existing file. Nothing else changes.
2. **Different format or location.** Add an entry to `data/assets.overrides.json`:
   ```json
   { "box.BOX-NFL-PRIZM-25": "assets/overrides/prizm-photo.webp" }
   ```
   The registry prefers the override and falls back to the manifest path when the
   key is absent. Raster overrides (`.png`, `.jpg`, `.webp`, `.avif`) are rendered
   as `<img>`; vector files are inlined so they can inherit franchise colours.
3. **Match the artboard.** Keep the listed pixel dimensions (or the same aspect
   ratio at higher resolution) so layout is unaffected.

## Runtime colour tokens

Athlete cutouts and card templates are franchise-agnostic. When inlined they read
five CSS custom properties from their host card, so one file serves all 24 teams:

| Token | Meaning |
| --- | --- |
| `--tp` | Franchise primary |
| `--tp-l` | Primary, lightened (highlights) |
| `--tp-d` | Primary, darkened (shadow side) |
| `--ts` | Franchise secondary |
| `--ta` | Franchise accent / rim light |

Athlete files also expose `text.jersey-num`, which the card renderer rewrites with
the player's number.

## Production status

All artwork currently ships as generated vector art produced by `tools/generate-assets.mjs`.
It is finished, shippable art rather than grey-box placeholder, but it is vector
illustration, not licensed photography. Any slot below can be swapped for
photography or externally commissioned art with no code change.

## Interface backgrounds

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `ui.bg-hall` | `assets/ui/bg-hall.svg` | 1920x1200 | SVG | Screen backdrop for the hall view. | Required |
| `ui.bg-break` | `assets/ui/bg-break.svg` | 1920x1200 | SVG | Screen backdrop for the break view. | Required |
| `ui.bg-vault` | `assets/ui/bg-vault.svg` | 1920x1200 | SVG | Screen backdrop for the vault view. | Required |
| `ui.bg-market` | `assets/ui/bg-market.svg` | 1920x1200 | SVG | Screen backdrop for the market view. | Required |
| `ui.bg-grading` | `assets/ui/bg-grading.svg` | 1920x1200 | SVG | Screen backdrop for the grading view. | Required |

## Interface icons

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `ui.icon-cash` | `assets/icons/icon-cash.svg` | 48x48 | SVG | Interface icon "cash". | Optional |
| `ui.icon-box` | `assets/icons/icon-box.svg` | 48x48 | SVG | Interface icon "box". | Optional |
| `ui.icon-cards` | `assets/icons/icon-cards.svg` | 48x48 | SVG | Interface icon "cards". | Optional |
| `ui.icon-grade` | `assets/icons/icon-grade.svg` | 48x48 | SVG | Interface icon "grade". | Optional |
| `ui.icon-market` | `assets/icons/icon-market.svg` | 48x48 | SVG | Interface icon "market". | Optional |
| `ui.icon-level` | `assets/icons/icon-level.svg` | 48x48 | SVG | Interface icon "level". | Optional |
| `ui.icon-trophy` | `assets/icons/icon-trophy.svg` | 48x48 | SVG | Interface icon "trophy". | Optional |
| `ui.icon-chart` | `assets/icons/icon-chart.svg` | 48x48 | SVG | Interface icon "chart". | Optional |
| `ui.icon-filter` | `assets/icons/icon-filter.svg` | 48x48 | SVG | Interface icon "filter". | Optional |
| `ui.icon-sell` | `assets/icons/icon-sell.svg` | 48x48 | SVG | Interface icon "sell". | Optional |
| `ui.icon-lock` | `assets/icons/icon-lock.svg` | 48x48 | SVG | Interface icon "lock". | Optional |
| `ui.icon-star` | `assets/icons/icon-star.svg` | 48x48 | SVG | Interface icon "star". | Optional |
| `ui.icon-clock` | `assets/icons/icon-clock.svg` | 48x48 | SVG | Interface icon "clock". | Optional |
| `ui.icon-check` | `assets/icons/icon-check.svg` | 48x48 | SVG | Interface icon "check". | Optional |
| `ui.icon-close` | `assets/icons/icon-close.svg` | 48x48 | SVG | Interface icon "close". | Optional |
| `ui.icon-chevron` | `assets/icons/icon-chevron.svg` | 48x48 | SVG | Interface icon "chevron". | Optional |
| `ui.icon-plus` | `assets/icons/icon-plus.svg` | 48x48 | SVG | Interface icon "plus". | Optional |
| `ui.icon-search` | `assets/icons/icon-search.svg` | 48x48 | SVG | Interface icon "search". | Optional |
| `ui.icon-sort` | `assets/icons/icon-sort.svg` | 48x48 | SVG | Interface icon "sort". | Optional |
| `ui.icon-sparkle` | `assets/icons/icon-sparkle.svg` | 48x48 | SVG | Interface icon "sparkle". | Optional |
| `ui.icon-flame` | `assets/icons/icon-flame.svg` | 48x48 | SVG | Interface icon "flame". | Optional |
| `ui.icon-gift` | `assets/icons/icon-gift.svg` | 48x48 | SVG | Interface icon "gift". | Optional |
| `ui.icon-shield` | `assets/icons/icon-shield.svg` | 48x48 | SVG | Interface icon "shield". | Optional |
| `ui.icon-info` | `assets/icons/icon-info.svg` | 48x48 | SVG | Interface icon "info". | Optional |
| `ui.icon-bolt` | `assets/icons/icon-bolt.svg` | 48x48 | SVG | Interface icon "bolt". | Optional |
| `ui.icon-currency` | `assets/icons/icon-currency.svg` | 96x96 | SVG | Interface icon "currency". | Required |

## Reveal effects

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `fx.rays` | `assets/effects/fx-rays.svg` | 1200x1200 | SVG | Reveal effect layer "rays". | Optional |
| `fx.ring` | `assets/effects/fx-ring.svg` | 600x600 | SVG | Reveal effect layer "ring". | Optional |
| `fx.confetti` | `assets/effects/fx-confetti.svg` | 600x600 | SVG | Reveal effect layer "confetti". | Optional |
| `fx.spark` | `assets/effects/fx-spark.svg` | 200x200 | SVG | Reveal effect layer "spark". | Optional |

## League marks

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `league.NFL` | `assets/leagues/league-football.svg` | 320x200 | SVG | League mark stamped on NFL cards, box art and filters. | Required |
| `league.NBA` | `assets/leagues/league-basketball.svg` | 320x200 | SVG | League mark stamped on NBA cards, box art and filters. | Required |
| `league.MLB` | `assets/leagues/league-baseball.svg` | 320x200 | SVG | League mark stamped on MLB cards, box art and filters. | Required |

## Franchise crests

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `team.FB-CAN` | `assets/teams/football/crest-fb-can.svg` | 256x256 | SVG | Canton Ironworks franchise crest. | Required |
| `team.FB-BAY` | `assets/teams/football/crest-fb-bay.svg` | 256x256 | SVG | Bayview Kingfishers franchise crest. | Required |
| `team.FB-RAM` | `assets/teams/football/crest-fb-ram.svg` | 256x256 | SVG | Rampart Sentinels franchise crest. | Required |
| `team.FB-GLF` | `assets/teams/football/crest-fb-glf.svg` | 256x256 | SVG | Gulfport Marauders franchise crest. | Required |
| `team.FB-AUR` | `assets/teams/football/crest-fb-aur.svg` | 256x256 | SVG | Aurora Voltage franchise crest. | Required |
| `team.FB-RED` | `assets/teams/football/crest-fb-red.svg` | 256x256 | SVG | Redstone Outlaws franchise crest. | Required |
| `team.FB-NOR` | `assets/teams/football/crest-fb-nor.svg` | 256x256 | SVG | Northgate Timberjacks franchise crest. | Required |
| `team.FB-VER` | `assets/teams/football/crest-fb-ver.svg` | 256x256 | SVG | Verona Centurions franchise crest. | Required |
| `team.BB-HAR` | `assets/teams/basketball/crest-bb-har.svg` | 256x256 | SVG | Harbor City Tide franchise crest. | Required |
| `team.BB-SOL` | `assets/teams/basketball/crest-bb-sol.svg` | 256x256 | SVG | Solaris Nova franchise crest. | Required |
| `team.BB-MET` | `assets/teams/basketball/crest-bb-met.svg` | 256x256 | SVG | Metro Vipers franchise crest. | Required |
| `team.BB-GRA` | `assets/teams/basketball/crest-bb-gra.svg` | 256x256 | SVG | Granite Peaks franchise crest. | Required |
| `team.BB-COB` | `assets/teams/basketball/crest-bb-cob.svg` | 256x256 | SVG | Cobalt Motion franchise crest. | Required |
| `team.BB-LAK` | `assets/teams/basketball/crest-bb-lak.svg` | 256x256 | SVG | Lakeshore Halos franchise crest. | Required |
| `team.BB-SAB` | `assets/teams/basketball/crest-bb-sab.svg` | 256x256 | SVG | Sable City Royals franchise crest. | Required |
| `team.BB-PAL` | `assets/teams/basketball/crest-bb-pal.svg` | 256x256 | SVG | Palm Court Solstice franchise crest. | Required |
| `team.BS-RIV` | `assets/teams/baseball/crest-bs-riv.svg` | 256x256 | SVG | Riverton Rails franchise crest. | Required |
| `team.BS-EME` | `assets/teams/baseball/crest-bs-eme.svg` | 256x256 | SVG | Emerald Bay Anchors franchise crest. | Required |
| `team.BS-FOR` | `assets/teams/baseball/crest-bs-for.svg` | 256x256 | SVG | Fort Hollow Miners franchise crest. | Required |
| `team.BS-SIL` | `assets/teams/baseball/crest-bs-sil.svg` | 256x256 | SVG | Silver Creek Coyotes franchise crest. | Required |
| `team.BS-PIN` | `assets/teams/baseball/crest-bs-pin.svg` | 256x256 | SVG | Pinehurst Pioneers franchise crest. | Required |
| `team.BS-BAR` | `assets/teams/baseball/crest-bs-bar.svg` | 256x256 | SVG | Bayline Barons franchise crest. | Required |
| `team.BS-COP` | `assets/teams/baseball/crest-bs-cop.svg` | 256x256 | SVG | Copper Ridge Bandits franchise crest. | Required |
| `team.BS-UNI` | `assets/teams/baseball/crest-bs-uni.svg` | 256x256 | SVG | Union Park Sentries franchise crest. | Required |

## Product wordmarks

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `brand.BOX-NFL-OPTIC-25` | `assets/brands/brand-box-nfl-optic-25.svg` | 520x150 | SVG | Optic Elite Football product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NFL-SELECT-25` | `assets/brands/brand-box-nfl-select-25.svg` | 520x150 | SVG | Vertex Select Football product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NFL-PRIZM-25` | `assets/brands/brand-box-nfl-prizm-25.svg` | 520x150 | SVG | Spectra Prizm Football product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NFL-TREASURES-25` | `assets/brands/brand-box-nfl-treasures-25.svg` | 520x150 | SVG | Sovereign Treasures Football product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NFL-FLAWLESS-25` | `assets/brands/brand-box-nfl-flawless-25.svg` | 520x150 | SVG | Flawless Gridiron product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NBA-OPTIC-25` | `assets/brands/brand-box-nba-optic-25.svg` | 520x150 | SVG | Optic Elite Basketball product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NBA-SELECT-25` | `assets/brands/brand-box-nba-select-25.svg` | 520x150 | SVG | Vertex Select Basketball product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NBA-PRIZM-25` | `assets/brands/brand-box-nba-prizm-25.svg` | 520x150 | SVG | Spectra Prizm Basketball product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NBA-TREASURES-25` | `assets/brands/brand-box-nba-treasures-25.svg` | 520x150 | SVG | Sovereign Treasures Basketball product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-NBA-FLAWLESS-25` | `assets/brands/brand-box-nba-flawless-25.svg` | 520x150 | SVG | Flawless Hardwood product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-MLB-PROSPECT-25` | `assets/brands/brand-box-mlb-prospect-25.svg` | 520x150 | SVG | Prospect Chrome Baseball product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-MLB-CHROME-25` | `assets/brands/brand-box-mlb-chrome-25.svg` | 520x150 | SVG | Apex Chrome Baseball product wordmark used on store tiles and card fronts. | Required |
| `brand.BOX-MLB-FINEST-25` | `assets/brands/brand-box-mlb-finest-25.svg` | 520x150 | SVG | Finest Edition Baseball product wordmark used on store tiles and card fronts. | Required |

## Hobby box packaging

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `box.BOX-NFL-OPTIC-25` | `assets/boxes/football/box-nfl-optic-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Optic Elite Football (3/4 product shot). | Required |
| `box.BOX-NFL-SELECT-25` | `assets/boxes/football/box-nfl-select-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Vertex Select Football (3/4 product shot). | Required |
| `box.BOX-NFL-PRIZM-25` | `assets/boxes/football/box-nfl-prizm-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Spectra Prizm Football (3/4 product shot). | Required |
| `box.BOX-NFL-TREASURES-25` | `assets/boxes/football/box-nfl-treasures-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Sovereign Treasures Football (3/4 product shot). | Required |
| `box.BOX-NFL-FLAWLESS-25` | `assets/boxes/football/box-nfl-flawless-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Flawless Gridiron (3/4 product shot). | Required |
| `box.BOX-NBA-OPTIC-25` | `assets/boxes/basketball/box-nba-optic-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Optic Elite Basketball (3/4 product shot). | Required |
| `box.BOX-NBA-SELECT-25` | `assets/boxes/basketball/box-nba-select-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Vertex Select Basketball (3/4 product shot). | Required |
| `box.BOX-NBA-PRIZM-25` | `assets/boxes/basketball/box-nba-prizm-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Spectra Prizm Basketball (3/4 product shot). | Required |
| `box.BOX-NBA-TREASURES-25` | `assets/boxes/basketball/box-nba-treasures-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Sovereign Treasures Basketball (3/4 product shot). | Required |
| `box.BOX-NBA-FLAWLESS-25` | `assets/boxes/basketball/box-nba-flawless-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Flawless Hardwood (3/4 product shot). | Required |
| `box.BOX-MLB-PROSPECT-25` | `assets/boxes/baseball/box-mlb-prospect-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Prospect Chrome Baseball (3/4 product shot). | Required |
| `box.BOX-MLB-CHROME-25` | `assets/boxes/baseball/box-mlb-chrome-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Apex Chrome Baseball (3/4 product shot). | Required |
| `box.BOX-MLB-FINEST-25` | `assets/boxes/baseball/box-mlb-finest-25.svg` | 900x1000 | SVG | Sealed hobby box packaging for Finest Edition Baseball (3/4 product shot). | Required |

## Pack wrappers

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `pack.BOX-NFL-OPTIC-25` | `assets/packs/football/box-nfl-optic-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Optic Elite Football. | Required |
| `pack.BOX-NFL-SELECT-25` | `assets/packs/football/box-nfl-select-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Vertex Select Football. | Required |
| `pack.BOX-NFL-PRIZM-25` | `assets/packs/football/box-nfl-prizm-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Spectra Prizm Football. | Required |
| `pack.BOX-NFL-TREASURES-25` | `assets/packs/football/box-nfl-treasures-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Sovereign Treasures Football. | Required |
| `pack.BOX-NFL-FLAWLESS-25` | `assets/packs/football/box-nfl-flawless-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Flawless Gridiron. | Required |
| `pack.BOX-NBA-OPTIC-25` | `assets/packs/basketball/box-nba-optic-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Optic Elite Basketball. | Required |
| `pack.BOX-NBA-SELECT-25` | `assets/packs/basketball/box-nba-select-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Vertex Select Basketball. | Required |
| `pack.BOX-NBA-PRIZM-25` | `assets/packs/basketball/box-nba-prizm-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Spectra Prizm Basketball. | Required |
| `pack.BOX-NBA-TREASURES-25` | `assets/packs/basketball/box-nba-treasures-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Sovereign Treasures Basketball. | Required |
| `pack.BOX-NBA-FLAWLESS-25` | `assets/packs/basketball/box-nba-flawless-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Flawless Hardwood. | Required |
| `pack.BOX-MLB-PROSPECT-25` | `assets/packs/baseball/box-mlb-prospect-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Prospect Chrome Baseball. | Required |
| `pack.BOX-MLB-CHROME-25` | `assets/packs/baseball/box-mlb-chrome-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Apex Chrome Baseball. | Required |
| `pack.BOX-MLB-FINEST-25` | `assets/packs/baseball/box-mlb-finest-25-pack.svg` | 540x780 | SVG | Foil pack wrapper for Finest Edition Baseball. | Required |

## Card templates

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `frame.optic.bg` | `assets/cards/templates/frame-optic-bg.svg` | 750x1050 | SVG | Art field behind the athlete on optic cards. | Required |
| `frame.optic.fg` | `assets/cards/templates/frame-optic-fg.svg` | 750x1050 | SVG | Border, nameplate and foil furniture for optic cards. | Required |
| `frame.select.bg` | `assets/cards/templates/frame-select-bg.svg` | 750x1050 | SVG | Art field behind the athlete on select cards. | Required |
| `frame.select.fg` | `assets/cards/templates/frame-select-fg.svg` | 750x1050 | SVG | Border, nameplate and foil furniture for select cards. | Required |
| `frame.prizm.bg` | `assets/cards/templates/frame-prizm-bg.svg` | 750x1050 | SVG | Art field behind the athlete on prizm cards. | Required |
| `frame.prizm.fg` | `assets/cards/templates/frame-prizm-fg.svg` | 750x1050 | SVG | Border, nameplate and foil furniture for prizm cards. | Required |
| `frame.treasures.bg` | `assets/cards/templates/frame-treasures-bg.svg` | 750x1050 | SVG | Art field behind the athlete on treasures cards. | Required |
| `frame.treasures.fg` | `assets/cards/templates/frame-treasures-fg.svg` | 750x1050 | SVG | Border, nameplate and foil furniture for treasures cards. | Required |
| `frame.flawless.bg` | `assets/cards/templates/frame-flawless-bg.svg` | 750x1050 | SVG | Art field behind the athlete on flawless cards. | Required |
| `frame.flawless.fg` | `assets/cards/templates/frame-flawless-fg.svg` | 750x1050 | SVG | Border, nameplate and foil furniture for flawless cards. | Required |
| `frame.prospect.bg` | `assets/cards/templates/frame-prospect-bg.svg` | 750x1050 | SVG | Art field behind the athlete on prospect cards. | Required |
| `frame.prospect.fg` | `assets/cards/templates/frame-prospect-fg.svg` | 750x1050 | SVG | Border, nameplate and foil furniture for prospect cards. | Required |
| `frame.chrome.bg` | `assets/cards/templates/frame-chrome-bg.svg` | 750x1050 | SVG | Art field behind the athlete on chrome cards. | Required |
| `frame.chrome.fg` | `assets/cards/templates/frame-chrome-fg.svg` | 750x1050 | SVG | Border, nameplate and foil furniture for chrome cards. | Required |
| `frame.finest.bg` | `assets/cards/templates/frame-finest-bg.svg` | 750x1050 | SVG | Art field behind the athlete on finest cards. | Required |
| `frame.finest.fg` | `assets/cards/templates/frame-finest-fg.svg` | 750x1050 | SVG | Border, nameplate and foil furniture for finest cards. | Required |

## Card backs

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `cardback.NFL` | `assets/cards/backs/back-football.svg` | 750x1050 | SVG | Reverse of every NFL card; shown before a reveal flip. | Required |
| `cardback.NBA` | `assets/cards/backs/back-basketball.svg` | 750x1050 | SVG | Reverse of every NBA card; shown before a reveal flip. | Required |
| `cardback.MLB` | `assets/cards/backs/back-baseball.svg` | 750x1050 | SVG | Reverse of every MLB card; shown before a reveal flip. | Required |

## Athlete cutouts

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `pose.qb_throw` | `assets/cards/poses/football/pose-qb_throw.svg` | 600x820 | SVG | Athlete cutout, pose "qb_throw". Recoloured per franchise at runtime. | Required |
| `pose.rb_stiffarm` | `assets/cards/poses/football/pose-rb_stiffarm.svg` | 600x820 | SVG | Athlete cutout, pose "rb_stiffarm". Recoloured per franchise at runtime. | Required |
| `pose.wr_catch` | `assets/cards/poses/football/pose-wr_catch.svg` | 600x820 | SVG | Athlete cutout, pose "wr_catch". Recoloured per franchise at runtime. | Required |
| `pose.dl_rush` | `assets/cards/poses/football/pose-dl_rush.svg` | 600x820 | SVG | Athlete cutout, pose "dl_rush". Recoloured per franchise at runtime. | Required |
| `pose.dunk` | `assets/cards/poses/basketball/pose-dunk.svg` | 600x820 | SVG | Athlete cutout, pose "dunk". Recoloured per franchise at runtime. | Required |
| `pose.jumper` | `assets/cards/poses/basketball/pose-jumper.svg` | 600x820 | SVG | Athlete cutout, pose "jumper". Recoloured per franchise at runtime. | Required |
| `pose.drive` | `assets/cards/poses/basketball/pose-drive.svg` | 600x820 | SVG | Athlete cutout, pose "drive". Recoloured per franchise at runtime. | Required |
| `pose.block` | `assets/cards/poses/basketball/pose-block.svg` | 600x820 | SVG | Athlete cutout, pose "block". Recoloured per franchise at runtime. | Required |
| `pose.swing` | `assets/cards/poses/baseball/pose-swing.svg` | 600x820 | SVG | Athlete cutout, pose "swing". Recoloured per franchise at runtime. | Required |
| `pose.pitch` | `assets/cards/poses/baseball/pose-pitch.svg` | 600x820 | SVG | Athlete cutout, pose "pitch". Recoloured per franchise at runtime. | Required |
| `pose.field` | `assets/cards/poses/baseball/pose-field.svg` | 600x820 | SVG | Athlete cutout, pose "field". Recoloured per franchise at runtime. | Required |
| `pose.slide` | `assets/cards/poses/baseball/pose-slide.svg` | 600x820 | SVG | Athlete cutout, pose "slide". Recoloured per franchise at runtime. | Required |

## Parallel finishes

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `foil.none` | `assets/cards/foils/foil-none.svg` | 750x1050 | SVG | Parallel finish overlay "none". | Optional |
| `foil.holo` | `assets/cards/foils/foil-holo.svg` | 750x1050 | SVG | Parallel finish overlay "holo". | Required |
| `foil.refractor` | `assets/cards/foils/foil-refractor.svg` | 750x1050 | SVG | Parallel finish overlay "refractor". | Required |
| `foil.silver` | `assets/cards/foils/foil-silver.svg` | 750x1050 | SVG | Parallel finish overlay "silver". | Required |
| `foil.tint` | `assets/cards/foils/foil-tint.svg` | 750x1050 | SVG | Parallel finish overlay "tint". | Required |
| `foil.metal` | `assets/cards/foils/foil-metal.svg` | 750x1050 | SVG | Parallel finish overlay "metal". | Required |
| `foil.superfractor` | `assets/cards/foils/foil-superfractor.svg` | 750x1050 | SVG | Parallel finish overlay "superfractor". | Required |

## Insert art

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `insert.burst` | `assets/cards/inserts/insert-burst.svg` | 600x820 | SVG | Insert-set background art "burst". | Required |
| `insert.skyline` | `assets/cards/inserts/insert-skyline.svg` | 600x820 | SVG | Insert-set background art "skyline". | Required |
| `insert.splash` | `assets/cards/inserts/insert-splash.svg` | 600x820 | SVG | Insert-set background art "splash". | Required |
| `insert.banner` | `assets/cards/inserts/insert-banner.svg` | 600x820 | SVG | Insert-set background art "banner". | Required |
| `insert.grid` | `assets/cards/inserts/insert-grid.svg` | 600x820 | SVG | Insert-set background art "grid". | Required |

## Grading slab

| Key | File | Size | Format | Used for | Required |
| --- | --- | --- | --- | --- | --- |
| `grading.shell` | `assets/grading/slab-shell.svg` | 820x1300 | SVG | Acrylic slab case with transparent card and label windows. | Required |
| `grading.label.standard` | `assets/grading/slab-label-standard.svg` | 732x210 | SVG | Slab label stock for the standard grade band. | Required |
| `grading.label.gold` | `assets/grading/slab-label-gold.svg` | 732x210 | SVG | Slab label stock for the gold grade band. | Required |
| `grading.label.black` | `assets/grading/slab-label-black.svg` | 732x210 | SVG | Slab label stock for the black grade band. | Required |
| `grading.barcode` | `assets/grading/slab-barcode.svg` | 150x62 | SVG | Certification barcode printed on the slab label. | Required |
| `grading.qr` | `assets/grading/slab-qr.svg` | 126x126 | SVG | Certification QR block on the slab label. | Optional |
| `grading.mark` | `assets/grading/grader-mark.svg` | 300x300 | SVG | Apex Grading Authority company mark. | Required |

## Regenerating

```bash
npm run assets     # redraw every asset + rewrite data/assets.manifest.json
npm run manifest   # rewrite this document from the manifest
npm run build      # both
```
