#' Calculate confidence intervals based on the harmonic mean chi-squared test
#'
#' @template thetahat
#' @template se
#' @param level Numeric vector of length 1 specifying the level of the
#' confidence interval. Defaults to 0.95.
#' @template alternative
#' @param pValueFUN A function that calculates the p-value. Must have arguments
#' \code{thetahat} and \code{se} as these are passed by this function.
#' Must further have an argument \code{mu} that specifies the null-hypothesis.
#' Defaults to \code{\link[confMeta]{hMeanChiSqMu}}.
#' @template check_inputs
#' @template pValueFUN_args
#' @return Returns a list containing confidence interval(s)
#' obtained by inverting the harmonic mean chi-squared test based on
#' study-specific estimates and standard errors. The list contains:
#' \item{CI}{Confidence interval(s).}\cr\cr
#' If the \code{alternative} is "none", the list also contains:
#' \item{gamma}{Local minima of the p-value function between the thetahats.}
#' \item{gammaMean}{Mean of all gammas.}
#' \item{gammaHMean}{Harmonic mean of all gammas.}
get_ci <- function(
  thetahat,
  se,
  level = 0.95,
  alternative = "none",
  check_inputs = TRUE,
  pValueFUN = hMeanChiSqMu,
  pValueFUN_args
) {

    # Get the function we need to optimise
    # This is calls the p-value function with specified
    # args and subtracts alpha
    alpha <- 1 - level
    f <- make_function(
        thetahat = thetahat,
        se = se,
        alpha = alpha,
        pValueFUN = pValueFUN,
        pValueFUN_args = pValueFUN_args
    )

    # remove duplicates and sort thetahat and se
    keep <- !duplicated(thetahat)
    thetahat <- thetahat[keep]
    se <- se[keep]
    o <- order(thetahat, decreasing = FALSE)
    thetahat <- thetahat[o]
    se <- se[o]

    # Check if CI exists: This is the case if
    # the function f(thetahat) returns at least one
    # positive value or we can find a local maximum x
    # between the thetahats where f(x) > 0.
    # Also, keep track of the status:
    # - 0 = estimate
    # - 1 = maximum
    # - 2 = minimum
    thetahat <- matrix(
        c(thetahat, f(thetahat), rep(0, length(thetahat))),
        ncol = 3L,
        dimnames = list(NULL, c("x", "y", "status"))
    )
    ## search for local maxima in between thetahats
    maxima <- find_optima(thetahat = thetahat[, 1L], f = f, maximum = TRUE)
    ## Find out which of these maxima is relevant, i.e. it has a higher p-value
    ## than both, the next smaller and the next larger thetahat
    isRelevant_max <- is_relevant(
        f_thetahat = thetahat[, 2L],
        f_extremum = maxima[, 2L],
        maximum = TRUE
    )

    ## For searching CIs: Add the relevant maxima to the thetahats
    ## Here, we only care about the maxima since they might be > 0
    ## even though none of the thetahats are
    if (any(isRelevant_max)) {
        thetahat <- rbind(thetahat, maxima[isRelevant_max, ])
        ## Sort this by the x-coordinate
        o <- order(thetahat[, 1L], decreasing = FALSE)
        thetahat <- thetahat[o, ]
    }
    f_thetahat <- thetahat[, 2L]
    thetahat <- thetahat[, 1L]

    if (all(f_thetahat <= 0)) {
        # Calculate p_max
        idx <- f_thetahat == max(f_thetahat)
        # If it does not exist, return same format
        out <- list(
            CI = matrix(rep(NA_real_, 2L), ncol = 2L),
            gamma = matrix(rep(NA_real_, 2L), ncol = 2L),
            gammaMean = NA_real_,
            gammaHMean = NA_real_,
            forest_plot_thetahat = thetahat[idx],
            forest_plot_f_thetahat = f_thetahat[idx] + alpha
        )
        colnames(out$CI) <- c("lower", "upper")
        colnames(out$gamma) <- c("minimum", "pvalue_fun/gamma")
    } else {
        # If the CI does exist:
        # 1. Determine the smallest and largest thetahat where f(thetahat) > 0
        # 2. Find the lower and upper bounds based on these thetahats
        # 3. Corners/Cusps are always at thetahats. Thus, we search between
        #    the lower bound, thetahat_min, all the thetahats in between and
        #    finally thetahat_max and the upper bound, this is implemented in
        #    the function get_CI

        # 1.
        thetahat_pos <- which(f_thetahat > 0)
        idx_min <- min(thetahat_pos)
        idx_max <- max(thetahat_pos)
        thetahat_min <- thetahat[idx_min]
        thetahat_max <- thetahat[idx_max]
        step <- max(se)

        # 2.
        lower <- find_lower(
            f = f,
            thetahat_min = thetahat_min,
            se_min = step
        )
        upper <- find_upper(
            f = f,
            thetahat_max = thetahat_max,
            se_max = step
        )
        # 3.
        ## Get the thetahats we need to examine. These are all in
        ## between thetahat_min and thetahat_max.
        thetahat <- thetahat[idx_min:idx_max]
        f_thetahat <- f_thetahat[idx_min:idx_max]
        ## Also, in order to avoid errors due to two thetahats being equal,
        ## we need to make sure that we only search between unique
        ## thetahats
        uniq_idx <- !duplicated(thetahat)
        thetahat <- thetahat[uniq_idx]
        f_thetahat <- f_thetahat[uniq_idx]

        ## Get the number of intervals between these thetahats
        n_intervals <- length(thetahat) - 1L

        ## For the intervals in the middle, compute the minimum and the
        ## corresponding p-value
        if (n_intervals == 0) {
            gam <- matrix(NA_real_, ncol = 2L, nrow = 1L)
        } else {
            gam <- t(
                vapply(
                    seq_len(n_intervals),
                    function(i) {
                        opt <- stats::optimize(
                            f = f,
                            lower = thetahat[i],
                            upper = thetahat[i + 1L]
                        )
                        c(opt$minimum, opt$objective)
                    },
                    double(2L)
                )
            )
        }
        colnames(gam) <- c("minimum", "pvalue_fun/gamma")

        # Whereever the p-value function is negative at the minimum,
        # search for the two roots. Also add the lower and upper bound
        # If there is no minimum (i.e. only one thetahat is positive),
        # then, we can also just use lower & upper for the CI
        minima <- gam[, 2L]
        # only search roots if there is more than one positive f(thetahat)
        # and there is at least one negative minimum
        one_pos_theta_only <- length(minima) == 1L && is.na(minima)
        exist_neg_minima <- any(minima < 0)
        search_roots <- !one_pos_theta_only && exist_neg_minima
        if (search_roots) {
            # Now that we know all the minima between the smallest and largest
            # positive thetahat, we need to apply an algorithm to find the
            # roots. These exist if the minimum between two thetahats i
            # and j is negative and both f(thetahat[i]) and f(thetahat[j])
            # are positive.

            # In order to find the correct intervals to search, we first
            # need to find all negative minima and then for each of them
            # the closest smaller thetahat where f_thetahat > 0 and the
            # closest larger thetahat where f_thetahat > 0. This is
            # is implemented in the functions get_search_interval and
            # find_closest_thetas
            intervals <- get_search_interval(
                x_max = thetahat,
                y_max = f_thetahat,
                x_min = gam[, 1L],
                y_min = gam[, 2L]
            )
            CI <- vapply(
                seq_len(ncol(intervals)),
                function(i) {
                    l <- stats::uniroot(
                        f = f,
                        lower = intervals[1L, i],
                        upper = intervals[3L, i]
                    )$root
                    u <- stats::uniroot(
                        f = f,
                        lower = intervals[3L, i],
                        upper = intervals[2L, i]
                    )$root
                    c(l, u)
                },
                double(2L)
            )
            CI <- matrix(c(lower, CI, upper), ncol = 2L, byrow = TRUE)
        } else {
            CI <- matrix(c(lower, upper), ncol = 2L, byrow = TRUE)
        }
        colnames(CI) <- c("lower", "upper")

        # Increase the y-coordinate of the minima by alpha
        if (!one_pos_theta_only) {
            gam[, 2L] <- gam[, 2L] + alpha
        }

        # return
        out <- list(
            CI = CI,
            gamma = gam,
            gammaMean = mean(gam[, 2L]),
            gammaHMean = nrow(gam) / sum(nrow(gam) / gam[, 2L]),
            forest_plot_thetahat = thetahat,
            forest_plot_f_thetahat = f_thetahat + alpha
        )
    }
    out
}

################################################################################
# Helper function to find out whether a local maximum is relevant or not       #
# Relevant here means that it has a higher p-value than the next smaller and   #
# the next larger effect estimate                                              #
################################################################################

is_relevant <- function(f_thetahat, f_extremum, maximum) {
    lower <- f_thetahat[-length(f_thetahat)]
    upper <- f_thetahat[-1L]
    if (maximum) {
        f_extremum > lower & f_extremum > upper
    } else {
        f_extremum < lower & f_extremum < upper
    }
}

################################################################################
# Helper function to find local maxima/minima between thetahats                #
################################################################################

find_optima <- function(f, thetahat, maximum, ...) {

    n_intervals <- length(thetahat) - 1L
    status <- if (maximum) 1 else 2
    out <- t(
        vapply(
            seq_len(n_intervals),
            function(i) {
                opt <- stats::optimize(
                    f = f,
                    lower = thetahat[i],
                    upper = thetahat[i + 1L],
                    maximum = maximum,
                    ...
                )
                c(opt[[1L]], opt[[2L]], status)
            },
            double(3L)
        )
    )
    colnames(out) <- c("x", "y", "status")
    out
}

################################################################################
# Helper functions to determine which intervals to search for roots            #
################################################################################

get_search_interval <- function(x_max, y_max, x_min, y_min) {
    # find x-vals where gamma is negative
    neg_min_x <- x_min[y_min < 0]
    # for each of these x-vals, find the closest theta i, where
    # f(theta[i]) > 0 and theta[i] < x-val. Also find theta j,
    # where f(theta[j]) > 0 and theta[j] > x-val.
    interval <- vapply(
        neg_min_x,
        find_closest_thetas,
        x_max = x_max,
        y_max = y_max,
        FUN.VALUE = double(3L)
    )
    # remove duplicate intervals
    keep <- !duplicated(interval[1:2, , drop = FALSE], MARGIN = 2L)
    interval[, keep, drop = FALSE]
}

# This function finds the closest smaller and larger
# value to `minimum` in `x_max` where y_max is positive
find_closest_thetas <- function(minimum, x_max, y_max) {
    cond1 <- y_max > 0
    cond2 <- x_max < minimum
    lower <- max(which(cond1 & cond2))
    cond3 <- x_max > minimum
    upper <- min(which(cond1 & cond3))
    c(
        "lower" = x_max[lower],
        "upper" = x_max[upper],
        "minimum" = minimum
    )
}

################################################################################
# Helper functions that return the lower and upper bound of the                #
# confidence set                                                               #
################################################################################

find_lower <- function(thetahat_min, se_min, f) {
    lower <- thetahat_min - se_min
    while (f(lower) > 0) {
        lower <- lower - se_min
    }
    stats::uniroot(
        f = f,
        lower = lower,
        upper = thetahat_min
    )$root
}

find_upper <- function(thetahat_max, se_max, f) {
    upper <- thetahat_max + se_max
    while (f(upper) > 0) {
        upper <- upper + se_max
    }
    stats::uniroot(
        f = f,
        lower = thetahat_max,
        upper = upper
    )$root
}

################################################################################
# Helper function that returns a function to optimize                          #
################################################################################

make_function <- function(
    thetahat,
    se,
    alpha,
    pValueFUN,
    pValueFUN_args
) {
    # Add/Overwrite thetahat and se args
    pValueFUN_args$thetahat <- thetahat
    pValueFUN_args$se <- se
    # Add mu argument
    if ("mu" %in% names(pValueFUN_args)) pValueFUN_args$mu <- NULL
    pValueFUN_args <- append(pValueFUN_args, alist(mu = limit))
    ## For the remaining arguments, use the defaults
    forms <- formals(pValueFUN)
    nforms <- names(formals)
    pValueFUN_args <- append(
        pValueFUN_args,
        forms[!nforms %in% names(pValueFUN_args)]
    )
    ## Check whether all arguments are there
    available_args <- nforms %in% names(pValueFUN_args)
    if (!all(available_args)) {
        stop(
            paste0(
                "List pValueFUN_args is missing argument(s) '",
                paste0(nforms[!available_args], collapse = "', '"),
                "'."
            )
        )
    }

    function(limit) {
        do.call("pValueFUN", pValueFUN_args) - alpha
    }
}