test_that("sigma nul geeft het verwachte pad", {
  x <- simulate_gbm(1500, log(1.1), 0, 5, 2)
  expect_equal(x[1, ncol(x)], 1500 * 1.1^5)
})

test_that("simulate_gbm geeft n x k, ook bij 1 stap", {
  expect_equal(dim(simulate_gbm(1000, 0.05, 0.2, 2, 7)), c(7L, 104L))
  expect_equal(dim(simulate_gbm(1000, 0.05, 0.2, 1, 7, stappen = 1)), c(7L, 1L))
})

test_that("mc_etf: 3 x 5, horizon als attribuut, gemiddelde exact bij sigma 0", {
  mc <- mc_etf(c(bear = 0, base = 0.05, bull = 0.1), 0, 1000, 2, n = 10)
  expect_equal(dim(mc), c(3L, 5L))
  expect_equal(attr(mc, "jaren"), 2)
  expect_equal(unname(mc["base", "gem"]), 1000 * 1.05^2)
})

test_that("obligaties: horizon gelijk aan duration maakt de rente onbelangrijk", {
  cfg <- list(type = "obligaties", horizon = 5, ter = 0,
              obligaties = list(ytm = 0.04, duration = 5, scenarios = list(base = list(dy = 0.01))))
  expect_equal(unname(verwacht_rendement(cfg)), 0.04)
})

test_that("break-even met het base-rendement als doel geeft de base-groei terug", {
  cfg <- list(type = "aandelen", horizon = 2, ter = 0.0015,
              waardering = list(pe0 = 22, dy = 0.006,
                                scenarios = list(base = list(g = 0.12, peH = 21.2))))
  expect_equal(breakeven_groei(cfg, verwacht_rendement(cfg)[["base"]]), 0.12)
})

test_that("auto_split weigert een te korte reeks", {
  r <- xts::xts(rnorm(1200, 0, 0.01), seq(as.Date("2020-01-01"), by = "day", length.out = 1200))
  expect_false(auto_split(r)$ok)
})

test_that("Kupiec geeft p = 1 bij precies het verwachte aantal", {
  expect_equal(unname(kupiec_test(10, 1000, 0.99)["p"]), 1)
})