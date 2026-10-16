lees_config <- function(pad = "config/etfs.yml") {
  cfg <- yaml::read_yaml(pad)
  lapply(cfg$etfs, function(e) modifyList(cfg$algemeen, e))
}

haal <- function(f, pogingen = 3) {
  
  # yahoo doet soms moeilijk: 3x proberen
  for (i in seq_len(pogingen)) {
    x <- tryCatch(suppressWarnings(f()), error = function(e) NULL)
    if (!is.null(x)) return(x)
    Sys.sleep(2 * i)   # even wachten, elke keer langer
  }
  NULL
}

verwijder_pieken <- function(px, venster = 21, drempel = 0.3) {
  
  # koers vs mediaan van de 21 dagen rond
  lp <- log(as.numeric(px))
  med <- zoo::rollapply(lp, venster, median, partial = TRUE, align = "center")
  weg <- abs(lp - med) > drempel   # >30% ernaast = datafout
  
  # eruit smijten, tellen hoeveel
  out <- px[!weg]
  attr(out, "pieken") <- sum(weg)
  out
}

load_etf <- function(ticker, from = "2010-01-01", cache = "data") {
  
  # vandaag al gehaald? dan uit cache
  pad <- file.path(cache, paste0(gsub("[^A-Za-z0-9]", "_", ticker), "_", Sys.Date(), ".rds"))
  if (file.exists(pad)) return(readRDS(pad))
  
  # koersen halen, adjusted, lege dagen + pieken eruit
  raw <- haal(function() getSymbols(ticker, from = from, auto.assign = FALSE))
  if (is.null(raw)) stop("Geen koersen voor ", ticker)
  px <- verwijder_pieken(na.omit(Ad(raw)))
  pieken <- attr(px, "pieken")
  
  # laatste koers + munt
  q <- haal(function() getQuote(ticker, what = yahooQF(c("Last Trade (Price Only)", "Currency"))))
  if (is.null(q)) stop("Geen quote voor ", ticker)
  valuta <- q$Currency
  koers <- as.numeric(q$Last)
  
  # londen in pence -> pond
  if (valuta == "GBp") {
    px <- px / 100
    koers <- koers / 100
    valuta <- "GBP"
  }
  
  # koers in eigen munt bijhouden
  koers_lokaal <- koers
  
  # geen euro? omrekenen via wisselkoers
  if (valuta != "EUR") {
    fx <- haal(function() getSymbols(paste0("EUR", valuta, "=X"), from = from, auto.assign = FALSE))
    if (is.null(fx)) stop("Geen wisselkoers voor ", valuta)
    fx <- na.omit(Ad(fx))
    m <- merge(px, fx, join = "left")
    m[, 2] <- na.locf(m[, 2], na.rm = FALSE)   # gat? koers vd dag ervoor
    m <- na.omit(m)
    px <- m[, 1] / m[, 2]
    koers <- koers / as.numeric(last(fx))
  }
  
  # log-returns, eerste NA weg
  colnames(px) <- "eur"
  r <- diff(log(px))[-1]
  
  # checks
  checks <- list(pieken = pieken, n = nrow(px), start = format(start(px)), nul = mean(as.numeric(r) == 0),
                 max_sprong = max(abs(as.numeric(r))), max_gat = max(as.numeric(diff(index(px)))))
  
  # rare dingen flaggen
  checks$waarschuwing <- c(if (checks$n < 1000) "korte historiek",
                           if (checks$nul > 0.05) "veel nulrendementen",
                           if (checks$max_sprong > 0.25) "sprong groter dan 25%",
                           if (checks$max_gat > 7) "gat groter dan 7 dagen",
                           if (pieken > 0) paste(pieken, "pieken verwijderd"))
  
  # opslaan in cache en teruggeven
  out <- list(ticker = ticker, valuta = valuta, px = px, r = r, koers = koers, koers_lokaal = koers_lokaal, checks = checks)
  dir.create(cache, showWarnings = FALSE)
  saveRDS(out, pad)
  out
}
