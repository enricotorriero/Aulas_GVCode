library(cluster) # for gower similarity and pam
library(Rtsne) # for t-SNE plot
library(ggplot2) # for visualization
library(dplyr) # for data management

seg <- read.csv("C:/Users/Pohlmann/Documents/FGV/GVCode/Aulas2sem/Comp_Dummmies.csv",header=TRUE)
normalize <- function(x){
  return ((x-min(x))/(max(x)-min(x)))
}
segNorm <- as.data.frame(lapply(seg,normalize))

cols <- colnames(segNorm)
cols <- cols[-c(1,5)] # 1 � o ID, que n�o interessa de qualquer maneira, e 5 � renda familiar, que n�o � categ�rico
segNorm[cols] <- lapply(segNorm[cols], as.factor) # lapply aplica uma fun��o a um objeto v�rias vezes

segNorm$ID <- NULL # remove ID, porque n�o adiciona nada

# Calcula as dist�ncias entre os pontos pela m�trica de Gower
# ?daisy # Para saber tudo o que a fun��o daisy faz
gower_dist <- daisy(segNorm,
                    metric="gower") # Calcula a dist�ncia entre os pontos do objeto pelo m�todo de Gower
summary(gower_dist) # Para ver se deu certo
gower_mat <- as.matrix(gower_dist) # Transforma o objeto em uma matriz para parsear e clusterizar
segNorm[which(gower_mat==min(gower_mat[gower_mat!=min(gower_mat)]),arr.ind = TRUE)[1, ],] #most similar pair
segNorm[which(gower_mat==max(gower_mat[gower_mat!=max(gower_mat)]),arr.ind = TRUE)[1, ],] #most dissimilar pair
sil_width <- c(NA) # para o gr�fico que diz o n�mero ideal de clusters

# particiona as dist�ncias pelo m�todo PAM, Particionamento Em torno de Medoides
for(i in 2:15){
  
  pam_fit <- pam(gower_dist,
                 diss = TRUE,
                 k = i)
  
  sil_width[i] <- pam_fit$silinfo$avg.width # atualizar o gr�fico do n�mero ideal de clusters
  
}
plot(1:15, sil_width,
     xlab = "Number of clusters",
     ylab = "Silhouette Width")
lines(1:15, sil_width) # O pico do gr�fico representa a quantidade ideal, que minimiza o erro

pam_fit <- pam(gower_dist, diss = TRUE, k = 3) # k=3 porque o número ideal foi 3
pam_results <- segNorm %>%
  mutate(cluster = pam_fit$clustering) %>%
  group_by(cluster) %>%
  do(the_summary = summary(.)) # finalmente termina o particionamento dos dados
pam_results$the_summary
med <- segNorm[pam_fit$medoids,] # cria um objeto mais permanente para ver os medoides

tsne_obj <- Rtsne(gower_dist, is_distance = TRUE) # Resume as dimens�es do problema em um objeto tsne de 2 dimens�es

tsne_data <- tsne_obj$Y %>%
  data.frame() %>%
  setNames(c("X", "Y")) %>%
  mutate(cluster = factor(pam_fit$clustering)) # trabalha os dados do objeto tsne

ggplot(aes(x = X, y = Y), data = tsne_data) +
  geom_point(aes(color = cluster)) + ggtitle("P.A.M.") # faz os gr�ficos

# Comparando com K-m�dias. Mesma métrica de dist��ncia e fator de redu��o de dimens�es
kmn <- kmeans(gower_mat,centers = 3)
kmn$cluster <- as.factor(kmn$cluster)

tsne_data_k <- tsne_obj$Y %>%
  data.frame() %>%
  setNames(c("X", "Y")) %>%
  mutate(cluster = factor(kmn$cluster))
ggplot(aes(x = X, y = Y), data = tsne_data_k) +
  geom_point(aes(color = cluster)) + ggtitle("K-Means")

# Comparando com Clustering Histogr�fico
clust <- hclust(gower_dist, method="ward.D2")
plot(clust)
groups <- cutree(clust, k=3) # corta para separar os clusters no n�mero definido acima
rect.hclust(clust, k=3, border="red")

# Para ver os tamanhos dos clusters em cada método
table(pam_fit$clustering)
table(kmn$cluster)
table(groups)

# Por que n�o usar dist�ncia Euclidiana ou Manhattan para separar os dados?
# Dados categ�ricos complicam as an�lises de dist�ncia
# Com dados mistos a fun��o daisy automaticamente roda a dist�ncia de Gower
mnht_dist <- daisy(segNorm[,-1], metric="manhattan")
mnht_mat <- as.matrix(mnht_dist)
kmn_m <- kmeans(mnht_mat,centers = 3)
kmn_m$cluster <- as.factor(kmn_m$cluster)

tsne_obj_m <- Rtsne(mnht_dist, is_distance = TRUE)

tsne_data_m <- tsne_obj_m$Y %>%
  data.frame() %>%
  setNames(c("X", "Y")) %>%
  mutate(cluster = factor(kmn_m$cluster))
ggplot(aes(x = X, y = Y), data = tsne_data_m) +
  geom_point(aes(color = cluster)) + ggtitle("Manhattan")

eucl_dist <- daisy(segNorm[,-1], metric="euclidean")
eucl_mat <- as.matrix(eucl_dist)
kmn_e <- kmeans(eucl_mat,centers = 3)
kmn_e$cluster <- as.factor(kmn_e$cluster)

tsne_obj_e <- Rtsne(mnht_dist, is_distance = TRUE)

tsne_data_e <- tsne_obj_e$Y %>%
  data.frame() %>%
  setNames(c("X", "Y")) %>%
  mutate(cluster = factor(kmn_e$cluster))
ggplot(aes(x = X, y = Y), data = tsne_data_e) +
  geom_point(aes(color = cluster)) + ggtitle("Euclidean")

# Comparando diferentes m�todos de proje��o em 2D
library(ggfortify)
pca_obj <- prcomp(gower_dist, center=TRUE, scale. = TRUE)
plot(pca_obj,type="l")
autoplot(kmn_e, data=eucl_dist,frame=TRUE,frame.type='norm') +ggtitle("Euclidean")
autoplot(kmn_m,data=mnht_dist,frame=TRUE,frame.type='norm') +ggtitle("Manhattan")
autoplot(kmn,data=gower_dist, frame=TRUE,frame.type='norm') +ggtitle("Gower")

# TSNE: https://lvdmaaten.github.io/tsne/
# PCA: https://www.r-bloggers.com/computing-and-visualizing-pca-in-r/
# PCA também: https://cran.r-project.org/web/packages/ggfortify/vignettes/plot_pca.html
# Fonte dos métodos: https://www.r-bloggers.com/clustering-mixed-data-types-in-r/
# Fonte adicional: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4939904/