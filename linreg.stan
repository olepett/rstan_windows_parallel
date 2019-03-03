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
