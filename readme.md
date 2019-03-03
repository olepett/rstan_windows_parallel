# RStan in Parallel on Windows

v0 - Ole-Petter Moe Hansen, March 03. 2019

### Introduction
In 2018, [Stan](https://mc-stan.org/) relased support for parallelism within a single MCMC-chain. However, it has been a challenge to get threading to work in  Windows. The issue is related to compilers, and hence affects PyStan, CmdStan and Rstan. 

A simple escape from the problem is to switch OS to e.g. Linux. However, if you e.g. work in a corporate world this might not be feasible. 

In this tutorial I'll show how you can run RStan in parallel on Windows using [Docker](https://www.docker.com/). Docker allows you to run applications within containers, and 

### Requirements

You'll need these pieces of software to get up and running: 

- Windows with the [Hyper-V ](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/about/)-feature. This comes with e.g. Win 10 Pro. 

- [Docker desktop](https://www.docker.com/products/docker-desktop). The community version is free, and has what you need to get going. 

### Setup and initialisation
#### Docker settings
Once you have installed docker, you'll need to allocate resources to the container. It is easiest done by right clicking the docker icon in the system tray. In the settings window, click settings -> Advanced. Set CPU's to 2 or higher, also enough memory. These settings defines the resources allocated to Docker. See [here](https://docs.docker.com/config/containers/resource_constraints/) for more on resources in Docker. I will assume this is set to at least 4. 

In the same settings Window, click "Shared Drives". If you mark a disk here, it will be available to you in the container. I have marked my C-drive.

For this example, I will assume you have a folder `c:\rstan_windows_parallel` containing the files from this repo. 

#### Initialising the container
I use the docker image by [Jeff Arnold](https://hub.docker.com/r/jrnold/rstan/). This is an image built from [Rocker](https://www.rocker-project.org/), which contains R, Rstudio and RStan (and more).

Open the command prompt, and enter the following: 
```
docker run -e PASSWORD=rpass --rm -p 8787:8787 -v /c/rstan_windows_parallel:/home/rstudio/rstan_windows_parallel jrnold/rstan
```
A few notes: 

- The password argument is required from the Rocker-image, and must be supplied. Feel free to replace it with something else. 

- `/c/rstan_windows_parallel:/home/rstudio/rstan_windows_parallel` makes the folder `c:\rstan_windows_parallel` available in the container

- `jrnold/rstan` is the image we will use. First time you issue the command it will start a large download. 

If successful, the terminal will end with the line `[services.d] done`. You can now open a browser, and type `localhost:8787`. Enter username "Rstudio" and the password you specified above, and you should see a tab with RStudio up and running. 

#### Initialising R and RStan
The following explains the setup in the `run_models.R`-file. First, we load Rstan, and specify the number of cores allocated to each MCMC-chain with the `STAN_NUM_THREADS`-argument.  
```
library(rstan)
Sys.setenv(STAN_NUM_THREADS=4)
```

Next, we need to edit the `makevars'-file with settings for the compiler. The following lines works for me:
```
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
```

The contents of the makevars file can now be read with:
```
writeLines(readLines(M))
```
...which should return: 
```
CXX14 = g++
CXX14FLAGS = -DSTAN_THREADS
CXX14FLAGS += -O3 -march=native -mtune=native
CXX14FLAGS += -fPIC
```

### Example: Linear, parallel regression
This is a toy example where threading won't save much time, but should let you see several cores working. The baseline model is a linear, normal regression with K explanatory variables, and informative normal priors on coefficients and the scale parameter. The `linreg.stan`-file contains the model: 
```
data {
  int<lower = 0> K;
  int<lower = 0> N;
  matrix[N,K] X;
  vector[N] Y;
}

parameters {
  vector[K] beta;
  real<lower=0> sigma;
}

model {
  beta ~ normal(0, 2);
  sigma ~ normal(0, 2);
  Y~normal(X*beta, sigma);
}
```

[Richard McElreath](https://github.com/rmcelreath/cmdstan_map_rect_tutorial) has a nice, minimal introduction to threading in Stan-models, so I'll skip the explanations here. The file `reg_par.stan` contains a parellel version of the linear model. 


In R, we simulate some data:
```
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
```

... and we can run the linear model: 
```
m0 <- 
  stan(
    file = "rstan_windows_parallel/linreg.stan",
    data=data, 
    chains=1 )
```

Similarly, the parallel version can be run with:
```
m1 <- 
  stan(
    file = "rstan_windows_parallel/reg_par.stan",
    data=data, 
    chains=1,
    cores = 4)

```
However, to check that you are indeed using several cores, you might want to set `iter=5000` or another high number. This ensures estimation takes long enough to be able to see the CPU-load increasing on several cores. 

Finally, we can plot the posterior means against true values and see that the model recovers the true values: 
```
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

```



