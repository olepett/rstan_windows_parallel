library(rstan)
Sys.setenv(STAN_NUM_THREADS=4)


dotR <- file.path(Sys.getenv("HOME"), ".R")
if (!file.exists(dotR)) dir.create(dotR)
M <- file.path(dotR, "Makevars")
if (!file.exists(M)) file.create(M)
cat("CXX14 = g++",
    "\nCXX14FLAGS = -DSTAN_THREADS",
    "\nCXX14FLAGS += -O3 -march=native -mtune=native",
    "\nCXX14FLAGS += -fPIC",
    "\n",
    file = M, sep = "", append = FALSE)


set.seed(42)
K <- 10
N <- 100
X <- matrix(rnorm(K*N), ncol=K)
beta <- rnorm(K)
Y <- as.vector(X %*% beta + rnorm(N))
shards <- 4

data <- 
  list(
    K=K,
    N=N,
    X=X,
    Y=Y,
    shards=shards
  )


m0 <- 
  stan(
    file = "rstan_windows_parallel/linreg.stan",
    data=data, 
    chains=1 )

m1 <- 
  stan(
    file = "rstan_windows_parallel/reg_par.stan",
    data=data, 
    iter = 5000,
    chains=1,
    cores = 4)

par(mfrow=c(2,1))
plot(head(summary(m0)$summary[,1],K),beta, 
     xlab="Posterior means, baseline", 
     ylab="True values", 
     main="Regression Coefficients")

plot(head(summary(m1)$summary[,1],K),beta, 
     xlab="Posterior means, parallel", 
     ylab="True values", 
     main="Regression Coefficients")
par(mfrow=c(1,1))








