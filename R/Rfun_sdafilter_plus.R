#' End-location check after argosfilter::sdafilter(), with one filter status per location
#'
#' Takes ONE track together with the result of a previous, separate
#' \code{argosfilter::sdafilter()} run, applies the two tests of the speed-distance-angle filter
#' (Freitas et al. 2008) to the end locations that \code{argosfilter::sdafilter()} cannot test or
#' does not report, and returns the filter status of every location. It does not run
#' \code{argosfilter::sdafilter()} itself: run it first and pass its result as a column of data.
#'
#' @importFrom geosphere distGeo
#'
#' @export sdafilter_plus
#'
#' @param data Data frame of one track (one individual), containing all locations (also those
#' removed by sdafilter) and a column with the sdafilter result. Rows are sorted by time
#' internally; the result is returned in the original row order.
#' @param lat Name of the latitude column in data (decimal degrees). Character. Default "lat".
#' @param lon Name of the longitude column in data (decimal degrees). Character. Default "lon".
#' @param datetime Name of the date-time column in data (POSIXct). Character. Default "date".
#' @param lc Name of the Argos location class column in data. Character. Default "lc".
#' @param sda_kept Name of the column in data with the result of \code{argosfilter::sdafilter()}:
#' either its labels ("not", "removed", "end_location") or a logical column (TRUE = retained,
#' i.e. "not" or "end_location"). Character. Default "sda_kept".
#' @param vmax Numeric. Speed threshold in m/s; use the same value as in sdafilter. No default on
#' purpose (species-specific; e.g. 4.5 for shortfin mako sharks, Vaudo et al. 2017).
#' @param ang Numeric vector of spike angles (internal angle, degrees); same as in sdafilter, e.g.
#' c(15, 25).
#' @param distlim Numeric vector of spike lengths (m), one per value of ang; same as in sdafilter,
#' e.g. c(5000, 8000).
#' @param dist_gate Numeric. Minimum distance in m to the previous retained location for a speed
#' removal of an end location. Default 5000 (as hard-coded in \code{argosfilter::sdafilter()}).
#'
#' @return Character vector with one status per row of data (original order):
#' "kept", "removed_sdafilter" (removed by the separate argosfilter::sdafilter() run),
#' "removed_end_angle" or "removed_end_speed" (removed by the end-location check).
#'
#' @details \code{argosfilter::sdafilter()} cannot test the first two and the last two locations
#' of a track: its speed step needs two neighbours on each side, and it overwrites the angle
#' result of the second and second-to-last location with "end_location" (Freitas et al. 2008, p.
#' 319). After the separate sdafilter run, this function applies
#' (a) the angle test to rows 2 and n-1: argosfilter's own spike result, which
#' \code{argosfilter::sdafilter()} computes but overwrites, obtained via \code{\link{sdafilter_ends}};
#' (b) the speed test to rows 2, n-1 and n, on the locations retained by sdafilter and step (a)
#' (see below).
#' A location failing both end tests is reported as "removed_end_angle", because (a) runs first.
#'
#' Speed test (b): root-mean-square (RMS) speed after McConnell et al. (1992), as used in
#' \code{argosfilter::vmask()}, but over the neighbours that exist within positions i-2 ... i+2
#' (3 for the second and second-to-last location, 2 for the last) instead of always 4. The speed
#' to each neighbour is distance / (|time difference| + 1 s); the +1 s is taken from
#' \code{argosfilter::vmask()}. A tested location is removed if its RMS speed > \code{vmax} AND
#' its distance to the previous retained location > \code{dist_gate} (fast locations closer than
#' this are kept, because close fixes taken in quick succession give high apparent speeds; Freitas
#' et al. 2008). The test is iterative: only the fastest failing location is removed, then all
#' speeds are recalculated. This protects a good location whose speed is only high because its
#' neighbour is bad. Differences from \code{argosfilter::vmask()}: neighbours that exist instead of
#' always 4; one removal per round instead of all speed peaks; the distance gate is applied inside
#' the loop and measured to the previous retained location (argosfilter: after the loop, to the
#' previous raw location); WGS84 instead of a sphere.
#'
#' Distances are geodesic, in m on the WGS84 ellipsoid (Karney 2013), via
#' \code{geosphere::distGeo()}. argosfilter uses a sphere with 60 nautical miles per degree. On
#' data of shortfin mako sharks tracked in the Gulf of California (2,810 pairs, 2026-11-10), the
#' difference was a median of 5 m, a maximum of 4.26 km, and no change in any filter classification.
#'
#' Tagging location: the first location in time (row 1 after sorting by \code{datetime}) is
#' treated as the tagging location. It is used as reference only and is never tested. Location
#' classes are not used for this, because other locations can have the same class (e.g. "G").
#' Make sure the tagging location has the earliest time stamp of the track.
#'
#' Use the same vmax, ang and distlim as in the sdafilter run. Requirements: location class Z
#' removed beforehand (\code{argosfilter::sdafilter()} keeps Z locations at the track ends; the
#' function stops if it finds any); at least 5 locations; no NA in coordinates or times.
#'
#' Parallelisation: the function works on one track and returns a vector, like
#' \code{argosfilter::sdafilter()}, so individuals can be run in parallel outside the function,
#' e.g. with \code{furrr::future_map()} on nested data.
#'
#' Structure: the internal helpers \code{.end_location_check()} (both end tests, two logical
#' columns), \code{.argos_end_speed_check()} (speed test), \code{.prepare_track()} and
#' \code{.as_sda_kept()} are in this file. Merged on 2026-11-13 from the former separate functions
#' \code{argos_end_location_check()}, \code{argos_end_speed_check()} and \code{geo_dist_m()};
#' results unchanged.
#'
#' @references Freitas C, Lydersen C, Fedak MA, Kovacs KM (2008). A simple new algorithm to filter
#' marine mammal Argos locations. Marine Mammal Science 24(2): 315-325.
#' doi:10.1111/j.1748-7692.2007.00180.x
#'
#' Karney CFF (2013). Algorithms for geodesics. Journal of Geodesy 87: 43-55.
#' doi:10.1007/s00190-012-0578-z
#'
#' McConnell BJ, Chambers C, Fedak MA (1992). Foraging ecology of southern elephant seals in
#' relation to the bathymetry and productivity of the Southern Ocean. Antarctic Science 4:
#' 393-398.
#'
#' Vaudo JJ, Byrne ME, Wetherbee BM, Harvey GM, Shivji MS (2017). Long-term satellite tracking
#' reveals region-specific movements of a large pelagic predator, the shortfin mako shark, in the
#' western North Atlantic Ocean. Journal of Applied Ecology 54: 1765-1775.
#' doi:10.1111/1365-2664.12852
#'
#' @author Vital Heim
#'
#' @seealso \code{\link{sdafilter_ends}}, \code{\link[argosfilter]{sdafilter}},
#' \code{\link[argosfilter]{vmask}}, \code{\link[geosphere]{distGeo}}
#'
#' @examples
#' set.seed(1)
#' n <- 20
#' mov <- data.frame(
#'   date = as.POSIXct("2025-01-01", tz = "UTC") + seq(0, by = 6 * 3600, length.out = n),
#'   lat  = 23 + cumsum(stats::rnorm(n, 0, 0.05)),
#'   lon  = -110 + cumsum(stats::rnorm(n, 0, 0.05)),
#'   lc   = c("G", sample(c("1", "0", "A", "B"), n - 1, replace = TRUE))
#' )
#' mov$lat[2] <- mov$lat[2] + 1 # implausible second location
#'
#' # step 1: argosfilter::sdafilter(), separately
#' mov$sdafilter <- argosfilter::sdafilter(lat = mov$lat, lon = mov$lon, dtime = mov$date,
#'                    lc = mov$lc, vmax = 4.5, ang = c(15, 25), distlim = c(5000, 8000))
#' # step 2: end-location check
#' mov$status <- sdafilter_plus(mov, sda_kept = "sdafilter",
#'                              vmax = 4.5, ang = c(15, 25), distlim = c(5000, 8000))
#' table(mov$sdafilter, mov$status)
#'
sdafilter_plus <- function(data,
                           lat = "lat",
                           lon = "lon",
                           datetime = "date",
                           lc = "lc",
                           sda_kept = "sda_kept",
                           vmax,
                           ang,
                           distlim,
                           dist_gate = 5000) {

  ## end-location check (angle test via sdafilter_ends, speed test); two logical columns in the
  ## original row order
  res <- .end_location_check(data, lat = lat, lon = lon, datetime = datetime, lc = lc,
                             sda_kept = sda_kept,
                             vmax = vmax, ang = ang, distlim = distlim, dist_gate = dist_gate)

  ## result of the separate sdafilter run (original row order)
  kept <- .as_sda_kept(data[[sda_kept]], sda_kept)

  ifelse(!kept, "removed_sdafilter",
  ifelse(res$end_angle_removed, "removed_end_angle",
  ifelse(res$end_speed_removed, "removed_end_speed", "kept")))
}


#' Both end tests for one track (internal)
#'
#' Angle test (rows 2 and n-1) and speed test (rows 2, n-1 and n) after a separate
#' argosfilter::sdafilter() run. Formerly the exported function argos_end_location_check().
#'
#' @param data,lat,lon,datetime,lc,sda_kept,vmax,ang,distlim,dist_gate See
#' \code{\link{sdafilter_plus}}.
#' @return Data frame with one row per row of data (original order) and two logical columns:
#' end_angle_removed and end_speed_removed.
#' @noRd
.end_location_check <- function(data, lat, lon, datetime, lc, sda_kept,
                                vmax, ang, distlim, dist_gate) {

  trk  <- .prepare_track(data, lat = lat, lon = lon, datetime = datetime, lc = lc,
                         extra = sda_kept)
  kept <- .as_sda_kept(trk$extra, sda_kept)
  n    <- length(trk$lat)
  pos  <- seq_len(n)
  tested <- pos != 1 # never the first location in time (tagging location)

  ## (a) angle test, rows 2 and n-1: argosfilter's spike result (sdafilter_ends)
  ang_lab  <- sdafilter_ends(lat = trk$lat, lon = trk$lon, dtime = trk$datetime, lc = trk$lc,
                             vmax = vmax, ang = ang, distlim = distlim)
  angle_rm <- pos %in% c(2, n - 1) & tested & kept & ang_lab == "removed"

  ## (b) speed test, rows 2, n-1 and n, on the locations retained after sdafilter and (a)
  test     <- pos %in% c(2, n - 1, n) & tested
  pass     <- kept & !angle_rm
  speed_rm <- rep(FALSE, n)
  speed_rm[pass] <- .argos_end_speed_check(lon = trk$lon[pass], lat = trk$lat[pass],
                                           datetime = trk$datetime[pass], test = test[pass],
                                           vmax = vmax, dist_gate = dist_gate)

  res <- data.frame(end_angle_removed = angle_rm, end_speed_removed = speed_rm)

  ## back to the original row order
  res[order(trk$ord), , drop = FALSE]
}


#' Speed test for the end locations of a track (internal)
#'
#' RMS speed test over the neighbours that exist, iterative, with distance gate; see Details of
#' \code{\link{sdafilter_plus}}. Formerly the exported function argos_end_speed_check().
#'
#' @param lon,lat Numeric vectors of ONE track in decimal degrees, sorted by time.
#' @param datetime POSIXct vector of the times of the locations, same order.
#' @param test Logical vector, TRUE for the locations to be tested. The first element must be
#' FALSE: the first location (tagging location) is used as reference only and is never removed.
#' @param vmax Numeric. Speed threshold in m/s.
#' @param dist_gate Numeric. Minimum distance in m to the previous retained location for a speed
#' removal.
#' @return Logical vector, TRUE = removed by the speed test.
#' @noRd
.argos_end_speed_check <- function(lon, lat, datetime, test, vmax, dist_gate = 5000) {

  ## input checks
  n_all <- length(lon)
  if (length(lat) != n_all || length(datetime) != n_all || length(test) != n_all) {
    stop("lon, lat, datetime and test must have the same length.")
  }
  if (!inherits(datetime, "POSIXct")) stop("datetime must be of class POSIXct.")
  if (!is.logical(test) || anyNA(test)) stop("test must be logical without NA.")
  if (n_all > 0 && test[1]) stop("The first location must not be tested (test[1] must be FALSE).")
  if (missing(vmax) || !is.numeric(vmax) || length(vmax) != 1) stop("vmax must be one number (m/s).")

  keep <- rep(TRUE, n_all)
  t    <- as.numeric(datetime)
  repeat {
    idx  <- which(keep)
    n    <- length(idx)
    cand <- idx[test[idx]]
    if (n < 3 || length(cand) == 0) break
    rms <- gate <- rep(NA_real_, length(cand))
    for (j in seq_along(cand)) {
      k  <- match(cand[j], idx)                          # k >= 2 (first location never tested)
      nb <- idx[setdiff(max(1, k - 2):min(n, k + 2), k)] # neighbours that exist
      ## distances in m on WGS84; note geosphere's order: longitude, latitude
      v  <- geosphere::distGeo(cbind(lon[cand[j]], lat[cand[j]]), cbind(lon[nb], lat[nb])) /
            (abs(t[nb] - t[cand[j]]) + 1)                # m/s, +1 s as in argosfilter::vmask()
      rms[j]  <- sqrt(mean(v^2))
      gate[j] <- geosphere::distGeo(cbind(lon[cand[j]], lat[cand[j]]),
                                    cbind(lon[idx[k - 1]], lat[idx[k - 1]])) # to previous retained location
    }
    bad <- which(rms > vmax & gate > dist_gate)
    if (length(bad) == 0) break
    keep[cand[bad[which.max(rms[bad])]]] <- FALSE
  }
  !keep # TRUE = removed
}


#' Check and prepare one track (internal)
#'
#' Checks the column names and classes, sorts the track by time and keeps the original order.
#'
#' @param data,lat,lon,datetime,lc See \code{\link{sdafilter_plus}}.
#' @param extra Optional name of one more column to carry along (or NULL).
#' @return List with lat, lon, datetime, lc, extra (sorted by time) and ord (the sorting order).
#' @noRd
.prepare_track <- function(data, lat, lon, datetime, lc, extra = NULL) {
  if (!is.data.frame(data)) stop("data must be a data frame of one track.")
  cols <- c(lat, lon, datetime, lc, extra)
  if (!is.character(cols)) stop("Column names must be given as character, e.g. lat = \"lat\".")
  miss <- setdiff(cols, names(data))
  if (length(miss) > 0) stop("Column(s) not found in data: ", paste(miss, collapse = ", "))
  if (nrow(data) < 5) stop("At least 5 locations per track are needed.")
  if (!inherits(data[[datetime]], "POSIXct")) stop("Column '", datetime, "' must be POSIXct.")
  if (anyNA(data[[lat]]) || anyNA(data[[lon]]) || anyNA(data[[datetime]])) {
    stop("Columns '", lat, "', '", lon, "' and '", datetime, "' must not contain NA.")
  }
  if (any(as.character(data[[lc]]) %in% c("Z", "z", "-9"))) {
    stop("Remove location class Z before filtering (sdafilter keeps Z at the track ends).")
  }
  ord <- order(data[[datetime]])
  list(lat      = data[[lat]][ord],
       lon      = data[[lon]][ord],
       datetime = data[[datetime]][ord],
       lc       = data[[lc]][ord],
       extra    = if (is.null(extra)) NULL else data[[extra]][ord],
       ord      = ord)
}


#' Convert the sdafilter result to TRUE / FALSE (internal)
#'
#' @param x Column with the argosfilter::sdafilter() result: labels ("not", "removed",
#' "end_location") or logical (TRUE = retained).
#' @param name Column name, for error messages.
#' @return Logical vector, TRUE = retained by sdafilter ("not" or "end_location").
#' @noRd
.as_sda_kept <- function(x, name) {
  if (is.factor(x)) x <- as.character(x)
  if (is.character(x)) {
    bad <- setdiff(unique(x), c("not", "removed", "end_location"))
    if (length(bad) > 0) {
      stop("Column '", name, "' contains values other than the sdafilter labels ",
           "'not', 'removed', 'end_location': ", paste(bad, collapse = ", "))
    }
    x <- x %in% c("not", "end_location")
  }
  if (!is.logical(x) || anyNA(x)) {
    stop("Column '", name, "' must hold the sdafilter labels or TRUE / FALSE, without NA.")
  }
  x
}
