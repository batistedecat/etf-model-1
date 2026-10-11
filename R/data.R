lees_config <- function(pad = "config/etfs.yml") {
  cfg <- yaml::read_yaml(pad)
  lapply(cfg$etfs, function(e) modifyList(cfg$algemeen, e))
}

load_etf <- function(ticker, from = "2010-01-01") {
  #GET DATA via yahoo finance via quantmod, 
  #adjusted prices om rekening te houden met corporate actions (dividends, splits, ..)
  #lege dagen eruit smijten
  raw <- getSymbols(ticker, from = from, auto.assign = FALSE)
  px <- na.omit(Ad(raw))
  
  #laatste koers en de munt waarin die genotteerd staat
  #yahoo quote format
  q <- getQuote(ticker, what = yahooQF(c("Last Trade (Price Only)", "Currency")))
  valuta <- q$Currency
  koers <- as.numeric(q$Last)
  
  #START DATA CLEANING
  #yahoo finance: london notteert soms in pence, fixen door deling door 100
  if (valuta == "GBp") { 
    px <- px / 100
    koers <- koers / 100
    valuta <- "GBP"
  }
  
  #koers in eigen munt bijhouden voort omrekenen
  koers_lokaal <- koers
  
  #niet in euro, dan via wisselkoers omrekenen
  if (valuta != "EUR") {
    fx <- na.omit(Ad(getSymbols(paste0("EUR", valuta, "=X"), from = from, auto.assign = FALSE))) #bvb: "EURUSD=X" wordt opgehaald
    m <- merge(px, fx, join = "left")
    m[,2] <- na.locf(m[,2], na.rm = FALSE) #last observation carried forward = locf
    m <- na.omit(m)
    px <- m[,1] / m[,2]
    koers <- koers / as.numeric(last(fx))
  }
  
  # log-returns gebruiken , eerste NA onnuttig
  colnames(px) <- "eur"
  r <- diff(log(px))[-1]
  
  # checks: lengte, startdatum, hoeveel dagen niks bewoog, grootste sprong, grootste gat
  checks <- list(n = nrow(px), start = format(start(px)), nul = mean(as.numeric(r) == 0),
                 max_sprong = max(abs(as.numeric(r))), max_gat = max(as.numeric(diff(index(px)))))
  
  #verdachte gegevens flaggen (soms klopt yahoo finance niet)
  # alleen de waarschuwingen die echt kloppen blijven over (if zonder else geeft NULL, c() laat dat vallen)
  checks$waarschuwing <- c(if (checks$n < 1000) "korte historiek",
                           if (checks$nul > 0.05) "veel nulrendementen",
                           if (checks$max_sprong > 0.25) "sprong groter dan 25%",
                           if (checks$max_gat > 7) "gat groter dan 7 dagen")
  #geeft 1 lijst terug
  list(ticker = ticker, valuta = valuta, px = px, r = r, koers = koers, koers_lokaal = koers_lokaal, checks = checks)
}





