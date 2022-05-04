# Proteomics_characterization. Follicular fluid from ovarian small antral follicles (hSAF)
This repository contains R code used to perform the data analysis descrived in the manuscript:

### Proteome of fluid from human ovarian small antral follicles reveals insights in folliculogenesis and oocyte maturation. https://doi.org/10.1093/humrep/deaa335

#### File: analysis of Metaphase II samples.R
To assess whether there were differences at protein level between FF that surrounded oocytes that matured or remained immature, a sparse partial least squares discriminant analysis (sPLS-DA) (Chung and Keles, 2010) was performed using ‘mixOmics’ R package. To select the top 100 most informative predictors (e.g. proteins) for discriminating samples, an LASSO penalisation was applied. With the top 100 proteins, a hierarchical clustering plus heatmap was performed using ‘ComplexHeatmap’ R library. In addition to the multivariable analysis, a Student t-test (two-tails) followed by FDR correction was performed to determine differentially expressed proteins. Proteins with an adjusted P-value <0.05 were considered significant. Since FF samples surrounding the immature oocyte and FF samples surrounding the MII oocyte originated in the same woman, the analyses (the multivariable and univariate) were performed considering the paired nature of the samples.

#### File: GOChord.R
This code perform a Chord plot to visualize a pathway enrichment analysis performed in FunRich software. Proteins that significantly correlated with MDK/VIM were subjected to a biological pathway enrichment analysis in FunRich (background: FunRich database) and pathways with a significant enrichment score (BH method: adj. P-value <0.05) were visualized using a Chord plot.
