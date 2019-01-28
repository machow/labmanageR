#remotes::install_github("centerforopenscience/osfr")
# TODO: user cronR to schedule to run every day


#' @export
osf_template = list(
  simple = "
Name: ${if (purrr::is_empty(tmp <- attributes$title)) attributes$name else tmp}
Modified: ${attributes$date_modified}
Type: ${if (purrr::is_empty(attributes$kind)) 'Component' else 'File'}
Link: ${links$html}
"
)


add_date_modified <- function(df) {
  df$date_modified <-
    purrr::map_dbl(df$meta, c("attributes", "date_modified")) %>%
    lubridate::as_datetime()

  df
}


find_modified_nodes <- function(nodes , after_date) {
  if (nrow(nodes) == 0) return(nodes)

  orig_class <- class(nodes)

  nodes %>%
    add_date_modified() %>%
    dplyr::filter(date_modified > after_date)
}

.check_files <- function(parent_node, after_date, level) {
  osfr::osf_ls_files(parent_node) %>%
    find_modified_nodes(after_date) %>%
    dplyr::mutate(
      node_level = level,
      parent_id = parent_node$id
      )
}

.split_tbl <- function(d) {
  if (nrow(d) > 0) split(d, 1:nrow(d)) else list()
}

#' Search an osf component for all modified subcomponents and files.
#'
#' @param parent_node Single osf_tbl row to search for subcomponents and files.
#' @param after_date Only search osf subcomponents modified after this datetime.
#' @param max_depth Maximum depth of subcomponents to search.
#' @param max_children Don't search subcomponents that have more than max_children nodes.
#' @param sleep Time to wait before getting more subcomponents.
#' @param include_files Whether to search for changed files in addition to components.
#' @param level How deep the parent_node's children are (you shouldn't need this).
#'
#' @return A list of osf_tbl objects that can be combined using dplyr::bind_rows
#' @examples
#'
#' @export
walk_parent <- function(
                        parent_node, after_date,
                        max_depth = 3,
                        max_children = 30,
                        sleep = .2,
                        include_files = TRUE,
                        level = 1
                        ) {
  if (nrow(parent_node) == 0 | level > max_depth) return(list())

  Sys.sleep(sleep)
  components <-
    osfr::osf_ls_nodes(parent_node) %>%
    find_modified_nodes(after_date)

  # osfr doesn't handle dplyr::mutate, so assign new col manually
  if (nrow(components)) {
    components$node_level <- level
    components$parent_id <- parent_node$id
  }

  if (include_files) {
    files <- .check_files(parent_node, after_date, level)
  } else {
    files <- tibble()
  }

  if (nrow(components) < max_children) {
    sub_components <-
      components %>%
      .split_tbl() %>%
      purrr::map(~ walk_parent(.x, after_date = after_date, level = level + 1)) %>%
      purrr::flatten()
  } else {
    sub_components <- list()
  }

  c(list(parent_node, files), sub_components)
}


#' Search an osf component for all modified subcomponents and files.
#'
#' @param id Single osf_tbl row to search for subcomponents and files.
#' @param after_date Only keep components and files modified after this date.
#' @param type What type of id is used, "user" or "component".
#' @param template String template for formatting results.
#' @param ... Additional arguments passed to walk_parent (only used if type is "component").
#'
#' @return A list of osf_tbl objects that can be combined using dplyr::bind_rows
#' @examples
#'
#' me <- osf_retrieve_user("aswnc")
#'
#' # return tibble of modified components and files
#' report <- osf_report_modified("aswnc", after_date = "2019-01-01")
#' report
#'
#'
#' # return printed reports only
#' osf_report_modified("aswnc", after_date = "2019-01-01", template = osf_template$simple)
#'
#' # "6sqvw" is the id for the paper "Inducing cognitive control..."
#' osf_report_modified("6sqvw", type = "node", after_date = "2019-01-01")
#'
#' # don't report files
#' osf_report_modified("6sqvw", type = "node", after_date = "2019-01-01")
#'
#'
#' @export
osf_report_modified <- function(id, after_date, type = "user", template = NULL, ...){
  if (type == "user") {
    # retrieving user brings up both recent components AND subcomponents
    nodes <-
      osfr::osf_retrieve_user(id) %>%
      osfr::osf_ls_nodes() %>%
      find_modified_nodes(after_date)

    changes <-
      nodes %>%
      .split_tbl() %>%
      purrr::map(~ .check_files(.x, after_date, level = NA)) %>%
      dplyr::bind_rows(nodes %>% dplyr::mutate(parent_id = NA, level = NA)) %>%
      dplyr::arrange(-dplyr::row_number())

  } else {

    changes <-
      osfr::osf_retrieve_node(id) %>%
      walk_parent(after_date, ...) %>%
      purrr::flatten() %>%
      dplyr::bind_rows() %>%
      dplyr::select(-dplyr::matches("metadata"))
  }

  if (!is.null(template))
    return(
      purrr::map_chr(changes$meta, ~stringr::str_interp(template, .x))
      )

  changes
}

#' Search an osf component for all modified subcomponents and files.
#'
#' @param data Either tibble returned from osf_retrieve/report_* functions, or list of meta data.
#' @param template Template to use for representing meta data. Passed to stringr::str_interp. See osf_template$simple for example.
#'
#' @return A character vector with descriptions for each entry.
#' @examples
#'
#' osf_retrieve_node("yu8zm") %>% osf_render_template()
#'
#' osf_retrieve_node("yu8zm") %>% osf_render_template("Name: ${attributes$title}")
#' @export
osf_render_template <- function(data, template = osf_template$simple) {
  # Note: not ideal to check class like this
  meta <- if (isClass("data.frame")) data$meta else data

  purrr::map_chr(meta, ~stringr::str_interp(template, .x))
}


#' Search an osf component for all modified subcomponents and files.
#'
#' @param id passed to osf_report_modified.
#' @param after_date passed to osf_report_modified.
#' @param type passed to osf_report_modified.
#' @param template passed to osf_report_modified.
#' @param ... passed to slackr::slackr_bot
#'
#' See slackr::slackr_setup for details on setting up slack credentials.
#'
#' @return NULL
#'
#' @examples
#' ## Not run:
#' # slackr_setup(incoming_webhook_url = "SOME_WEBHOOK_URL")
#' osf_report_modified_slack("aswnc", after_date = "2019-01-01", type = "user")
#'
#' ## End(Not run)
#' @export
osf_report_modified_slack <- function (
                             id, after_date,
                             type = "user",
                             template = osf_template$simple,
                             ...
                             ) {
  slackr::slackr_setup()
  updates <- osf_report_modified(id, after_date, type, template) %>% paste(collapse = "\n\n")

  if (length(updates) > 0) slackr::slackr_bot(updates, ...)
}
