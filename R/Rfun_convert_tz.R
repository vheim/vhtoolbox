#' Quick timezone change if e.g. tagging data is local TZ but tracking equipment set to UTC
#'
#' Documentation TBC

convert_tz <- function(x, from_tz, to_tz) {
  attr(x, "tzone") <- to_tz
  x
}