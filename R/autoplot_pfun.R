#' @title Visualizations of `confMeta` objects
#'
#' @description Plot one or more `confMeta` objects. Currently, this function
#'     can create two types of plots, the *p*-value function as well as the
#'     forest plot. This allows to compare different *p*-value functions with
#'     each other.
#'
#' @param ... One or more objects of class `confMeta`.
#' @param type A character vector of length 1 or 2. Indicates what type of
#'     plot should be returned. Accepted is any combination of `"p"` and
#'     `"forest"`. Defaults to `c("p", "forest")`.
#' @param diamond_height Numeric vector of length 1. Indicates the maximal
#'     possible height of the diamonds in the forest plot. Defaults to 0.5.
#'     This argument is only relevant if `type` contains `"forest"` and will
#'     be ignored otherwise.
#' @param v_space Numeric vector of length 1. Indicates the vertical space
#'     between two diamonds in the forest plot. Defaults to 1.5.
#'     This argument is only relevant if `type` contains `"forest"` and will
#'     be ignored otherwise.
#' @param scale_diamonds Logical vector of lenght 1. Accepted values are either
#'     `TRUE` (default) or `FALSE`. If `TRUE`, the diamond is rescaled to the
#'      interval \[0, 1\] in cases where the maximum of the p-value
#'     function is not equal to 1. This argument is only relevant if `type`
#'     contains `"forest"` and will be ignored otherwise.
#' @param show_studies Logical vector of lenght 1. Accepted values are either
#'     `TRUE` (default) or `FALSE`. If `TRUE`, the forest plot shows the
#'     confidence intervals for the individual effect estimates. Otherwise,
#'     the intervals are suppressed. This argument is only relevant if `type`
#'     contains `"forest"` and will be ignored otherwise.
#' @param drapery Either `TRUE` (default) or `FALSE`. If `TRUE`, the individual
#'     study effects are represented as drapery plots. If `FALSE` the studies
#'     are represented by a simple vertical line at their effect estimates.
#' @param reference_methods A character vector of length 1, 2, 3 or 4. Denotes
#'     the reference methods that should be shown in the plot. Valid options are
#'     any combination of `c("fe", "re", "hk", "hc")` which stand for fixed
#'     effect meta-analysis, random effects meta-analysis, Hartung-Knapp and
#'     Henmi-Copas. Defaults to `c("fe", "re", "hk", "hc")`.
#' @param xlim Either NULL (default) or a numeric vector of length 2 which
#'     indicates the extent of the x-axis that should be shown.
#' @param xlab Either NULL (default) or a character vector of length 1 which
#'     is used as the label for the x-axis.
#'
#' @return An object of class `ggplot` containing the specified plot(s).
#'
#' @importFrom patchwork wrap_plots
#'
#' @export
autoplot.confMeta <- function(
    ...,
    type = c("p", "forest"),
    diamond_height = 0.5,
    v_space = 1.5,
    scale_diamonds = TRUE,
    show_studies = TRUE,
    drapery = TRUE,
    # drapery_ma = c("fe"),
    reference_methods = c("re", "hk", "hc"),
    xlim = NULL,
    xlab = NULL
) {

    # Check validity of reference methods
    check_ref_methods(reference_methods = reference_methods)

    # get the type of plot
    type <- match.arg(type, several.ok = TRUE)
    reference_methods <- match.arg(
        reference_methods,
        several.ok = TRUE,
        choices = c("fe", "re", "hk", "hc")
    )

    # Check all the confMeta objects
    cms <- list(...)
    check_cms(cms = cms)
    check_unique_names(cms = cms)

    # Check that the levels, estimates, SEs are equal
    # in all confMeta objects
    ests <- lapply(cms, "[[", i = "estimates")
    ses <- lapply(cms, "[[", i = "SEs")
    lvl <- lapply(cms, "[[", i = "conf_level")
    nms <- lapply(cms, "[[", i = "study_names")
    ok <- c(
        check_equal(ests),
        check_equal(ses),
        check_equal(lvl),
        check_equal(nms)
    )
    if (any(!ok)) {
        stop(
            paste0(
                "For plotting, all confMeta objects must have the same ",
                "'estimates', 'SEs', 'study_names', and 'conf_level' elements."
            )
        )
    }

    # Add some more checks for other graphics parameters
    check_TF(x = scale_diamonds)
    check_TF(x = show_studies)
    check_TF(x = drapery)
    check_length_1(x = diamond_height)
    check_class(x = diamond_height, "numeric")
    check_length_1(x = v_space)
    check_class(x = v_space, "numeric")

    # determine the xlim
    if (!is.null(xlim)) {
        check_xlim(x = xlim)
    } else {
        candidates <- unname(
            do.call(
                "c",
                lapply(
                    cms,
                    function(x) {
                        with(x, c(individual_cis, joint_cis, comparison_cis))
                    }
                )
            )
        )
        candidates <- candidates[is.finite(candidates)]
        ext_perc <- 5
        lower <- min(candidates)
        upper <- max(candidates)
        margin <- (upper - lower) * ext_perc / 100
        xlim <- c(lower - margin, upper + margin)
    }

    # generate plots
    expr <- list(
        p = quote({
            pplot <- ggPvalueFunction(
                cms = cms,
                drapery = drapery,
                xlim = xlim,
                xlab = xlab,
                reference_methods = reference_methods
            )
        }),
        forest = quote({
            fplot <- ForestPlot(
                cms = cms,
                diamond_height = diamond_height,
                v_space = v_space,
                xlim = xlim,
                show_studies = show_studies,
                scale_diamonds = scale_diamonds,
                reference_methods = reference_methods,
                xlab = xlab
            )
        })
    )
    expr <- expr[names(expr) %in% type]

    # put all the graphics parameters in a list
    pars <- list(
        type = type,
        diamond_height = diamond_height,
        v_space = v_space,
        scale_diamonds = scale_diamonds,
        show_studies = show_studies,
        drapery = drapery,
        reference_methods = reference_methods,
        xlim = xlim,
        xlab = xlab
    )

    # make the p_value function plot
    plots <- lapply(
        expr,
        function(x, cms, pars) eval(x),
        cms = cms,
        pars = pars
    )

    if (length(plots) < 2L) {
        plots[[1L]]
    } else {
        patchwork::wrap_plots(plots, ncol = 1L)
    }
}

# ==============================================================================
# Reexport autoplot function
# ==============================================================================

#' @importFrom ggplot2 autoplot
#' @export
ggplot2::autoplot

# ==============================================================================
# Input checks
# ==============================================================================

check_cms <- function(cms) {

    l_cms <- length(cms)
    counter <- 0L
    message <- NA_character_

    while (is.na(message) && counter < l_cms) {
        counter <- counter + 1L
        y <- tryCatch(
            {
                validate_confMeta(cms[[counter]])
            },
            error = function(e) conditionMessage(e)
        )
        if (!is.null(y)) message <- y
    }

    if (!is.na(message)) {
        stop(
            paste0(
                "Problem found in confMeta object number ",
                counter,
                ": ",
                message
            ),
            call. = FALSE
        )
    }
    invisible(NULL)
}

check_unique_names <- function(cms) {
    nms <- vapply(cms, "[[", i = "fun_name", character(1L))
    if (any(duplicated(nms))) {
        stop(
            "confMeta objects must have unique `fun_name`.",
            call. = FALSE
        )
    }
    invisible(NULL)
}

check_equal <- function(x) {

    # Order-agnostic
    x <- lapply(x, sort, decreasing = FALSE)
    # Get the first for comparison
    comp <- x[[1L]]
    all(
        do.call(
            "c",
            lapply(
                x,
                function(x, comp) {
                    all(x == comp)
                },
                comp = comp
            )
        )
    )
}

check_TF <- function(x) {
    obj <- deparse1(substitute(x))
    if (!is_TF(x)) {
        stop(
            paste0(
                "Object ", obj, " must be either `TRUE` or `FALSE`."
            ),
            call. = FALSE
        )
    }
    invisible(FALSE)
}

is_TF <- function(x) {
    if (length(x) == 1L && is.logical(x) && !is.na(x)) {
        TRUE
    } else {
        FALSE
    }
}

check_xlim <- function(x) {
    ok <- length(x) == 2L && is.numeric(x) && x[1L] < x[2L]
    if (!ok) {
        stop(
            paste0(
                "Argument `xlim` must be a numeric vector of length 2 where ",
                "the first element is smaller than the second."
            ),
            call. = FALSE
        )
    }
    invisible(NULL)
}


check_ref_methods <- function(reference_methods) {
    # Check for invalid reference_methods
    valid_methods <- c("fe", "re", "hk", "hc")
    is_invalid <- !(reference_methods %in% valid_methods)
    if (any(is_invalid)) {
        msg <- paste0(
            "Detected invalid reference_methods: ",
            paste0(reference_methods[is_invalid], collapse = ", "),
            "."
        )
        stop(msg)
    }
    # Check that there is only either fixed effect or random effects
    if ("fe" %in% reference_methods && "re" %in% reference_methods) {
        stop(
            paste0(
                "At the moment `reference_methods` can only contain either ",
                "\"fe\" or \"re\" but not both."
            )
        )
    }
}

# ==============================================================================
# p-value function plot
# ==============================================================================

#' @importFrom stats qnorm
#' @importFrom ggplot2 ggplot aes xlim geom_line geom_hline geom_vline
#' @importFrom ggplot2 geom_point scale_y_continuous sec_axis geom_segment
#' @importFrom ggplot2 theme theme_minimal labs element_text element_blank
#' @importFrom ggplot2 xlim scale_color_discrete
#' @importFrom scales hue_pal
ggPvalueFunction <- function(
    cms,
    xlim,
    drapery,
    xlab,
    reference_methods
) {

    # Set some constants that are equal for all grid rows
    const <- list(
        estimates = cms[[1L]]$estimates,
        SEs = cms[[1L]]$SEs,
        conf_level = cms[[1L]]$conf_level,
        eps = 0.0025, # for plotting error bars
        eb_height = 0.025,
        muSeq = seq(xlim[1], xlim[2], length.out = 1e4)
    )

    # Get the function names (for legend)
    fun_names <- vapply(cms, "[[", i = "fun_name", character(1L))
    # Add the reference methods and make factor levels
    fac_levels <- if ("fe" %in% reference_methods) {
        c(map_ref_methods("fe"), fun_names)
    } else if ("re" %in% reference_methods) {
        c(map_ref_methods("re"), fun_names)
    }

    # Calculate the p-values and CIs
    data <- lapply(seq_along(cms), function(x) {

        cm <- cms[[x]]
        fun <- cm$p_fun
        fun_name <- cm$fun_name
        alpha <- 1 - const$conf_level

        pval <- fun(
            estimates = const$estimates,
            SEs = const$SEs,
            mu = const$muSeq
        )
        CIs <- cm$joint_ci
        y0 <- cm$p_0[, 2L]

        # Data frame with the lines of the p-value function: (x,y coords, value
        # at x = 0)
        df1 <- data.frame(
            x = const$muSeq,
            y = pval,
            p_val_fun = cm$fun_name,
            y0 = y0,
            group = factor(fun_name, levels = fac_levels),
            stringsAsFactors = FALSE,
            row.names = NULL
        )
        # make a second data frame for the display of confidence intervals
        df2 <- data.frame(
            xmin = CIs[, 1L],
            xmax = CIs[, 2L],
            p_val_fun = fun_name,
            # y = rep(1 - conf_level, nrow(CIs$CI)) + factor * const$eps,
            y = rep(alpha, nrow(CIs)),
            group = factor(fun_name, levels = fac_levels),
            stringsAsFactors = FALSE,
            row.names = NULL
        )
        df2$ymax <- df2$y + const$eb_height
        df2$ymin <- df2$y - const$eb_height
        list(df1, df2)
    })
    # Extract the data frame for the lines with p-value functions
    # as well as the data frame for the error bars
    plot_data <- lapply(
        list(lines = 1L, errorbars = 2L),
        function(z, data) do.call("rbind", lapply(data, "[[", i = z)),
        data = data
    )
    lines <- plot_data[["lines"]]
    errorbars <- plot_data[["errorbars"]]

    # Calculate the drapery lines
    if (drapery) {
        dp <- get_drapery_df(
            estimates = const$estimates,
            SEs = const$SEs,
            mu = const$muSeq
        )
        ## also compute the RMA p-value function
        ### Object containing CIs for the reference methods
        ci_obj <- cms[[1L]]$comparison_cis
        cl <- cms[[1L]]$conf_level
        ## What reference method should we calculate drapery plot for:
        ## "fe" or "re"
        index <- if ("fe" %in% reference_methods) 1L else 2L
        ## In a further step, we might want to show more than 1, then just
        ## uncomment the following
        # index <- which(
        #     rownames(ci_obj) %in% map_ref_methods(abbrevs = reference_methods)
        # )
        rmaestimate <- rowMeans(ci_obj[index, , drop = FALSE])
        rmase <- (ci_obj[index, 2L] - ci_obj[index, 1L]) /
            (2 * stats::qnorm(p = (1 + cl) / 2))
        rmadf <- get_drapery_df(
            estimates = rmaestimate,
            SEs = rmase,
            mu = const$muSeq
        )
        rmadf$study <- factor(rmadf$study, levels = fac_levels)
    }

    # Define function to convert breaks from primary y-axis to
    # breaks for secondary y-axis
    trans <- function(x) abs(x - 1) * 100
    # Define breaks for the primary y-axis
    b_points <- c(1 - const$conf_level, pretty(c(lines$y, 1)))
    o <- order(b_points, decreasing = FALSE)
    breaks_y1 <- b_points[o]
    # Compute breaks for the secondary y-axis
    # breaks_y2 <- trans(b_points[o])
    # Set transparency
    transparency <- 1

    p <- ggplot2::ggplot(
        data = lines,
        ggplot2::aes(x = x, y = y, color = group)
    ) +
        ggplot2::xlim(xlim) +
        ggplot2::geom_hline(
            yintercept = 1 - const$conf_level, linetype = "dashed"
        )
    if (!drapery) {
        p <- p + ggplot2::geom_vline(
            xintercept = estimates,
            linetype = "dashed"
        )
    } else {
        p <- p +
            ggplot2::geom_line(
                data = dp,
                mapping = ggplot2::aes(x = x, y = y, group = study),
                linetype = "dashed",
                color = "lightgrey",
                show.legend = FALSE
            ) +
            ggplot2::geom_line(
                data = rmadf,
                mapping = ggplot2::aes(x = x, y = y, color = study),
                # color = "#00000099",
                show.legend = TRUE
            )


    }
    if (0 > xlim[1L] && 0 < xlim[2L]) {
        # Vertical line at 0
        p <- p + ggplot2::geom_vline(xintercept = 0, linetype = "solid") +
            ggplot2::geom_point(
                # Points at (x = 0, y = p_0)
                data = lines[!is.na(lines$y0), ],
                ggplot2::aes(x = 0, y = y0, color = group),
                alpha = transparency
            )
    }
    p <- p +
        ggplot2::geom_hline(yintercept = 0, linetype = "solid") +
        ggplot2::geom_line(alpha = transparency) +
        ggplot2::scale_y_continuous(
            name = "p-value",
            breaks = breaks_y1,
            limits = c(0, 1),
            expand = c(0, 0),
            sec.axis = ggplot2::sec_axis(
                transform = trans,
                name = "Confidence level [%]",
                breaks = trans(breaks_y1)
            )
        ) +
        # Draw intervals on x-axis
        ggplot2::geom_segment(
            data = errorbars[!is.na(errorbars$xmin), ],
            ggplot2::aes(x = xmin, xend = xmax, y = y, yend = y)
        ) +
        ggplot2::geom_segment(
            data = errorbars[!is.na(errorbars$xmin), ],
            ggplot2::aes(x = xmin, xend = xmin, y = ymin, yend = ymax)
        ) +
        ggplot2::geom_segment(
            data = errorbars[!is.na(errorbars$xmin), ],
            ggplot2::aes(x = xmax, xend = xmax, y = ymin, yend = ymax)
        ) +
        # Set x-axis window, labels
        # ggplot2::labs(
        #     x = bquote(mu),
        #     color = "Configuration"
        # ) +
        # Set theme
        ggplot2::theme_minimal() +
        ggplot2::theme(
            axis.title.y.right = ggplot2::element_text(angle = 90),
            legend.position = "bottom"
        )

    # Add axis/legend labels
    xlab <- if (is.null(xlab)) {
        bquote(mu)
    } else {
        xlab
    }
    p <- p +
        ggplot2::labs(
            x = xlab,
            color = ggplot2::element_blank()
        )

    # Add desired coloring for curves
    line_cols <- c("#000000", scales::hue_pal()(length(fac_levels) - 1))
    p <- p + ggplot2::scale_color_discrete(type = line_cols)

    # return
    p
}

# Calculate the drapery lines
#' @importFrom stats pnorm
get_drapery_df <- function(estimates, SEs, mu) {
    # get lenghts
    l_t <- length(estimates)
    l_m <- length(mu)
    l_tot <- l_t * l_m
    # Initialize vectors
    x_dp <- rep(mu, times = l_t)
    y_dp <- study <- numeric(l_tot)
    # Indices to loop over
    idx <- seq_len(l_m)
    nms <- names(estimates)
    for (i in seq_along(estimates)) {
        y_dp[idx] <- 2 *
            (1 - stats::pnorm(abs(estimates[i] - mu) / SEs[i]))
        study[idx] <- if (is.null(nms)) rep(i, l_m) else rep(nms[i], l_m)
        idx <- idx + l_m
    }
    data.frame(
        x = x_dp,
        y = y_dp,
        study = study,
        stringsAsFactors = FALSE
    )
}

map_ref_methods <- function(abbrevs) {
    map_one <- function(abbrev) {
        switch(
            abbrev,
            "re" = "Random effects",
            "hk" = "Hartung & Knapp",
            "hc" = "Henmi & Copas",
            "fe" = "Fixed effect"
        )
    }
    vapply(abbrevs, map_one, character(1L), USE.NAMES = FALSE)
}

# ==============================================================================
# forest plot
# ==============================================================================

#' @importFrom ggplot2 ggplot xlim geom_vline geom_errorbarh aes geom_point
#' @importFrom ggplot2 geom_polygon theme_minimal theme element_blank
#' @importFrom ggplot2 element_line scale_y_continuous labs scale_fill_discrete
#' @importFrom ggplot2 annotate
#' @importFrom scales hue_pal
ForestPlot <- function(
    cms,
    diamond_height,
    v_space,
    show_studies,
    scale_diamonds,
    reference_methods,
    xlim,
    xlab
) {

    # Make a data frame for the single studies
    cm <- cms[[1L]]
    studyCIs <- data.frame(
        lower = cm$individual_cis[, 1L],
        upper = cm$individual_cis[, 2L],
        estimate = cm$estimates,
        name = cm$study_names,
        plottype = 0L,
        color = 0L,
        stringsAsFactors = FALSE,
        row.names = NULL
    )

    # Get the dataframe for the polygons of the new methods
    new_method_cis <- get_CI_new_methods(
        cms = cms,
        diamond_height = diamond_height,
        scale_diamonds = scale_diamonds
    )

    # Get the dataframe for the polygons of the old methods
    old_methods_cis <- get_CI_old_methods(
        estimates = cm$estimates,
        SEs = cm$SEs,
        conf_level = cm$conf_level,
        diamond_height = diamond_height
    )

    ###########################################################################
    # Quick fix, remove the below at some point                               #
    ###########################################################################

    rename_methods <- function(old_methods) {
        rename_one <- function(old_method) {
            switch(
                old_method,
                "Fixed effect" = "Fixed effect",
                "Random effects" = "Random effects",
                "Hartung & Knapp" = "Hartung & Knapp",
                "Henmi & Copas" = "Henmi & Copas"
            )
        }
        vapply(old_methods, rename_one, character(1L), USE.NAMES = FALSE)
    }

    old_methods_cis <- lapply(old_methods_cis, function(x) {
        within(x, name <- rename_methods(name))
    })


    reference_methods <- map_ref_methods(abbrevs = reference_methods)

    keep_cis <- with(old_methods_cis, CIs$name %in% reference_methods)
    keep_p0 <- with(old_methods_cis, p_0$name %in% reference_methods)

    old_methods_cis$CIs <- old_methods_cis$CIs[keep_cis, ]
    old_methods_cis$p_0 <- old_methods_cis$p_0[keep_p0, ]

    ###########################################################################
    # Quick fix, remove the above at some point                               #
    ###########################################################################

    # Assemble p_0
    p_0 <- rbind(old_methods_cis$p_0, new_method_cis$p_0)

    # Assemble the dataset
    polygons <- rbind(old_methods_cis$CIs, new_method_cis$CIs)

    # Some cosmetics
    ## If any of the CIs does not exist, replace the row
    na_cis <- anyNA(polygons$x)
    if (na_cis) {
        # Which methods have an NA CI
        na_methods <- with(polygons, unique(name[is.na(x)]))
        # Mark it with a new variable
        polygons$ci_exists <- ifelse(polygons$name %in% na_methods, FALSE, TRUE)
        # Set y coordinate to 0
        idx <- with(polygons, name %in% na_methods)
        polygons$y[idx] <- 0
        polygons$x[idx] <- 0
    } else {
        polygons$ci_exists <- TRUE
    }
    ## Assign correct y-coordinate
    methods <- unique(polygons$name)
    n_methods <- length(methods)
    spacing <- seq(
        (nrow(studyCIs) + n_methods + 1L) * v_space,
        v_space,
        by = -v_space
    )
    studyCIs$y <- spacing[seq_len(nrow(studyCIs))]
    method_spacing <- spacing[(nrow(studyCIs) + 2L):length(spacing)]
    for (i in seq_along(methods)) {
        idx <- with(polygons, name == methods[i])
        polygons$y[idx] <- polygons$y[idx] + method_spacing[i]
    }
    ## Manage colors
    n_colors <- length(unique(polygons$color)) - 1L
    if (n_colors > 0) {
        colors <- scales::hue_pal()(n_colors)
        col_idx <- with(polygons, unique(color[ci_exists & color != 0]))
        colors <- c("gray20", colors[col_idx])
    }
    polygons$color <- factor(polygons$color)

    # Make the plot
    p <- ggplot2::ggplot()
    if (!is.null(xlim)) {
        p <- p + ggplot2::xlim(xlim)
        if (0 > xlim[1L] && 0 < xlim[2L]) {
            p <- p + ggplot2::geom_vline(xintercept = 0, linetype = "dashed")
        }
    }
    if (show_studies) {
        p <- p +
            ggplot2::geom_errorbarh(
                data = studyCIs,
                ggplot2::aes(
                    y = y,
                    xmin = lower,
                    xmax = upper,
                    height = diamond_height
                ),
                show.legend = FALSE
            ) +
            ggplot2::geom_point(
                data = studyCIs,
                ggplot2::aes(x = estimate, y = y)
            )
    }
    p <- p +
        ggplot2::geom_polygon(
            data = polygons[polygons$ci_exists == TRUE, ],
            ggplot2::aes(
                x = x,
                y = y,
                group = paste0(name, ".", id),
                fill = color
            ),
            show.legend = FALSE
        ) +
        ggplot2::theme_minimal() +
        ggplot2::theme(
            axis.title.y = ggplot2::element_blank(),
            axis.line.x = ggplot2::element_line(linetype = "solid"),
            axis.ticks.x = ggplot2::element_line(linetype = "solid"),
            panel.border = ggplot2::element_blank(),
            axis.ticks = ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank(),
            panel.grid.major.y = ggplot2::element_blank()
        ) +
        ggplot2::scale_y_continuous(
            breaks = spacing,
            labels = c(studyCIs$name, "", unique(polygons$name))
        ) +
        # ggplot2::labs(
        #     x = bquote(mu)
        # ) +
        ggplot2::scale_fill_discrete(type = colors)

    if (is.null(xlab)) {
        p <- p +
            ggplot2::labs(
                x = bquote(mu)
            )
    } else {
        p <- p +
            ggplot2::labs(
                x = xlab
            )
    }

    if (na_cis) {
        na_rows <- polygons[polygons$ci_exists == FALSE, ]
        for (i in seq_len(nrow(na_rows))) {
            p <- p + ggplot2::annotate(
                geom = "text",
                x = na_rows$x[i],
                y = na_rows$y[i],
                label = "CI does not exist"
            )
        }
    }

    p
}


get_CI_new_methods <- function(
    cms,
    diamond_height,
    scale_diamonds
) {

    out <- lapply(seq_along(cms), function(r) {

        # Get one of the cms
        cm <- cms[[r]]

        # Calculate polygons
        ci_exists <- if (all(is.na(cm$joint_ci))) FALSE else TRUE

        if (ci_exists) {
            # Calculate the polygons for the diamond
            polygons <- calculate_polygon(
                cm = cm,
                diamond_height = diamond_height,
                scale_diamonds = scale_diamonds
            )
            polygons$name <- cm$fun_name
            polygons$color <- r

        } else {
            polygons <- data.frame(
                x = NA_real_,
                y = NA_real_,
                id = NA_real_,
                name = cm$fun_name,
                color = r
            )
        }

        # Calculate the p-value at mu = 0
        p_0 <- data.frame(
            name = cm$fun_name,
            p_0 = cm$p_0[, 2L],
            stringsAsFactors = FALSE,
            row.names = NULL
        )

        p_max <- data.frame(
            name = cm$fun_name,
            mu = cm$p_max[, 1L],
            p_max = cm$p_max[, 2L],
            stringsAsFactors = FALSE,
            row.names = NULL
        )

        # Return
        list(
            CIs = polygons,
            p_0 = p_0,
            p_max = p_max
        )
    })

    # Reorganize list
    CIs <- do.call("rbind", lapply(out, "[[", i = 1L))
    p_0 <- do.call("rbind", lapply(out, "[[", i = 2L))
    p_max <- do.call("rbind", lapply(out, "[[", i = 3L))

    # Return
    list(CIs = CIs, p_0 = p_0, p_max = p_max)
}


get_CI_old_methods <- function(
    estimates,
    SEs,
    conf_level,
    diamond_height
) {


    # calculate CIs, p_0 for other methods
    methods <- get_method_names()
    cis <- get_stats_others(
        method = names(methods),
        estimates = estimates,
        SEs = SEs,
        conf_level = conf_level
    )
    # get the estimates
    ests <- with(cis, rowMeans(CI))

    # Create df
    t_ci <- t(cis$CI)
    t_ci <- rbind(t_ci[1L, ], ests, t_ci[2L, ], ests)
    x <- c(t_ci)
    y <- rep(
        c(0, -diamond_height / 2, 0, diamond_height / 2),
        times = length(ests)
    )

    CIs <- data.frame(
        x = x,
        y = y,
        id = 1L,
        name = rep(rownames(cis$CI), each = 4L),
        color = 0L,
        row.names = NULL,
        stringsAsFactors = FALSE
    )

    p_0 <- data.frame(
        name = rownames(cis$CI),
        p_0 = cis$p_0[, 2L],
        row.names = NULL,
        stringsAsFactors = FALSE
    )

    list(
        CIs = CIs,
        p_0 = p_0
    )
}

# Make a df that contains the data for the diamonds
calculate_polygon <- function(
    cm,
    diamond_height,
    scale_diamonds
) {

    # If gamma == NA, there is either one or no CI
    no_ci <- if (all(is.na(cm$joint_ci))) TRUE else FALSE
    no_gamma <- if (all(is.na(cm$gamma))) TRUE else FALSE

    # Which points to evaluate for the diamonds (all maxima, minima, estimates)
    # type of point
    # 0 = lower ci
    # 1 = minimum
    # 2 = maximum
    # 3 = upper ci
    pt_eval <- with(
        cm,
        {
            f_estimates <- p_fun(
                estimates = estimates,
                SEs = SEs,
                mu = estimates
            )
            nrep <- nrow(joint_cis)
            m <- rbind(
                cbind(p_max, 2),
                matrix(
                    c(estimates, f_estimates, rep(2, length(cm$estimates))),
                    ncol = 3L
                ),
                matrix(c(joint_cis[, 1L], rep(0, 2 * nrep)), ncol = 3L),
                matrix(
                    c(joint_cis[, 2L], rep(0, nrep), rep(3, nrep)),
                    ncol = 3L
                )
            )
            if (!no_gamma) m <- rbind(m, cbind(gamma, 1))
            m
        }
    )

    # Remove duplicates
    pt_eval <- pt_eval[!duplicated(pt_eval), ]

    # Remove those not in CI
    idx <- vapply(
        pt_eval[, 1L],
        function(x, cis) any(x >= cis[, 1L] & x <= cis[, 2L]),
        logical(1L),
        cis = cm$joint_cis
    )
    pt_eval <- pt_eval[idx, ]

    # Sort these by x-values
    o <- order(pt_eval[, 1L], decreasing = FALSE)
    pt_eval <- pt_eval[o, ]

    if (no_ci) {
        return(NULL)
    } else {
        x <- pt_eval[, 1L]
        y <- pt_eval[, 2L]
        type <- pt_eval[, 3L]
        # rescale the diamonds if needed (such that the max height is always 1)
        if (scale_diamonds) {
            scale_factor <- 1 / max(y)
            y <- y * scale_factor
        }
        # Assign polygon id
        is_upper <- which(type == 3L)
        is_lower <- which(type == 0L)
        id <- vector("numeric", length(x))
        counter <- 1L
        for (i in seq_along(is_upper)) {
            id[is_lower[i]:is_upper[i]] <- counter
            counter <- counter + 1L
        }
        # Arrange this such that it gives back a data.frame
        # that can be used with ggplot
        as.data.frame(
            do.call(
                "rbind",
                lapply(
                    unique(id),
                    function(z) {
                        idx <- id == z
                        x_sub <- x[idx]
                        y_sub <- y[idx] * diamond_height / 2
                        l <- length(x_sub)
                        mat <- matrix(
                            NA_real_,
                            ncol = 3,
                            nrow = 2L * l - 2L
                        )
                        colnames(mat) <- c("x", "y", "id")
                        mat[, 1L] <- c(x_sub, rev(x_sub[-c(1L, l)]))
                        mat[, 2L] <- c(-y_sub, rev(y_sub[-c(1L, l)]))
                        mat[, 3L] <- z
                        mat
                    }
                )
            )
        )
    }
}
