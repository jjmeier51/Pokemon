# PokeTracker

A native iOS app for tracking your progress on the English **Pokémon TCG: 30th Celebration** master set (September 16, 2026) and the 25th-anniversary **Celebrations** set (October 8, 2021), styled after the official Pokémon TCG apps. A toggle at the top of the Collection tab switches sets, and the whole app re-themes: navy and gold for 30th Celebration, black and yellow for Celebrations.

<p align="center"><img src="PokeTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="PokeTracker icon"></p>

## What it tracks

**30th Celebration (2026)**: every Pokémon and Trainer card on the official card list (P11221), the three unlisted RGB Mew secret rares, and the 17 Black Star Promos that ship with the 30th Celebration products — **209 cards** (the eight Basic Energy cards are intentionally left out):

| Section | Cards | Notes |
|---|---|---|
| Main set | 001–128 | 68 Common, 18 Rare, 12 Double Rare, 30 Pikachu Rare |
| Secret rares | 129–158 | 18 Illustration Rare, 10 Special Illustration Rare, 2 Futuristic Rare |
| RGB Mew | R/RGB, G/RGB, B/RGB | YOSHIROTTEN's Red / Green / Blue Mew |
| Classic Collection | 30 reprints | Base Set Charizard through Paldea Evolved Magikarp, with original set and year |
| Promos | MEP 094–110 | Tech Sticker, Poster, ex Box/Tin, ETB (plus the Pokémon Center-stamped Nidorina), Battle Deck, Figure, Ditto Premium and Ultra-Premium Collection promos |

**Celebrations (2021)**: the official 25-card list, its 25-card Classic Collection, and the 16 Sword & Shield promos that carry the 25th-anniversary stamp — **66 cards**:

| Section | Cards | Notes |
|---|---|---|
| Main set | 001–024 | Rare, Holo Rare, Holo Rare V / VMAX, Ultra Rare (Full Art Professor's Research) |
| Secret rare | 025 | Gold Mew |
| Classic Collection | 25 reprints | Base Set Blastoise / Charizard / Venusaur through Tapu Lele-GX, with original set and year |
| Promos | SWSH132–146, SWSH167 | Dragapult Prime, Lance's Charizard V, Dark Sylveon V, Zacian LV.X, Mimikyu δ, Light Toxtricity, Hydreigon C, the four Pikachu V-UNION cards, Pikachu V, Greninja ★, Pikachu V (UPC), Poké Ball, Professor Burnet |

Rarities come straight from the official checklist PDFs. Artists, HP, types, attacks and Pokédex text were merged in from Limitless TCG, pokemontcg.io and TCGplayer.

## Features

- **Card grid** with the official scan of every card. Cards you still need show in full color; cards you've collected get a gold border, a check badge, and are greyed out so the remaining chase is obvious at a glance.
- **One-tap collecting**: tap the `+` badge on any card (or long-press for a menu). Haptic feedback and a pop animation on each catch.
- **Filter** by collected / missing, by any combination of rarities, and by section. **Sort** by number, name, rarity, market price, or recently collected, ascending or descending.
- **Search** by name, number (`158/128`, `R/RGB`, `4/102`), rarity, artist, type, or original set.
- **Glitter borders** on every rarity above Common: a foil sheen sweeps around the edge while sparkles twinkle, tinted per rarity (gold for Classic Collection and Illustration Rares, rainbow for Special Illustration Rares, teal for Futuristic Rares, red/green/blue for the RGB Mew). Honors Reduce Motion and can be switched off in Settings.
- **Card detail** opens on the card back and flips over to reveal the front (tap to flip again), with a 3D tilt + holographic sheen (varies by rarity), quantity, favorite, personal note, attacks, ability, Pokédex entry, and previous/next navigation.
- **Set switcher** at the top of the Collection and Progress tabs. Collection progress, filters, stats and value are all per set.
- **Graded values** in every card: pick PSA, CGC, BGS or TAG and a grade (10, 9.5, 9, 8.5 …) to see the most recent sale of that exact slab plus PriceCharting's market value for it, with the last few graded sales listed underneath.
- **Raw or graded ownership**: when you collect a card, mark it raw or graded (company, grade, cert number). Graded cards are counted at their grade's market value in your collection total.
- **Prices in every card**, from two sources, plus an **Open on eBay** button that jumps into the eBay app with a search for that exact card:
  - **TCGplayer** — current Market Price, the most recent day's average sale price (with count and low–high range), 30-day trend and sparkline.
  - **Card Ladder** — CL Value, most recent sale, and sales history.
- **Progress tab**: completion ring, per-section and per-rarity progress bars, value of what you own, cost to finish, and the priciest cards you're still missing.
- **Backup**: export / import your collection as JSON; everything is stored on-device.

## Building

1. Open `PokeTracker.xcodeproj` in **Xcode 16 or newer** (the project uses file-system-synchronized groups, so every file under `PokeTracker/` is picked up automatically).
2. Select your team under *Signing & Capabilities* (bundle id `com.jjmeier.PokeTracker`, change it if you like).
3. Run on an iPhone or simulator with **iOS 17+**.

No third-party dependencies. Everything is SwiftUI + Foundation.

## Prices: how the two sources work

**TCGplayer** needs no configuration. The app reads the same public JSON endpoints tcgplayer.com itself uses (`mpapi.tcgplayer.com/v2/product/{id}/pricepoints` for Market Price and `infinite-api.tcgplayer.com/price/history/{id}/detailed` for daily sales). Every card ships with its TCGplayer product id, and there is a name + number search fallback if an id is ever missing.

**PriceCharting** supplies graded data with no configuration: each card carries the path of its PriceCharting page (resolved offline), and the app reads the page's full price guide (Ungraded, Grade 1–9.5, PSA 10, CGC 10, BGS 10, TAG 10 …) and its completed-sales list, classifying each sale's title into a grading company and grade. Pages are cached for twelve hours.

**Card Ladder** has no public API and its website sits behind a bot challenge, so the app uses the [Parse.bot Card Ladder API](https://parse.bot/marketplace/5554022d-8a04-46d0-b2c5-56f3b5abcea2/cardladder-com-api) wrapper (`search_cards`, `get_card_value`, `get_card_sales`). Create a key (there is a free tier) and paste it into **Settings → Card Ladder**. The base URL is editable, so any bridge that mirrors those routes works too. Until a key is added, the Card Ladder panel shows a prompt and an "Open on Card Ladder" link.

Every card's prices are pulled when the app launches and again when it returns to the foreground; **Progress → refresh** or **Settings → Refresh every card now** reloads the whole set on demand, and opening a card refreshes that card if its quote is more than six hours old.

## Card images

`PokeTracker/Resources/CardImages/` holds a scan of every card. 30th Celebration scans come from the official tcg.pokemon.com gallery (660×920); the RGB Mew and 30th promos come from TCGplayer at the same resolution. Celebrations scans (main set, Classic Collection and promos) come from pokemontcg.io at 734×1024. The card back and the 30th Celebration logo are in the asset catalog. Each card also carries the URL of its official gallery scan, which the image store uses if a bundled file is ever missing.

## Project layout

```
PokeTracker/
  PokeTrackerApp.swift        App entry; injects the catalog, collection, prices and settings
  Models/                     Card, CardSet, CardCatalog, CollectionStore (persistence), Grading, PriceModels, AppSettings
  Services/                   ImageStore, TCGPlayerService, CardLadderService, PriceChartingService, PriceCenter
  Theme/                      Per-set color themes, fonts, rarity badges, glitter border, holo/tilt effect
  Views/                      Collection grid, filters, card detail, prices, progress, settings
  Resources/set-30th.json     The 209-card 30th Celebration catalog
  Resources/set-celebrations.json  The 66-card Celebrations catalog
  Resources/CardImages/       Card scans
```

## Disclaimer

PokeTracker is a fan-made tool and is not affiliated with or endorsed by The Pokémon Company, Nintendo, Creatures Inc., GAME FREAK, TCGplayer or Card Ladder. Card images and names are © their respective owners.
