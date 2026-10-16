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