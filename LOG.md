# Wat wanneer gedaan

| Dag | Datum      | Gedaan                              |
|:----|:-----------|:------------------------------------|
| 1   | 10/10/2026 | repo, renv, config, `lees_config()` |
| 2   | 11/10/2026 | `club.yml`, `load_etf()`, mermaid diagram  |


# Functies

| Functie            | Bestand    | Doet                                               | Geeft terug                 |
|:-------------------|:-----------|:---------------------------------------------------|:----------------------------|
| `lees_config(pad)` | `R/data.R` | leest een config, vult elke ETF aan met `algemeen` | lijst met één `cfg` per ETF |
| `load_etf(ticker, from)` | `R/data.R` | haalt koersen, zet om naar euro, doet datachecks   | lijst met `px`, `r`, `koers`, `checks`, … |

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



# Diagram (via mermaid)
```mermaid
flowchart LR
  subgraph A["1 · Vooranalyse"]
    S["factsheets, FactSet"]
  end
  subgraph B["2 · Config"]
    Y["config/club.yml"]
  end
  subgraph C["3 · Machine: R/*.R"]
    LC["lees_config()"]
    RE["run_etf()"]
    LE["load_etf()"]
    HI["historiek()"]
    VR["verwacht_rendement()"]
    MC["mc_etf()"]
    AS["auto_split()"]
    FT["fit_t()"]
    RK["risk_3ways()"]
    BT["backtest()"]
    HR["horizon_risk()"]
    LM["limieten_check()"]
  end
  subgraph D["4 · Rapport"]
    RP["rapport.Rmd → PDF"]
  end
  subgraph E["5 · Databron"]
    YH["Yahoo Finance"]
  end
  S --> Y --> LC --> RE
  RE --> LE
  LE -->|px| HI
  YH --> LE
  RE --> VR -->|scenario's| MC
  HI -->|vol| MC
  LE -->|r| AS --> FT
  FT --> RK
  FT --> BT
  FT --> HR
  RE --> LM
  RE --> RP
  classDef klaar fill:#1BAF7A,color:#fff,stroke:#0d6b4a
  class LC,LE klaar
```
