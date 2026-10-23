# Le Gradient · ETF engine — Shiny prototype
# Zet dit bestand in de root van etf-model-1 (naast run_all.R) en start met shiny::runApp()
# Het past geen enkel bestaand bestand aan: het gebruikt de engine (R/*.R) en rapport.Rmd zoals ze zijn.

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


# ---- helpers: opmaak en veilige invoer ----

pct <- function(x, d = 1) ifelse(is.na(x), "n/a", paste0(formatC(100 * x, format = "f", digits = d), "%"))
eur <- function(x, d = 0) ifelse(is.na(x), "n/a", paste0("EUR ", formatC(x, format = "f", digits = d, big.mark = ",")))
jaren <- function(n) if (n == 1) "1 year" else paste(n, "years")
maand <- function(d) ifelse(is.na(d), "not yet", format(d, "%b %Y"))

schoon <- function(x, n = 80) {
  x <- as.character(unlist(x))[1]
  if (is.na(x)) x <- ""
  substr(trimws(gsub("[^A-Za-z0-9 .,()&+/'-]", "", x)), 1, n)
}
ticker_ok <- function(x) grepl("^[A-Z0-9][A-Z0-9.-]{0,14}$", x)

info <- function(label, hulp) {
  tagList(label, tooltip(span(" ⓘ", class = "text-primary", style = "cursor: help;"), hulp))
}

scen_rij <- function(sc, ids, waarden, step) {
  velden <- Map(function(id, v, s) numericInput(id, NULL, v, step = s), ids, waarden, step)
  breedte <- if (length(ids) == 2) c(2, 5, 5) else c(4, 8)
  do.call(layout_columns, c(list(col_widths = breedte, gap = "0.5rem", class = "align-items-center",
                                 tags$b(sc)), unname(velden)))
}

scen_kop <- function(...) {
  koppen <- list(...)
  breedte <- if (length(koppen) == 2) c(2, 5, 5) else c(4, 8)
  do.call(layout_columns, c(list(col_widths = breedte, gap = "0.5rem", class = "small text-muted"),
                            list(""), lapply(koppen, tags$span)))
}

vergelijk_rij <- function(x) {
  bt99 <- if (is.null(x$bt)) NA else x$bt$x[x$bt$alpha == 0.99 & x$bt$model == "student_t"]
  data.frame(ticker = x$cfg$ticker, type = x$cfg$type, valuta = x$data$valuta,
             cagr = round(x$hist$cagr, 3), vol = round(x$hist$vol, 3), maxdd = round(x$hist$maxdd, 3),
             base = if (is.null(x$rs)) NA else round(x$rs[["base"]], 3),
             horizon = x$cfg$horizon,
             verlies_H = if (is.null(x$mc)) NA else round(x$mc["base", "verlies"], 2),
             p10_H = if (is.null(x$mc)) NA else round(x$mc["base", "p10"]),
             test_vanaf = if (x$split$ok) format(x$split$start_test) else x$split$reden,
             bt99_t = bt99, esH = round(x$esH[["ES"]], 3),
             waarschuwing = paste(x$data$checks$waarschuwing, collapse = "; "))
}

nog_niet <- function(res) validate(need(res, "Click “Run full model” in the sidebar to fill this tab."))


# ---- UI ----

ui <- page_sidebar(
  title = tags$span("Le Gradient", tags$small(class = "text-muted ms-2", "ETF engine · prototype")),
  theme = bs_theme(version = 5, primary = "#0B3D91"),
  fillable = FALSE,
  
  sidebar = sidebar(
    width = 390,
    accordion(
      id = "wizard", open = "ticker",
      
      accordion_panel(
        "1 · Ticker", value = "ticker",
        textInput("ticker", info("Yahoo ticker", "Search the fund on finance.yahoo.com, e.g. QDVE.DE"), "QDVE.DE"),
        textInput("naam", "Fund name", "iShares S&P 500 Information Technology Sector"),
        dateInput("start", info("Price history from", "Leave at 2010-01-01 unless the fund is younger or the early data look odd."),
                  "2010-01-01"),
        actionButton("check", "Check ticker", class = "btn-outline-primary w-100"),
        uiOutput("ticker_status"),
        plotOutput("mini", height = 130)
      ),
      
      accordion_panel(
        "2 · Fund", value = "fonds",
        selectInput("type", "Type", types),
        selectInput("sector", info("Sector", "Use ‘Diversified’ for a broad fund. Sector limits only apply to sector funds."), sectoren),
        numericInput("ter", info("Yearly cost, TER (%)", "On the factsheet. Type 0.15 for 0.15% a year."), 0.15, step = 0.01),
        conditionalPanel(
          "input.type == 'aandelen'",
          numericInput("top", info("Biggest holding (%)", "Holdings tab on the fund's website, or justETF."), 21.1, step = 0.1)
        ),
        numericInput("positie", info("Position (EUR)", "How much we would put in this ETF."), club$positie, step = 100),
        tags$small(class = "text-muted",
                   paste0("Club settings, from config/club.yml: portfolio ", eur(club$portefeuille), " · cash ",
                          eur(club$cash), " · horizon ", jaren(H), ". Only the repo owner changes these."))
      ),
      
      accordion_panel(
        "3 · Scenarios", value = "scen",
        conditionalPanel(
          "input.type == 'aandelen'",
          layout_columns(
            col_widths = c(6, 6),
            numericInput("pe0", info("P/E today", "FactSet Earnings Insight or the factsheet."), 22, step = 0.1),
            numericInput("dy", info("Dividend yield (%)", "On the factsheet. Type 0.6 for 0.6%."), 0.6, step = 0.1)
          ),
          scen_kop("Profit growth (% / year)", paste0("P/E after ", jaren(H))),
          scen_rij("Bear", c("g_bear", "peH_bear"), c(5, 20.9), c(0.5, 0.1)),
          scen_rij("Base", c("g_base", "peH_base"), c(12, 21.6), c(0.5, 0.1)),
          scen_rij("Bull", c("g_bull", "peH_bull"), c(18, 22), c(0.5, 0.1)),
          helpText(paste0("Growth: analyst forecasts plus your own judgement. P/E after ", jaren(H),
                          ": your call, will the market pay more or less at the end of our horizon?"))
        ),
        conditionalPanel(
          "input.type == 'obligaties'",
          layout_columns(
            col_widths = c(6, 6),
            numericInput("ytm", info("Yield to maturity (%)", "On the factsheet."), 3.94, step = 0.01),
            numericInput("duration", info("Duration (years)", "On the factsheet."), 5.95, step = 0.05)
          ),
          scen_kop("Change in interest rates (%-points)"),
          scen_rij("Bear", "dr_bear", 2, 0.25),
          scen_rij("Base", "dr_base", 0, 0.25),
          scen_rij("Bull", "dr_bull", -1, 0.25),
          helpText("Bear = rates go up, which hurts bond prices.")
        ),
        conditionalPanel(
          "input.type == 'overig'",
          scen_kop("Return (% / year)"),
          scen_rij("Bear", "ov_bear", -2, 0.5),
          scen_rij("Base", "ov_base", 3, 0.5),
          scen_rij("Bull", "ov_bull", 7, 0.5),
          helpText("No valuation model for this type: you give the yearly return per scenario yourself.")
        )
      ),
      
      accordion_panel(
        "Advanced", value = "adv",
        numericInput("drempel", info("Drawdown threshold (%)", "Every fall at least this big is listed as an episode."),
                     100 * (club$drempel %||% 0.15), step = 1),
        selectInput("centrum", info("Centre of daily losses", "Zero is the cautious choice for one-day risk."),
                    c("Zero" = "nul", "Estimated mean" = "geschat"), club$centrum %||% "nul"),
        numericInput("stappen", info("Simulation steps per year", "52 = weekly steps."), club$stappen %||% 52, step = 1),
        layout_columns(
          col_widths = c(4, 4, 4),
          numericInput("min_test", "Min. test days", club$min_test %||% 750, step = 50),
          numericInput("min_train", "Min. train days", club$min_train %||% 1000, step = 50),
          numericInput("frac_test", "Test share (%)", 100 * (club$frac_test %||% 0.3), step = 5)
        )
      ),
      
      accordion_panel(
        "Load / save inputs", value = "laden",
        fileInput("upload", "Load inputs (.yml)", accept = c(".yml", ".yaml")),
        uiOutput("upload_kies"),
        helpText("Works with a file you saved here, and with config/club.yml itself."),
        downloadButton("yml", "Save inputs (.yml)", class = "btn-outline-secondary w-100")
      )
    ),
    
    input_task_button("run", "Run full model", label_busy = "Running the model…", class = "w-100"),
    downloadButton("pdf", "Download PDF report", class = "btn-outline-primary w-100"),
    tags$small(class = "text-muted", "Not investment advice. The engine is only as good as the numbers you put in.")
  ),
  
  uiOutput("vakken"),
  uiOutput("meldingen"),
  layout_columns(
    col_widths = c(6, 6),
    card(card_header("Live check · updates while you type"), tableOutput("live_tabel")),
    card(card_header("Club limits"), tableOutput("live_lim"))
  ),
  uiOutput("verouderd"),
  conditionalPanel(
    "!output.heeft_res",
    card(card_header("Full model"),
         p(class = "text-muted mb-0",
           "Fill in the three steps on the left, then click “Run full model”. ",
           "The charts and tables of the report appear here, and the PDF button starts working."))
  ),
  conditionalPanel(
    "output.heeft_res",
    navset_card_underline(
      id = "tabs", title = "Full model",
      nav_panel("History", uiOutput("hist_tekst"), plotOutput("p_koers", height = 330),
                plotOutput("p_dd", height = 230), tableOutput("t_episodes")),
      nav_panel("Monte Carlo", tableOutput("t_mc"), plotOutput("p_football", height = 190),
                plotOutput("p_paden", height = 300)),
      nav_panel("Daily risk", uiOutput("dag_tekst"), tableOutput("t_dag")),
      nav_panel("Backtest", uiOutput("bt_tekst"), tableOutput("t_bt")),
      nav_panel("Horizon risk", tableOutput("t_hor")),
      nav_panel("Compare", helpText("Every ETF you run in this session becomes a row here."),
                tableOutput("t_vgl"), downloadButton("vgl_csv", "Download comparison (.csv)"))
    )
  )
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
               min_test = "Min. test days", min_train = "Min. train days", frac_test = "Test share")
    nodig <- c(nodig, switch(input$type,
                             aandelen = c(top = "Biggest holding", pe0 = "P/E today", dy = "Dividend yield",
                                          setNames(paste("Growth", scenarios), paste0("g_", scenarios)),
                                          setNames(paste("P/E end", scenarios), paste0("peH_", scenarios))),
                             obligaties = c(ytm = "Yield", duration = "Duration", setNames(paste("Rate change", scenarios), paste0("dr_", scenarios))),
                             overig = setNames(paste("Return", scenarios), paste0("ov_", scenarios))))
    leeg <- names(nodig)[vapply(names(nodig), function(id) is.null(v(id)) || is.na(v(id)), logical(1))]
    if (length(leeg)) {
      fout <- c(fout, paste("Fill in every number field. Missing:", paste(nodig[leeg], collapse = ", ")))
      return(list(fout = fout, let = let))
    }
    
    if (!ticker_ok(ticker())) fout <- c(fout, "Ticker: use the Yahoo code, e.g. QDVE.DE (letters, digits, dots and dashes only).")
    if (!nzchar(schoon(input$naam))) fout <- c(fout, "Give the fund a name.")
    if (!identical(schoon(input$naam), trimws(input$naam))) let <- c(let, "Some special characters were removed from the fund name.")
    if (length(input$start) == 0 || is.na(input$start) || input$start > Sys.Date() - 30) {
      fout <- c(fout, "The price history must start at least a month ago.")
    } else if (input$start > Sys.Date() - 3 * 365) {
      let <- c(let, "Less than 3 years of prices: the backtest will probably be skipped.")
    }
    
    if (v("positie") <= 0) fout <- c(fout, "Position must be above 0.")
    if (v("ter") < 0 || v("ter") > 3) fout <- c(fout, "TER must be between 0% and 3%.")
    if (v("ter") > 0 && v("ter") < 0.01) let <- c(let, paste0("A TER of ", v("ter"), "% looks tiny. This field is in percent: type 0.15 for 0.15%."))
    if (v("ter") > 1) let <- c(let, "A TER above 1% is rare for an ETF. Check the factsheet.")
    if (v("drempel") <= 0 || v("drempel") >= 100) fout <- c(fout, "Drawdown threshold must be between 0% and 100%.")
    if (v("stappen") < 1 || v("stappen") > 365 || v("stappen") != round(v("stappen"))) fout <- c(fout, "Steps per year: a whole number between 1 and 365.")
    if (v("min_test") < 50 || v("min_train") < 50) fout <- c(fout, "Min. test and train days must be at least 50.")
    if (v("frac_test") <= 0 || v("frac_test") >= 90) fout <- c(fout, "Test share must be between 0% and 90%.")
    
    oplopend <- function(x) all(diff(x) >= 0)
    
    if (input$type == "aandelen") {
      g <- vapply(paste0("g_", scenarios), v, numeric(1))
      peH <- vapply(paste0("peH_", scenarios), v, numeric(1))
      if (v("top") < 0 || v("top") > 100) fout <- c(fout, "Biggest holding must be between 0% and 100%.")
      if (v("pe0") <= 0 || any(peH <= 0)) fout <- c(fout, "P/E values must be above 0.")
      if (v("dy") < 0 || v("dy") > 20) fout <- c(fout, "Dividend yield must be between 0% and 20%.")
      if (any(g < -50 | g > 100)) fout <- c(fout, "Profit growth must be between -50% and 100% a year.")
      if (v("dy") > 0 && v("dy") < 0.05) let <- c(let, "That dividend yield looks like a decimal. This field is in percent: type 0.6 for 0.6%.")
      if (all(abs(g) < 1) && any(g != 0)) let <- c(let, "Profit growth looks like decimals. These fields are in percent: type 12 for 12%.")
      if (!oplopend(g) || !oplopend(peH)) let <- c(let, "Bear should be the worst case and bull the best: check the order of growth and P/E.")
      if (v("pe0") > 0 && any(abs(peH / v("pe0") - 1) > 0.5)) let <- c(let, "A P/E after the horizon more than 50% away from today's is a big call. Is that on purpose?")
    }
    if (input$type == "obligaties") {
      dr <- vapply(paste0("dr_", scenarios), v, numeric(1))
      if (v("ytm") < -5 || v("ytm") > 30) fout <- c(fout, "Yield must be between -5% and 30%.")
      if (v("duration") < 0 || v("duration") > 40) fout <- c(fout, "Duration must be between 0 and 40 years.")
      if (any(abs(dr) > 10)) fout <- c(fout, "Rate changes must be between -10 and +10 %-points.")
      if (!oplopend(-dr)) let <- c(let, "Bear should have the biggest rate rise and bull the biggest fall.")
    }
    if (input$type == "overig") {
      ov <- vapply(paste0("ov_", scenarios), v, numeric(1))
      if (any(abs(ov) > 100)) fout <- c(fout, "Returns must be between -100% and 100% a year.")
      if (!oplopend(ov)) let <- c(let, "Bear should be the worst case and bull the best: check the order.")
    }
    list(fout = fout, let = let)
  })
  
  output$meldingen <- renderUI({
    p <- problemen()
    tagList(lapply(p$fout, function(m) div(class = "alert alert-danger py-2 mb-2", m)),
            lapply(p$let, function(m) div(class = "alert alert-warning py-2 mb-2", m)))
  })
  
  
  # ---- stap 1: ticker controleren ----
  
  koersdata <- reactiveVal(NULL)
  
  observeEvent(input$check, {
    if (!ticker_ok(ticker())) {
      showNotification("That is not a valid Yahoo ticker.", type = "error")
      return()
    }
    d <- withProgress(message = paste("Downloading prices for", ticker()), value = 0.5,
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
    if (!identical(d$ticker, ticker())) return(div(class = "small text-muted mt-2", "Ticker changed: click Check again."))
    w <- unname(ifelse(sub("^\\d+ ", "", d$checks$waarschuwing) %in% names(checks_en),
                       checks_en[sub("^\\d+ ", "", d$checks$waarschuwing)], d$checks$waarschuwing))
    div(class = "small mt-2",
        div(class = "text-success fw-bold", "✓ ", d$ticker, " works"),
        div(d$valuta, " · last price ", formatC(d$koers_lokaal, format = "f", digits = 2), " ", d$valuta,
            " · ", format(d$checks$n, big.mark = ","), " days since ", d$checks$start),
        if (length(w)) div(class = "text-warning-emphasis", "Data checks: ", paste(w, collapse = "; ")))
  })
  
  output$mini <- renderPlot({
    d <- koersdata()
    req(d, identical(d$ticker, ticker()))
    ggplot(data.frame(datum = index(d$px), p = as.numeric(d$px)), aes(datum, p)) +
      geom_line(linewidth = 0.3, colour = "#0B3D91") +
      labs(x = NULL, y = "EUR") +
      theme_minimal(base_size = 9)
  })
  
  observeEvent(input$type, {
    if (input$type == "obligaties") updateSelectInput(session, "sector", selected = "obligaties")
    if (input$type == "overig" && input$sector %in% c("obligaties", "technologie")) updateSelectInput(session, "sector", selected = "grondstoffen")
  }, ignoreInit = TRUE)
  
  
  # ---- live check: goedkope berekeningen ----
  
  live <- reactive({
    req(length(problemen()$fout) == 0)
    c0 <- cfg()
    list(rs = verwacht_rendement(c0),
         be8 = if (c0$type == "aandelen") breakeven_groei(c0, 0.08) else NA,
         lim = limieten_check(c0, c0$positie),
         lim30 = limieten_check(c0, 0.30 * c0$portefeuille))
  })
  
  output$vakken <- renderUI({
    l <- live()
    n <- sum(!is.na(l$lim$ok))
    n_ok <- sum(l$lim$ok, na.rm = TRUE)
    layout_columns(
      fill = FALSE,
      value_box("Expected return, base", pct(l$rs[["base"]]), paste("per year over", jaren(H))),
      value_box("Growth needed for 8% a year", pct(l$be8),
                if (is.na(l$be8)) "equity funds only" else "profit growth the companies must deliver"),
      value_box("Club limits", paste(n_ok, "of", n, "OK"),
                if (n_ok == n) "all rules respected at this position" else "a rule is broken: see Club limits",
                theme = if (n_ok == n) "success" else "danger")
    )
  })
  
  output$live_tabel <- renderTable({
    l <- live()
    c0 <- cfg()
    d <- data.frame(Scenario = c("Bear", "Base", "Bull"))
    if (c0$type == "aandelen") {
      d$`Growth / year` <- pct(vapply(c0$waardering$scenarios, `[[`, numeric(1), "g"))
      d[[paste("P/E after", jaren(H))]] <- vapply(c0$waardering$scenarios, `[[`, numeric(1), "peH")
    }
    if (c0$type == "obligaties") {
      dr <- vapply(c0$obligaties$scenarios, `[[`, numeric(1), "dy")
      d$`Rate change` <- paste(formatC(100 * dr, format = "f", digits = 2, flag = "+"), "%-pts")
    }
    d$`Expected return / year` <- pct(l$rs[scenarios])
    d
  }, striped = TRUE, width = "100%", align = "l")
  
  lim_tabel <- function(lim, lim30) {
    teken <- function(ok) ifelse(is.na(ok), "–", ifelse(ok, "✓", "✗"))
    data.frame(Rule = unname(regels[lim$regel]),
               Limit = paste(ifelse(lim$soort == "max", "max", "min"), pct(lim$grens, 0)),
               `Your position` = paste(pct(lim$waarde), teken(lim$ok)),
               `At 30% weight` = paste(pct(lim30$waarde), teken(lim30$ok)),
               check.names = FALSE)
  }
  
  output$live_lim <- renderTable({
    l <- live()
    lim_tabel(l$lim, l$lim30)
  }, striped = TRUE, width = "100%", align = "l")
  
  
  # ---- volledig model: dure berekeningen, enkel op de knop ----
  
  res <- reactiveVal(NULL)
  res_blok <- reactiveVal(NULL)
  runs <- reactiveVal(list())
  
  observeEvent(input$run, {
    p <- problemen()
    if (length(p$fout)) {
      showNotification("Fix the red messages first.", type = "error")
      return()
    }
    b <- blok()
    c0 <- cfg()
    out <- withProgress(message = "Running the model", value = 0, {
      tryCatch({
        incProgress(0.2, detail = "prices")
        load_etf(c0$ticker, from = c0$start)
        incProgress(0.3, detail = "Monte Carlo, Student-t fit and backtest")
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
    r <- runs()
    r[[c0$ticker]] <- out
    runs(r)
  })
  
  output$heeft_res <- reactive(!is.null(res()))
  outputOptions(output, "heeft_res", suspendWhenHidden = FALSE)
  
  output$verouderd <- renderUI({
    req(res_blok())
    if (!identical(res_blok(), blok())) {
      div(class = "alert alert-info py-2",
          paste0("You changed inputs since the last run. The tabs below and the PDF still show the run for ",
                 res()$cfg$ticker, ". Click “Run full model” to update them."))
    }
  })
  
  output$hist_tekst <- renderUI({
    nog_niet(res())
    h <- res()$hist
    p(tags$b(res()$cfg$ticker),
      paste0(": grew ", pct(h$cagr), " a year since ", format(start(res()$data$px), "%Y"),
             ", volatility ", pct(h$vol), ", worst fall ", pct(h$maxdd), "."))
  })
  
  output$p_koers <- renderPlot({
    nog_niet(res())
    print(plot_koers(res()$data$px))
  })
  
  output$p_dd <- renderPlot({
    nog_niet(res())
    plot_drawdown(res()$data$px, res()$cfg$drempel %||% 0.15)
  })
  
  output$t_episodes <- renderTable({
    nog_niet(res())
    ep <- res()$hist$episodes
    validate(need(nrow(ep) > 0, paste0("No fall of ", pct(res()$cfg$drempel, 0), " or more.")))
    data.frame(Peak = maand(as.Date(ep$top)), Bottom = maand(as.Date(ep$bodem)), Fall = pct(ep$daling),
               `Back at the peak` = maand(as.Date(ep$herstel)), check.names = FALSE)
  }, striped = TRUE, align = "l")
  
  output$t_mc <- renderTable({
    nog_niet(res())
    mc <- res()$mc
    validate(need(mc, "No scenarios for this fund, so no simulation."))
    data.frame(Scenario = c("Bear", "Base", "Bull"), `Return / year` = pct(res()$rs[scenarios]),
               P10 = eur(mc[scenarios, "p10"]), P50 = eur(mc[scenarios, "p50"]), P90 = eur(mc[scenarios, "p90"]),
               `Chance of a loss` = pct(mc[scenarios, "verlies"], 0), check.names = FALSE)
  }, striped = TRUE, width = "100%", align = "l")
  
  output$p_football <- renderPlot({
    nog_niet(res())
    req(res()$mc)
    plot_football(res()$mc, res()$cfg$positie)
  })
  
  output$p_paden <- renderPlot({
    nog_niet(res())
    req(res()$mc)
    c0 <- res()$cfg
    set.seed(42)
    plot_paden(res()$rs, res()$hist$vol, c0$positie, c0$horizon, stappen = c0$stappen %||% 52)
  })
  
  output$dag_tekst <- renderUI({
    nog_niet(res())
    f <- res()$fit
    p(paste0("Loss on one bad day for a position of ", eur(res()$cfg$positie), ", fitted on the training data. ",
             "The Student-t has ", formatC(f[["df"]], format = "f", digits = 1), " degrees of freedom: ",
             if (f[["aic_t"]] < f[["aic_n"]]) "it fits better than the normal (lower AIC)." else "the normal fits as well (AIC)."))
  })
  
  output$t_dag <- renderTable({
    nog_niet(res())
    r95 <- res()$r95
    r99 <- res()$r99
    k <- function(x) paste0(pct(x, 2), " (", eur(res()$cfg$positie * x), ")")
    data.frame(Model = unname(modellen[rownames(r95)]), `VaR 95%` = k(r95[, "VaR"]), `ES 95%` = k(r95[, "ES"]),
               `VaR 99%` = k(r99[, "VaR"]), `ES 99%` = k(r99[, "ES"]), check.names = FALSE)
  }, striped = TRUE, width = "100%", align = "l")
  
  output$bt_tekst <- renderUI({
    nog_niet(res())
    sp <- res()$split
    if (!sp$ok) return(p(class = "text-warning-emphasis", "No backtest: ", sp$reden, "."))
    p(paste0("Trained on data before ", format(sp$start_test, "%d %b %Y"), ", tested on the ",
             format(length(sp$test), big.mark = ","),
             " days after. A model holds up when neither test rejects it (p > 0.05)."))
  })
  
  output$t_bt <- renderTable({
    nog_niet(res())
    bt <- res()$bt
    req(bt)
    data.frame(Level = pct(bt$alpha, 0), Model = unname(modellen[bt$model]), `Days over VaR` = as.integer(bt$x),
               Expected = formatC(bt$verwacht, format = "f", digits = 1),
               `Kupiec p` = formatC(bt$p_kupiec, format = "f", digits = 3),
               `Independence p` = formatC(bt$p_indep, format = "f", digits = 3),
               `ES ratio` = ifelse(is.na(bt$es_ratio), "–", formatC(bt$es_ratio, format = "f", digits = 2)),
               Verdict = ifelse(bt$p_kupiec > 0.05 & bt$p_indep > 0.05, "✓ holds", "✗ rejected"),
               check.names = FALSE)
  }, striped = TRUE, width = "100%", align = "l")
  
  output$t_hor <- renderTable({
    nog_niet(res())
    x <- res()
    pos <- x$cfg$positie
    data.frame(Horizon = c("1 year", jaren(x$cfg$horizon)),
               `VaR 95%` = c(pct(x$es1[["VaR"]]), pct(x$esH[["VaR"]])),
               `ES 95%` = c(pct(x$es1[["ES"]]), pct(x$esH[["ES"]])),
               `ES 95% in EUR` = c(eur(pos * x$es1[["ES"]]), eur(pos * x$esH[["ES"]])),
               check.names = FALSE)
  }, striped = TRUE, width = "100%", align = "l")
  
  vgl <- reactive({
    validate(need(length(runs()), "Run at least one ETF."))
    do.call(rbind, lapply(runs(), vergelijk_rij))
  })
  
  output$t_vgl <- renderTable({
    v <- vgl()
    data.frame(Ticker = v$ticker, Type = names(types)[match(v$type, types)],
               `Return / year, past` = pct(v$cagr), Volatility = pct(v$vol),
               `Worst fall` = pct(v$maxdd), `Expected, base` = pct(v$base),
               `Chance of loss after horizon` = pct(v$verlies_H, 0), `P10 after horizon` = eur(v$p10_H),
               `ES over horizon` = pct(v$esH), check.names = FALSE)
  }, striped = TRUE, width = "100%", align = "l")
  
  
  # ---- downloads ----
  
  output$pdf <- downloadHandler(
    filename = function() paste0(gsub("[^A-Za-z0-9]", "_", res()$cfg$ticker %||% "etf"), ".pdf"),
    content = function(file) {
      if (is.null(res())) {
        showNotification("Run the full model first.", type = "error")
        stop("Run the full model first.")
      }
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
  
  output$vgl_csv <- downloadHandler(
    filename = function() "vergelijking.csv",
    content = function(file) write.csv(vgl(), file, row.names = FALSE)
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
    showNotification(paste("Loaded", tk, "— check the fields, then click Check ticker."), type = "message")
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
            actionButton("kies_ok", "Load this ETF", class = "btn-outline-primary w-100 mb-2"))
  })
  
  observeEvent(input$kies_ok, {
    i <- as.integer(input$kies_etf)
    req(geladen(), i >= 1, i <= length(geladen()$etfs))
    tryCatch(vul_in(geladen(), i), error = function(e) showNotification("Some fields could not be read.", type = "warning"))
  })
}

shinyApp(ui, server)