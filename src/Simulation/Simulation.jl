abstract type AbstractSimulation{T <: SSDFloat} end

mutable struct Simulation{T <: SSDFloat} <: AbstractSimulation{T}
    detector::Union{SolidStateDetector{T}, Missing}
    ρ::Union{ChargeDensity{T}, Missing}
    ϵ::Union{DielectricDistribution{T}, Missing}
    point_types::Union{PointTypes{T}, Missing}
    electric_potential::Union{ElectricPotential{T}, Missing}
    weighting_potentials::Vector{Any}
    electric_field::Union{ElectricField{T}, Missing}

    charge_drift_model::Union{AbstractChargeDriftModel{T}, Missing}

    interpolated_electron_drift_field::Any
    interpolated_hole_drift_field::Any

    Simulation{T}() where {T <: SSDFloat} = new{T}(missing, missing, missing, missing, missing, [missing], missing, missing, missing, missing )
end

function Simulation(detector::SolidStateDetector{T})::Simulation{T} where {T <: SSDFloat}
    sim::Simulation{T} = Simulation{T}()
    sim.detector = detector
    sim.weighting_potentials = Missing[ missing for i in 1:length(sim.detector.contacts)]
    return sim
end

function Simulation{T}(config_file::AbstractString)::Simulation{T} where{T <: SSDFloat}
    return Simulation( SolidStateDetector{T}(config_file) )
end


# function Simulation(nt::NamedTuple)

# end

# Base.convert(T::Type{Simulation}, x::NamedTuple) = T(x)

# function NamedTuple(sim::Simulation{T}, wps::Vector) where {T <: SSDFloat}
#     n::Int = length(sim.detector.contacts)
#     ids = NTuple{n, Symbol}([Symbol("contact_$(contact.id)") for contact in sim.detector.contacts])
#     return NamedTuple{ids, NTuple{n, Any}}(sim.weighting_potentials)
# end

# function NamedTuple(sim::Simulation{T}) where {T <: SSDFloat}
#     return (
#         electric_potential = NamedTuple(sim.electric_potential),
#         point_types = NamedTuple(sim.point_types),
#         ρ = NamedTuple(sim.ρ),
#         ϵ = NamedTuple(sim.ϵ),
#         electric_field = NamedTuple(sim.electric_field),
#         weighting_potentials = NamedTuple(sim, sim.weighting_potentials),
#         charge_drift_model = NamedTupleFromStruct(sim.charge_drift_model),
#         interpolated_electron_drift_field = NamedTupleFromStruct(sim.interpolated_electron_drift_field),
#         interpolated_hole_drift_field = NamedTupleFromStruct(sim.interpolated_hole_drift_field)
#     )
# end

# Base.convert(T::Type{NamedTuple}, x::Simulation) = T(x)



# Functions

function apply_initial_state!(sim::Simulation{T})::Nothing where {T <: SSDFloat}
    init_sim = SolidStateDetectors.PotentialSimulationSetup(sim.detector);

    sim.ρ = ChargeDensity(init_sim.ρ, init_sim.grid)
    sim.ϵ = DielectricDistribution(init_sim.ϵ, init_sim.grid)
    sim.point_types = PointTypes(init_sim.pointtypes, init_sim.grid)
    sim.electric_potential = ElectricPotential(init_sim.potential, init_sim.grid)

    nothing
end

function calculate_electric_potential!(sim::Simulation{T}, args...; kwargs...)::Nothing where {T <: SSDFloat}
    ep = calculate_electric_potential(sim.detector, args...; kwargs...)

    sim.ρ = ChargeDensity(ep.ρ, ep.grid)
    sim.ϵ = DielectricDistribution(ep.ϵ, ep.grid)
    sim.point_types = PointTypes(ep.pointtypes, ep.grid)
    sim.electric_potential = ElectricPotential(ep.potential, ep.grid)

    nothing
end


function calculate_weighting_potential!(sim::Simulation{T}, contact_id::Int, args...; n_points_in_φ::Union{Missing, Int} = missing, kwargs...)::Nothing where {T <: SSDFloat}
    S = SSD.get_coordinate_system(sim.detector)
    if S == :Cylindrical && sim.detector.cyclic == T(0)
        if ismissing(n_points_in_φ)
            @info "\tIn weighing potential calculation: Keyword `n_points_in_φ` not set.\n\t\tDefault is `n_points_in_φ = 36`. 2D field will be extended to 36 points in φ."
            n_points_in_φ = 36
        else
            if !(n_points_in_φ > 1 && iseven(n_points_in_φ))
                @info "\tIn weighing potential calculation: Keyword `n_points_in_φ` is $(n_points_in_φ) but must be even and larger than 1.\n\t\t`n_points_in_φ` is now set to 36. 2D field will be extended to 36 points in φ."
                n_points_in_φ = 36
            end
        end
    end
    wps = calculate_weighting_potential(sim.detector, contact_id, args...; kwargs...)
    if S == :Cylindrical && size(wps.potential, 2) == 1 && !ismissing(n_points_in_φ)
        wp = WeightingPotential(wps, n_points_in_φ = n_points_in_φ)
    else
        wp = WeightingPotential(wps)
    end
    sim.weighting_potentials[contact_id] = interpolated_scalarfield(wp)
    nothing
end


function calculate_electric_field!(sim::Simulation{T}, args...; n_points_in_φ::Union{Missing, Int} = missing, kwargs...)::Nothing where {T <: SSDFloat}
    S = SSD.get_coordinate_system(sim.detector)
    e_pot, point_types = if S == :Cylindrical && sim.detector.cyclic == T(0) # 2D, only one point in φ
        if ismissing(n_points_in_φ)
            @info "\tIn electric field calculation: Keyword `n_points_in_φ` not set.\n\t\tDefault is `n_points_in_φ = 36`. 2D field will be extended to 36 points in φ."
            n_points_in_φ = 36
        else
            if !(n_points_in_φ > 1 && iseven(n_points_in_φ))
                @info "\tIn electric field calculation: Keyword `n_points_in_φ` is $(n_points_in_φ) but must be even and larger than 1.\n\t\t`n_points_in_φ` is now set to 36. 2D field will be extended to 36 points in φ."
                n_points_in_φ = 36
            end
        end
        get_2π_potential(sim.electric_potential, n_points_in_φ = n_points_in_φ),
        get_2π_potential(sim.point_types,  n_points_in_φ = n_points_in_φ);
    else
        sim.electric_potential,
        sim.point_types
    end
    sim.electric_field = get_electric_field_from_potential(e_pot, point_types);
    nothing
end

function set_charge_drift_model!(sim::Simulation{T}, charge_drift_model::AbstractChargeDriftModel)::Nothing where {T <: SSDFloat}
    sim.charge_drift_model = charge_drift_model
    nothing
end

function apply_charge_drift_model!(sim::Simulation{T})::Nothing where {T <: SSDFloat}
    sim.interpolated_electron_drift_field = get_interpolated_drift_field(
        get_electron_drift_field(sim.electric_field.data, sim.charge_drift_model), sim.electric_field.grid
    )
    sim.interpolated_hole_drift_field = get_interpolated_drift_field(
        get_hole_drift_field(sim.electric_field.data, sim.charge_drift_model), sim.electric_field.grid
    )
    nothing
end

function drift_charges( sim::Simulation{T}, starting_positions::Vector{CartesianPoint{T}};
                        Δt::RealQuantity = 5u"ns", n_steps::Int = 1000, verbose::Bool = true )::Vector{DriftPath{T}} where {T <: SSDFloat}
    return _drift_charges(   sim.detector, sim.electric_potential.grid, starting_positions,
                             sim.interpolated_electron_drift_field, sim.interpolated_hole_drift_field,
                             Δt = T(to_internal_units(internal_time_unit, Δt)), n_steps = n_steps, verbose = verbose)::Vector{DriftPath{T}}
end

# User friendly functions for looking at single events. They are not ment to be used for large sets of events
function get_signal(sim::Simulation{T}, drift_paths::Vector{DriftPath{T}}, energy_depositions::Vector{T}, contact_id::Int)::Vector{T} where {T <: SSDFloat}
    signal::Vector{T} = zeros(T, length(drift_paths[1].e_path))
    wp::Interpolations.Extrapolation{T, 3} = sim.weighting_potentials[contact_id]
    for ipath in eachindex(drift_paths)
        add_signal!(signal, drift_paths[ipath], energy_depositions[ipath], wp, Val(get_coordinate_system(sim.detector)))
    end
    return signal
end
function get_signals(sim::Simulation{T}, drift_paths::Vector{DriftPath{T}}, energy_depositions::Vector{T})::Array{T, 2} where {T <: SSDFloat}
    n_contacts::Int = length(sim.detector.contacts)
    signals::Array{T, 2} = zeros(T, length(drift_paths[1].e_path), n_contacts)
    S = Val(get_coordinate_system(sim.detector))
    for c in sim.detector.contacts
        wp::Interpolations.Extrapolation{T, 3} = sim.weighting_potentials[c.id]
        signal::Vector{T} = zeros(T, length(drift_paths[1].e_path))
        for ipath in eachindex(drift_paths)
            add_signal!(signal, drift_paths[ipath], energy_depositions[ipath], wp, S)
        end
        signals[:, c.id] = signal
    end
    return signals
end



function generate_charge_signals!(
    contact_charge_signals::AbstractVector{<:AbstractVector{<:AbstractVector{<:RealQuantity}}},
    sim::Simulation{T},
    hit_pos::AbstractVector{<:AbstractVector{<:AbstractVector{<:RealQuantity}}},
    hit_edep::AbstractVector{<:AbstractVector{<:RealQuantity}},
    n_steps::Integer,
    Δt::RealQuantity;
    verbose::Bool = true
)::Nothing where {T <: SSDFloat}
    E_ionisation = sim.detector.material_detector.E_ionisation

    unitless_delta_t::T = to_internal_units(u"s", Δt)
    S = Val(get_coordinate_system(sim.detector))
    n_contacts::Int = length(sim.detector.contacts)

    prog = Progress(length(hit_pos), 0.005, "Generating charge signals...")
    @inbounds for i_evt in eachindex(hit_pos)
        startpos_vec::Vector{CartesianPoint{T}} = CartesianPoint{T}[ CartesianPoint{T}( to_internal_units(u"m", hit_pos[i_evt][idep]) ) for idep in eachindex(hit_pos[i_evt]) ]
        edep_vec::Vector{T} = T[ to_internal_units(u"eV", hit_edep[i_evt][idep]) for idep in eachindex(hit_edep[i_evt]) ]
        n_charges_vec::Vector{T} = edep_vec / ustrip(uconvert(u"eV", E_ionisation))

        drift_paths::Vector{DriftPath{T}} = drift_charges( sim, startpos_vec, Δt = unitless_delta_t, n_steps = n_steps, verbose = verbose)

        for contact in sim.detector.contacts
            signal::Vector{T} = zeros(T, n_steps)
            add_signal!(signal, drift_paths, n_charges_vec, sim.weighting_potentials[contact.id], S)
            contact_charge_signals[contact.id][i_evt] = signal
        end
        ProgressMeter.next!(prog)
    end
    ProgressMeter.finish!(prog)
    nothing
end


function generate_charge_signals(   sim::Simulation{T},
                                    events::DetectorHitEvents;
                                    n_steps::Integer = 1000,
                                    Δt::RealQuantity = 5u"ns",
                                    verbose::Bool = true
                                ) where {T <: SSDFloat}
    hit_pos = events.pos
    hit_edep = events.edep

    # contact_charge_signals = [nestedview(Array{T, 2}(undef, n_steps, size(hit_pos, 1))) for i in eachindex(sim.detector.contacts)]
    contact_charge_signals = [nestedview(zeros(T, n_steps, size(hit_pos, 1))) for i in eachindex(sim.detector.contacts)]

    generate_charge_signals!(
        contact_charge_signals,
        sim,
        hit_pos, hit_edep,
        n_steps, Δt,
        verbose = verbose
    )

    contact_charge_signals
end
