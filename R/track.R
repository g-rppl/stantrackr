#' Model data
#'
#' @description
#' Model flight path from point estimates using a DCRW model.
#'
#' @param data A `data.frame` containing the point estimate data.
#' @param ci The method used to calculate the credible intervals. Available
#'   options are `'HDI'` for the highest posterior density interval and `'ETI'`
#'   for the equal-tailed interval; defaults to `'HDI'`.
#' @param prob The probability mass of the credible interval; defaults to `0.9`.
#' @param output_dir The directory to save the `CmdStanMCMC` objects to;
#'   defaults to the current working directory. If `NULL`, the objects are not
#'   saved.
#' @param ... Additional arguments passed to `cmdstanr::sample()`.
#'
#' @return
#' Returns a `data.frame` containing the model summaries.
#'
#' @details
#' This function is a wrapper around `cmdstanr::sample()` and uses a difference
#' correlated random walk model (DCRW) to estimate individual flight paths. The
#' model is described in more detail in
#' [Jonsen et al. 2005](https://doi.org/10.1890/04-1852) and
#' [Baldwin et al. 2018](https://doi.org/10.1016/j.ecolmodel.2018.08.006). To
#' learn more about state-space models in animal movement in general,
#' [Auger-Méthé et al. 2021](https://doi.org/10.1002/ecm.1470) is a good
#' starting point.
#'
#' @import dplyr
#' @import lubridate
#' @import cmdstanr
#' @importFrom stats median quantile
#' @importFrom HDInterval hdi
#'
#' @export
#'
track <- function(
    data = NULL,
    ci = "HDI",
    prob = 0.9,
    output_dir = getwd(),
    ...) {
  # Bind variables locally so that R CMD check doesn't complain
  . <- ID <- name <- NULL

  # Check data
  if (is.null(data)) {
    stop("No data provided.")
  }
  if (!ci %in% c("HDI", "ETI")) {
    stop(
      "Invalid credible interval method. Available options are 'HDI' and 'ETI'."
    )
  }
  if (prob < 0 || prob > 1) {
    stop("Probability mass must be between 0 und 1.")
  }

  ids <- data %>%
    group_by(ID) %>%
    summarise(n = n()) %>%
    filter(n < 3) %>%
    .$ID
  if (length(ids) > 0) {
    warning(paste0(
      ifelse(length(ids) < 2, "ID ", "IDs "), paste(ids, collapse = ", "),
      " had less than 3 observations and ",
      ifelse(length(ids) < 2, "was", "were"),
      " not modelled. You may want to decrease the `dtime` argument in",
      " `locate()` to increase the number of observations."
    ))
    data <- data[!data$ID %in% ids, ]
  }

  # Compile model
  mod <- cmdstan_model(system.file("Stan", "DCRW.stan", package = "stantrackr"))

  for (i in unique(data$ID)) {
    # Subset data
    d <- data[data$ID == i, ]

    # Prepare data
    loc <- as.matrix(d[, c("lon", "lat")])
    sigma <- as.matrix(d[, c("lon_sd", "lat_sd")])

    # Bundle data
    stan.data <- list(
      loc = loc, sigma = sigma,
      N = nrow(loc), w = d$w
    )

    # Sample
    fit <- mod$sample(data = stan.data, output_dir = NULL, ...)

    # Save CmdStanMCMC object
    if (!is.null(output_dir)) {
      fit$save_object(paste0(output_dir, "/model-", i, ".RDS"))
    }

    # Summarise draws
    drws <- fit$draws("y")

    s <- data.frame(
      time = unique(d$ts),
      name = rep(c("lon", "lat"), each = length(d$ts)),
      mean = c(apply(drws, 3, mean)),
      median = c(apply(drws, 3, median)),
      lwr = if (ci == "ETI") {
        c(apply(drws, 3, quantile, prob = (1 - prob) / 2))
      } else {
        c(apply(drws, 3, hdi, credMass = prob)[1, ])
      },
      upr = if (ci == "ETI") {
        c(apply(drws, 3, quantile, prob = 1 - (1 - prob) / 2))
      } else {
        c(apply(drws, 3, hdi, credMass = prob)[2, ])
      }
    ) %>%
      group_split(name, .keep = FALSE)

    # Wide format and additional variables
    s <- merge(s[[2]], s[[1]], by = "time", suffix = c(".lon", ".lat"))
    s$ID <- i
    s$distance <- .distance(s)
    s$speed <- s$distance / (c(NA, diff(s$time)) * 60)

    # Add to output
    if (i == unique(data$ID)[1]) {
      summary <- s
    } else {
      summary <- rbind(summary, s)
    }

    # Print progress
    cat(paste0("Done with ID ", i, ".\n \n"))
  }
  return(summary)
}
