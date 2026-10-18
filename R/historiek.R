#achteruit kijken: antwoord op : wat is er al gebeurd????

drawdowns <- function(px, drempel = 0.15) {
  x <- as.numeric(px)
  d <- index(px)
  
  #drawdown is hoeveel% onder de hoogste koers tot nu toe
  # ik doe min 1 om het maximum op 0 te zetten
  dd <- x / cummax(x) - 1 
  # episodes verzamelen in een lijst, i loopt over de dagen
  out <- list()
  i <- 1
  n <- length(x)
  
  while (i <= n) {
    if (dd[i] < 0) {
      
      # begin van een daling: loop door tot wnr we weer op een top zitten (dd = 0) of wnr de data stopt
      j <- i
      while (j <= n && dd[j] < 0) j <- j + 1
      seg <- i:(j - 1)
      
      # dieptepunt van deze episode
      b <- seg[which.min(dd[seg])]
      
      # alleen bijhouden als de daling minstens de drempel is (standaard 15%)
      if (-dd[b] >= drempel) {
        out[[length(out) + 1]] <- data.frame(
          top = d[i - 1],                          # laatste dag op de top, net voor de daling
          bodem = d[b],                            # dag van het dieptepunt
          daling = dd[b],                          # grootte van de daling (negatief)
          herstel = if (j <= n) d[j] else NA       # eerste dag terug op de top, NA als nog niet hersteld
        )
      }
      
      # verder zoeken na deze episode
      i <- j
    } else {
      i <- i + 1
    }
  }
  
  # alle episodes onder elkaar in één tabel, of een lege tabel als er geen zijn
  if (length(out)) do.call(rbind, out) else data.frame()
}

historiek <- function(px, drempel = 0.15) {
  
  # koersen als getallen, lengte vd reeks in jaren
  x <- as.numeric(px)
  jaren <- as.numeric(end(px) - start(px)) / 365.25
  
  # dagelijkse log-returns, eerste NA weg
  r <- diff(log(px))[-1]
  
  # rendement per kalenderjaar: slotkoers van elk jaar delen door die van het jaar ervoor
  per_jaar <- split(px, "years")
  slot <- sapply(per_jaar, function(s) as.numeric(last(s)))
  kalender <- c(NA, slot[-1] / slot[-length(slot)] - 1)
  
  # jaartal als naam; binnen de functie, want sapply verliest anders de datumklasse
  names(kalender) <- sapply(per_jaar, function(s) format(end(s), "%Y"))
  
  list(
    cagr = (x[length(x)] / x[1])^(1 / jaren) - 1,   ##gemiddeld jaarrendement (samengesteld)
    vol = sd(as.numeric(r)) * sqrt(252),            # dagvolatiliteit naar jaarbasis, 252 beursdagen
    maxdd = min(x / cummax(x) - 1),                 # grootste daling ooit (negatief)
    kalender = kalender,                            # rendement per kalenderjaar, eerste jaar NA
    episodes = drawdowns(px, drempel)             # tabel met alle dalingen van minstens 15% of gegeven drempel
  )
}

plot_koers <- function(px) {
  
  # daily log-returns, eerste NA moet weg
  r <- diff(log(px))[-1]
  
  # bovenste paneel: koers in euro
  p <- plot(px, main = "Price (EUR)", lwd = 1.5)
  
  # onderste paneel: on = NA maakt een nieuw paneel,
  p <- lines(r, on = NA, main = "Daily log-return", lwd = 0.6)
  
  # return plot object,zou moeten getekent worden bij het knitten vd markdown sebiet
  p
}

plot_drawdown <- function(px, drempel = 0.15) {
  
  # drawdown in procent: 0 op een top, negatief eronder
  x <- as.numeric(px)
  df <- data.frame(datum = index(px), dd = 100 * (x / cummax(x) - 1))
  
  ggplot(df, aes(datum, dd)) +
    geom_area(fill = "grey75") +                                   # grijze vlakte = hoe diep onder water
    geom_line(linewidth = 0.3) +                                   # dunne lijn erover voor de rand
    geom_hline(yintercept = -100 * drempel, linetype = "dashed",
               colour = "firebrick", linewidth = 0.4) +            # drempel: alles eronder telt als episode
    annotate("text", x = min(df$datum), y = -100 * drempel,
             label = paste0("threshold -", 100 * drempel, "%"),
             hjust = 0, vjust = -0.5, size = 3, colour = "firebrick") +   # label links boven de lijn
    labs(x = NULL, y = "Drawdown (%)", title = "Fall from the previous peak") +
    theme_minimal(base_size = 10)
}