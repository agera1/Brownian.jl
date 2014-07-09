# Fractional Brownian motion
immutable FBM <: ContinuousUnivariateStochasticProcess
  t::Vector{Float64}
  n::Int64
  h::Float64 # Hurst index

  function FBM(t::Vector{Float64}, n::Int64, h::Float64)
    t[1] == 0.0 || error("Starting time point must be equal to 0.0.")
    issorted(t, lt=<=) || error("The time points must be strictly sorted.")
    int64(length(t)) == n || error("Number of time points must be equal to the vector holding the time points.")
    0 < h < 1 || error("Hurst index must be between 0 and 1.")
    new(t, n, h)
  end
end

FBM(t::Vector{Float64}, h::Float64) = FBM(t, int64(length(t)), h)
FBM(t::Ranges, h::Float64) = FBM(collect(t), int64(length(t)), h)
FBM(t::Float64, n::Int64, h::Float64) = FBM(t/n:t/n:t, h)
FBM(t::Float64, h::Float64) = FBM([t], 1, h)

FBM(t::Matrix{Float64}, h::Float64) = FBM[FBM(t[:, i], h) for i = 1:size(t, 2)]
FBM(t::Ranges, np::Int, h::Float64) = FBM[FBM(t, h) for i = 1:np]
FBM(t::Float64, n::Int64, np::Int, h::Float64) = FBM[FBM(t, n, h) for i = 1:np]

# Fractional Gaussian noise
immutable FGN <: ContinuousUnivariateStochasticProcess
  σ::Float64
  h::Float64 # Hurst index

  function FGN(σ::Float64, h::Float64)
    σ > 0. || error("Standard deviation must be positive.")
    0 < h < 1 || error("Hurst index must be between 0 and 1.")
    new(σ, h)
  end
end

FGN(h::Float64) = FGN(1., h)

function autocov!(y::Vector{Float64}, p::FGN, lags::IntegerVector)
  nlags = length(lags)
  sigmasq = abs2(p.σ)
  twoh::Float64 = 2*p.h

  for i = 1:nlags
    y[i] = 0.5*sigmasq*(abs(lags[i]+1)^twoh+abs(lags[i]-1)^twoh-2*abs(lags[i])^twoh)
  end

  y
end

autocov(p::FGN, lags::IntegerVector) = autocov!(Array(Float64, length(lags)), p, lags)

function autocov(p::FBM, i::Int64, j::Int64)
  twoh::Float64 = 2*p.h
  0.5*((p.t[i])^twoh+(p.t[j])^twoh-abs(p.t[i]-p.t[j])^twoh)
end

function autocov(p::FBM)
  n::Int64 = p.n-1
  c = Array(Float64, n, n)

  for i = 1:n
    for j = 1:i
      c[i, j] = autocov(p, i+1, j+1)
    end
  end

  for i = 1:n
    for j = (i+1):n
      c[i, j] = c[j, i]
    end
  end

  c
end

### rand_chol generates FBM using the method based on Cholesky decomposition.
### T. Dieker, Simulation of Fractional Brownian Motion, master thesis, 2004.
### The complexity of the algorithm is O(n^3), where n is the number of FBM samples.
rand_chol(p::FBM) = [0., chol(autocov(p), :L)*randn(p.n-1)]

function rand_chol(p::Vector{FBM})
  np::Int64 = length(p)

  if np > 1
    for i = 2:np
      p[1].n == p[i].n || error("All FBM must have same number of points.")
    end
  end

  x = Array(Float64, p[1].n, np)

  for i = 1:np
    x[:, i] = rand_chol(p[i])
  end

  x
end

### rand_fft generates FBM using fast Fourier transform (FFT).
### The time interval of FBM is [0, 1] with a stepsize of 2^p, where p is a natural number.
### The algorithm is known as the Davies-Harte method or the method of circular embedding.
### R.B. Davies and D.S. Harte, Tests for Hurst Effect, Biometrika, 74 (1987), pp. 95–102.
### The complexity of the algorithm is O(n*log(n)), where n=2^p is the number of FBM samples.
function rand_fft(p::FBM; fbm::Bool=true)
  # Determine number of points of simulated FBM
  pnmone::Int64 = p.n-1
  n::Int64 = 2^ceil(log2(pnmone))

  # Compute covariant matrix of underlying FGN
  c = Array(Float64, n+1)
  autocov!(c, FGN(p.h), 0:n)

  # Compute square root of eigenvalues of circular covariant matrix
  lsqrt = sqrt(real(fft([c, c[end-1:-1:2]])))

  # Simulate standard random normal variables
  twon::Int64 = 2*n
  z = randn(twon)

  # Compute the circular process in the Fourier domain
  x = sqrt(0.5)*lsqrt[2:n].*complex(z[2*(2:n)-2], z[2*(2:n)-1])
  y = [lsqrt[1]*z[1], x, lsqrt[n+1]*z[twon], conj(reverse(x))]

  # Generate fractional Gaussian noise (retain only the first p.n-1 values)
  w = real(bfft(y))[1:pnmone]/sqrt(twon)

  if fbm
    w = [0, w]
  else
    w = cumsum(w)
  end

  w
end