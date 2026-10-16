#alles samen
#één ETF van config tot resultaat

limieten_check <- function(cfg, positie) {
  
  # gewicht in portefeuille
  w <- positie / cfg$portefeuille
  
  # sector: niet bij gespreid/obligaties; emittent: doorkijk
  sector <- if (cfg$sector %in% c("gespreid", "obligaties")) NA else w
  emittent <- if (is.null(cfg$top_positie)) NA else w * cfg$top_positie
  cash <- (cfg$cash - positie) / cfg$portefeuille
  
  # clubregels: 30% ETF, 40% sector, 20% emittent, min 5% cash
  out <- data.frame(regel = c("per ETF", "per sector", "per emittent (doorkijk)", "cash na aankoop"),
                    waarde = c(w, sector, emittent, cash),
                    grens = c(0.30, 0.40, 0.20, 0.05),
                    soort = c("max", "max", "max", "min"))
  out$ok <- ifelse(out$soort == "max", out$waarde <= out$grens, out$waarde >= out$grens)
  out
}

run_etf <- function(cfg, seed = 42) {
  
  #zelfde toeval elke run
  set.seed(seed)
  
  #dag 2-5
  d  <- load_etf(cfg$ticker, from = cfg$start %||% "2010-01-01")
  h  <- historiek(d$px, cfg$drempel %||% 0.15)
  rs <- verwacht_rendement(cfg)
  mc <- if (is.null(rs)) NULL else mc_etf(rs, h$vol, cfg$positie, cfg$horizon, stappen = cfg$stappen %||% 52)
  
  #dag 6: split, t-fit op training
  sp <- auto_split(d$r, cfg$min_test, cfg$min_train, cfg$frac_test)
  L_train <- -as.numeric(sp$train)
  ft <- fit_t(L_train)
  
  #dag 7: backtest, hertrainen op alles
  bt <- if (sp$ok) backtest(L_train, -as.numeric(sp$test), ft, cfg$centrum) else NULL
  ft_alle <- fit_t(-as.numeric(d$r))
  
  #verlies per euro: 1 jaar en horizon
  set.seed(7)
  h1 <- horizon_risk(1, ft_alle[["s"]], ft_alle[["df"]], 1)
  hH <- horizon_risk(1, ft_alle[["s"]], ft_alle[["df"]], cfg$horizon)
  
  list(cfg = cfg, data = d, hist = h, rs = rs, mc = mc, split = sp,
       norm = normaliteit(sp$train), fit = ft,
       r95 = risk_3ways(L_train, 0.95, ft, cfg$centrum),
       r99 = risk_3ways(L_train, 0.99, ft, cfg$centrum),
       bt = bt, fit_full = ft_alle,
       es1 = var_es(h1), esH = var_es(hH),
       be8 = breakeven_groei(cfg, 0.08),
       limieten = limieten_check(cfg, cfg$positie),
       limieten30 = limieten_check(cfg, 0.30 * cfg$portefeuille))
}