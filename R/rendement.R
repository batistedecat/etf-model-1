#mn aannames uit de config naar één getal per scenario, het verwachte rendement per jaar over je horizon.

verwacht_rendement <- function(cfg) {
  
  # horizon in jaren
  H <- cfg$horizon
  
  if (cfg$type == "aandelen" && !is.null(cfg$waardering)) {
    
    # Grinold-Kroner:=>>> groei × P/E-effect + dividend - kosten
    w <- cfg$waardering
    sapply(w$scenarios, function(s) (1 + s$g) * (s$peH / w$pe0)^(1 / H) + w$dy - cfg$ter - 1)
    
  } else if (cfg$type == "obligaties" && !is.null(cfg$obligaties)) {
    
    # duration:=>>> yield - kosten + renteschok × (H - D) / H
    o <- cfg$obligaties
    sapply(o$scenarios, function(s) o$ytm - cfg$ter + s$dy * (H - o$duration) / H)
    
  } else if (cfg$type == "overig" && !is.null(cfg$overig)) {
    
    # vaste scenario's uit config
    unlist(cfg$overig$scenarios)
    
  } else {
    
    #geen waardering zoals goud -> want pure speculatie
    NULL
  }
}

breakeven_groei <- function(cfg, doel = 0, peH = cfg$waardering$scenarios$base$peH) {
  
  #enkel aandelen
  w <- cfg$waardering
  if (is.null(w)) return(NA)
  
  # Grinold-Kroner opgelost naar g
  (1 + doel - w$dy + cfg$ter) / (peH / w$pe0)^(1 / cfg$horizon) - 1
}