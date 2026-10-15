module StaticInferenceTests

# Issue #67: nested conversions must infer without runtime dispatch.

using Test
using JET

import MATFrost

using MATFrost._Types
import MATFrost._ConvertToJulia
import MATFrost._ConvertToMATLAB

const toJulia  = MATFrost._ConvertToJulia.convert_matfrostarray
const toMATLAB = MATFrost._ConvertToMATLAB.convert_matfrostarray

struct Inner
    a::Float64
    b::Int64
    s::String
end

struct Middle
    inner::Inner
    inners::Vector{Inner}
    tup::Tuple{String, Int64, Float64}
end

struct Outer
    middle::Middle
    middles::Matrix{Middle}
    nested::Vector{Vector{Float64}}
    nt::NamedTuple{(:x, :y), Tuple{Int64, Inner}}
end

scalar(v::T) where {T<:Number} = MATFrostArrayPrimitive{T}(Int64[1, 1], T[v])
str(s::String) = MATFrostArrayString(Int64[1, 1], String[s])
mstruct(fns::Vector{Symbol}, vals::Vector{MATFrostArrayAbstract}, dims=Int64[1, 1]) =
    MATFrostArrayStruct(dims, fns, vals)

inner_m() = mstruct([:a, :b, :s], MATFrostArrayAbstract[scalar(1.5), scalar(2), str("x")])

function middle_m()
    inners = MATFrostArrayStruct(Int64[1, 2], [:a, :b, :s], MATFrostArrayAbstract[
        scalar(1.0), scalar(1), str("p"),
        scalar(2.0), scalar(2), str("q"),
    ])
    tup = MATFrostArrayCell(Int64[3, 1], MATFrostArrayAbstract[str("t"), scalar(3), scalar(4.0)])
    mstruct([:inner, :inners, :tup], MATFrostArrayAbstract[inner_m(), inners, tup])
end

function outer_m()
    m = middle_m()
    middles = MATFrostArrayStruct(Int64[1, 1], [:inner, :inners, :tup], copy(m.values))
    nested = MATFrostArrayCell(Int64[2, 1], MATFrostArrayAbstract[
        MATFrostArrayPrimitive{Float64}(Int64[1, 2], [1.0, 2.0]),
        MATFrostArrayPrimitive{Float64}(Int64[1, 3], [3.0, 4.0, 5.0]),
    ])
    nt = mstruct([:x, :y], MATFrostArrayAbstract[scalar(7), inner_m()])
    mstruct([:middle, :middles, :nested, :nt], MATFrostArrayAbstract[m, middles, nested, nt])
end

@testset "Static inference (issue #67)" begin
    marr = outer_m()

    @testset "MATLAB -> Julia, nested" begin
        out = toJulia(Outer, marr)
        @test out.middle.inners[2].s == "q"
        @test out.nested[2] == [3.0, 4.0, 5.0]
        @test out.nt.y.a == 1.5
        @test Base.return_types(toJulia, (Type{Outer}, MATFrostArrayAbstract)) == Any[Outer]
        @test_opt target_modules=(MATFrost,) toJulia(Outer, marr)
    end

    @testset "Julia -> MATLAB, nested" begin
        val = toJulia(Outer, marr)
        @test toMATLAB(val) isa MATFrostArrayStruct
        @test toMATLAB(("a", 1, 2.0)) isa MATFrostArrayCell
        @test_opt target_modules=(MATFrost,) toMATLAB(val)
        @test_opt target_modules=(MATFrost,) toMATLAB(("a", 1, 2.0, Inner(1.0, 2, "z")))
    end
end

end
