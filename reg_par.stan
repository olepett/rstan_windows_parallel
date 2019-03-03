functions {
  vector bl_glm(vector sigma_beta, vector theta,
                real[] xs, int[] xi) {
	int J = xi[1];
	int K = xi[2];			
	real lp;
    real sigma = sigma_beta[1];
	vector[K] beta= sigma_beta[2:(K+1)];
    lp=normal_lpdf(xs[1:J] | to_matrix(xs[(J+1):(J*(K+1))],J,K) * beta, sigma);
    return [lp]';
  }
}

data {
  int<lower = 0> K;
  int<lower = 0> shards;
  int<lower = 0> N;
  matrix[N,K] X;
  vector[N] Y;
}

transformed data {
vector[0] theta[shards];
  int<lower = 0> J = N / shards;      
  real x_r[shards, J * (K+1)];
  int x_i[shards, 2];
  {
    int pos = 1;
    for (k in 1:shards) {
      int end = pos + J - 1;
      x_r[k] = to_array_1d(append_col(Y[pos:end],X[pos:end,]));
      x_i[k,1] = J;
      x_i[k,2] = K;
      pos += J;
    }
  }
}

parameters {
  vector[K] beta;
  real<lower=0> sigma;
}

model {
  beta ~ normal(0, 2);
  sigma ~ normal(0, 2);
  target += sum(map_rect(bl_glm, append_row(sigma, beta),
                         theta, x_r, x_i));
}
