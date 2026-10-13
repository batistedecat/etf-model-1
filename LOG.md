# Wat wanneer gedaan

| Dag | Datum      | Gedaan                                                |
|:----|:-----------|:------------------------------------------------------|
| 1   | 10/10/2026 | repo, renv, config, `lees_config()`                   |
| 2   | 11/10/2026 | `club.yml`, `load_etf()`, mermaid diagram             |
| 3   | 12/10/2026 | `historiek()`, `drawdowns()`, twee plots, drempel 15% |
| 4   | 13/10/2026 | `verwacht_rendement()`, `breakeven_groei()`, `pe5` → `peH` |

# Functies

| Functie                      | Bestand          | Doet                                               | Geeft terug                                       |
|:-----------------------------|:-----------------|:---------------------------------------------------|:--------------------------------------------------|
| `lees_config(pad)`           | `R/data.R`       | leest een config, vult elke ETF aan met `algemeen` | lijst met één `cfg` per ETF                       |
| `load_etf(ticker, from)`     | `R/data.R`       | haalt koersen, zet om naar euro, doet datachecks   | lijst met `px`, `r`, `koers`, `checks`, …         |
| `drawdowns(px, drempel)`     | `R/historiek.R`  | zoekt dalingen ≥ drempel: top, bodem, herstel      | `data.frame`, één rij per episode                 |
| `historiek(px)`              | `R/historiek.R`  | CAGR, volatiliteit, max drawdown, kalenderjaren    | lijst met `cagr`, `vol`, `maxdd`, `kalender`, … |
| `plot_koers(px)`             | `R/historiek.R`  | koers en dagrendement in twee panelen (xts)        | xts-plot                                          |
| `plot_drawdown(px, drempel)` | `R/historiek.R`  | drawdown in % met drempellijn (ggplot)             | ggplot                                            |
| `verwacht_rendement(cfg)`    | `R/rendement.R`  | verwacht rendement per scenario, formule per type  | benoemde vector `bear`, `base`, `bull` (of NULL)  |
| `breakeven_groei(cfg, doel)` | `R/rendement.R`  | winstgroei nodig voor `doel`; standaard base-`peH` | getal, bv. 0.096 = 9,6%                           |

# Configuratie

Config = invoer, `R/*.R` = machine. Andere ETF of aanname? Alleen de config aanpassen.

`config/*.yml` → `lees_config()` → één `cfg` per ETF → `R/*.R` → resultaten per ETF

| Bestand    | Doel                                | Aanpassen? |
|:-----------|:------------------------------------|:-----------|
| `etfs.yml` | gewoon een testdatabank vo mezelf   | nooit      |
| `club.yml` | analyse voor de club                | ja         |

| Soort      | Velden                                                            | Aanpassen wanneer                |
|:-----------|:------------------------------------------------------------------|:---------------------------------|
| club       | `positie`, `portefeuille`, `cash`                                 | aankoop, verkoop, nieuw kapitaal |
| model      | `horizon`, `min_test`, `min_train`, `frac_test`, `centrum`        | zelden                           |
| ETF-feiten | `ticker`, `naam`, `type`, `sector`, `ter`, `top_positie`, `start` | nieuwe ETF of factsheet          |
| aannames   | `pe0`, `dy`, `ytm`, `duration`, scenario's                        | vóór elke pitch                  |

`peH` = forward P/E op het einde van de horizon (`horizon` jaar, club: 2), per scenario. Vroeger `pe5`.
