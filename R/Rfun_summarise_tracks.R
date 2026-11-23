#' Tracking duration (days) and length (km) of movement tracks per individual
#'
#' Summarises movement tracks per individual: date of the first and last location, track
#' duration in days and track length in km (sum of the distances between consecutive
#' locations). Column names are arguments, so the function works with any data layout.
#' 
#' @importFrom dplyr arrange group_by across all_of mutate lag summarise first
#' @importFrom geosphere distGeo
#' @importFrom rlang .data
#'
#' @param data Data frame or tibble with one row per location.
#' @param id_col Character. Name of the column with the individual ID. Default `"id"`.
#' @param date_col Character (POSIXct or Date). Name of the column with the 
#'   date-time of each location. Default `"date"`.
#' @param lat_col Character. Name of the latitude column (in decimal degrees, WGS84).
#'   Default `"lat"`.
#' @param lon_col Character. Name of the longitude column (in decimal degrees, WGS84).
#'   Default `"lon"`.
#' @param include_last_day Logical. Default `TRUE`: the day of the last location
#'   counts as a full day, i.e. duration = last date - first date + 1 (i.e.
#'   a track with all locations on one day lasts 1 day). If `FALSE`: duration = last date -
#'   first date (i.e. a track with all locations on one day lasts 0 days).
#'
#' @return A tibble with one row per individual, sorted by ID, with the columns: ID
#'   column (same name as `id_col`), `start_obs` and `end_obs` (Date of first and last day with
#'   an observation), `trackduration_days` (numeric, see `include_last_day`) and
#'   `tracklength_km` (numeric).
#'
#' @details
#'   First, the data are sorted by individual and time inside the function before
#'   the distances between consecutive locations are calculated, so the input order does
#'   not matter. Distances are caclulated using `geosphere::distGeo()`, i.e. the shortest distance on the WGS84
#'   ellipsoid between consecutive locations (Karney 2013). The track length is therefore
#'   the length of straight lines between the locations; movement between locations is
#'   not included. The first location of each individual has no previous location and
#'   adds nothing (`NA`, ignored in the sum).
#'
#'   The duration is calculated as calendar days of the first and last location as returned by
#'   `as.Date()`, i.e. in the time zone of `date_col` (R >= 4.3; UTC in older R versions).
#'   Whole days only: the time of day is not used. When you set `include_last_day = TRUE` the
#'   result is the number of calendar days with the tag at liberty ("days at liberty" in
#'   many tagging studies) including the last day; with `FALSE` the last day of 
#'   is excluded.
#'
#'   If you have missing values, a location with `NA` coordinates gives `NA` distances to its
#'   neighbours, which are ignored in the sum, so the track length is underestimated. A
#'   `NA` in `date_col` gives `NA` dates and duration for that individual (and the row is
#'   sorted to the end of its track).
#'
#'   The function stops if `data` is not a data frame, if a column name
#'   is not a single character string or is missing from `data`, if `date_col` is not
#'   POSIXct or Date, if the coordinates are not numeric, if they lie outside
#'   -90 to 90 (latitude) or -180 to 180 (longitude), e.g. when `lat_col` and `lon_col`
#'   are swapped, or if `include_last_day` is not a single `TRUE` or `FALSE`.
#'   
#'   Dependencies: requires R >= 4.1.0 (native pipe `|>`) and the packages
#'   `dplyr` (>= 1.0.0, for `across()`) and `geosphere` installed. All functions are
#'   called with `package::function()`, so the packages do not need to be loaded with
#'   `library()`. The `.data` pronoun comes from `rlang` and is installed with `dplyr`.
#'
#' @references Karney CFF (2013). Algorithms for geodesics. *Journal of Geodesy* 87: 43–55.
#'
#' @author Vital Heim
#'
#' @examples
#' ## two simulated tracks, rows not in time order
#' trk <- data.frame(
#'   animal = rep(c("A", "B"), times = c(4, 3)),
#'   time  = as.POSIXct(c("2025-01-02 08:00", "2025-01-01 10:00", "2025-01-02 20:00",
#'                        "2025-01-05 06:00",
#'                        "2025-03-10 12:00", "2025-03-10 18:00", "2025-03-11 07:00"),
#'                      tz = "UTC"),
#'   y     = c(23.1, 23.0, 23.3, 23.2, 22.5, 22.6, 22.6),
#'   x     = c(-110.2, -110.0, -110.3, -110.5, -109.8, -109.7, -109.5)
#' )
#'
#' ## Last day included; A : 1-5 Jan = 5 days, B: 10-11 Mar = 2 days
#' summarise_tracks(trk, id_col = "animal", date_col = "time", lat_col = "y", lon_col = "x")
#'
#' ## Lst day not included; A: 4 days, B: 1 day
#' summarise_tracks(trk, id_col = "animal", date_col = "time", lat_col = "y", lon_col = "x",
#'                  include_last_day = FALSE)
#'
#' @export
summarise_tracks <- function(data, id_col = "id", date_col = "date",
                             lat_col = "lat", lon_col = "lon",
                             include_last_day = TRUE) {

  ## input checks
  if (!is.data.frame(data))
    stop("`data` must be a data frame or tibble.")
  cols <- c(id_col = id_col, date_col = date_col, lat_col = lat_col, lon_col = lon_col)
  args <- list(id_col = id_col, date_col = date_col, lat_col = lat_col, lon_col = lon_col)
  bad_arg <- !vapply(args, function(a) is.character(a) && length(a) == 1 && !is.na(a),
                     logical(1))
  if (any(bad_arg))
    stop("`", paste(names(args)[bad_arg], collapse = "`, `"),
         "` must be a single column name (character).")
  missing_col <- !cols %in% names(data)
  if (any(missing_col))
    stop("Column(s) not found in `data`: ",
         paste0(names(cols)[missing_col], " = \"", cols[missing_col], "\"", collapse = ", "))
  if (!inherits(data[[date_col]], c("POSIXct", "Date")))
    stop("`", date_col, "` must be POSIXct or Date, not ", class(data[[date_col]])[1], ".")
  if (!is.numeric(data[[lat_col]]) || !is.numeric(data[[lon_col]]))
    stop("`", lat_col, "` and `", lon_col, "` must be numeric (decimal degrees).")
  if (any(abs(data[[lat_col]]) > 90, na.rm = TRUE) ||
      any(abs(data[[lon_col]]) > 180, na.rm = TRUE))
    stop("Coordinates outside -90/90 (lat) or -180/180 (lon); ",
         "are `lat_col` and `lon_col` swapped?")
  if (!is.logical(include_last_day) || length(include_last_day) != 1 || is.na(include_last_day))
    stop("`include_last_day` must be TRUE or FALSE.")

  last_day <- if (include_last_day) 1 else 0   # +1: count the day of the last location too

  data |>
    dplyr::arrange(.data[[id_col]], .data[[date_col]]) |>  # consecutive locations in time order
    dplyr::group_by(dplyr::across(dplyr::all_of(id_col))) |>
    dplyr::mutate(
      distance_m = geosphere::distGeo(cbind(.data[[lon_col]], .data[[lat_col]]),
                                      cbind(dplyr::lag(.data[[lon_col]]),
                                            dplyr::lag(.data[[lat_col]]))),
      start_obs  = as.Date(min(.data[[date_col]])),
      end_obs    = as.Date(max(.data[[date_col]])),
      total_days = as.numeric(difftime(as.Date(max(.data[[date_col]])),
                                       as.Date(min(.data[[date_col]])),
                                       units = "days")) + last_day
    ) |>
    dplyr::summarise(
      start_obs          = dplyr::first(start_obs),
      end_obs            = dplyr::first(end_obs),
      trackduration_days = dplyr::first(total_days),
      tracklength_km     = sum(distance_m, na.rm = TRUE) / 1000
    )
}
