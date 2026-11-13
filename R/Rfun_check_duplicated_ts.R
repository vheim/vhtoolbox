#' Find duplicated time stamps in datetime column of e.g. animal tracking data
#'
#' Documentation TBC

check_duplicated_ts <- function(x, y, group_var = "id", time_var = "date") {
  
  # Count duplicates within groups in both dataframes
  duplicates_x <- x %>% 
    ungroup() %>%
    group_by(across(all_of(group_var))) %>%
    summarise(n_duplicates = sum(duplicated(.data[[time_var]])), .groups = "drop") %>%
    summarise(total_duplicates = sum(n_duplicates)) %>%
    pull(total_duplicates)
  
  duplicates_y <- y %>% 
    ungroup() %>%
    group_by(across(all_of(group_var))) %>%
    summarise(n_duplicates = sum(duplicated(.data[[time_var]])), .groups = "drop") %>%
    summarise(total_duplicates = sum(n_duplicates)) %>%
    pull(total_duplicates)
  
  # Ensure single values
  duplicates_x <- duplicates_x[1]
  duplicates_y <- duplicates_y[1]
  
  # Print results
  cat(sprintf("* There are %d duplicates in uncorrected df, there are %d duplicates in time-corrected df.\n", 
              duplicates_x, duplicates_y))
  
  # Check if y has no duplicates
  if (isTRUE(duplicates_y == 0)) {
    cat(green(sprintf("* Given the %d duplicate timestamps in your time-corrected df, you can continue.\n", 
                      duplicates_y)))
  } else {
    cat(red("* Warning: your time-corrected df still contains duplicates. Please review the corrections.\n"))
  }
  
  # Return invisibly for potential further use
  invisible(list(
    duplicates_uncorrected = duplicates_x,
    duplicates_corrected = duplicates_y,
    passed = duplicates_y == 0
  ))
}