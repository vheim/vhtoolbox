#' Import the speed-filtered data and make sure that only the most recent dataset is used
#'
#' Looks in a folder for .rds files (e.g. the output of a previous speed-distance-angle (sda)
#' filter script) and imports one of them. If exactly one file is found, it is imported without asking. If several
#' files are found, all of them are listed with their modification time, the most recent one is
#' named, and the user is asked whether to import it. This prevents an older filter output from
#' being imported together with, or instead of, the current one.
#'
#' @importFrom magrittr %>%
#' @importFrom purrr map_dfr
#'
#' @export import_sda_data
#'
#' @param dataloc Character string specifying the directory path, i.e. the folder that contains
#' the output file(s) of the sda filter script. No default.
#'
#' @return A data frame containing the imported data if successful, NULL otherwise (i.e. if the
#' user did not confirm the import of the most recent file). The function stops with an error if
#' no .rds file is found.
#'
#' @details File search: all files in \code{dataloc} whose name ends in ".rds" are listed with
#' \code{list.files()} (pattern \code{"\\\\.rds$"}), whatever the rest of the file name is.
#' Subfolders are not searched, the match is case sensitive (".RDS" is not found) and files with
#' other extensions (e.g. .csv or .tiff) are ignored. Every .rds file in \code{dataloc} counts, so
#' keep only the file(s) to be imported there. Changed on 2026-11-16: the argument
#' \code{speedfilter} and the file-name pattern built from it were removed.
#'
#' One file: the file is read with \code{readRDS()} (via \code{purrr::map_dfr()}) and returned.
#' A green message names the imported file.
#'
#' Several files: a red warning lists all files, sorted by modification time (most recent first,
#' marked "[MOST RECENT]"). The user is then asked in the console: "Do you want to import this
#' file? (y/n)". With "y" only the most recent file is imported; any other answer cancels the
#' import and NULL is returned. The files are never combined in this case.
#'
#' Interactive use: the question uses \code{readline()}. In a non-interactive session (e.g.
#' \code{Rscript}) \code{readline()} returns "" immediately, so with several files the import is
#' cancelled and NULL is returned.
#'
#' Colours: the messages use colour codes (green, red, yellow) in the RStudio console.
#'
#' The files must be R data files saved with \code{saveRDS()}.
#'
#' @author Vital Heim
#'
#' @examples
#' # simulated data in a temporary folder
#' tmp <- file.path(tempdir(), "sda_import_example")
#' dir.create(tmp, showWarnings = FALSE)
#' dets <- data.frame(id = "A", date = Sys.time(), lon = -110, lat = 23)
#' saveRDS(dets, file.path(tmp, "Data_argosfilter_example_2025-01-01_2025-02-01.rds"))
#'
#' # one file: imported without asking
#' mydets_f <- import_sda_data(dataloc = tmp)
#'
#' \dontrun{
#' # several files: the files are listed and the user is asked to import the most recent one
#' saveRDS(dets, file.path(tmp, "Data_argosfilter_example_2025-01-01_2025-03-01.rds"))
#' mydets_f <- import_sda_data(dataloc = tmp)
#' }
#'
#' unlink(tmp, recursive = TRUE)
#'
import_sda_data <- function(dataloc) {

  # Check number of data files in directory
  data_files <- list.files(path = dataloc,
                           pattern = "\\.rds$",
                           full.names = FALSE)

  n_files <- length(data_files)

  if (n_files == 0) {
    stop("No data files found in directory: ", dataloc)

  } else if (n_files == 1) {
    # Print success message in green
    cat("\033[32m✓ Single file available and imported:", data_files[1], "\033[0m\n")

    # Run the import code
    mydets_f <- list.files(path = dataloc,
                           pattern = "\\.rds$",
                           full.names = TRUE) %>%
      purrr::map_dfr(readRDS)

    return(mydets_f)

  } else {
    # Print warning in red
    cat("\033[31m⚠ WARNING: Multiple files found in the import folder!\033[0m\n")
    cat("\033[31mFiles detected:\033[0m\n")

    # Get full file info including modification times
    full_paths <- list.files(path = dataloc,
                             pattern = "\\.rds$",
                             full.names = TRUE)

    file_info <- file.info(full_paths)
    file_info$filename <- basename(rownames(file_info))
    file_info <- file_info[order(file_info$mtime, decreasing = TRUE), ]

    # List all files with timestamps
    for (i in 1:nrow(file_info)) {
      timestamp <- format(file_info$mtime[i], "%Y-%m-%d %H:%M:%S")
      if (i == 1) {
        cat("\033[31m  -", file_info$filename[i], "(", timestamp, ") [MOST RECENT]\033[0m\n")
      } else {
        cat("\033[31m  -", file_info$filename[i], "(", timestamp, ")\033[0m\n")
      }
    }

    # Get most recent file
    most_recent_file <- rownames(file_info)[1]
    most_recent_name <- basename(most_recent_file)
    most_recent_time <- format(file_info$mtime[1], "%Y-%m-%d %H:%M:%S")

    cat("\033[33m→ The most recent file is:", most_recent_name, "(", most_recent_time, ")\033[0m\n")

    # Ask for confirmation
    response <- readline(prompt = "Do you want to import this file? (y/n): ")

    if (tolower(trimws(response)) == "y") {
      cat("\033[32m✓ Importing:", most_recent_name, "\033[0m\n")

      # Import only the most recent file
      mydets_f <- readRDS(most_recent_file)

      return(mydets_f)
    } else {
      cat("\033[31m✗ Import cancelled by user.\033[0m\n")
      return(NULL)
    }
  }
}
