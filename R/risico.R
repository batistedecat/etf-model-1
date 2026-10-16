#vooruit kijken op korte termijn: 
#hoeveel kan ik op één dag verliezen, en klopt dat?

auto_split <- function(r, min_test = 750, min_train = 1000, frac_test = 0.3) {
  
  #jaren van recent naar oud
  n <- length(r)
  jaren <- rev(unique(as.integer(substr(as.character(index(r)), 1, 4))))
  
  for (jaar in jaren) {
    #test vanaf 1 januari van dit! jaar
    s <- as.Date(paste0(jaar, "-01-01"))
    n_test <- sum(index(r) >= s)
    #eerste jaar met genoeg testdagen
    if (n_test >= max(min_test, frac_test * n)) {
      #genoeg training over?
      if (n - n_test >= min_train) {
        return(list(ok = TRUE, start_test = s, train = r[index(r) < s], test = r[index(r) >= s]))
      }
      return(list(ok = FALSE, reden = paste0("training te kort (", n - n_test, " dagen)"), train = r, test = NULL))
    }
  }
  list(ok = FALSE, reden = "te weinig data", train = r, test = NULL) #niet genoeg data
}

normaliteit <- function(r) {
  # scheefheid, kurtosis, Jarque-Bera op dag+ week+ maand
  z <- as.numeric(r)
  c(skew = mean((z - mean(z))^3) / sd(z)^3,
    kurt = mean((z - mean(z))^4) / sd(z)^4,
    jb_dag = tseries::jarque.bera.test(z)$p.value,
    jb_week = tseries::jarque.bera.test(as.numeric(apply.weekly(r, sum)))$p.value,
    jb_maand = tseries::jarque.bera.test(as.numeric(apply.monthly(r, sum)))$p.value)
}

fit_t <- function(L, schaal = 100) {
  
  # fit op 100 × L, anders convergeerde fitdistr slecht
  f <- suppressWarnings(MASS::fitdistr(schaal * L, "t"))
  est <- f$estimate
  
  # terugschalen
  est[c("m", "s")] <- est[c("m", "s")] / schaal
  
  # AIC: t (3 parameters, loglik gecorrigeerd) vs normaal (2 pars)
  c(est,
    aic_t = -2 * (f$loglik + length(L) * log(schaal)) + 6,
    aic_n = -2 * sum(dnorm(L, mean(L), sd(L), log = TRUE)) + 4)
}

risk_3ways <- function(L, alpha, ft, centrum = "nul") {
  
  # centrum: nul of geschat: zie config file
  m <- if (centrum == "nul") 0 else ft[["m"]]
  mu <- if (centrum == "nul") 0 else mean(L)
  
  # t-parameters
  s <- ft[["s"]]
  nu <- ft[["df"]]
  q <- qt(alpha, nu)
  
  # empirisch, normaal, Student-t
  v <- quantile(L, alpha, names = FALSE)
  out <- rbind(empirisch = c(v, mean(L[L >= v])),
               normaal = c(mu + sd(L) * qnorm(alpha), mu + sd(L) * dnorm(qnorm(alpha)) / (1 - alpha)),
               student_t = c(m + s * q, m + s * dt(q, nu) / (1 - alpha) * (nu + q^2) / (nu - 1)))
  colnames(out) <- c("VaR", "ES")
  out
}

kupiec_test <- function(x, n, alpha) {
  
  # verwacht tegen gezien
  p0 <- 1 - alpha
  ph <- x / n
  
  # LR-test, 1 vrijheidsgraad
  LR <- if (x == 0) -2 * n * log(1 - p0) else
    -2 * ((n - x) * log(1 - p0) + x * log(p0)) + 2 * ((n - x) * log(1 - ph) + x * log(ph))
  c(x = x, verwacht = n * p0, LR = LR, p = 1 - pchisq(LR, 1))
}

indep_test <- function(v) {
  
  # overgangen gisteren -> vandaag
  tab <- table(vorige = factor(v[-length(v)], 0:1), nu = factor(v[-1], 0:1))
  
  # kans op overschrijding na overschrijding vs na rust
  c(p_vv = tab["1", "1"] / max(1, sum(tab["1", ])),
    p_v_rust = tab["0", "1"] / sum(tab["0", ]),
    p = suppressWarnings(chisq.test(tab, correct = FALSE)$p.value))
}

backtest <- function(L_train, L_test, ft, centrum = "nul") {
  
  # per alpha, per model: dus 6 totaal
  do.call(rbind, lapply(c(0.95, 0.99), function(a) {
    R3 <- risk_3ways(L_train, a, ft, centrum)
    do.call(rbind, lapply(rownames(R3), function(model) {
      
      # 1 = overschrijding
      v <- as.integer(L_test > R3[model, "VaR"])
      k <- kupiec_test(sum(v), length(v), a)
      id <- indep_test(v)
      
      # aantal, clusters, grootte
      data.frame(alpha = a, model = model, x = k[["x"]], verwacht = k[["verwacht"]],
                 p_kupiec = k[["p"]], p_indep = id[["p"]],
                 es_ratio = if (sum(v) > 0) mean(L_test[v == 1]) / R3[model, "ES"] else NA)
    }))
  }))
}

var_es <- function(pnl, alpha = 0.95) {
  
  # verliezen, grootste eerst
  k <- ceiling(length(pnl) * (1 - alpha))
  v <- sort(-pnl, decreasing = TRUE)
  c(VaR = v[k], ES = mean(v[1:k]))
}

horizon_risk <- function(positie, s, nu, jaren, n = 10000) {
  
  # aantal dagen, dag-sd van de t
  k <- round(252 * jaren)
  sd_dag <- s * sqrt(nu / (nu - 2))
  
  # t-schokken, opgeteld per pad, zonder drift
  Z <- matrix(s * rt(n * k, df = nu), nrow = n)
  positie * (exp(rowSums(Z) - k * sd_dag^2 / 2) - 1)
}