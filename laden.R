# alle packages laden voor gebruik vant model
# waarom ist nodig? de functies die ik gebruik van derden zullen verspreid staan over verschillende bestanden

suppressPackageStartupMessages({
  library(quantmod)
  library(ggplot2)
})
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)
#voor elk pad "f" voert source() het bestand uit
