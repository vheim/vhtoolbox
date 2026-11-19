#' Add value labels in boxes next to horizontal bars (barplot with horiz = TRUE)
#'
#' Adds a text label in a box at a fixed distance beyond the end of each bar of a
#' horizontal bar plot, or beyond the outer end of its error bar if there is one.
#' Works for bars growing to the right or to the left (negative values or a reversed
#' x axis, e.g. `xlim = c(100, 0)`), so it can be used for both halves of a butterfly
#' plot. Error bars can be symmetric (`err`) or asymmetric (`err_end`). Bars with value
#' 0 get a box (e.g. "0.0%"). Bars with a missing value (`NA`) get no box by default,
#' or a box labelled "NA" with `na_label = TRUE`.
#'
#' @param values Numeric vector. Bar lengths, as passed to `barplot(height = ...)`.
#'   `NA` allowed, see `na_label`.
#' @param y Numeric vector. Bar positions, i.e. the value returned by
#'   `barplot(..., horiz = TRUE)`. Same length as `values`.
#' @param err Numeric vector or `NULL`. Symmetric error bars: length of the error bar
#'   beyond the bar end (e.g. the SD of your values). `NA` or `0`: no error bar for that bar.
#'   Default `NULL`.
#' @param err_end Numeric vector or `NULL`. Asymmetric error bars: position of the
#'   outer end of each error bar on the x axis (e.g. upper CI limit or 3rd quartile;
#'   for bars growing to the left, the limit on that side). `NA`: no error bar for
#'   that bar. Use either `err` or `err_end`, not both. Default `NULL`.
#' @param err_max Numeric or `NULL`. Limit for the error bar end if the error bars were
#'   cut, e.g. `100` for percentages. `NULL`: no limit.
#' @param labels Character vector or `NULL`. Label texts, one per bar. `NULL`: `values`
#'   formatted with `fmt` (as absolute values, see Details). Default `NULL`.
#' @param fmt Character. `sprintf()` format for the default labels. Default `"%.1f%%"`.
#'    Default prints `values` with a `%`sign.
#' @param na_label Logical. `FALSE` (default): bars with a missing value get no box.
#'   `TRUE`: they get a box labelled "NA" at the zero line.
#' @param side `NULL`, `"left"` or `"right"` (one value, or one per bar). Side of the
#'   box for bars without a direction, i.e. value 0 or `NA`. Bars with a value always
#'   follow their own direction. `NULL`: the side the other bars grow to (right if
#'   there are no negative values). Needed for butterfly plots drawn on one set of
#'   axes.
#' @param gap Numeric or `NULL`. Distance between the end of the error bar (or bar) and
#'   the box, in x-axis units. Default `NULL`, i.e. 1.5 % of the x-axis range.
#' @param cex Numeric. Text size. Default `0.55`.
#' @param box_width Numeric. Box width as a multiple of the text width. Default `1.6`.
#' @param box_height Numeric or `"bar"`. Box height as a multiple of the text height
#'   (default `1.6`), or `"bar"` for the same height as the bars. Reduce the number if
#'   boxes of neighbouring bars overlap (e.g. when many bars on small plot).
#' @param space Numeric. Only used with `box_height = "bar"`: the `space` used in
#'   `barplot()` (default `0.2`, as in `barplot()`).
#' @param box_col Character. Box fill colour.  Default `"white"`
#' @param border_col Character. Box border colour. Default `"black"`.
#'
#' @return A data frame (invisible) with one row per box drawn: box limits (`x_left`,
#'   `x_right`), `y`, `inside` (`TRUE` where the box was moved inside the bar if the label
#'   would have otherwise exceeded the plot limits) and
#'   `cut` (`TRUE` where the box does not fit in the plot). `NULL` if no box is drawn.
#'
#' @details Call it after `barplot()` and/or after drawing the error bars, on the same plot.
#'   Only for horizontal bar plots (values on the x axis).
#'
#'   Direction: each bar follows the sign of its value. A reversed axis needs no extra
#'   argument, because the function works in data units: "outwards" is always away
#'   from 0. Only bars of length 0 or `NA` have no direction; for these see `side`.
#'
#'   Labels: the default labels show absolute values (`abs(values)`), so that both
#'   halves of a butterfly plot show positive numbers. For data that are really
#'   negative (e.g. differences), pass your own `labels` to keep the sign.
#'
#'   Space: if a box does not fit between the error bar and the plot edge, it is moved
#'   inside the bar, just before the bar end, if the bar is long enough. Otherwise it
#'   stays outside, is cut at the plot edge, and a warning is given; make room with a
#'   wider `xlim` (e.g. `c(0, 115)` for percentages).
#'
#'   Error bar ends: an `err_end` that lies inside the bar (e.g. a lower limit passed
#'   by mistake) gives a warning and is replaced by the bar end.
#'
#' @author Vital Heim
#'
#' @examples
#' m <- c(5, 20, 45, 30, NA, 0)
#'
#' ## symmetric error bars (e.g. SD), bars to the right, no box for the NA bar
#' s <- c(2, 8, NA, 10, NA, 0)
#' bp <- barplot(m, horiz = TRUE, xlim = c(0, 70))
#' arrows(m - s, bp, m + s, bp, angle = 90, code = 3, length = 0.03)
#' add_horiz_bar_labels(m, bp, err = s)
#'
#' ## asymmetric error bars (e.g. bootstrap CI), bars to the left (reversed axis),
#' ## box "NA" for the missing bar
#' lo <- c(3, 12, 38, 22, NA, 0)
#' hi <- c(11, 24, 52, 41, NA, 0)
#' bp <- barplot(m, horiz = TRUE, xlim = c(70, 0))
#' arrows(lo, bp, hi, bp, angle = 90, code = 3, length = 0.03)
#' add_horiz_bar_labels(m, bp, err_end = hi, na_label = TRUE)
#'
#' ## butterfly plot on one set of axes: e.g. day vs. night comparisons, 0-bars need a side
#' ## here, we use the unit hours so you can see how the fmt parameter works.
#' day  <- c(10, 0, 35)
#' night <- c(25, 15, 0)
#' bp <- barplot(-day, horiz = TRUE, xlim = c(-60, 60), col = "grey80")
#' barplot(night, horiz = TRUE, add = TRUE, col = "grey40")
#' add_horiz_bar_labels(-day, bp, side = "left", fmt = "%.1f hours")
#' add_horiz_bar_labels(night, bp, side = "right",fmt = "%.1f hours")
#'
#' ## same as above but with non-negative values on both sides of butterfly plot
#' day   <- c(10, 0, 35)
#' night <- c(25, 15, 0)
#' op <- par(mfrow = c(1, 2), mar = c(3, 1, 1, 2))
#' ## left: day, reversed axis -> bars grow to the left with positive values
#' bp <- barplot(day, horiz = TRUE, xlim = c(60, 0), col = "grey80")
#' add_horiz_bar_labels(day, bp, side = "left", fmt = "%.1f hours")
#' ## right: night
#' par(mar = c(3, 0.5, 1, 2))
#' bp <- barplot(night, horiz = TRUE, xlim = c(0, 60), col = "grey40")
#' add_horiz_bar_labels(night, bp, side = "right", fmt = "%.1f hours")
#' par(op)
#' 
#' @export
add_horiz_bar_labels <- function(values, y, err = NULL, err_end = NULL, err_max = NULL,
                                 labels = NULL, fmt = "%.1f%%", na_label = FALSE,
                                 side = NULL, gap = NULL, cex = 0.55, 
                                 box_width = 1.6, box_height = 1.6, space = 0.2,
                                 box_col = "white", border_col = "black") {
  n <- length(values)

  ## input checks
  lens <- c(y       = length(y),
            err     = if (is.null(err))     n else length(err),
            err_end = if (is.null(err_end)) n else length(err_end),
            labels  = if (is.null(labels))  n else length(labels),
            side    = if (is.null(side) || length(side) == 1) n else length(side))
  if (any(lens != n))
    stop("`", paste(names(lens)[lens != n], collapse = "`, `"),
         "` must have the same length as `values` (", n, ").")
  if (!is.null(err) && !is.null(err_end))
    stop("Use either `err` (symmetric) or `err_end` (asymmetric), not both.")
  if (!is.null(side) && !all(side %in% c("left", "right")))
    stop("`side` must be \"left\" or \"right\".")

  na_val <- is.na(values)
  if (is.null(labels)) labels <- ifelse(na_val, "NA", sprintf(fmt, abs(values)))
  if (!is.null(side))  side   <- rep(side, length.out = n)

  ## default side for bars without a direction: the side the other bars grow to
  all_neg <- any(values < 0, na.rm = TRUE) && !any(values > 0, na.rm = TRUE)

  ## box height: multiple of the text height, or the bar height ("bar");
  ## calculated from all bar positions, before NA bars are dropped
  if (identical(box_height, "bar")) {
    ys <- sort(unique(y))
    h  <- if (length(ys) > 1) min(diff(ys)) / (1 + space) else 1  # bar height = width; barplot default 1
  } else {
    h <- strheight("0", cex = cex) * box_height
  }
  
  ## missing bars: skip (default) or keep as a bar of length 0
  keep <- if (na_label) rep(TRUE, n) else !na_val
  if (!any(keep)) return(invisible(NULL))
  values <- values[keep]; y <- y[keep]; labels <- labels[keep]; na_val <- na_val[keep]
  if (!is.null(err))     err     <- err[keep]
  if (!is.null(err_end)) err_end <- err_end[keep]
  if (!is.null(side))    side    <- side[keep]
  val <- ifelse(na_val, 0, values)

  usr <- par("usr")
  if (is.null(gap)) gap <- 0.015 * abs(usr[2] - usr[1])

  ## direction each bar grows in, in data units (+1 = towards larger x)
  dir  <- sign(val)
  none <- dir == 0                                     # bars of length 0 or NA
  if (any(none)) {
    if (is.null(side)) {
      dir[none] <- if (all_neg) -1 else 1
    } else {
      right <- if (usr[1] < usr[2]) 1 else -1          # data direction of "right" on the page
      dir[none] <- ifelse(side[none] == "right", right, -right)
    }
  }

  ## outer end of the error bar (or the bar itself, if there is none)
  if (!is.null(err_end)) {
    end <- ifelse(is.na(err_end) | na_val, val, err_end)
    wrong <- dir * end < dir * val
    if (any(wrong))
      warning(sum(wrong), " `err_end` value(s) lie inside the bar (lower limit passed?); ",
              "the bar end is used instead.")
  } else if (!is.null(err)) {
    end <- val + dir * ifelse(is.na(err) | na_val, 0, abs(err))
  } else {
    end <- val
  }
  end <- dir * pmax(dir * end, dir * val) # never inside the bar
  if (!is.null(err_max)) end <- dir * pmin(abs(end), err_max)

  ## box height and width
  w <- abs(strwidth(labels, cex = cex)) * box_width # abs() as values are negative on reversed axis
  # h <- strheight("0", cex = cex) * box_height # replaced 20261119 w/ L146

  ## box outside the error bar: x_a = side facing the bar, x_b = outer side
  edge <- ifelse(dir > 0, max(usr[1:2]), min(usr[1:2]))   # plot edge in growth direction
  x_a  <- end + dir * gap
  x_b  <- x_a + dir * w

  ## no room before the plot edge: inside the bar if it is long enough, else warn
  no_room <- dir * x_b > dir * edge
  fits_in <- abs(val) >= w + 2 * gap                   # gap to the bar end and to the zero line
  inside  <- no_room & fits_in
  cut     <- no_room & !fits_in
  x_a[inside] <- val[inside] - dir[inside] * gap
  x_b[inside] <- x_a[inside] - dir[inside] * w
  if (any(cut))
    warning(sum(cut), " label box(es) do not fit in the plot and are cut at the edge; ",
            "make room with a wider `xlim`.")

  x_left  <- pmin(x_a, x_b)
  x_right <- pmax(x_a, x_b)
  rect(x_left, y - h/2, x_right, y + h/2, col = box_col, border = border_col)
  # text((x_left + x_right) / 2, y, labels = labels, adj = c(0.5, 0.5), cex = cex)
  ## text centred in the box. pos = 4 (as in the old loop) uses the device's own
  ## vertical character offset, which centres digits visually; adj = 0.5 in y puts
  ## them too low. Start = box centre minus half the (signed) text width.
  x_text <- (x_left + x_right) / 2 - strwidth(labels, cex = cex) / 2
  text(x_text, y, labels = labels, pos = 4, offset = 0, cex = cex)

  invisible(data.frame(x_left = x_left, x_right = x_right, y = y,
                       inside = inside, cut = cut))
}
