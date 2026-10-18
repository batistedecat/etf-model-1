#!!! doel: Ik wil de KANS OP VERLIES berekenen

#welke info wil ik gebruiken:
# mu <- verwacht_rendement()
# sigma <- historiek$vol
# voor monte carlo trekking Z <- rnorm()
### verklaring voor Z: zie formule geometric brownian motion

#to do: maak een tabel met info-titels: etf, rendement,  vol, verlies, p10,  p50
#source("laden.R")
#cfg <- lees_config("config/club.yml")[[1]]
#d   <- load_etf(cfg$ticker)
#h   <- historiek(d$px)
#rs  <- verwacht_rendement(cfg)


simulate_gbm <- function(x0, mu, sigma, jaren, n, stappen = 52) {
  
  #stapgrootte (in jaar) en aantal stappen
  dt <- 1 / stappen
  k <- jaren * stappen
  # toeval
  Z <- matrix(rnorm(n * k), nrow = n)
  
  # log-returns per stap: drift - volatility drag + schok
  inc <- (mu - sigma^2 / 2) * dt + sigma * sqrt(dt) * Z
  #terug naar koers, returns cummuleren exponentieel
  x0 * exp(matrix(t(apply(inc, 1, cumsum)), nrow = n))
}

mc_etf <- function(rs, sigma, positie, jaren, n = 10000, stappen = 52) {
  
  # per scenario: simuleren, eindwaarden samenvatten
  out <- t(sapply(rs, function(r) {
    
    # drift = ln(1 + r), eindwaarde = laatste kolom
    x <- simulate_gbm(positie, log(1 + r), sigma, jaren, n, stappen)
    e <- x[, ncol(x)]
    
    c(p10 = quantile(e, 0.1, names = FALSE),   #slecht geval
      p50 = median(e),                         #typisch pad
      p90 = quantile(e, 0.9, names = FALSE),   # goed geval
      verlies = mean(e < positie),             # kans op verlies
      gem = mean(e))                           #gemiddelde
  }))
  
  # horizon meegeven voor de plot
  attr(out, "jaren") <- jaren
  out
}

plot_football <- function(mc, positie) {
  
  # één rij per scenario, bear onderaan
  d <- data.frame(scenario = factor(rownames(mc), levels = rownames(mc)),
                  p10 = mc[, "p10"], p50 = mc[, "p50"], p90 = mc[, "p90"])
  
  # aslabel met horizon (uit attr van mc_etf)
  jaren <- attr(mc, "jaren")
  as_y <- if (is.null(jaren)) "Value (EUR)" else paste0("Value after ", jaren, " years (EUR)")
  
  ggplot(d) +
    geom_linerange(aes(x = scenario, ymin = p10, ymax = p90),
                   linewidth = 8, colour = "grey60") +             # balk P10-P90
    geom_point(aes(scenario, p50), size = 2.5) +                   # mediaan
    geom_hline(yintercept = positie, linetype = "dashed") +        # inleg
    coord_flip() +                                                 # liggende balken
    labs(x = NULL, y = as_y, title = "P10 to P90 per scenario, dot = median, dashed = amount invested") +
    theme_minimal(base_size = 10)
}

plot_paden <- function(rs, sigma, positie, jaren, n_toon = 50, n = 10000, stappen = 52) {
  
  # per scenario: paden + band, alles in één data.frame
  delen <- lapply(names(rs), function(sc) {
    
    # simuleren, startwaarde als kolom 0 erbij
    x <- cbind(positie, simulate_gbm(positie, log(1 + rs[[sc]]), sigma, jaren, n, stappen))
    tijd <- seq(0, jaren, length.out = ncol(x))
    
    # P10 / P50 / P90 per tijdstip
    q <- apply(x, 2, quantile, c(0.1, 0.5, 0.9))
    
    # steekproef van paden om te tekenen
    kies <- sample(n, n_toon)
    
    list(band = data.frame(scenario = sc, tijd = tijd, p10 = q[1, ], p50 = q[2, ], p90 = q[3, ]),
         paden = data.frame(scenario = sc, tijd = rep(tijd, each = n_toon),
                            waarde = as.vector(x[kies, ]), pad = rep(seq_len(n_toon), times = ncol(x))))
  })
  
  # samenvoegen, volgorde bear - base - bull
  band  <- do.call(rbind, lapply(delen, `[[`, "band"))
  paden <- do.call(rbind, lapply(delen, `[[`, "paden"))
  band$scenario  <- factor(band$scenario,  levels = names(rs))
  paden$scenario <- factor(paden$scenario, levels = names(rs))
  
  # eindwaarden per scenario voor de labels
  eind <- band[band$tijd == jaren, ]
  lab <- data.frame(scenario = rep(eind$scenario, 3),
                    y = c(eind$p90, eind$p50, eind$p10),
                    tekst = paste0(rep(c("P90 ", "P50 ", "P10 "), each = nrow(eind)),
                                   round(c(eind$p90, eind$p50, eind$p10))))
  
  ggplot() +
    geom_line(data = paden, aes(tijd, waarde, group = pad),
              colour = "grey55", alpha = 0.25, linewidth = 0.2) +          # individuele paden
    geom_ribbon(data = band, aes(tijd, ymin = p10, ymax = p90),
                fill = "#2A78D6", alpha = 0.15) +                           # band P10-P90
    geom_line(data = band, aes(tijd, p10), colour = "#2A78D6", linewidth = 0.4) +
    geom_line(data = band, aes(tijd, p90), colour = "#2A78D6", linewidth = 0.4) +
    geom_line(data = band, aes(tijd, p50), colour = "#0B3D91", linewidth = 0.8) +   # mediaan
    annotate("segment", x = 0, xend = jaren, y = positie, yend = positie,
             linetype = "dashed") +                                         # inleg (stopt voor de labels)
    geom_text(data = lab, aes(jaren, y, label = tekst), hjust = -0.1, size = 2.8) + # eindwaarden
    facet_wrap(~ scenario, nrow = 1) +                                      # naast elkaar, zelfde y-as
    scale_x_continuous(expand = expansion(mult = c(0.01, 0.35))) +          # ruimte voor labels
    labs(x = "Years", y = "Value (EUR)",
         title = paste0(n_toon, " of ", n, " paths per scenario, band = P10-P90, dashed = amount invested")) +
    theme_minimal(base_size = 10) +
    theme(strip.text = element_text(face = "bold", size = 10))             # scenarionaam vet
}