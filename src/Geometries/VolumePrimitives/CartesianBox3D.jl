"""
    mutable struct CartesianBox3D{T} <: AbstractGeometry{T, 3}

Very simple rectengular box in cartesian coordinates.
"""
struct CartesianBox3D{T} <: AbstractVolumePrimitive{T, 3} # should be immutable, mutable right now just for testing.
    x::Tuple{T, T}
    y::Tuple{T, T}
    z::Tuple{T, T}
    translate::Union{CartesianVector{T}, Missing}
end

function in(pt::CartesianPoint{T}, g::CartesianBox3D{T})::Bool where {T}
    return (g.x[1] <= pt[1] <= g.x[2]) && (g.y[1] <= pt[2] <= g.y[2]) && (g.z[1] <= pt[3] <= g.z[2])
end

@inline in(pt::CylindricalPoint, g::CartesianBox3D)::Bool = in(CartesianPoint(pt), g)

function CartesianBox3D{T}(dict::Union{Dict{Any, Any}, Dict{String, Any}}, inputunit_dict::Dict{String,Unitful.Units})::CartesianBox3D{T} where {T <: SSDFloat}

    if haskey(dict, "translate")
        translate = CartesianVector{T}(
            haskey(dict["translate"],"x") ? geom_round(ustrip(uconvert(u"m", T(dict["translate"]["x"]) * inputunit_dict["length"] ))) : 0.0,
            haskey(dict["translate"],"y") ? geom_round(ustrip(uconvert(u"m", T(dict["translate"]["y"]) * inputunit_dict["length"] ))) : 0.0,
            haskey(dict["translate"],"z") ? geom_round(ustrip(uconvert(u"m", T(dict["translate"]["z"]) * inputunit_dict["length"] ))) : 0.0)
    else
        translate = CartesianVector{T}(0.0, 0.0, 0.0)
    end

    if typeof(dict["x"]) <: SSDFloat
        xStart, xStop = geom_round(translate[1] + T(0.0)), geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["x"]) * inputunit_dict["length"])))
    else
        xStart, xStop = geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["x"]["from"]) * inputunit_dict["length"] ))), geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["x"]["to"]) * inputunit_dict["length"])))
    end
    if typeof(dict["y"]) <: SSDFloat
        yStart, yStop = geom_round(translate[1] + T(0.0)), geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["y"]) * inputunit_dict["length"])))
    else
        yStart, yStop = geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["y"]["from"]) * inputunit_dict["length"] ))), geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["y"]["to"]) * inputunit_dict["length"])))
    end
    if typeof(dict["z"]) <: SSDFloat
        zStart, zStop = geom_round(translate[1] + T(0.0)), geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["z"]) * inputunit_dict["length"])))
    else
        zStart, zStop = geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["z"]["from"]) * inputunit_dict["length"] ))), geom_round(translate[1] + ustrip(uconvert(u"m", T(dict["z"]["to"]) * inputunit_dict["length"])))
    end
    translate = missing
    return CartesianBox3D{T}(
        (xStart, xStop),
        (yStart, yStop),
        (zStart, zStop),
        translate )
end

function Geometry(T::DataType, t::Val{:CartesianBox3D}, dict::Dict{Any, Any}, inputunit_dict::Dict{String,Unitful.Units})
    return CartesianBox3D{T}(dict, inputunit_dict)
end

function get_important_points(g::CartesianBox3D{T})::NTuple{3, Vector{T}} where {T <: SSDFloat}
    v1::Vector{T} = T[g.x[1], g.x[2]] #[g.x[1], g.x[2]]
    v2::Vector{T} = T[g.y[1], g.y[2]]
    v3::Vector{T} = T[g.z[1], g.z[2]]
    return v1, v2, v3
end

function get_important_points(g::CartesianBox3D{T}, ::Val{:r})::Vector{T} where {T <: SSDFloat}
    @warn "Not yet implemented"
    return T[]
end
function get_important_points(g::CartesianBox3D{T}, ::Val{:φ})::Vector{T} where {T <: SSDFloat}
    @warn "Not yet implemented"
    return T[]
end
function get_important_points(g::CartesianBox3D{T}, ::Val{:z})::Vector{T} where {T <: SSDFloat}
    return T[g.z[1], g.z[2]]
end
function get_important_points(g::CartesianBox3D{T}, ::Val{:x})::Vector{T} where {T <: SSDFloat}
    return T[g.x[1], g.x[2]]
end
function get_important_points(g::CartesianBox3D{T}, ::Val{:y})::Vector{T} where {T <: SSDFloat}
    return T[g.y[1], g.y[2]]
end


function vertices(cb::CartesianBox3D{T})::Vector{CartesianPoint{T}} where {T <: SSDFloat}
    v::Vector{CartesianPoint{T}} = CartesianPoint{T}[
        CartesianPoint{T}(cb.x[1], cb.y[1], cb.z[1]),
        CartesianPoint{T}(cb.x[2], cb.y[1], cb.z[1]),
        CartesianPoint{T}(cb.x[2], cb.y[2], cb.z[1]),
        CartesianPoint{T}(cb.x[1], cb.y[2], cb.z[1]),
        CartesianPoint{T}(cb.x[1], cb.y[1], cb.z[2]),
        CartesianPoint{T}(cb.x[2], cb.y[1], cb.z[2]),
        CartesianPoint{T}(cb.x[2], cb.y[2], cb.z[2]),
        CartesianPoint{T}(cb.x[1], cb.y[2], cb.z[2]),
    ]
    return v
end

function LineSegments(cb::CartesianBox3D{T})::Vector{LineSegment{T, 3, :Cartesian}} where {T}
    v::Vector{CartesianPoint{T}} = vertices(cb)
    return LineSegment{T, 3, :Cartesian}[
        LineSegment(v[1], v[2]),
        LineSegment(v[2], v[3]),
        LineSegment(v[3], v[4]),
        LineSegment(v[4], v[1]),
        LineSegment(v[1], v[5]),
        LineSegment(v[2], v[6]),
        LineSegment(v[3], v[7]),
        LineSegment(v[4], v[8]),
        LineSegment(v[5], v[6]),
        LineSegment(v[6], v[7]),
        LineSegment(v[7], v[8]),
        LineSegment(v[8], v[5])
    ]
end

@recipe function f(cb::CartesianBox3D{T}) where {T <: SSDFloat}
    ls = LineSegments(cb)
    @series begin
        ls
    end
end

function sample(cb::CartesianBox3D{T}, stepsize::Vector{T})  where {T <: SSDFloat}
    samples  = CartesianPoint{T}[]
    for x in cb.x[1] : stepsize[1] : cb.x[2]
        for y in cb.y[1] :stepsize[2] : cb.y[2]
            for z in cb.z[1] : stepsize[3] : cb.z[2]
                push!(samples,CartesianPoint{T}(x, y, z))
            end
        end
    end
    return samples
end
