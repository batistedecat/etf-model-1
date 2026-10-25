# Le Gradient · ETF engine — Shiny app (donkere versie)
# Zet dit bestand in de root van etf-model-1 (naast run_all.R), logo in www/logo.png, start met shiny::runApp()
# Past geen bestaand bestand aan: gebruikt de engine (R/*.R) en rapport.Rmd zoals ze zijn.

if (!file.exists("laden.R") || !file.exists("rapport.Rmd")) {
  stop("Zet app.R in de root van etf-model-1, naast run_all.R en rapport.Rmd.")
}

options(yaml.eval.expr = FALSE, shiny.maxRequestSize = 100 * 1024)

source("laden.R")
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
})


# ---- clubinstellingen en vaste lijsten ----

club <- yaml::read_yaml("config/club.yml", eval.expr = FALSE)$algemeen
H <- club$horizon

scenarios <- c("bear", "base", "bull")
types <- c("Equity fund" = "aandelen", "Bond fund" = "obligaties", "Other (e.g. gold)" = "overig")
sectoren <- c("Technology" = "technologie", "Diversified (broad fund)" = "gespreid", "Bonds" = "obligaties",
              "Commodities" = "grondstoffen", "Healthcare" = "gezondheidszorg", "Financials" = "financieel",
              "Energy" = "energie", "Real estate" = "vastgoed")
modellen <- c(empirisch = "Empirical", normaal = "Normal", student_t = "Student-t")
regels <- c("per ETF" = "Per ETF", "per sector" = "Per sector",
            "per emittent (doorkijk)" = "Per issuer (look-through)", "cash na aankoop" = "Cash after purchase")
checks_en <- c("korte historiek" = "short history", "veel nulrendementen" = "many days without a price change",
               "sprong groter dan 25%" = "a jump above 25%", "gat groter dan 7 dagen" = "a gap longer than 7 days",
               "pieken verwijderd" = "odd prices removed")


# ---- kleuren en huisstijl ----

kleur <- list(bg = "#0E0E10", zijbalk = "#121215", kaart = "#151518", veld = "#18181C", lijn = "#25252A",
              tekst = "#ECECEE", zacht = "#8C8C94", rood = "#E5484D", groen = "#46A758", geel = "#D6A43B")
scen_kleur <- c(bear = kleur$rood, base = kleur$tekst, bull = kleur$groen)

lg_font <- font_collection(font_google("Instrument Sans", local = FALSE, wght = c(400, 500, 600)),
                           "Inter", "system-ui", "-apple-system", "Segoe UI", "sans-serif")

lg_css <- r"(
body { -webkit-font-smoothing: antialiased; }
.navbar, .bslib-page-title { background: #0E0E10 !important; border-bottom: 1px solid #25252A; }
.lg-brand { display: flex; align-items: center; gap: .6rem; width: 100%; }
.lg-brand img { height: 22px; width: auto; filter: invert(1); }
.lg-naam { font-weight: 600; font-size: 1.15rem; letter-spacing: -0.03em; color: #ECECEE; white-space: nowrap; }
.lg-sub { font-size: .9rem; color: #8C8C94; padding-left: .6rem; border-left: 1px solid #25252A; white-space: nowrap; }
.lg-link { margin-left: auto; font-size: .85rem; color: #8C8C94 !important; text-decoration: none; white-space: nowrap; }
.lg-link:hover { color: #ECECEE !important; }
@media (max-width: 575.98px) { .lg-sub, .lg-link { display: none; } }

.bslib-sidebar-layout { --_border: 1px solid #25252A; }
.bslib-sidebar-layout > .main { padding: 1.75rem 2rem; }
.sidebar .form-label, .sidebar .control-label { color: #C4C4CA; font-weight: 500; font-size: .84rem; }
.lg-info { color: #6A6A72; cursor: help; font-size: .85em; }
.form-control, .selectize-input { background: #18181C !important; border: 1px solid #25252A !important;
  color: #ECECEE !important; border-radius: 10px !important; box-shadow: none !important; }
.form-control:focus, .selectize-input.focus { border-color: #55555D !important; box-shadow: 0 0 0 3px rgba(255,255,255,.05) !important; }
.selectize-input > input { color: #ECECEE !important; }
.selectize-dropdown, .selectize-dropdown-content { background: #18181C !important; color: #ECECEE !important; border-color: #25252A !important; }
.selectize-dropdown .active { background: #25252A !important; color: #FFFFFF !important; }
.btn-file { background: #18181C !important; border-color: #25252A !important; color: #ECECEE !important; }
.progress-bar { background: #ECECEE; color: #0E0E10; }

.accordion { --bs-accordion-bg: transparent; --bs-accordion-color: #ECECEE; --bs-accordion-btn-color: #ECECEE;
  --bs-accordion-active-bg: transparent; --bs-accordion-active-color: #ECECEE; --bs-accordion-border-color: #25252A;
  --bs-accordion-btn-focus-box-shadow: none; }
.accordion-button { font-weight: 600; font-size: .93rem; }
.accordion-button::after { filter: invert(1) opacity(.55); }
.lg-stap { display: inline-flex; align-items: center; justify-content: center; flex: none; width: 1.5rem; height: 1.5rem;
  margin-right: .7rem; border: 1px solid #55555D; border-radius: 50%; font-size: .75rem; font-weight: 600; }
.lg-stap.lg-zacht { border-color: #33333A; color: #8C8C94; font-size: .65rem; }
.lg-scen { font-weight: 600; font-size: .85rem; color: #C4C4CA; }
.lg-status { font-size: .8rem; color: #8C8C94; margin-top: .6rem; line-height: 1.45; }
.lg-status b { color: #46A758; font-weight: 600; }

.btn { border-radius: 999px; font-weight: 500; letter-spacing: -0.01em; }
.btn-outline-light { --bs-btn-color: #ECECEE; --bs-btn-border-color: #2E2E34; --bs-btn-hover-bg: #1D1D21;
  --bs-btn-hover-color: #FFFFFF; --bs-btn-hover-border-color: #44444B; --bs-btn-active-bg: #1D1D21;
  --bs-btn-disabled-color: #55555D; --bs-btn-disabled-border-color: #222227; }
.lg-meldingen { display: grid; gap: .4rem; }
.lg-melding { font-size: .78rem; line-height: 1.4; padding: .45rem .65rem; border-radius: 8px; background: #18181C; border-left: 2px solid; }
.lg-melding.lg-fout { border-color: #E5484D; color: #F3B9BB; }
.lg-melding.lg-let { border-color: #D6A43B; color: #E9D5A6; }

.lg-stats { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }
.lg-stat { background: #151518; border: 1px solid #25252A; border-radius: 16px; padding: 1.25rem 1.4rem; }
.lg-stat-label { color: #8C8C94; font-size: .82rem; font-weight: 500; }
.lg-stat-waarde { font-size: 2.3rem; font-weight: 600; letter-spacing: -0.04em; line-height: 1.15; margin: .35rem 0 .25rem;
  font-variant-numeric: tabular-nums; color: #ECECEE; }
.lg-stat-waarde.lg-leeg-waarde { color: #3A3A41; }
.lg-stat-sub { color: #8C8C94; font-size: .8rem; }
@media (max-width: 767.98px) { .lg-stats { grid-template-columns: 1fr; } .bslib-sidebar-layout > .main { padding: 1.25rem 1rem; } }

.lg-leeg { border: 1px dashed #25252A; border-radius: 16px; padding: 3.5rem 1rem; text-align: center; color: #8C8C94; }
.lg-leeg img { filter: invert(1); opacity: .35; height: 30px; width: auto; margin-bottom: 1rem; }
.lg-leeg p { margin: 0; }
.lg-leeg .lg-klein { font-size: .85rem; color: #5E5E66; margin-top: .35rem; }
.lg-verouderd { font-size: .85rem; color: #E9D5A6; margin-bottom: .8rem; }
.lg-verouderd::before { content: ''; display: inline-block; width: .45rem; height: .45rem; border-radius: 50%;
  background: #D6A43B; margin-right: .5rem; vertical-align: middle; }

.card { background: #151518; border: 1px solid #25252A; border-radius: 16px; box-shadow: none; }
.card-header { background: transparent; border-bottom: 1px solid #25252A; padding-top: .35rem; }
.card-body { padding: 1.4rem 1.5rem; }
.nav-underline { gap: 1.4rem; }
.nav-underline .nav-link { color: #8C8C94; font-weight: 500; letter-spacing: -0.01em; }
.nav-underline .nav-link:hover { color: #ECECEE; }
.nav-underline .nav-link.active { color: #ECECEE; border-bottom-color: #ECECEE; font-weight: 600; }

.lg-mini-rij { display: flex; flex-wrap: wrap; gap: 1.5rem 2.75rem; margin-bottom: 1.1rem; }
.lg-mini-label { color: #8C8C94; font-size: .78rem; }
.lg-mini-waarde { font-size: 1.35rem; font-weight: 600; letter-spacing: -0.025em; font-variant-numeric: tabular-nums; }
.lg-mini-sub { color: #5E5E66; font-size: .75rem; }
.lg-zin { color: #C4C4CA; font-size: .92rem; margin-bottom: 1rem; }

.lg-uitleg { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1.75rem; margin-top: 1.4rem;
  padding-top: 1.2rem; border-top: 1px solid #25252A; }
.lg-uitleg-kop { color: #ECECEE; font-size: .78rem; font-weight: 600; margin-bottom: .35rem; }
.lg-uitleg p { color: #8C8C94; font-size: .88rem; line-height: 1.6; margin: 0; }
@media (max-width: 991.98px) { .lg-uitleg { grid-template-columns: 1fr; gap: 1rem; } }

.table { --bs-table-bg: transparent; --bs-table-color: #ECECEE; --bs-table-border-color: #25252A;
  font-variant-numeric: tabular-nums; margin: .25rem 0 0; font-size: .9rem; }
.table > :not(caption) > * > * { padding: .55rem .75rem; background: transparent; border-bottom-color: #25252A; }
.table thead th { color: #8C8C94; font-weight: 500; font-size: .78rem; border-bottom-color: #3A3A41 !important; }
.shiny-html-output table td:not(:first-child), .shiny-html-output table th:not(:first-child) { text-align: right; white-space: nowrap; }
.lg-tabel { overflow-x: auto; }
.lg-tabel .table { max-width: 860px; }
.lg-goed { color: #46A758; } .lg-slecht { color: #E5484D; }
.lg-tabel td span { margin: 0 .3rem; }
.shiny-output-error-validation { color: #8C8C94; font-size: .9rem; }

.tooltip { --bs-tooltip-bg: #2A2A30; --bs-tooltip-color: #ECECEE; }
.shiny-notification { background: #1A1A1E; color: #ECECEE; border: 1px solid #25252A; border-radius: 12px; }
.lg-voet { display: flex; justify-content: space-between; flex-wrap: wrap; gap: .5rem; color: #55555D; font-size: .76rem;
  margin-top: 1.75rem; padding-top: 1rem; border-top: 1px solid #1E1E22; }
)"

lg_thema <- bs_theme(
  version = 5,
  bg = kleur$bg, fg = kleur$tekst,
  primary = kleur$tekst, secondary = kleur$zacht,
  success = kleur$groen, danger = kleur$rood, warning = kleur$geel,
  base_font = lg_font, heading_font = lg_font,
  "border-color" = kleur$lijn,
  "border-radius" = "0.75rem",
  "card-bg" = kleur$kaart,
  "input-bg" = kleur$veld,
  "input-border-color" = kleur$lijn,
  "link-color" = kleur$tekst
) |>
  bs_add_rules(lg_css)

plot_thema <- function() {
  theme_minimal(base_size = 11) +
    theme(plot.background = element_rect(fill = "transparent", colour = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),
          panel.grid.major = element_line(colour = "#222226", linewidth = 0.3),
          panel.grid.minor = element_blank(),
          axis.text = element_text(colour = kleur$zacht, size = 9),
          axis.title = element_text(colour = kleur$zacht, size = 9),
          legend.position = "none",
          plot.margin = margin(4, 4, 4, 4))
}


# ---- helpers: opmaak en veilige invoer ----

min_teken <- function(x) gsub("-", "−", x, fixed = TRUE)
pct <- function(x, d = 1) ifelse(is.na(x), "n/a", min_teken(paste0(formatC(100 * x, format = "f", digits = d), "%")))
pct_s <- function(x, d = 1) ifelse(is.na(x), "n/a", paste0(ifelse(x > 0, "+", ""), pct(x, d)))
eur <- function(x, d = 0) {
  ifelse(is.na(x), "n/a", paste0(ifelse(x < 0, "−", ""), "€", formatC(abs(x), format = "f", digits = d, big.mark = ",")))
}
jaren <- function(n) if (n == 1) "1 year" else paste(n, "years")
maand <- function(d) ifelse(is.na(d), "not yet", format(d, "%b %Y"))

schoon <- function(x, n = 80) {
  x <- as.character(unlist(x))[1]
  if (is.na(x)) x <- ""
  substr(trimws(gsub("[^A-Za-z0-9 .,()&+/'-]", "", x)), 1, n)
}
ticker_ok <- function(x) grepl("^[A-Z0-9][A-Z0-9.-]{0,14}$", x)

info <- function(label, hulp) tagList(label, tooltip(span(class = "lg-info", " ⓘ"), hulp))

logo <- function(h = 22) {
  if (file.exists("www/logo.png")) tags$img(src = "logo.png", alt = "Le Gradient", height = h)
  else span("∇")
}

stap <- function(teken, tekst, zacht = FALSE) tagList(span(class = if (zacht) "lg-stap lg-zacht" else "lg-stap", teken), tekst)

scen_rij <- function(sc, ids, waarden, step) {
  velden <- Map(function(id, v, s) numericInput(id, NULL, v, step = s), ids, waarden, step)
  breedte <- if (length(ids) == 2) c(2, 5, 5) else c(4, 8)
  do.call(layout_columns, c(list(col_widths = breedte, gap = "0.5rem", class = "align-items-center",
                                 span(class = "lg-scen", sc)), unname(velden)))
}

scen_kop <- function(...) {
  koppen <- list(...)
  breedte <- if (length(koppen) == 2) c(2, 5, 5) else c(4, 8)
  do.call(layout_columns, c(list(col_widths = breedte, gap = "0.5rem", class = "small text-secondary"),
                            list(""), lapply(koppen, tags$span)))
}

stat <- function(label, waarde, sub) {
  div(class = "lg-stat",
      div(class = "lg-stat-label", label),
      div(class = if (identical(waarde, "—")) "lg-stat-waarde lg-leeg-waarde" else "lg-stat-waarde", waarde),
      div(class = "lg-stat-sub", sub))
}

mini <- function(label, waarde, sub = NULL) {
  div(div(class = "lg-mini-label", label), div(class = "lg-mini-waarde", waarde),
      if (!is.null(sub)) div(class = "lg-mini-sub", sub))
}

uitleg <- function(zie, lees, let) {
  blok <- function(kop, tekst) div(div(class = "lg-uitleg-kop", kop), p(tekst))
  div(class = "lg-uitleg", blok("What you see", zie), blok("How to read it", lees), blok("Watch out", let))
}

tabel <- function(id) div(class = "lg-tabel", uiOutput(id))

cel <- function(v) {
  v <- as.character(v)
  for (m in c("✓", "✗")) {
    klasse <- if (m == "✓") "lg-goed" else "lg-slecht"
    if (startsWith(v, m)) return(tags$td(span(class = klasse, m), sub(m, "", v, fixed = TRUE)))
    if (endsWith(v, m)) return(tags$td(sub(m, "", v, fixed = TRUE), span(class = klasse, m)))
  }
  tags$td(v)
}

html_tabel <- function(df) {
  tags$table(class = "table",
             tags$thead(tags$tr(lapply(names(df), tags$th))),
             tags$tbody(lapply(seq_len(nrow(df)), function(i) tags$tr(lapply(df[i, ], cel)))))
}


# ---- grafieken voor de preview (de PDF gebruikt de grafieken uit de engine) ----

plot_prijs <- function(px) {
  d <- data.frame(datum = index(px), p = as.numeric(px))
  ggplot(d, aes(datum, p)) +
    geom_line(colour = kleur$tekst, linewidth = 0.35) +
    scale_y_continuous(labels = function(y) eur(y)) +
    labs(x = NULL, y = NULL) +
    plot_thema()
}

plot_dd <- function(px, drempel) {
  x <- as.numeric(px)
  d <- data.frame(datum = index(px), dd = x / cummax(x) - 1)
  ggplot(d, aes(datum, dd)) +
    geom_area(fill = kleur$rood, alpha = 0.22) +
    geom_line(colour = kleur$rood, linewidth = 0.3) +
    geom_hline(yintercept = -drempel, colour = kleur$zacht, linetype = "dashed", linewidth = 0.3) +
    scale_y_continuous(labels = function(y) pct(y, 0)) +
    labs(x = NULL, y = NULL) +
    plot_thema()
}

plot_waaier <- function(rs, sigma, positie, jaren, stappen) {
  set.seed(42)
  d <- do.call(rbind, lapply(names(rs), function(sc) {
    x <- cbind(positie, simulate_gbm(positie, log(1 + rs[[sc]]), sigma, jaren, 4000, stappen))
    q <- apply(x, 2, quantile, c(0.1, 0.5, 0.9))
    data.frame(scenario = sc, tijd = seq(0, jaren, length.out = ncol(x)), p10 = q[1, ], p50 = q[2, ], p90 = q[3, ])
  }))
  d$scenario <- factor(d$scenario, levels = scenarios)
  base <- d[d$scenario == "base", ]
  eind <- d[d$tijd == jaren, ]
  eind_b <- base[base$tijd == jaren, ]
  ggplot() +
    geom_ribbon(data = base, aes(tijd, ymin = p10, ymax = p90), fill = kleur$tekst, alpha = 0.07) +
    geom_hline(yintercept = positie, colour = kleur$zacht, linetype = "dashed", linewidth = 0.3) +
    geom_line(data = d, aes(tijd, p50, colour = scenario), linewidth = 0.8) +
    geom_text(data = eind, aes(tijd, p50, colour = scenario,
                               label = paste0(tools::toTitleCase(as.character(scenario)), "  ", eur(p50))),
              hjust = -0.08, size = 3.3) +
    annotate("text", x = jaren, y = c(eind_b$p90, eind_b$p10), label = paste(c("P90", "P10"), eur(c(eind_b$p90, eind_b$p10))),
             hjust = -0.08, size = 2.9, colour = kleur$zacht) +
    scale_colour_manual(values = scen_kleur) +
    scale_x_continuous(breaks = 0:jaren, labels = function(x) paste0(x, "y"), expand = expansion(mult = c(0.01, 0.3))) +
    scale_y_continuous(labels = function(y) eur(y)) +
    labs(x = NULL, y = NULL) +
    plot_thema()
}

plot_dag <- function(r, positie, var95, es95) {
  pnl <- positie * (exp(as.numeric(r)) - 1)
  grens <- quantile(pnl, c(0.002, 0.998))
  ggplot(data.frame(pnl = pnl), aes(pnl)) +
    geom_histogram(bins = 90, fill = kleur$tekst, alpha = 0.28) +
    geom_vline(xintercept = -positie * var95, colour = kleur$rood, linewidth = 0.5) +
    geom_vline(xintercept = -positie * es95, colour = kleur$rood, linetype = "dashed", linewidth = 0.5) +
    annotate("text", x = -positie * var95, y = Inf, label = "VaR 95%", vjust = 1.6, hjust = -0.1, size = 3, colour = kleur$rood) +
    annotate("text", x = -positie * es95, y = Inf, label = "ES 95%", vjust = 3.4, hjust = 1.1, size = 3, colour = kleur$rood) +
    scale_x_continuous(labels = function(x) eur(x)) +
    coord_cartesian(xlim = grens) +
    labs(x = "Result on one day", y = NULL) +
    plot_thema() +
    theme(axis.text.y = element_blank(), panel.grid.major.y = element_blank())
}


# ---- UI ----

ui <- page_sidebar(
  title = div(class = "lg-brand", logo(), span(class = "lg-naam", "Le Gradient"), span(class = "lg-sub", "ETF engine"),
              tags$a(class = "lg-link", href = "https://legradient.be", target = "_blank", rel = "noopener", "legradient.be ↗")),
  window_title = "Le Gradient · ETF engine",
  theme = lg_thema,
  fillable = FALSE,
  
  sidebar = sidebar(
    width = 360,
    bg = kleur$zijbalk,
    open = list(desktop = "open", mobile = "always-above"),
    accordion(
      id = "wizard", open = "ticker",
      
      accordion_panel(
        stap(1, "Ticker"), value = "ticker",
        textInput("ticker", info("Yahoo ticker", "Search the fund on finance.yahoo.com, e.g. QDVE.DE"), "QDVE.DE"),
        textInput("naam", "Fund name", "iShares S&P 500 Information Technology Sector"),
        dateInput("start", info("Price history from", "Leave at 2010-01-01 unless the fund is younger or the early data look odd."),
                  "2010-01-01"),
        actionButton("check", "Check ticker", class = "btn-outline-light w-100"),
        uiOutput("ticker_status")
      ),
      
      accordion_panel(
        stap(2, "Fund"), value = "fonds",
        selectInput("type", "Type", types),
        selectInput("sector", info("Sector", "Use ‘Diversified’ for a broad fund. Sector limits only apply to sector funds."), sectoren),
        numericInput("ter", info("Yearly cost, TER (%)", "On the factsheet. Type 0.15 for 0.15% a year."), 0.15, step = 0.01),
        conditionalPanel(
          "input.type == 'aandelen'",
          numericInput("top", info("Biggest holding (%)", "Holdings tab on the fund's website, or justETF."), 21.1, step = 0.1)
        ),
        numericInput("positie", info("Position (EUR)", "How much we would put in this ETF."), club$positie, step = 100),
        div(class = "small text-secondary",
            paste0("Portfolio ", eur(club$portefeuille), " · cash ", eur(club$cash), " · horizon ", jaren(H),
                   ". Set in config/club.yml."))
      ),
      
      accordion_panel(
        stap(3, "Scenarios"), value = "scen",
        conditionalPanel(
          "input.type == 'aandelen'",
          layout_columns(
            col_widths = c(6, 6),
            numericInput("pe0", info("P/E today", "FactSet Earnings Insight or the factsheet."), 22, step = 0.1),
            numericInput("dy", info("Dividend yield (%)", "On the factsheet. Type 0.6 for 0.6%."), 0.6, step = 0.1)
          ),
          scen_kop("Growth (%/yr)", paste0("P/E after ", H, "y")),
          scen_rij("Bear", c("g_bear", "peH_bear"), c(5, 20.9), c(0.5, 0.1)),
          scen_rij("Base", c("g_base", "peH_base"), c(12, 21.6), c(0.5, 0.1)),
          scen_rij("Bull", c("g_bull", "peH_bull"), c(18, 22), c(0.5, 0.1))
        ),
        conditionalPanel(
          "input.type == 'obligaties'",
          layout_columns(
            col_widths = c(6, 6),
            numericInput("ytm", info("Yield (%)", "Yield to maturity, on the factsheet."), 3.94, step = 0.01),
            numericInput("duration", info("Duration (yrs)", "On the factsheet."), 5.95, step = 0.05)
          ),
          scen_kop("Rate change (%-points)"),
          scen_rij("Bear", "dr_bear", 2, 0.25),
          scen_rij("Base", "dr_base", 0, 0.25),
          scen_rij("Bull", "dr_bull", -1, 0.25)
        ),
        conditionalPanel(
          "input.type == 'overig'",
          scen_kop("Return (%/yr)"),
          scen_rij("Bear", "ov_bear", -2, 0.5),
          scen_rij("Base", "ov_base", 3, 0.5),
          scen_rij("Bull", "ov_bull", 7, 0.5)
        )
      ),
      
      accordion_panel(
        stap(icon("sliders"), "Advanced", zacht = TRUE), value = "adv",
        numericInput("drempel", info("Drawdown threshold (%)", "Every fall at least this big counts as an episode."),
                     100 * (club$drempel %||% 0.15), step = 1),
        selectInput("centrum", info("Centre of daily losses", "Zero is the cautious choice for one-day risk."),
                    c("Zero" = "nul", "Estimated mean" = "geschat"), club$centrum %||% "nul"),
        numericInput("stappen", info("Simulation steps per year", "52 = weekly steps."), club$stappen %||% 52, step = 1),
        layout_columns(
          col_widths = c(4, 4, 4),
          numericInput("min_test", "Min. test", club$min_test %||% 750, step = 50),
          numericInput("min_train", "Min. train", club$min_train %||% 1000, step = 50),
          numericInput("frac_test", "Test %", 100 * (club$frac_test %||% 0.3), step = 5)
        )
      ),
      
      accordion_panel(
        stap(icon("folder-open"), "Load / save", zacht = TRUE), value = "laden",
        fileInput("upload", "Load inputs (.yml)", accept = c(".yml", ".yaml")),
        uiOutput("upload_kies"),
        downloadButton("yml", "Save inputs (.yml)", class = "btn-outline-light btn-sm w-100")
      )
    ),
    
    uiOutput("meldingen"),
    input_task_button("run", "Run model", label_busy = "Running…", class = "w-100"),
    uiOutput("pdf_knop")
  ),
  
  tags$head(tags$link(rel = "icon", type = "image/png", href = "logo.png")),
  uiOutput("kern"),
  uiOutput("verouderd"),
  conditionalPanel(
    "!output.heeft_res",
    div(class = "lg-leeg", logo(30), p("Fill in the steps on the left and press Run model."),
        p(class = "lg-klein", "The full analysis appears here, section by section."))
  ),
  conditionalPanel(
    "output.heeft_res",
    navset_card_underline(
      id = "secties",
      nav_panel("History", uiOutput("s_hist_stats"), plotOutput("p_hist", height = 360), uiOutput("s_hist_uitleg")),
      nav_panel("Outlook", plotOutput("p_waaier", height = 300), tabel("t_mc"), uiOutput("s_out_uitleg")),
      nav_panel("Daily risk", plotOutput("p_dag", height = 210), tabel("t_dag"), uiOutput("s_dag_uitleg")),
      nav_panel("Backtest", uiOutput("s_bt_zin"), tabel("t_bt"), uiOutput("s_bt_uitleg")),
      nav_panel("Horizon", uiOutput("s_hor_stats"), uiOutput("s_hor_uitleg")),
      nav_panel("Club limits", tabel("t_lim"), uiOutput("s_lim_uitleg"))
    )
  ),
  div(class = "lg-voet",
      span(paste0("© ", format(Sys.Date(), "%Y"), " Le Gradient · Ghent")),
      span("Not investment advice. The engine is only as good as the numbers you put in."))
)


# ---- server ----

server <- function(input, output, session) {
  
  ticker <- reactive(toupper(trimws(input$ticker)))
  
  algemeen <- reactive({
    a <- club
    a$positie <- input$positie
    a$centrum <- input$centrum
    a$stappen <- input$stappen
    a$min_test <- input$min_test
    a$min_train <- input$min_train
    a$frac_test <- input$frac_test / 100
    a
  })
  
  etf <- reactive({
    b <- list(ticker = ticker(), naam = schoon(input$naam), type = input$type, sector = input$sector,
              start = format(input$start), ter = input$ter / 100, drempel = input$drempel / 100)
    if (input$type == "aandelen") {
      b$top_positie <- input$top / 100
      b$waardering <- list(
        pe0 = input$pe0, dy = input$dy / 100,
        scenarios = setNames(lapply(scenarios, function(s) {
          list(g = input[[paste0("g_", s)]] / 100, peH = input[[paste0("peH_", s)]])
        }), scenarios))
    } else if (input$type == "obligaties") {
      b$obligaties <- list(
        ytm = input$ytm / 100, duration = input$duration,
        scenarios = setNames(lapply(scenarios, function(s) list(dy = input[[paste0("dr_", s)]] / 100)), scenarios))
    } else {
      b$overig <- list(scenarios = setNames(lapply(scenarios, function(s) input[[paste0("ov_", s)]] / 100), scenarios))
    }
    b
  })
  
  blok <- reactive(list(algemeen = algemeen(), etfs = list(etf())))
  cfg <- reactive(modifyList(algemeen(), etf()))
  
  
  # ---- controle van de invoer ----
  
  problemen <- reactive({
    fout <- character()
    let <- character()
    v <- function(id) input[[id]]
    
    nodig <- c(ter = "TER", positie = "Position", drempel = "Drawdown threshold", stappen = "Steps per year",
               min_test = "Min. test", min_train = "Min. train", frac_test = "Test %")
    nodig <- c(nodig, switch(input$type,
                             aandelen = c(top = "Biggest holding", pe0 = "P/E today", dy = "Dividend yield",
                                          setNames(paste("Growth", scenarios), paste0("g_", scenarios)),
                                          setNames(paste("P/E", scenarios), paste0("peH_", scenarios))),
                             obligaties = c(ytm = "Yield", duration = "Duration", setNames(paste("Rate change", scenarios), paste0("dr_", scenarios))),
                             overig = setNames(paste("Return", scenarios), paste0("ov_", scenarios))))
    leeg <- names(nodig)[vapply(names(nodig), function(id) is.null(v(id)) || is.na(v(id)), logical(1))]
    if (length(leeg)) return(list(fout = paste("Missing:", paste(nodig[leeg], collapse = ", ")), let = let))
    
    if (!ticker_ok(ticker())) fout <- c(fout, "Ticker: use the Yahoo code, e.g. QDVE.DE.")
    if (!nzchar(schoon(input$naam))) fout <- c(fout, "Give the fund a name.")
    if (!identical(schoon(input$naam), trimws(input$naam))) let <- c(let, "Special characters were removed from the name.")
    if (length(input$start) == 0 || is.na(input$start) || input$start > Sys.Date() - 30) {
      fout <- c(fout, "The price history must start at least a month ago.")
    } else if (input$start > Sys.Date() - 3 * 365) {
      let <- c(let, "Less than 3 years of prices: the backtest will probably be skipped.")
    }
    
    if (v("positie") <= 0) fout <- c(fout, "Position must be above 0.")
    if (v("ter") < 0 || v("ter") > 3) fout <- c(fout, "TER must be between 0% and 3%.")
    if (v("ter") > 0 && v("ter") < 0.01) let <- c(let, paste0("TER of ", v("ter"), "% looks tiny. Type 0.15 for 0.15%."))
    if (v("ter") > 1) let <- c(let, "A TER above 1% is rare for an ETF.")
    if (v("drempel") <= 0 || v("drempel") >= 100) fout <- c(fout, "Drawdown threshold must be between 0% and 100%.")
    if (v("stappen") < 1 || v("stappen") > 365 || v("stappen") != round(v("stappen"))) fout <- c(fout, "Steps per year: a whole number from 1 to 365.")
    if (v("min_test") < 50 || v("min_train") < 50) fout <- c(fout, "Min. test and train days must be at least 50.")
    if (v("frac_test") <= 0 || v("frac_test") >= 90) fout <- c(fout, "Test % must be between 0 and 90.")
    
    oplopend <- function(x) all(diff(x) >= 0)
    
    if (input$type == "aandelen") {
      g <- vapply(paste0("g_", scenarios), v, numeric(1))
      peH <- vapply(paste0("peH_", scenarios), v, numeric(1))
      if (v("top") < 0 || v("top") > 100) fout <- c(fout, "Biggest holding must be between 0% and 100%.")
      if (v("pe0") <= 0 || any(peH <= 0)) fout <- c(fout, "P/E values must be above 0.")
      if (v("dy") < 0 || v("dy") > 20) fout <- c(fout, "Dividend yield must be between 0% and 20%.")
      if (any(g < -50 | g > 100)) fout <- c(fout, "Growth must be between −50% and 100% a year.")
      if (v("dy") > 0 && v("dy") < 0.05) let <- c(let, "Dividend yield looks like a decimal. Type 0.6 for 0.6%.")
      if (all(abs(g) < 1) && any(g != 0)) let <- c(let, "Growth looks like decimals. Type 12 for 12%.")
      if (!oplopend(g) || !oplopend(peH)) let <- c(let, "Bear should be the worst case and bull the best.")
      if (v("pe0") > 0 && any(abs(peH / v("pe0") - 1) > 0.5)) let <- c(let, "A P/E change of more than 50% is a big call.")
    }
    if (input$type == "obligaties") {
      dr <- vapply(paste0("dr_", scenarios), v, numeric(1))
      if (v("ytm") < -5 || v("ytm") > 30) fout <- c(fout, "Yield must be between −5% and 30%.")
      if (v("duration") < 0 || v("duration") > 40) fout <- c(fout, "Duration must be between 0 and 40 years.")
      if (any(abs(dr) > 10)) fout <- c(fout, "Rate changes must be between −10 and +10 points.")
      if (!oplopend(-dr)) let <- c(let, "Bear should have the biggest rate rise, bull the biggest fall.")
    }
    if (input$type == "overig") {
      ov <- vapply(paste0("ov_", scenarios), v, numeric(1))
      if (any(abs(ov) > 100)) fout <- c(fout, "Returns must be between −100% and 100% a year.")
      if (!oplopend(ov)) let <- c(let, "Bear should be the worst case and bull the best.")
    }
    list(fout = fout, let = let)
  })
  
  output$meldingen <- renderUI({
    p <- problemen()
    if (!length(p$fout) && !length(p$let)) return(NULL)
    div(class = "lg-meldingen mt-2",
        lapply(p$fout, function(m) div(class = "lg-melding lg-fout", m)),
        lapply(p$let, function(m) div(class = "lg-melding lg-let", m)))
  })
  
  
  # ---- koersen: ticker controleren ----
  
  koersdata <- reactiveVal(NULL)
  
  observeEvent(input$check, {
    if (!ticker_ok(ticker())) {
      showNotification("That is not a valid Yahoo ticker.", type = "error")
      return()
    }
    d <- withProgress(message = paste("Loading prices for", ticker()), value = 0.5,
                      tryCatch(load_etf(ticker(), from = format(input$start)), error = function(e) e))
    if (inherits(d, "error")) {
      koersdata(NULL)
      showNotification(paste0("Could not load ", ticker(), ": ", conditionMessage(d)), type = "error", duration = 10)
      return()
    }
    koersdata(d)
    accordion_panel_open("wizard", "fonds")
  })
  
  output$ticker_status <- renderUI({
    d <- koersdata()
    req(d)
    if (!identical(d$ticker, ticker())) return(div(class = "lg-status", "Ticker changed: check again."))
    w <- sub("^\\d+ ", "", d$checks$waarschuwing)
    w <- unname(ifelse(w %in% names(checks_en), checks_en[w], d$checks$waarschuwing))
    div(class = "lg-status",
        tags$b("✓ Found"), paste0(" · ", d$valuta, " · last ", formatC(d$koers_lokaal, format = "f", digits = 2),
                                  " · ", format(d$checks$n, big.mark = ","), " days"),
        if (length(w)) div(paste("Data checks:", paste(w, collapse = "; "))))
  })
  
  observeEvent(input$type, {
    if (input$type == "obligaties") updateSelectInput(session, "sector", selected = "obligaties")
    if (input$type == "overig" && input$sector %in% c("obligaties", "technologie")) updateSelectInput(session, "sector", selected = "grondstoffen")
  }, ignoreInit = TRUE)
  
  
  # ---- voorpagina: drie kerncijfers ----
  
  live <- reactive({
    if (length(problemen()$fout)) return(NULL)
    verwacht_rendement(cfg())
  })
  
  hist_nu <- reactive({
    d <- koersdata()
    if (is.null(d) || !identical(d$ticker, ticker())) return(NULL)
    list(h = historiek(d$px), start = format(start(d$px), "%Y"))
  })
  
  output$kern <- renderUI({
    rs <- live()
    h <- hist_nu()
    leeg <- "—"
    div(class = "lg-stats",
        stat("Expected return",
             if (is.null(rs)) leeg else pct(rs[["base"]]),
             if (is.null(rs)) "fill in the scenarios" else paste0("per year, base · bear ", pct(rs[["bear"]]), " · bull ", pct(rs[["bull"]]))),
        stat("Historic return",
             if (is.null(h)) leeg else pct(h$h$cagr),
             if (is.null(h)) "check the ticker to load prices" else paste0("per year (CAGR) since ", h$start)),
        stat("Historic volatility",
             if (is.null(h)) leeg else pct(h$h$vol),
             if (is.null(h)) "check the ticker to load prices" else "typical yearly swing, up or down"))
  })
  
  
  # ---- volledig model: enkel op de knop ----
  
  res <- reactiveVal(NULL)
  res_blok <- reactiveVal(NULL)
  
  observeEvent(input$run, {
    if (length(problemen()$fout)) {
      showNotification("Fix the red messages first.", type = "error")
      return()
    }
    b <- blok()
    c0 <- cfg()
    out <- withProgress(message = "Running the model", value = 0, {
      tryCatch({
        incProgress(0.2, detail = "prices")
        koersdata(load_etf(c0$ticker, from = c0$start))
        incProgress(0.3, detail = "simulation, Student-t fit, backtest")
        r <- run_etf(c0)
        incProgress(0.5, detail = "done")
        r
      }, error = function(e) e)
    })
    if (inherits(out, "error")) {
      showNotification(paste("The model stopped:", conditionMessage(out)), type = "error", duration = 10)
      return()
    }
    res(out)
    res_blok(b)
  })
  
  output$heeft_res <- reactive(!is.null(res()))
  outputOptions(output, "heeft_res", suspendWhenHidden = FALSE)
  
  output$verouderd <- renderUI({
    req(res_blok())
    if (!identical(res_blok(), blok())) div(class = "lg-verouderd", "Inputs changed since the last run. Press Run model to update.")
  })
  
  output$pdf_knop <- renderUI({
    if (is.null(res())) {
      tags$button(class = "btn btn-outline-light w-100 mt-2", disabled = NA, "Download PDF report")
    } else {
      downloadButton("pdf", "Download PDF report", class = "btn-outline-light w-100 mt-2")
    }
  })
  
  
  # ---- sectie: history ----
  
  output$s_hist_stats <- renderUI({
    x <- res()
    req(x)
    h <- x$hist
    k <- h$kalender[!is.na(h$kalender)]
    div(class = "lg-mini-rij",
        mini("Worst fall", pct(h$maxdd)),
        mini(paste0("Falls of ", pct(x$cfg$drempel, 0), " or more"), nrow(h$episodes)),
        mini("Best year", pct_s(max(k)), names(k)[which.max(k)]),
        mini("Worst year", pct_s(min(k)), names(k)[which.min(k)]))
  })
  
  output$p_hist <- renderPlot({
    req(res())
    g <- rbind(ggplotGrob(plot_prijs(res()$data$px)),
               ggplotGrob(plot_dd(res()$data$px, res()$cfg$drempel %||% 0.15)), size = "max")
    panelen <- g$layout$t[grepl("^panel", g$layout$name)]
    g$heights[panelen] <- grid::unit(c(2.3, 1), "null")
    grid::grid.newpage()
    grid::grid.draw(g)
  }, bg = "transparent")
  
  output$s_hist_uitleg <- renderUI({
    x <- res()
    req(x)
    ep <- x$hist$episodes
    diepste <- if (nrow(ep)) {
      i <- which.min(ep$daling)
      paste0(" The deepest fall started in ", maand(as.Date(ep$top[i])), " and ",
             if (is.na(ep$herstel[i])) "has not recovered yet." else paste0("was back at its peak in ", maand(as.Date(ep$herstel[i])), "."))
    } else ""
    uitleg(
      paste0("Top: the price in euro since ", format(start(x$data$px), "%Y"), ". Bottom: how far the price sat below its previous peak (the drawdown)."),
      paste0("The deeper and longer the red area, the more patience someone who bought at the top needed.", diepste),
      "The past shows how wild the ride was, not where it goes next."
    )
  })
  
  
  # ---- sectie: outlook ----
  
  output$p_waaier <- renderPlot({
    x <- res()
    req(x)
    validate(need(x$mc, "No scenarios for this fund, so no simulation."))
    plot_waaier(x$rs, x$hist$vol, x$cfg$positie, x$cfg$horizon, x$cfg$stappen %||% 52)
  }, bg = "transparent")
  
  output$t_mc <- renderUI({
    x <- res()
    req(x, x$mc)
    mc <- x$mc
    html_tabel(data.frame(Scenario = c("Bear", "Base", "Bull"), `Return / year` = pct(x$rs[scenarios]),
                          P10 = eur(mc[scenarios, "p10"]), P50 = eur(mc[scenarios, "p50"]), P90 = eur(mc[scenarios, "p90"]),
                          `Chance of a loss` = pct(mc[scenarios, "verlies"], 0), check.names = FALSE))
  })
  
  output$s_out_uitleg <- renderUI({
    x <- res()
    req(x)
    hoe <- switch(x$cfg$type,
                  aandelen = "Return per year = profit growth + change in P/E + dividend − costs (Grinold–Kroner).",
                  obligaties = "Return per year = yield − costs + the price effect of the rate change, spread over the horizon.",
                  "There is no valuation model for this type: the yearly returns are your own input.")
    uitleg(
      paste0("10,000 simulated paths of ", eur(x$cfg$positie), " over ", jaren(x$cfg$horizon),
             ". Lines: the middle outcome per scenario. Band: 80% of the base-case paths. Dashed: what we put in."),
      paste0(hoe, " The simulation adds the fund's historic volatility (", pct(x$hist$vol), ") around that trend. ",
             "P10 means 1 in 10 paths ends lower. Chance of a loss = share of paths that end below what we put in."),
      paste0("The outlook is only as good as the ",
             switch(x$cfg$type, aandelen = "growth and P/E", obligaties = "yield and rate changes", "returns"),
             " you typed in. Change one and run again to see how much it matters.")
    )
  })
  
  
  # ---- sectie: daily risk ----
  
  output$p_dag <- renderPlot({
    x <- res()
    req(x)
    plot_dag(x$data$r, x$cfg$positie, x$r95["student_t", "VaR"], x$r95["student_t", "ES"])
  }, bg = "transparent")
  
  output$t_dag <- renderUI({
    x <- res()
    req(x)
    k <- function(v) eur(x$cfg$positie * v)
    html_tabel(data.frame(Model = unname(modellen[rownames(x$r95)]), `VaR 95%` = k(x$r95[, "VaR"]), `ES 95%` = k(x$r95[, "ES"]),
                          `VaR 99%` = k(x$r99[, "VaR"]), `ES 99%` = k(x$r99[, "ES"]), check.names = FALSE))
  })
  
  output$s_dag_uitleg <- renderUI({
    x <- res()
    req(x)
    uitleg(
      paste0("How much ", eur(x$cfg$positie), " can lose on one bad day. Bars: the fund's daily results in the past. ",
             "Red lines: VaR and ES at 95% from the Student-t model."),
      "VaR 95% is the loss we exceed on about 1 day in 20. ES 95% is the average loss on those bad days, so it looks into the tail.",
      paste0("Markets crash more often than the normal distribution says. The Student-t here has ",
             formatC(x$fit[["df"]], format = "f", digits = 1), " degrees of freedom: the lower, the fatter the tails.")
    )
  })
  
  
  # ---- sectie: backtest ----
  
  output$s_bt_zin <- renderUI({
    x <- res()
    req(x)
    sp <- x$split
    if (!sp$ok) return(div(class = "lg-zin", paste0("No backtest: ", sp$reden, ".")))
    bt <- x$bt
    ok <- sum(bt$p_kupiec >= 0.05)
    div(class = "lg-mini-rij",
        mini("Tested from", format(sp$start_test, "%b %Y"), paste(format(length(sp$test), big.mark = ","), "days")),
        mini("Models that hold", paste(ok, "of", nrow(bt))))
  })
  
  output$t_bt <- renderUI({
    x <- res()
    req(x, x$bt)
    bt <- x$bt
    html_tabel(data.frame(Model = unname(modellen[bt$model]), Level = pct(bt$alpha, 0), `Days over VaR` = as.integer(bt$x),
                          Expected = formatC(bt$verwacht, format = "f", digits = 0),
                          Verdict = ifelse(bt$p_kupiec >= 0.05, "✓ holds", "✗ rejected"),
                          check.names = FALSE))
  })
  
  output$s_bt_uitleg <- renderUI({
    x <- res()
    req(x)
    uitleg(
      "We fitted each risk model on older data and checked it on recent days it had never seen.",
      "A model holds when the number of days the loss went past its VaR is close to what it promised (Kupiec count test, p ≥ 0.05).",
      "The verdict only counts the bad days. It ignores whether they come in clusters, which they often do: the model uses one fixed volatility, so it can't raise its guard when markets get nervous."
    )
  })
  
  
  # ---- sectie: horizon ----
  
  output$s_hor_stats <- renderUI({
    x <- res()
    req(x)
    pos <- x$cfg$positie
    div(class = "lg-mini-rij",
        mini("Average loss, worst 5%", eur(pos * x$es1[["ES"]]), "over 1 year"),
        mini("Average loss, worst 5%", eur(pos * x$esH[["ES"]]), paste("over", jaren(x$cfg$horizon))),
        mini("Loss in 1 of 20 cases", eur(pos * x$esH[["VaR"]]), paste("over", jaren(x$cfg$horizon))))
  })
  
  output$s_hor_uitleg <- renderUI({
    x <- res()
    req(x)
    uitleg(
      paste0("What we could lose on ", eur(x$cfg$positie), " if we hold for 1 year and for our full horizon, simulated with the Student-t model."),
      "“Average loss, worst 5%” is the expected shortfall: in the 1 in 20 worst outcomes, we lose this much on average.",
      "This view leaves out our return forecast on purpose. It shows the risk, not the expected gain."
    )
  })
  
  
  # ---- sectie: club limits ----
  
  output$t_lim <- renderUI({
    x <- res()
    req(x)
    teken <- function(ok) ifelse(is.na(ok), "", ifelse(ok, " ✓", " ✗"))
    l <- x$limieten
    l30 <- x$limieten30
    html_tabel(data.frame(Rule = unname(regels[l$regel]),
                          Limit = paste(ifelse(l$soort == "max", "max", "min"), pct(l$grens, 0)),
                          `Your position` = paste0(pct(l$waarde), teken(l$ok)),
                          `At 30% weight` = paste0(pct(l30$waarde), teken(l30$ok)),
                          check.names = FALSE))
  })
  
  output$s_lim_uitleg <- renderUI({
    x <- res()
    req(x)
    uitleg(
      paste0("Our club rules for this ETF, with the position you entered (", eur(x$cfg$positie), ") and at the 30% maximum."),
      "Sector limits only count for sector funds. Look-through uses the fund's biggest holding to check the 20% issuer limit.",
      "Look-through only uses the biggest holding. It doesn't see overlap with what we already own."
    )
  })
  
  
  # ---- downloads ----
  
  output$pdf <- downloadHandler(
    filename = function() paste0(gsub("[^A-Za-z0-9]", "_", res()$cfg$ticker %||% "etf"), ".pdf"),
    content = function(file) {
      if (is.null(res())) stop("Run the model first.")
      tmp <- tempfile("rapport_")
      dir.create(tmp)
      on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
      yml <- file.path(tmp, "invoer.yml")
      yaml::write_yaml(res_blok(), yml)
      e <- new.env()
      e$res <- res()
      ok <- withProgress(message = "Writing the PDF…", value = 0.4, tryCatch({
        rmarkdown::render("rapport.Rmd", params = list(ticker = res()$cfg$ticker, config = yml), envir = e,
                          quiet = TRUE, output_file = "rapport.pdf", output_dir = tmp,
                          intermediates_dir = tmp, knit_root_dir = getwd())
        TRUE
      }, error = function(err) {
        showNotification(paste("The PDF failed:", conditionMessage(err)), type = "error", duration = 15)
        FALSE
      }))
      if (!ok) stop("PDF failed")
      file.copy(file.path(tmp, "rapport.pdf"), file)
    },
    contentType = "application/pdf"
  )
  
  output$yml <- downloadHandler(
    filename = function() paste0(gsub("[^A-Za-z0-9]", "_", ticker()), ".yml"),
    content = function(file) yaml::write_yaml(blok(), file)
  )
  
  
  # ---- invoer laden uit een .yml ----
  
  geladen <- reactiveVal(NULL)
  
  vul_in <- function(y, i) {
    a <- if (is.list(y$algemeen)) y$algemeen else list()
    e <- y$etfs[[i]]
    getal <- function(x, schaal = 1) {
      x <- suppressWarnings(as.numeric(x))
      if (length(x) == 1 && is.finite(x)) round(x * schaal, 6) else NULL
    }
    zet <- function(id, x, schaal = 1) {
      g <- getal(x, schaal)
      if (!is.null(g)) updateNumericInput(session, id, value = g)
    }
    deel <- function(x, naam) if (is.list(x) && !is.null(x[[naam]])) x[[naam]] else NULL
    
    tk <- toupper(schoon(e$ticker, 15))
    updateTextInput(session, "ticker", value = tk)
    updateTextInput(session, "naam", value = schoon(e$naam))
    if (isTRUE(e$type %in% types)) updateSelectInput(session, "type", selected = e$type)
    if (isTRUE(e$sector %in% sectoren)) updateSelectInput(session, "sector", selected = e$sector)
    d <- tryCatch(as.Date(as.character(unlist(e$start %||% "2010-01-01"))[1]), error = function(err) NA)
    if (!is.na(d)) updateDateInput(session, "start", value = d)
    
    zet("ter", e$ter, 100)
    zet("top", e$top_positie, 100)
    zet("positie", e$positie %||% a$positie)
    zet("drempel", e$drempel %||% a$drempel %||% 0.15, 100)
    zet("stappen", e$stappen %||% a$stappen)
    zet("min_test", e$min_test %||% a$min_test)
    zet("min_train", e$min_train %||% a$min_train)
    zet("frac_test", e$frac_test %||% a$frac_test, 100)
    centrum <- e$centrum %||% a$centrum
    if (isTRUE(centrum %in% c("nul", "geschat"))) updateSelectInput(session, "centrum", selected = centrum)
    
    w <- deel(e, "waardering")
    zet("pe0", deel(w, "pe0"))
    zet("dy", deel(w, "dy"), 100)
    o <- deel(e, "obligaties")
    zet("ytm", deel(o, "ytm"), 100)
    zet("duration", deel(o, "duration"))
    for (s in scenarios) {
      zet(paste0("g_", s), deel(deel(deel(w, "scenarios"), s), "g"), 100)
      zet(paste0("peH_", s), deel(deel(deel(w, "scenarios"), s), "peH"))
      zet(paste0("dr_", s), deel(deel(deel(o, "scenarios"), s), "dy"), 100)
      zet(paste0("ov_", s), deel(deel(deel(e, "overig"), "scenarios"), s), 100)
    }
    koersdata(NULL)
    showNotification(paste("Loaded", tk, "— check the fields, then Check ticker."), type = "message")
  }
  
  observeEvent(input$upload, {
    y <- tryCatch(yaml::read_yaml(input$upload$datapath, eval.expr = FALSE), error = function(e) NULL)
    if (!is.list(y) || !is.list(y$etfs) || !length(y$etfs) || !all(vapply(y$etfs, is.list, logical(1)))) {
      geladen(NULL)
      showNotification("This is not a config file from the ETF engine.", type = "error")
      return()
    }
    y$etfs <- head(y$etfs, 50)
    geladen(y)
    if (length(y$etfs) == 1) tryCatch(vul_in(y, 1), error = function(e) showNotification("Some fields could not be read.", type = "warning"))
  })
  
  output$upload_kies <- renderUI({
    y <- geladen()
    req(y, length(y$etfs) > 1)
    namen <- vapply(y$etfs, function(e) toupper(schoon(e$ticker, 15)), character(1))
    namen[!nzchar(namen)] <- "(no ticker)"
    tagList(selectInput("kies_etf", "This file has several ETFs. Which one?", setNames(seq_along(namen), namen)),
            actionButton("kies_ok", "Load this ETF", class = "btn-outline-light btn-sm w-100 mb-2"))
  })
  
  observeEvent(input$kies_ok, {
    i <- as.integer(input$kies_etf)
    req(geladen(), i >= 1, i <= length(geladen()$etfs))
    tryCatch(vul_in(geladen(), i), error = function(e) showNotification("Some fields could not be read.", type = "warning"))
  })
}

shinyApp(ui, server)