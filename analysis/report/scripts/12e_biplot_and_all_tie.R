# =============================================================================
# 12e_biplot_and_all_tie.R
#
# a. PCA biplot: first two components of the four key metrics (log(1 + x), standardised, fitted on the whole
#    main corpus); a 30,000-method random sample as a density, loading arrows, and the 34 survey snippets
#    (originals orange, variants blue), labelling only snippets outside the corpus 90% ellipse.
# b. Forest plot: share of decisive responses preferring the later version on the seven pairs where all four
#    key metrics tie (comments / Javadoc / naming changes), Wilson 95% CIs, reference line at 50%.
# No titles.
# =============================================================================

source("scripts/00_setup.R")
suppressPackageStartupMessages(library(ggrepel))
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
responses <- readRDS(file.path(PATHS$work, "responses.rds"))
rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
snip <- read_csv(PATHS$snippets, show_col_types = FALSE)
pids <- participants$pid
bh <- boot_helpers(pids)

# ---- a. PCA biplot ----------------------------------------------------------------------------------------------
d <- readRDS(file.path(PATHS$work, "corpus_key.rds"))
m <- d[main == TRUE]
X <- log1p(as.matrix(m[, ..METRICS])); colnames(X) <- unname(METRIC_LABELS[METRICS])
pr <- prcomp(X, center = TRUE, scale. = TRUE)
var_share <- pr$sdev^2 / sum(pr$sdev^2)
validate("biplot: the PCA reproduces the corpus PC1 share recorded in the corpus script (88.7%)", abs(var_share[1] - 0.8873) < 0.01,
         sprintf("%.4f", var_share[1]))
set.seed(SEED)
idx <- sample.int(nrow(X), 30000)
project <- function(M) scale(M, center = pr$center, scale = pr$scale) %*% pr$rotation[, 1:2]
samp <- as.data.frame(project(X[idx, ])); names(samp) <- c("PC1", "PC2")
S <- as.matrix(snip[, METRICS]); colnames(S) <- unname(METRIC_LABELS[METRICS])
sn <- as.data.frame(project(log1p(S))); names(sn) <- c("PC1", "PC2")
sn$id <- snip$id; sn$kind <- ifelse(snip$variant == "ORIG", "Original", "Variant")
mu <- colMeans(samp); cv <- cov(samp); rad <- sqrt(qchisq(0.90, 2))
ev <- eigen(cv); th <- seq(0, 2 * pi, length.out = 200)
ell <- as.data.frame(t(mu + ev$vectors %*% diag(sqrt(ev$values)) %*% rbind(rad * cos(th), rad * sin(th)))); names(ell) <- c("PC1", "PC2")
sn$maha <- sqrt(mahalanobis(sn[, c("PC1", "PC2")], mu, cv)); sn$outside <- sn$maha > rad
share_in_ellipse_sample <- mean(sqrt(mahalanobis(samp, mu, cv)) <= rad)
validate("biplot: the 90% ellipse holds about 90% of the sampled corpus methods", abs(share_in_ellipse_sample - 0.9) < 0.03, sprintf("%.3f", share_in_ellipse_sample))
record("PCA biplot: survey snippets outside the corpus 90% ellipse in PC1-PC2", sum(sn$outside), denominator = nrow(sn), section = "RQ1: biplot",
       note = paste(sn$id[sn$outside], collapse = ", "))
record("PCA biplot: PC1 share of variance", var_share[1], n = nrow(X), section = "RQ1: biplot", note = "log(1+x), standardised, main corpus")
record("PCA biplot: PC2 share of variance", var_share[2], n = nrow(X), section = "RQ1: biplot")
save_table(sn |> select(id, kind, PC1, PC2, maha, outside), "rq1_biplot_snippet_scores")
ld <- as.data.frame(pr$rotation[, 1:2]); ld$metric <- rownames(ld)
# Arrows are scaled so the longest reaches about 80% of the way to the snippet farthest from the centre
karrow <- 0.8 * max(sqrt(sn$PC1^2 + sn$PC2^2)) / max(sqrt(ld$PC1^2 + ld$PC2^2))
ld <- ld |> mutate(x = PC1 * karrow, y = PC2 * karrow)
p_biplot <- ggplot() +
  geom_bin2d(data = samp, aes(PC1, PC2), bins = 90) +
  scale_fill_viridis_c(trans = "log10", name = "Corpus methods per cell", option = "D", direction = -1, alpha = 0.9,
                       guide = guide_colourbar(order = 2, barwidth = 6, barheight = 0.5, title.position = "top")) +
  geom_path(data = ell, aes(PC1, PC2), colour = "#333333", linewidth = 0.45, linetype = "dashed") +
  geom_segment(data = ld, aes(x = 0, y = 0, xend = x, yend = y), arrow = arrow(length = unit(0.15, "cm")), linewidth = 0.7, colour = "#222222") +
  geom_text_repel(data = ld, aes(x = x, y = y, label = metric), size = 3.2, family = FONT_FAMILY, fontface = "bold", colour = "#222222",
                  box.padding = 0.9, point.padding = 0.3, seed = SEED, segment.size = 0.2, min.segment.length = 0.3) +
  geom_point(data = sn, aes(PC1, PC2, colour = kind, shape = kind), size = 2.4) +
  geom_text_repel(data = sn[sn$outside, ], aes(PC1, PC2, label = id, colour = kind), size = 2.6, family = FONT_FAMILY, seed = SEED, max.overlaps = Inf,
                  box.padding = 0.35, segment.size = 0.25, min.segment.length = 0, show.legend = FALSE) +
  scale_colour_manual(values = c(Original = ORIG_COLOUR, Variant = REFACTOR_COLOUR), name = "Survey snippets") +
  scale_shape_manual(values = c(Original = 16, Variant = 17), name = "Survey snippets") +
  labs(x = sprintf("PC1 (%.1f%% of the variance)", 100 * var_share[1]), y = sprintf("PC2 (%.1f%% of the variance)", 100 * var_share[2])) +
  theme_report() + theme(legend.box = "horizontal", legend.title = element_text(size = 8), legend.box.just = "bottom") +
  guides(colour = guide_legend(order = 1), shape = guide_legend(order = 1))
save_fig(p_biplot, "diag_rq1_pca_biplot", height_cm = 11, rq = "RQ1",
         purpose = "PCA biplot: corpus density (30,000-method sample), loadings of the four metrics, and the 34 survey snippets (originals orange, variants blue); dashed ellipse holds 90% of corpus methods; only snippets outside it are labelled")

# ---- b. All-tie pairs ---------------------------------------------------------------------------------------------
all_tie <- rq2$all_tie
what <- c(Q1C = "comments", Q2C = "Javadoc", Q5C = "naming", Q5D = "comments", Q5J = "naming vs comments", Q6B = "naming", Q7C = "comments")
validate("all-tie forest: the seven all-tie pairs are the ones described in the snippet catalogue", setequal(all_tie$item, names(what)), paste(all_tie$item, collapse = ", "))
at <- all_tie |>
  mutate(decisive = chose_A + chose_B, k = chose_B, share = k / decisive,
         label = sprintf("%s  %s vs %s (%s)", item, method_a_id, method_b_id, what[item]), pooled = FALSE)
w <- t(mapply(function(k, n) wilson_ci(k, n), at$k, at$decisive))
at$low <- w[, 1]; at$high <- w[, 2]
tie_resp <- responses |> filter(item %in% all_tie$item)
pool <- boot_ratio_ci(bh$W, bh$psum(tie_resp$human == 1 & tie_resp$human != 0, tie_resp$pid), bh$psum(tie_resp$human != 0, tie_resp$pid))
pool_row <- tibble::tibble(item = "Pooled", label = "Pooled (participant bootstrap)", k = sum(tie_resp$human == 1), decisive = sum(tie_resp$human != 0),
                           share = sum(tie_resp$human == 1) / sum(tie_resp$human != 0), low = pool[["low"]], high = pool[["high"]], pooled = TRUE)
fa <- bind_rows(at |> select(item, label, k, decisive, share, low, high, pooled), pool_row)
validate("all-tie forest: pooled counts match the all-tie numbers recorded earlier (61 of 75)", pool_row$k == 61 && pool_row$decisive == 75,
         sprintf("%d of %d", pool_row$k, pool_row$decisive))
save_table(fa, "rq2_all_tie_forest")
record("all-tie pairs: pooled share of decisive responses preferring the later version (participant bootstrap interval)", pool_row$share, pool_row$low, pool_row$high,
       n = pool_row$k, denominator = pool_row$decisive, test = "participant cluster bootstrap 95% CI", section = "RQ2: all-tie pairs",
       note = sprintf("%d of the 7 pairs have a Wilson interval above 50%%", sum(at$low > 0.5)))
fa <- fa |> arrange(pooled, desc(share)) |> mutate(label = factor(label, levels = rev(label)))
p_alltie <- ggplot(fa, aes(share, label)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#777777", linewidth = 0.4) +
  geom_errorbar(aes(xmin = low, xmax = high, colour = pooled), width = 0.28, orientation = "y", linewidth = 0.55) +
  geom_point(aes(shape = pooled, colour = pooled, size = pooled)) +
  geom_text(aes(x = 1.02, label = sprintf("%d/%d", k, decisive)), hjust = 0, size = 2.7, family = FONT_FAMILY) +
  scale_colour_manual(values = c(`FALSE` = "#4D4D4D", `TRUE` = "#B2182B"), guide = "none") +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 18), guide = "none") +
  scale_size_manual(values = c(`FALSE` = 2.2, `TRUE` = 4), guide = "none") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1.12), breaks = seq(0, 1, 0.25), expand = c(0, 0)) +
  labs(x = "Share of decisive responses preferring the later version (B)", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
save_fig(p_alltie, "diag_rq2_all_tie_forest", height_cm = 7, rq = "RQ2",
         purpose = "The seven pairs where CC, CogC, LOC and MaxNest all tie: share of decisive responses preferring the later version, with Wilson 95% CIs per pair and the pooled participant-bootstrap estimate in red; dashed line = 50%")

save_figure_registry("12e_biplot_and_all_tie")
save_numbers("12e_biplot_and_all_tie")
save_validation("12e_biplot_and_all_tie")
cat("Biplot and all-tie figures done\n")
