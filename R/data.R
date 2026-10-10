lees_config <- function(pad = "config/etfs.yml") {
  cfg <- yaml::read_yaml(pad)
  lapply(cfg$etfs, function(e) modifyList(cfg$algemeen, e))
}