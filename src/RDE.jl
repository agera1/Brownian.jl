module RDE

using Distributions

import Base.rand
import Distributions: VariateForm, Univariate, Multivariate, ValueSupport, Discrete, Continuous

export
  StochasticProcess,
  UnivariateStochasticProcess,
  MultivariateStochasticProcess,
  DiscreteStochasticProcess,
  ContinuousStochasticProcess,
  DiscreteUnivariateStochasticProcess,
  ContinuousUnivariateStochasticProcess,
  DiscreteMultivariateStochasticProcess,
  ContinuousMultivariateStochasticProcess,
  WienerProcess,
  rand

include(joinpath("stochastic_processes", "StochasticProcess.jl"))
include(joinpath("stochastic_processes", "WienerProcess.jl"))

end # module