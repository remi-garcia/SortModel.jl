module SortModel

using JuMP
using MathOptInterface
const MOI = MathOptInterface
using Random

import Base.sort!
import Base.sort
export sort!
export sort

include("utils.jl")
include("sort.jl")

end # module
