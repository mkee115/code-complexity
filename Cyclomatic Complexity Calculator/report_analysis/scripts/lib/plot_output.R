# =============================================================================
# lib/plot_output.R
# Where outputs go (one folder per report section), the shared ggplot theme,
# and the helpers that write figures, CSV tables and table PNGs.
# =============================================================================

# Which report section a figure or table file belongs to, from its name
section_of <- function(name) {
  n <- sub("^(tbl_|diag_)", "", name)
  key <- if (grepl("^(fig01|corpus_|survey_|position_lean|sensitivity_corpus)", n)) "data"
    else if (grepl("^(fig0[2-5]|rq1_)", n)) "rq1"
    else if (grepl("^(fig(0[6-9]|1[0-3])|rq2_|sensitivity_)", n)) "rq2"
    else if (grepl("^(fig1[4-7]|rq3_)", n)) "rq3"
    else stop("No report section for output file: ", name)
  SECTIONS[[key]]
}

# Importance: the figures the report is built around are the ones marked "main" in
# figure_takeaways.csv; these tables are the ones that will definitely be in the report.
# Everything else is optional: include it if it fits, or if you decide you want it.
IMPORTANT_TABLES <- c("tbl_corpus_filter_counts", "tbl_corpus_summary", "tbl_rq2_agreement_summary",
                      "tbl_rq3_original_vs_refactor")
IMPORTANT_OUTPUTS <- c(
  sub("[.]png$", "", read_csv("scripts/figure_takeaways.csv", show_col_types = FALSE) |>
        filter(suggested_use == "main") |> pull(figure)),
  IMPORTANT_TABLES)
importance_of <- function(name) if (name %in% IMPORTANT_OUTPUTS) "important" else "optional"

# Images (figures and table PNGs) go to <section>/important or <section>/optional;
# the CSV and text results behind them go to <section>/csv.
image_dir <- function(name) file.path(PATHS$out, section_of(name), importance_of(name))
data_dir <- function(name) file.path(PATHS$out, section_of(name), "csv")

theme_report <- function(base_size = 9.5) {
  theme_minimal(base_size = base_size, base_family = FONT_FAMILY) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#E5E5E5", linewidth = 0.3),
      axis.text = element_text(colour = "#333333"),
      axis.title = element_text(colour = "#222222"),
      strip.text = element_text(face = "bold", hjust = 0),
      plot.title = element_text(face = "bold", size = base_size + 1.5),
      plot.subtitle = element_text(colour = "#444444", size = base_size - 0.5),
      plot.title.position = "plot",
      legend.position = "bottom",
      legend.title = element_blank(),
      plot.margin = margin(4, 6, 4, 4)
    )
}

# Figures go to the folder of their report section and importance (see image_dir)
.registry <- new.env()
.registry$figs <- list()
save_fig <- function(plot, name, height_cm, width_cm = TEXT_WIDTH_CM,
                     rq = NA, purpose = NA) {
  dir <- image_dir(name)
  ggsave(file.path(dir, paste0(name, ".png")), plot, width = width_cm, height = height_cm,
         units = "cm", dpi = 300, bg = "white")
  # Copy without the title and subtitle, for a report whose captions carry them. It goes to
  # output/figures_no_titles/<section>/ (outside the section folders the export checks scan).
  # A figure whose titles cannot be removed (a composite of several plots) is copied unchanged.
  ndir <- file.path(PATHS$out, "figures_no_titles", basename(dirname(dir)))
  dir.create(ndir, showWarnings = FALSE, recursive = TRUE)
  bare <- tryCatch(plot + labs(title = NULL, subtitle = NULL), error = function(e) plot)
  ggsave(file.path(ndir, paste0(name, ".png")), bare, width = width_cm, height = height_cm,
         units = "cm", dpi = 300, bg = "white")
  .registry$figs[[name]] <- tibble::tibble(figure = paste0(name, ".png"),
    folder = basename(dirname(dir)), importance = basename(dir), research_question = rq, purpose = purpose)
  invisible(name)
}

save_table <- function(df, name) {
  write_csv(df, file.path(data_dir(name), paste0(name, ".csv")))
  invisible(df)
}

# Label colour that stays readable on a filled bar
text_on <- function(fill) ifelse(fill %in% c("#2166AC", "#B2182B", "#636363"), "white", "#111111")

# Render a small table as a PNG (for tables that go straight into the report)
table_png <- function(df, name, title = NULL, subtitle = NULL, width_cm = TEXT_WIDTH_CM,
                      left_cols = 1, wrap_note = NULL) {
  df <- as.data.frame(lapply(df, as.character), stringsAsFactors = FALSE, check.names = FALSE)
  df[is.na(df)] <- ""
  nr <- nrow(df); nc <- ncol(df)
  chars <- vapply(seq_len(nc), function(j) max(nchar(c(names(df)[j], df[[j]])), 3), numeric(1))
  w <- chars + 2.2
  pt <- min(9, 0.92 * (width_cm / sum(w)) / 0.0176)
  if (pt < 6.5) {                       # widen the table rather than shrink the text
    pt <- 6.5
    width_cm <- sum(w) * 0.0176 * 6.5 / 0.92
  } else if (pt >= 9) {                 # narrow table: fit to its content
    width_cm <- sum(w) * 0.0176 * 9 / 0.92
  }
  xr <- cumsum(w); xl <- c(0, head(xr, -1)); xc <- (xl + xr) / 2
  row_h <- pt * 0.0353 * 1.9                         # cm
  title_h <- (if (!is.null(title)) 0.9 else 0) + (if (!is.null(subtitle)) 0.55 else 0)
  height_cm <- (nr + 1) * row_h + title_h + 0.3 + (if (!is.null(wrap_note)) 0.55 else 0)
  cells <- tibble::tibble(
    row = rep(seq_len(nr), times = nc), col = rep(seq_len(nc), each = nr),
    label = unlist(df, use.names = FALSE),
    x = ifelse(col <= left_cols, xl[col] + 0.6, xc[col]),
    hj = ifelse(col <= left_cols, 0, 0.5))
  head <- tibble::tibble(col = seq_len(nc), label = names(df),
                         x = ifelse(col <= left_cols, xl[col] + 0.6, xc[col]),
                         hj = ifelse(col <= left_cols, 0, 0.5))
  zebra <- tibble::tibble(row = seq_len(nr)[seq_len(nr) %% 2 == 0])
  mm <- pt / 2.845
  p <- ggplot() +
    annotate("rect", xmin = 0, xmax = sum(w), ymin = 0, ymax = 1, fill = "#E4E4E4") +
    geom_rect(data = zebra, aes(xmin = 0, xmax = sum(w), ymin = row, ymax = row + 1), fill = "#F6F6F6") +
    geom_text(data = head, aes(x, 0.5, label = label, hjust = hj), family = FONT_FAMILY,
              fontface = "bold", size = mm) +
    geom_text(data = cells, aes(x, row + 0.5, label = label, hjust = hj), family = FONT_FAMILY, size = mm) +
    annotate("segment", x = 0, xend = sum(w), y = c(0, 1, nr + 1), yend = c(0, 1, nr + 1),
             colour = "#555555", linewidth = 0.3) +
    scale_y_reverse(limits = c(nr + 1, 0), expand = c(0, 0)) +
    scale_x_continuous(limits = c(0, sum(w)), expand = c(0, 0)) +
    labs(title = title, subtitle = subtitle, caption = wrap_note) +
    theme_void(base_family = FONT_FAMILY) +
    theme(plot.title = element_text(face = "bold", size = pt + 1.5, margin = margin(b = 3)),
          plot.subtitle = element_text(size = pt - 0.5, colour = "#444444", margin = margin(b = 4)),
          plot.caption = element_text(size = pt - 1, colour = "#444444", hjust = 0, margin = margin(t = 4)),
          plot.title.position = "plot", plot.caption.position = "plot",
          plot.margin = margin(4, 6, 4, 6))
  ggsave(file.path(image_dir(paste0("tbl_", name)), paste0("tbl_", name, ".png")), p, width = width_cm, height = height_cm,
         units = "cm", dpi = 300, bg = "white", limitsize = FALSE)
  invisible(df)
}
