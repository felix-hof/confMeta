path <- "https://raw.githubusercontent.com/felix-hof/hMean/main/R/kTRMu.R"
fun_name <- "kTRMu"

# get the old function
get_old_FUN <- function(
    path,
    fun_name
) {

    # Source the utils file as well
    code_utils <- paste0(
        readLines(
            "https://raw.githubusercontent.com/felix-hof/hMean/main/R/utils.R",
            warn = FALSE
        ),
        collapse = "\n"
    )
    code_function <- paste0(
        readLines(path, warn = FALSE),
        collapse = "\n"
    )
    e <- new.env()
    eval(code_utils, envir = e)
    eval(code_function, envir = e)

    get(fun_name, envir = e)
}