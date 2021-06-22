geom_sigdigits(::Type{Int64})::Int = 12
geom_sigdigits(::Type{Float32})::Int = 5
geom_sigdigits(::Type{Float64})::Int = 12

geom_atol_zero(::Type{Int64})::Float64 = 1e-12
geom_atol_zero(::Type{Float32})::Float32 = 1e-6
geom_atol_zero(::Type{Float64})::Float64 = 1e-12

function geom_round(v::T)::T where {T}
    return isapprox(v, 0, atol = geom_atol_zero(T)) ? T(0) : round(v, sigdigits = geom_sigdigits(T))
end
# function geom_round(cyl::CylindricalPoint{T})::CylindricalPoint{T} where T
#     return Cylindrical{T}(geom_round(cyl.r),geom_round(cyl.φ),geom_round(cyl.z))
# end

function geom_round(pt::CylindricalPoint{T})::CylindricalPoint{T} where {T <: Real}
    return CylindricalPoint{T}( geom_round(pt.r), geom_round(pt.φ), geom_round(pt.z)  )
end

function geom_round(pt::CartesianPoint{T})::CartesianPoint{T} where {T <: Real}
    return CartesianPoint{T}( geom_round(pt.x), geom_round(pt.y), geom_round(pt.z)  )
end

csg_isapprox(x::T, y::T) where {T} = abs(x - y)/((x+y)/2) < T(1e-9)
csg_isapprox(x::Float32, y::Float32)  = abs(x - y)/((x+y)/2) < 1f-7