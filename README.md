# PokeTracker

A native iOS app for tracking your progress on the English **Pokémon TCG: 30th Celebration** master set (released September 16, 2026), styled after the official Pokémon TCG apps.

<p align="center"><img src="PokeTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="PokeTracker icon"></p>

## What it tracks

Every Pokémon and Trainer card on the official 30th Celebration card list (P11221), the three unlisted RGB Mew secret rares, and the 17 Black Star Promos that ship with the 30th Celebration products — **209 cards** in total (the eight Basic Energy cards are intentionally left out):

| Section | Cards | Notes |
|---|---|---|
| Main set | 001–128 | 68 Common, 18 Rare, 12 Double Rare, 30 Pikachu Rare |
| Secret rares | 129–158 | 18 Illustration Rare, 10 Special Illustration Rare, 2 Futuristic Rare |
| RGB Mew | R/RGB, G/RGB, B/RGB | YOSHIROTTEN's Red / Green / Blue Mew |
| Classic Collection | 30 reprints | Base Set Charizard through Paldea Evolved Magikarp, with original set and year |
| Promos | MEP 094–110 | Tech Sticker, Poster, ex Box/Tin, ETB (plus the Pokémon Center-stamped Nidorina), Battle Deck, Figure, Ditto Premium and Ultra-Premium Collection promos, including the UPC Espeon ex / Umbreon ex |

Rarities come straight from the official checklist PDF. Artists, HP, types, attacks and Pokédex text were merged in from Limitless TCG and TCGplayer.

## Features

- **Card grid** with the official scan of every card. Cards you still need show in full color; cards you've collected get a gold border, a check badge, and are greyed out so the remaining chase is obvious at a glance.
- **One-tap collecting**: tap the `+` badge on any card (or long-press for a menu). Haptic feedback and a pop animation on each catch.
- **Filter** by collected / missing, by any combination of rarities, and by section. **Sort** by number, name, rarity, market price, or recently collected, ascending or descending.
- **Search** by name, number (`158/128`, `R/RGB`, `4/102`), rarity, artist, type, or original set.
- **Glitter borders** on every rarity above Common: a foil sheen sweeps around the edge while sparkles twinkle, tinted per rarity (gold for Classic Collection and Illustration Rares, rainbow for Special Illustration Rares, teal for Futuristic Rares, red/green/blue for the RGB Mew). Honors Reduce Motion and can be switched off in Settings.
- **Card detail** opens on the card back and flips over to reveal the front (tap to flip again), with a 3D tilt + holographic sheen (varies by rarity), quantity, favorite, personal note, attacks, ability, Pokédex entry, and previous/next navigation.
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

**Card Ladder** has no public API and its website sits behind a bot challenge, so the app uses the [Parse.bot Card Ladder API](https://parse.bot/marketplace/5554022d-8a04-46d0-b2c5-56f3b5abcea2/cardladder-com-api) wrapper (`search_cards`, `get_card_value`, `get_card_sales`). Create a key (there is a free tier) and paste it into **Settings → Card Ladder**. The base URL is editable, so any bridge that mirrors those routes works too. Until a key is added, the Card Ladder panel shows a prompt and an "Open on Card Ladder" link.

Every card's prices are pulled when the app launches and again when it returns to the foreground; **Progress → refresh** or **Settings → Refresh every card now** reloads the whole set on demand, and opening a card refreshes that card if its quote is more than six hours old.

## Card images

`PokeTracker/Resources/CardImages/` holds the official scan of every card from the Pokémon TCG 30th Celebration gallery (tcg.pokemon.com), stored as 660×920 JPEGs. The three RGB Mew and the promos are not in the official gallery, so those come from TCGplayer's product images at the same resolution. The card back and the 30th Celebration logo are in the asset catalog. Each card also carries the URL of its official gallery scan, which the image store uses if a bundled file is ever missing.

## Project layout

```
PokeTracker/
  PokeTrackerApp.swift        App entry; injects the catalog, collection, prices and settings
  Models/                     Card, CardCatalog, CollectionStore (persistence), PriceModels, AppSettings
  Services/                   ImageStore, TCGPlayerService, CardLadderService, PriceCenter
  Theme/                      Colors, fonts, rarity badges, holo/tilt effect
  Views/                      Collection grid, filters, card detail, prices, progress, settings
  Resources/cards.json        The 209-card catalog
  Resources/CardImages/       Card scans
```

## Disclaimer

PokeTracker is a fan-made tool and is not affiliated with or endorsed by The Pokémon Company, Nintendo, Creatures Inc., GAME FREAK, TCGplayer or Card Ladder. Card images and names are © their respective owners.
