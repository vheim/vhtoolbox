#' Speed-distance-angle filter that keeps the angle result of the second and second-to-last locations
#'
#' Modified version of \code{argosfilter::sdafilter()} (Freitas et al. 2008). The algorithm is
#' identical: locations with location class Z are removed, then locations requiring unrealistic
#' swimming speeds (McConnell et al. 1992, via \code{argosfilter::vmask()}) unless they are less
#' than 5 km from the previous location, then spikes defined by \code{ang} and \code{distlim}
#' (repeated until no spike is left). The only difference is the final labelling:
#' \code{argosfilter::sdafilter()} labels the first two and the last two locations
#' \code{"end_location"}, which overwrites the spike (angle) result that it has computed for the
#' second and the second-to-last location. \code{sdafilter_ends()} labels only the first and the
#' last location \code{"end_location"}; these two can never have an angle, because they lack a
#' neighbour on one side.
#'
#' @importFrom argosfilter vmask dist.prev dist.next internal.angles
#'
#' @export sdafilter_ends
#'
#' @param lat Numeric vector of latitudes in decimal degrees, sorted by time.
#' @param lon Numeric vector of longitudes in decimal degrees, sorted by time.
#' @param dtime Vector of class POSIXct with the date and time of each location.
#' @param lc Numeric or character vector of Argos location classes. Class Z can be given as "Z",
#' "z" or -9.
#' @param vmax Speed threshold in m/s. Default 2, as in \code{argosfilter::sdafilter()}.
#' @param ang Internal angles (degrees) of the spikes to be removed. Default c(15, 25), as in
#' \code{argosfilter::sdafilter()}. No spikes are removed if ang = -1. An internal angle of 15
#' degrees equals a turning angle of 165 degrees in Freitas et al. (2008).
#' @param distlim Lengths (m) of the spikes, one per value of \code{ang}. A location is a spike if
#' its internal angle is <= \code{ang[i]} AND both the distance to the previous and to the next
#' location are > \code{distlim[i]}. Default c(2500, 5000), as in \code{argosfilter::sdafilter()}.
#'
#' @return Character vector with one label per location: "removed" (removed by the Z, speed or
#' angle step), "not" (retained) or "end_location" (first and last location only).
#'
#' @details Copyright and licence: the algorithm and the code structure are from
#' \code{argosfilter::sdafilter()} by Carla Freitas, argosfilter version 0.70, licence
#' GPL (>= 2). Modified by Vital Heim on 2026-11-10: \code{extremes} is c(1, n) instead of
#' c(1, 2, n-1, n). Restyled 2026-11-12 (debug lines removed, the text-built removal rule replaced
#' by an equivalent loop, input checks added). This function is therefore distributed under
#' GPL (>= 2).
#'
#' For all locations except the second and second-to-last, the labels are identical to
#' \code{argosfilter::sdafilter()}. For rows 2 and n-1, "removed" means that the spike (angle)
#' step removed them; vmask never removes these rows, and LC Z should be removed beforehand
#' (\code{argosfilter::sdafilter()} itself keeps Z locations at the track ends).
#'
#' The speed step needs at least 5 locations (two neighbours on each side), so tracks with fewer
#' than 5 locations are rejected with an error (\code{argosfilter::sdafilter()} fails with an
#' unclear error in that case).
#'
#' Guard for short or very noisy tracks (added 2026-11-12, not in argosfilter): if the speed
#' step or earlier angle rounds leave fewer than 3 locations, the angle step stops, because no
#' angle can be calculated. \code{argosfilter::sdafilter()} stops with the error "missing value
#' where TRUE/FALSE needed" in that case (inside \code{argosfilter::internal.angles()}). Whenever
#' \code{argosfilter::sdafilter()} runs without error, the results are identical.
#'
#' @references Freitas C, Lydersen C, Fedak MA, Kovacs KM (2008). A simple new algorithm to filter
#' marine mammal Argos locations. Marine Mammal Science 24(2): 315-325.
#' doi:10.1111/j.1748-7692.2007.00180.x
#'
#' McConnell BJ, Chambers C, Fedak MA (1992). Foraging ecology of southern elephant seals in
#' relation to the bathymetry and productivity of the Southern Ocean. Antarctic Science 4:
#' 393-398.
#'
#' @author Carla Freitas (original \code{sdafilter()}), Vital Heim (modification).
#'
#' @seealso \code{\link[argosfilter]{sdafilter}}, \code{\link{sdafilter_plus}}
#'
#' @examples
#' set.seed(1)
#' n <- 20
#' trk <- data.frame(
#'   date = as.POSIXct("2025-01-01", tz = "UTC") + seq(0, by = 6 * 3600, length.out = n),
#'   lat  = 23 + cumsum(stats::rnorm(n, 0, 0.05)),
#'   lon  = -110 + cumsum(stats::rnorm(n, 0, 0.05)),
#'   lc   = c("G", sample(c("1", "0", "A", "B"), n - 1, replace = TRUE))
#' )
#' trk$lat[2] <- trk$lat[2] + 1 # spike at the second location
#' sdafilter_ends(lat = trk$lat, lon = trk$lon, dtime = trk$date, lc = trk$lc,
#'                vmax = 4.5, ang = c(15, 25), distlim = c(5000, 8000))
#'
sdafilter_ends <- function(lat,
                           lon,
                           dtime,
                           lc,
                           vmax = 2,
                           ang = c(15, 25),
                           distlim = c(2500, 5000)) {

  ## input checks
  n <- length(lat)
  if (length(lon) != n || length(dtime) != n || length(lc) != n) {
    stop("lat, lon, dtime and lc must have the same length.")
  }
  if (n < 5) {
    stop("At least 5 locations are needed (the speed step uses two neighbours on each side).")
  }
  if (!inherits(dtime, "POSIXct")) stop("dtime must be of class POSIXct.")
  if (anyNA(lat) || anyNA(lon) || anyNA(dtime)) stop("lat, lon and dtime must not contain NA.")
  if (length(ang) != length(distlim)) stop("ang and distlim must have the same length.")

  row_id        <- seq_len(n)
  original_data <- data.frame(row_id, lat, lon, dtime, lc)

  ## speed step (McConnell et al. 1992); rows 1, 2, n-1, n are never "removed" here
  mfilter <- argosfilter::vmask(lat, lon, dtime, vmax)

  ## remove LC Z and speed-flagged locations > 5 km from the previous raw location
  dist <- argosfilter::dist.prev(lat, lon)
  rem  <- which((mfilter == "removed" & dist > 5000) | lc == -9 | lc == "z" | lc == "Z")
  filt_data <- if (length(rem) != 0) original_data[-rem, ] else original_data

  ## spike (angle) step, repeated until no spike is left
  ## (argosfilter builds this rule as text and evaluates it; the loop below is equivalent)
  repeat {
    ## guard (not in argosfilter): with < 3 locations no angle exists, and
    ## argosfilter::internal.angles() would stop with an error
    if (nrow(filt_data) < 3) break
    angs  <- argosfilter::internal.angles(filt_data$lat, filt_data$lon)
    dnext <- argosfilter::dist.next(filt_data$lat, filt_data$lon)
    dprev <- argosfilter::dist.prev(filt_data$lat, filt_data$lon)
    spike <- rep(FALSE, length(angs))
    for (i in seq_along(ang)) {
      spike <- spike | (angs <= ang[i] & dprev > distlim[i] & dnext > distlim[i])
    }
    remx <- which(spike)
    if (length(remx) == 0) break
    filt_data <- filt_data[-remx, ]
  }

  ## labels
  not_rem <- match(filt_data$row_id, original_data$row_id)
  out <- rep("removed", n)
  out[not_rem] <- "not"
  out[c(1, n)] <- "end_location" # argosfilter::sdafilter(): c(1, 2, n - 1, n)
  out
}
