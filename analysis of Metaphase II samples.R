#========Follicular fluid from unstimulated ovarian small antral follicles=====Metaphase II samples=

#   Paper: Proteome of fluid from human ovarian small antral follicles reveals insights in folliculogenesis and oocyte maturation
# Authors: Indira Pla, Aniel Sanchez, Susanne Elisabeth Pors, Krzysztof Pawlowski, Roger Appelqvist, K Barbara Sahlin, 
#          Liv La Cour Poulsen, György Marko-Varga, Claus Yding Andersen, Johan Malm Author Notes


#====INSTALL PACKAGES================================================================================

# List of packages to install
.packages = c("BiocManager","devtools","ggplot2","ggbiplot","graphics","reshape2","dplyr","ggpubr","mixOmics", 
              "ComplexHeatmap","Hmisc")


# Install packages if not installed
.inst <- .packages %in% installed.packages()
if(length(.packages[!.inst]) > 0) {install.packages(.packages[!.inst])
  install_github("vqv/ggbiplot")
  BiocManager::install(c("mixOmics","ComplexHeatmap"))
}

# Loading packages
lapply(.packages, require, character.only=TRUE)
#======END INSTALL PACKAGES============================================================================

##http://mixomics.org/graphics/sample-plots/plotindiv/

#=====Loading dataset================================================================================== 
# Download files "meta2_2020_short4_paired.xlsx", "annotation_col.xlsx" and "ttest.results_100.xlsx" to your computer and 
# read (upload) them from RStudio to start doing the analysis.

# Protein expression data
table_paired <- as.data.frame(readxl::read_excel("./meta2_2020_short4_paired_.xlsx")) # uploading the data
class(table_paired)
rownames(table_paired) <- paste(table_paired$Accession,".",table_paired$`Gene`)

# sample annotations
Annotations <- as.data.frame(readxl::read_excel("./annotation_col.xlsx"))
row.names(Annotations) <- Annotations$sample

# protein annotation
row.Annotations <- as.data.frame(readxl::read_excel("./ttest.results_100.xlsx")) # Open the data
class(row.Annotations)
rownames(row.Annotations) <- row.Annotations$Gene
row.Annotations$Log10.p <- log10(row.Annotations$q.values)*(-1)

##====sPLS-DA and PCA with paired data =========MULTIVARIATE ANALYSIS ============

# Previously, we subtracted from the protein intensity of a given sample, 
# the mean of the two samples belonging to the patient from which they were taken. 

main.data <- table_paired %>% select(contains("P_"))  #as.data.frame(table_paired[, 11:ncol(table_paired)])

main.data <- as.data.frame(t(main.data))

cond.names <- as.factor(c(rep("competent (MII)",7),rep("non-competent",7)))

# PCA
pca.res <- mixOmics::pca(main.data, ncomp = 5)

plotIndiv(pca.res, group = cond.names, legend = TRUE, title = 'PCA paired',
          ind.names = T,ellipse = T,comp = 1:2)   

# sPLS-DA
splsda.res <- mixOmics::splsda(main.data, cond.names, ncomp = 5,
                               mode = "regression", keepX = (c(100,100,100)))
# sPLS-DA plot
explained.variance <- splsda.res$explained_variance$X

plotIndiv(splsda.res, ind.names = F, legend = TRUE, ellipse = TRUE,
          title = 'sPLS-DA',comp = 1:2,style = 'ggplot2',
          X.label=paste("Component 1 (",round(explained.variance[1]*100,0),"%)",sep = ""), 
          Y.label = paste("Component 2 (",round(explained.variance[2]*100,0),"%)",sep = ""))

# The plot Loading function displays the loading weights, 
plotLoadings(splsda.res, comp = 1, title = 'Loadings on comp 1', size.name = 0.3,
             contrib = 'max', method = 'mean',ndisplay=100)#,ndisplay=50)

# CIM results

cim.results <- cim(splsda.res, comp = 1, xlab = "proteins", ylab = "sample",col.cex=0.85,
                   margins = c(7, 7),row.sideColors = cond.row,zoom = F)
cim.matrix <- cim.results$mat

# saving matrixs
loading.matrix.X <- splsda.res$loadings$X
#write.csv(loading.matrix.X,"loading.matrix.X_top100.csv")

##====STUDENT t-test with paired data=======UNIVARIATE ANALYSIS ============      

loading.matrix.X <- as.data.frame(loading.matrix.X)
head(loading.matrix.X)

loading.matrix.X.100 <- subset(loading.matrix.X, loading.matrix.X$comp1!=0)
loading.matrix.X.100$sample <- row.names(loading.matrix.X.100)

main.data <- table_paired %>% select(contains("P_"))  #as.data.frame(table_paired[, 11:ncol(table_paired)])

m.ttest <- as.data.frame(main.data)    #Proteins expression to be evaluated
m.ttest$sample <- row.names(m.ttest)

m.ttest1 <- plyr::join_all(list(loading.matrix.X.100,m.ttest), by="sample")   # matriz with the top 100 proteins that most contribute to distinguish in the sPLS-DA analysis 
row.names(m.ttest1) <- m.ttest1$sample
m.ttest1 <- m.ttest1[,7:ncol(m.ttest1)]

cond.names <- as.factor(c(rep("competent (MII)",7),rep("non-competent",7)))
cond <- as.data.frame(cond.names)
cond$sample <- colnames(m.ttest1)          #conditions to compare

ttest.proteome <- function(m, groups){
  
  ttest <- matrix(nrow=nrow(m),ncol = 4)
  
  for (i in 1:nrow(m)) {
    
    prot.data <- as.data.frame(t(m[i,]))
    prot.data$sample <- row.names(prot.data)
    
    data <- join_all(list(prot.data,groups),by="sample")
    row.names(data) <- data$sample
    data <- data[,-2]
    
    #==ttest
    ttest1 <- t.test(data[,1]~data[,2], var.equal = T)
    
    ttest[i,1] <- ttest1$conf.int[1]
    ttest[i,2] <- ttest1$conf.int[2]
    ttest[i,3] <- ttest1$estimate[1]-ttest1$estimate[2]
    ttest[i,4] <- ttest1$p.value 
  }
  
  row.names(ttest) <- row.names(m)
  colnames(ttest) <- c("Lower Limit", "Upper Limit","Log2.Fold change","p.v_t.test")
  
  ttest <- as.data.frame(ttest)
  
  # Adjusting p-values by FDR multitesting
  
  ttest$q.values <- p.adjust(ttest$p.v_t.test, method = "fdr")
  
  for (j in 4:ncol(ttest)){
    
    ttest$sig <- cut(ttest[,j], breaks=c(-Inf, 0.001, 0.01, 0.05, Inf), label=c("***", "**", "*", ""))
    
    colnames(ttest) <- c(colnames(ttest)[-c(length(colnames(ttest)))],paste("Sig_",colnames(ttest)[j]))
  }
  
  return(ttest)
}

ttest.results <- ttest.proteome(m = m.ttest1,groups = cond)
ttest.results$`-Log10 p-values` <- log10(ttest.results$p.v_t.test)*(-1)

ttest.results$sample<- row.names(ttest.results)
ttest.results1 <- plyr::join_all(list(ttest.results,loading.matrix.X.100), by="sample")

#write.csv(ttest.results1, "ttest.results_100_2020.csv")

m.ttest0<-dplyr::select(m.ttest, -sample)
ttest.results <- ttest.proteome(m = m.ttest0,groups = cond)
ttest.results$`-Log10 p-values` <- log10(ttest.results$p.v_t.test)*(-1)

#write.csv(ttest.results, "ttest.results_all.csv")

##==========HEATMAP================================
library(ComplexHeatmap)
library(pheatmap)

cim.matrix <- as.data.frame(t(cim.matrix))
cim.matrix1 <- cim.matrix[ , !(names(cim.matrix) %in% c("P_982.46_B"))]

col.Annotation <- Annotations[,c("cond.","size" ,"patient","sample")]
colnames(col.Annotation) <- c(c("condition", "Follicular size","patient","sample"))
row.names(col.Annotation) <- col.Annotation$sample

break2 <- round(seq(min(cim.matrix1),max(cim.matrix1),length=101 ),2)

#Making a vector of gene codes
library(Hmisc)

gene.code.maker <- function(x){
  
  genes.code <- character()
  
  for (i in 1:nrow(x)){
    m <- row.names(x)[i]
    substring2(m, 1,(substring.location(m,".")[[1]])+1) <- ''
    genes.code[i] <- m
  }
  return(genes.code)
}

genes.code <- gene.code.maker(x=cim.matrix1)
genes.code


row.Annotations1 <- row.Annotations %>% select(c("Log2.Fold change","Log10.p", "secreted"))


ann_colors = list(
  `Log2.Fold change` = col4
)

row.names(cim.matrix1) <- genes.code

# Heatmap complex 

row.Annotations1 <- row.Annotations %>% select(c("Gene","Log2.Fold change","Log10.p", "secreted"))

cim.matrix1.m1 <- as.data.frame(cim.matrix1.m)
cim.matrix1.m1$Gene <- rownames(cim.matrix1.m)

loading.top100_gene <- gene.code.maker(loading.matrix.X.100)
loading.matrix.X.100$Gene <- loading.top100_gene

cim.matrix1.m1<-plyr::join_all(list(cim.matrix1.m1, row.Annotations1, loading.matrix.X.100, clust.ff),by="Gene")
row.names(cim.matrix1.m1)<- cim.matrix1.m1$Gene

ff <- as.data.frame(t(cim.matrix1.m))
ff$sample <- rownames(ff)
ff <- plyr::join_all(list(ff,col.Annotation),by = "sample")
col.Annotation1 <- as.data.frame(ff[,c("sample","condition","Follicular size","patient")])

matrix1 <- as.matrix(cim.matrix1.m1[,1:13])
matrix2 <- as.data.frame(cim.matrix1.m1[,14:ncol(cim.matrix1.m1)])

col3<- colorRampPalette(c("mediumblue","dodgerblue3", "lemonchiffon","coral2","red3"))(100)

# TOP ANNOTATIONS. 
# Define colors for each levels of qualitative variables
# Define gradient color for continuous variable (mpg)

col.top = list(condition = c("C" = "sienna1","M2" = "steelblue3"),
               `Follicular size` = colorRamp2(c(4,8), 
                                              c("white", "green")))
col.secreted = list(secreted = c("secreted" = "green3"))

# Create the heatmap annotation
ha.top <- HeatmapAnnotation(
  condition = col.Annotation1$condition,
  `Follicular size` = col.Annotation1$`Follicular size`,
  col = col.top, show_legend = T,simple_anno_size = unit(0.3, "cm"),
  patient=anno_simple(col.Annotation1$patient,pch=c(1:6, 1:7),pt_gp = gpar(col = "black"), pt_size = unit(1.5, "mm")))

row.annot <- rowAnnotation(comp1 = anno_barplot(matrix2$comp1,bar_width = 1, gp = gpar(col = ifelse(matrix2$comp1 > 0, "red", "blue"))),
                           prot = anno_text(matrix2$Gene, gp = gpar(fontsize = 5)))

row.annot1 <- rowAnnotation(comp1 = anno_barplot(matrix2$comp1,bar_width = 1),
                            prot = anno_text(matrix2$Gene, gp = gpar(fontsize = 5)))
# Combine the heatmap and the annotation
Heatmap(matrix1, name = "sPLS-DA (score)",row_names_gp = gpar(fontsize = 7), row_km = 3,column_km = 2,column_names_gp = gpar(fontsize = 8),
        top_annotation = ha.top, show_row_names = F,col = col3, show_column_names = T)+
  Heatmap(matrix2$`Log2.Fold change`, name = "Log2 Fold change", width = unit(3, "mm"),
          col = circlize::colorRamp2(c(-1, 0,1), c("cyan3","white", "orange2")))+
  Heatmap(matrix2$Log10.p, name = "-Log10.adj.p-value(t-test)", width = unit(3, "mm"),
          col = circlize::colorRamp2(c(1.32, 2,6), c("gold", "goldenrod2","goldenrod4")))+
  Heatmap(matrix2$secreted, name = "Secreted proteins", width = unit(3, "mm"), 
          col = col.secreted,show_row_names = T, right_annotation = row.annot1,row_names_side = "left")


ff<-kmeans(matrix1,centers = 3)
clust.ff<-as.data.frame(ff$cluster)
colnames(clust.ff)<- "cluster"
clust.ff$Gene<- row.names(clust.ff)
clust.ff$cluster<-as.factor(clus)

#END