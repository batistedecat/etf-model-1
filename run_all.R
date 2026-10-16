# alle ETF's uit één config in één keer

source("laden.R")

# welke config? club of testbank
config <- "config/club.yml"
cfgs <- lees_config(config)

# elke ETF apart, één kapotte = melden en doorgaan
res <- lapply(cfgs, function(cfg) {
  tryCatch(run_etf(cfg), error = function(e) {
    message(cfg$ticker, ": ", conditionMessage(e))
    NULL
  })
})
names(res) <- sapply(cfgs, `[[`, "ticker")
res <- Filter(Negate(is.null), res)   # mislukte eruit

# één rij per ETF
rij <- function(x) {
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

# alles onder elkaar, opslaan, tonen
tab <- do.call(rbind, lapply(res, rij))
dir.create("out", showWarnings = FALSE)
write.csv(tab, "out/vergelijking.csv", row.names = FALSE)
print(tab, row.names = FALSE)


# per ETF een PDF in out/
for (t in names(res)) {
  e <- new.env()
  e$res <- res[[t]]   # resultaat meegeven, niet opnieuw rekenen
  rmarkdown::render("rapport.Rmd", params = list(ticker = t, config = config), envir = e, quiet = TRUE,
                    output_file = paste0(gsub("[^A-Za-z0-9]", "_", t), ".pdf"), output_dir = "out")
}