#' Get the bounding box of movement data, with an optional buffer
#'
#' Returns the smallest and largest longitude and latitude of a data set of locations (e.g.
#' satellite-derived positions of tracked animas), each moved outwards by a buffer. 
#' The result can be passed directly to functions that need a spatial extent.
#'
#' @export get_buffered_bbox
#'
#' @param data A data frame (or tibble) that contains locations, one row per location.
#' No default.
#' @param lat_col Character string, name of the column with the latitudes in decimal degrees.
#' Default \code{"lat"}.
#' @param lon_col Character string, name of the column with the longitudes in decimal degrees.
#' Default \code{"lon"}.
#' @param buffer Numeric. Distance added on every side of the bounding box,
#' in the units of the coordinates (degrees for lon/lat). Default \code{0} (no buffer).
#'
#' @return A named list with four numbers:
#' \describe{
#'   \item{lon1}{smallest longitude minus \code{buffer} (western edge)}
#'   \item{lon2}{largest longitude plus \code{buffer} (eastern edge)}
#'   \item{lat1}{smallest latitude minus \code{buffer} (southern edge)}
#'   \item{lat2}{largest latitude plus \code{buffer} (northern edge)}
#' }
#'
#' @details Missing values: NA coordinates are ignored (\code{na.rm = TRUE}). If a coordinate
#' column contains no value at all (only NA), the function stops with an error, because
#' \code{min()} and \code{max()} would otherwise return \code{Inf}/\code{-Inf} with a warning.
#'
#'
#' Units: the buffer is added in degrees. One degree of latitude is about 111 km everywhere,
#' but one degree of longitude is about 111 km x cos(latitude), i.e. shorter towards the poles
#' (about 101 km at 25 degrees N). A buffer of 1 degree is therefore not the same distance in
#' east-west and north-south direction.
#'
#' Limits not handled: the edges are not clipped to valid ranges, so a large buffer can give
#' latitudes beyond -90/90 or longitudes beyond -180/180. Tracks that cross the antimeridian
#' (180 degrees) give a box that spans the whole globe in longitude; convert the longitudes to
#' 0-360 first in that case.
#'
#' Grouping: a grouped data frame (\code{dplyr::group_by()}) is treated as one data set; the box
#' covers all rows. For one box per individual, call the function per group (e.g. with
#' \code{split()} and \code{lapply()}).
#'
#' @author Vital Heim
#'
#' @examples
#' # simulated locations
#' tracks <- data.frame(id  = rep(c("A", "B"), each = 3),
#'                      lon = c(-110.2, -111.0, -112.5, -109.8, -108.9, NA),
#'                      lat = c(  22.9,   23.4,   24.1,   21.7,   20.5, 21.0))
#'
#' # bounding box without buffer
#' get_buffered_bbox(tracks)
#'
#' # bounding box with 1 degree buffer
#' bbox <- get_buffered_bbox(tracks, buffer = 1)
#'
#' # other column names
#' tracks2 <- setNames(tracks, c("id", "x", "y"))
#' get_buffered_bbox(tracks2, lat_col = "y", lon_col = "x", buffer = 0.5)

get_buffered_bbox <- function(data, lat_col = "lat", lon_col = "lon", buffer = 0) {
  # Bounding box, moved outwards by the buffer
  list(
    lon1 = min(data[[lon_col]], na.rm = TRUE) - buffer,
    lon2 = max(data[[lon_col]], na.rm = TRUE) + buffer,
    lat1 = min(data[[lat_col]], na.rm = TRUE) - buffer,
    lat2 = max(data[[lat_col]], na.rm = TRUE) + buffer
  )
}
