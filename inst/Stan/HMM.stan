data {
  int<lower=1> T;         // number of occasions
  int<lower=1> I;         // number of tracks
  int<lower=1> N;         // number of states
  int nCovs;              // number of covariates
  matrix[T,2] loc;        // observed location
  matrix[T,2] sigma;      // measurement error
  array[I,2] int index;   // track start and end
  matrix[T,nCovs+1] covs; // covariates
  vector[T] w;            // proportions of time intervals
}

transformed data {
  matrix[T,2] loc_c; // centred location
  
  for (i in 1:2)
    loc_c[,i] = loc[,i] - mean(loc[,i]);
}

parameters {
  matrix[T,2] y;                  // real location
  matrix[N*(N-1),nCovs+1] beta;   // transition parameters
  vector<lower=0>[2] tau;         // sd for process model
  vector<lower=0,upper=1>[N] cor; // correlation between steps
}

transformed parameters {
  matrix[T,2] y_c;   // centred location estimates
  matrix[2,2] Omega; // MVN diag matrix
  
  for (i in 1:2)
    y_c[,i] = y[,i] - mean(loc[,i]);
  
  Omega = diag_matrix(tau);
}

model {
  matrix[T,2] mu1;
  vector[N] logp;
  vector[N] logptemp;
  array[T] matrix[N,N] gamma;
  array[T] matrix[N,N] log_gamma;
  array[T] matrix[N,N] log_gamma_tr;

  // PRIORS
  tau ~ exponential(20);

  // Transition probabilities
  for (t in 1:T) {
    int betarow = 1;
    for (i in 1:N) {
      for (j in 1:N) {
        if (i==j) {
          gamma[t,i,j] = 1;
        } else {
          gamma[t,i,j] = exp(beta[betarow] * to_vector(covs[t]));
          betarow = betarow + 1;
        }
      }
    }
    // each row must sum to 1
    for (i in 1:N)
      log_gamma[t][i] = log(gamma[t][i] / sum(gamma[t][i]));
  }

  // Transpose
  for (t in 1:T)
    for (i in 1:N)
      for (j in 1:N)
        log_gamma_tr[t,j,i] = log_gamma[t,i,j];

  for (i in 1:I) {
    int t1 = index[i,1];
    int t2 = index[i,2];

    // estimate first two location
    y_c[t1,] ~ student_t(5, loc_c[t1,], sigma[t1,]);
    y_c[t1+1,] ~ multi_normal(y_c[t1,], Omega);
    for (t in (t1+1):(t2-1)) {
      // initialise forward variable
      if (t==t1+1)
        logp = rep_vector(-log(N), N);

      // State-based process equation
      for (n in 1:N) {
        mu1[t,] = y_c[t,] + (y_c[t,] - y_c[t-1,]) * cor[n];
        logptemp[n] = log_sum_exp(to_vector(log_gamma_tr[t,n]) + logp) + 
          multi_normal_lpdf(y_c[t+1,] | mu1[t,], Omega);
      }
      logp = logptemp;

      // add log forward variable to target at the end of each track
      if (t==t2-1)
        target += log_sum_exp(logp);
    }
  }

  // OBSERVATION MODEL
  {
    matrix[T,2] mu2;
    for (t in 2:T){
      mu2[t,] = w[t] * y_c[t,] + (1 - w[t]) * y_c[t-1,];
    }
    loc_c[2:T,1] ~ student_t(5, mu2[2:T,1], sigma[2:T,1]);
    loc_c[2:T,2] ~ student_t(5, mu2[2:T,2], sigma[2:T,2]);
  }
}
