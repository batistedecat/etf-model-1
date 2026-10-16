# Wat wanneer gedaan

| Dag | Datum      | Gedaan                                                |
|:----|:-----------|:------------------------------------------------------|
| 1   | 10/10/2026 | repo, renv, config, `lees_config()`                   |
| 2   | 11/10/2026 | `club.yml`, `load_etf()`, mermaid diagram             |
| 3   | 12/10/2026 | `historiek()`, `drawdowns()`, twee plots, drempel 15% |
| 4   | 13/10/2026 | `verwacht_rendement()`, `breakeven_groei()`, `pe5` → `peH` |
| 5   | 14/10/2026 | Monte Carlo: GBM, football field, paden-plot          |
| 6   | 16/10/2026 | risicomodel: split, Student-t, VaR/ES op 3 manieren   |
| 7   | 16/10/2026 | backtest, ES over horizon, limieten, `run_etf()`      |

# Functies

| Functie                      | Bestand          | Doet                                               | Geeft terug                                       |
|:-----------------------------|:-----------------|:---------------------------------------------------|:--------------------------------------------------|
| `lees_config(pad)`           | `R/data.R`       | leest een config, vult elke ETF aan met `algemeen` | lijst met één `cfg` per ETF                       |
| `load_etf(ticker, from)`     | `R/data.R`       | haalt koersen, zet om naar euro, doet datachecks   | lijst met `px`, `r`, `koers`, `checks`, …         |
| `drawdowns(px, drempel)`     | `R/historiek.R`  | zoekt dalingen ≥ drempel: top, bodem, herstel      | `data.frame`, één rij per episode                 |
| `historiek(px, drempel)`              | `R/historiek.R`  | CAGR, volatiliteit, max drawdown, kalenderjaren    | lijst met `cagr`, `vol`, `maxdd`, `kalender`, … |
| `plot_koers(px)`             | `R/historiek.R`  | koers en dagrendement in twee panelen (xts)        | xts-plot                                          |
| `plot_drawdown(px, drempel)` | `R/historiek.R`  | drawdown in % met drempellijn (ggplot)             | ggplot                                            |
| `verwacht_rendement(cfg)`    | `R/rendement.R`  | verwacht rendement per scenario, formule per type  | benoemde vector `bear`, `base`, `bull` (of NULL)  |
| `breakeven_groei(cfg, doel)` | `R/rendement.R`  | winstgroei nodig voor `doel`; standaard base-`peH` | getal, bv. 0.096 = 9,6%                           |
| `simulate_gbm()`             | `R/montecarlo.R` | koerspaden met GBM                                 | matrix paden × weken                              |
| `mc_etf(rs, sigma, positie)` | `R/montecarlo.R` | samenvatting per scenario                          | `p10`, `p50`, `p90`, `verlies`, `gem`             |
| `plot_football(mc, positie)` | `R/montecarlo.R` | P10–P90 per scenario                               | ggplot                                            |
| `plot_paden()`               | `R/montecarlo.R` | paden + band, 3 scenario's                         | ggplot                                            |
| `auto_split(r)`              | `R/risico.R`     | kiest training/test: laatste geschikte 1 januari   | lijst `ok`, `start_test`, `train`, `test`         |
| `normaliteit(r)`             | `R/risico.R`     | scheefheid, kurtosis, Jarque-Bera dag/week/maand   | benoemde vector                                   |
| `fit_t(L)`                   | `R/risico.R`     | Student-t op 100·L, AIC t vs normaal               | `m`, `s`, `df`, `aic_t`, `aic_n`                  |
| `risk_3ways(L, alpha, ft)`   | `R/risico.R`     | VaR en ES: empirisch, normaal, Student-t           | tabel 3 × 2 (per €1), verm. met positie om VaR en ES te weten|
| `kupiec_test(x, n, alpha)`   | `R/risico.R`     | klopt het aantal overschrijdingen? (LR-test)       | `x`, `verwacht`, `LR`, `p`                        |
| `indep_test(v)`              | `R/risico.R`     | komen de overschrijdingen in clusters?             | `p_vv`, `p_v_rust`, `p`                           |
| `backtest()`                 | `R/risico.R`     | VaR op testdata: aantal, clusters, grootte         | `data.frame`, 6 rijen (2 alpha × 3 modellen)      |
| `var_es(pnl, alpha)`         | `R/risico.R`     | VaR en ES uit gesimuleerde winst/verlies           | `VaR`, `ES`                                       |
| `horizon_risk()`             | `R/risico.R`     | 10.000 paden met t-schokken, zonder drift          | vector: winst/verlies per pad                     |
| `limieten_check()`           | `R/pipeline.R`   | toetst clubregels: ETF, sector, emittent, cash     | `data.frame`: `regel`, `waarde`, `grens`, `ok`    |
| `run_etf(cfg, seed)`         | `R/pipeline.R`   | dag 2–7 voor één ETF in één keer                   | lijst: `data`, `hist`, `rs`, `mc`, `bt`, `es1`, … |

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
`stappen` = simulatiestappen per jaar (52 = week).
`drempel` = minimale daling die als episode telt (15%; IEAG.AS 5%, een obligatie-ETF zakt zelden 15%).
`centrum: nul` = VaR/ES rond 0, niet rond het gemiddelde dagrendement.
Waarom: op één dag is het gemiddelde klein tegenover de spreiding (RiskMetrics), en de training was uitzonderlijk sterk (+0,14%/dag).

# Bevindingen dag 6 QDVE.DE (training 2015–2022, per €1.000)

- Niet normaal: scheefheid −0,47, kurtosis 6,75, Jarque-Bera verwerpt dag en week (maand p = 0,39).
- Student-t past veel beter: ν = 3,47, AIC 239 lager dan normaal.
- 95%: VaR ≈ €21–24, ES ≈ €33; de modellen zijn het eens.
- 99%: VaR t €38,7, ES t €56,3; normaal geeft €32 / €37 en onderschat de staart met een derde.

# Bevindingen dag 7 QDVE.DE (test 2023–nu, per €1.000)

- Aantal klopt: 99% t 5 overschrijdingen (verwacht 9,6; Kupiec p = 0,10), 95% 55 (verwacht 47,9; p = 0,30).
- Grootte klopt: ES-ratio 99% ≈ 1,04.
- Clusters: onafhankelijkheid verworpen, overschrijdingen samen in april 2025. De VaR past zich niet aan als de markt onrustig wordt.
- Hertraind op alle data: ν = 3,79.
- ES 95% zonder drift: €393 over 1 jaar, €501 over 2 jaar.
- Break-even 8%: 9,56% winstgroei per jaar nodig; base rekent met 12%, dus 2,4 pp buffer.
- Limieten: alles OK, ook bij de maximale positie van 30% (€3.600).

