#' Short wrapper to deal with near duplicate datetime-stamps when working with tracking data
#'
#' Documentation TBC

make_unique <- function(x) {
  xts::make.time.unique(x$date,eps = 10) # eps = number of seconds to make unique
}