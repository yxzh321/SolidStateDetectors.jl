function load_weights_for_innerloop!(
    line_weights, pssrb::PotentialCalculationSetup{T, S, 3, Array{T, 3}},
    i2, in2, i3, in3,
    update_even_points, i23_is_even_t,
    pww3r, pww3l, pww2r, pww2l, # pw: precalculated weight
    pww3r_pww2r, pww3l_pww2r, pww3r_pww2l, pww3l_pww2l,
    pwΔmp2_pwΔmp3, 
    pwΔmp2r, pwΔmp2l, 
    pwΔmp3r, pwΔmp3l,
) where {T, S}
    @fastmath @inbounds @simd ivdep for i1 in 2:(size(pssrb.potential, 1) - 1)
        in1 = nidx(i1, update_even_points, i23_is_even_t)

        pww1r        = pssrb.geom_weights[3][1, in1]
        pww1l        = pssrb.geom_weights[3][2, in1]
        pwΔmp1       = pssrb.geom_weights[3][3, in1]
        Δ1_ext_inv_l = pssrb.geom_weights[3][4, in1]
        Δ1_ext_inv_r = pssrb.geom_weights[3][4, in1 + 1]

        # ϵ_ijk: i: 1.RB-Dim. | j: 2.RB-Dim. | k: 3.RB-Dim.
        ϵ_lll, ϵ_llr, ϵ_lrl, ϵ_lrr, ϵ_rll, ϵ_rlr, ϵ_rrl, ϵ_rrr = get_ϵ_of_oktant(
            pssrb, in1 + 1, in1, i2, in2, i3, in3
        )
        
        pww2r_pww1r = pww2r * pww1r
        pww2l_pww1r = pww2l * pww1r
        pww2r_pww1l = pww2r * pww1l
        pww2l_pww1l = pww2l * pww1l
        pww3l_pww1r = pww3l * pww1r
        pww3r_pww1r = pww3r * pww1r
        pww3l_pww1l = pww3l * pww1l
        pww3r_pww1l = pww3r * pww1l

        w1r =        ϵ_rrr * pww3r_pww2r  
        w1r = muladd(ϵ_rlr,  pww3r_pww2l, w1r)     
        w1r = muladd(ϵ_rrl,  pww3l_pww2r, w1r)     
        w1r = muladd(ϵ_rll,  pww3l_pww2l, w1r)
        
        w1l =        ϵ_lrr * pww3r_pww2r 
        w1l = muladd(ϵ_llr,  pww3r_pww2l, w1l)    
        w1l = muladd(ϵ_lrl,  pww3l_pww2r, w1l)    
        w1l = muladd(ϵ_lll,  pww3l_pww2l, w1l)
        
        w2r =        ϵ_rrl * pww3l_pww1r 
        w2r = muladd(ϵ_rrr,  pww3r_pww1r, w2r)  
        w2r = muladd(ϵ_lrl,  pww3l_pww1l, w2r)    
        w2r = muladd(ϵ_lrr,  pww3r_pww1l, w2r) 
        
        w2l =        ϵ_rll * pww3l_pww1r 
        w2l = muladd(ϵ_rlr,  pww3r_pww1r, w2l)  
        w2l = muladd(ϵ_lll,  pww3l_pww1l, w2l)    
        w2l = muladd(ϵ_llr,  pww3r_pww1l, w2l) 

        w3r =        ϵ_rrr * pww2r_pww1r
        w3r = muladd(ϵ_rlr,  pww2l_pww1r, w3r)   
        w3r = muladd(ϵ_lrr,  pww2r_pww1l, w3r)    
        w3r = muladd(ϵ_llr,  pww2l_pww1l, w3r)

        w3l =        ϵ_rrl * pww2r_pww1r
        w3l = muladd(ϵ_rll,  pww2l_pww1r, w3l)   
        w3l = muladd(ϵ_lrl,  pww2r_pww1l, w3l)    
        w3l = muladd(ϵ_lll,  pww2l_pww1l, w3l) 

        # wxy *= Surfaces areas of the voxel
        w1l *= Δ1_ext_inv_l * pwΔmp2_pwΔmp3 
        w1r *= Δ1_ext_inv_r * pwΔmp2_pwΔmp3 
        w2l *= pwΔmp3l * pwΔmp1
        w2r *= pwΔmp3r * pwΔmp1
        w3l *= pwΔmp2l * pwΔmp1 
        w3r *= pwΔmp2r * pwΔmp1 

        line_weights[i1-1, 1] = w1l 
        line_weights[i1-1, 2] = w1r 
        line_weights[i1-1, 3] = w2l 
        line_weights[i1-1, 4] = w2r 
        line_weights[i1-1, 5] = w3l 
        line_weights[i1-1, 6] = w3r 
    end
    nothing
end

function innerloop!(
    line_weights, pssrb::PotentialCalculationSetup{T, S, 3, Array{T, 3}}, 
    i2, in2, i3, in3, rb_tar_idx, rb_src_idx, 
    update_even_points, i23_is_even_t,
    depletion_handling::Val{depletion_handling_enabled},
    is_weighting_potential::Val{_is_weighting_potential}, 
    only2d::Val{only_2d}
) where {T, S, depletion_handling_enabled, _is_weighting_potential, only_2d}
    @fastmath @inbounds @simd ivdep for i1 in 2:(size(pssrb.potential, 1) - 1)
        i1r = get_rbidx_right_neighbour(i1, update_even_points, i23_is_even_t)
        
        old_potential = pssrb.potential[i1, i2, i3, rb_tar_idx]
        q_eff = _is_weighting_potential ? zero(T) : (pssrb.q_eff_imp[i1, i2, i3, rb_tar_idx] + pssrb.q_eff_fix[i1, i2, i3, rb_tar_idx])

        weights = get_sor_weights(line_weights, i1-1)

        neighbor_potentials = get_neighbor_potentials(
            pssrb, old_potential, i1, i2, i3, i1r, in2, in3, rb_src_idx, only2d
        )
        
        new_potential = calc_new_potential_SOR_3D(
            q_eff,
            pssrb.volume_weights[i1, i2, i3, rb_tar_idx],
            weights,
            neighbor_potentials,
            old_potential,
            get_sor_constant(pssrb, in3)
        )

        if depletion_handling_enabled
            new_potential, pssrb.point_types[i1, i2, i3, rb_tar_idx] = handle_depletion(
                new_potential,
                pssrb.point_types[i1, i2, i3, rb_tar_idx],
                r0_handling_depletion_handling(neighbor_potentials, S, in3),
                pssrb.q_eff_imp[i1, i2, i3, rb_tar_idx],
                pssrb.volume_weights[i1, i2, i3, rb_tar_idx],
                get_sor_constant(pssrb, in3)
            )
        end

        pssrb.potential[i1, i2, i3, rb_tar_idx] = ifelse(pssrb.point_types[i1, i2, i3, rb_tar_idx] & update_bit > 0, new_potential, old_potential)
    end
    nothing
end

@inline function get_ϵ_of_oktant(
    pssrb::PotentialCalculationSetup{T, Cylindrical},
    i1, in1, i2, in2, i3, in3
) where {T}
    # ϵ_r is not transformed into an red-black-4D-array.
    # The inner loop (over i1) is along the z-Dimension (Cylindrical Case), 
    # which is the 3rd dimension for Cylindrical coordinates: (r, φ, z)
    return @inbounds begin
        pssrb.ϵ_r[ in3, in2, in1 ],
        pssrb.ϵ_r[  i3, in2, in1 ],
        pssrb.ϵ_r[ in3,  i2, in1 ],
        pssrb.ϵ_r[  i3,  i2, in1 ],
        pssrb.ϵ_r[ in3, in2,  i1 ],
        pssrb.ϵ_r[  i3, in2,  i1 ],
        pssrb.ϵ_r[ in3,  i2,  i1 ],
        pssrb.ϵ_r[  i3,  i2,  i1 ]
    end
end

@inline function get_ϵ_of_oktant(
    pssrb::PotentialCalculationSetup{T, Cartesian},
    i1, in1, i2, in2, i3, in3
) where {T}
    # The inner loop (over i1) is along the x-Dimension (Cartesian Case), 
    # which is the 1rd dimension for Cartesian coordinates: (x, y, z)
    return @inbounds begin
        pssrb.ϵ_r[ in1, in2, in3 ], 
        pssrb.ϵ_r[ in1, in2,  i3 ],
        pssrb.ϵ_r[ in1,  i2, in3 ], 
        pssrb.ϵ_r[ in1,  i2,  i3 ],
        pssrb.ϵ_r[  i1, in2, in3 ],
        pssrb.ϵ_r[  i1, in2,  i3 ],
        pssrb.ϵ_r[  i1,  i2, in3 ],
        pssrb.ϵ_r[  i1,  i2,  i3 ]
    end
end

@inline function get_sor_weights(line_weights::Matrix{T}, i::Int)::NTuple{6, T} where {T}
    @inbounds return ( # w: weight; 1: RB-dimension; l/r: left/right
        line_weights[i, 1], # w1l
        line_weights[i, 2], # w1r
        line_weights[i, 3], # w2l
        line_weights[i, 4], # w2r
        line_weights[i, 5], # w3l
        line_weights[i, 6], # w3r
    ) 
end

@inline function get_neighbor_potentials(
    pssrb::PotentialCalculationSetup{T, S, 3, Array{T, 3}},
    old_potential, i1, i2, i3, i1r, in2, in3, rb_src_idx, only2d::Val{only_2d}
)::NTuple{6, T} where {T,S,only_2d}
    @inbounds return ( # p: potential; 1: RB-dimension; l/r: left/right
    pssrb.potential[i1r - 1,     i2,     i3, rb_src_idx], # p1l
    pssrb.potential[    i1r,     i2,     i3, rb_src_idx], # p1r
    only_2d ? old_potential : pssrb.potential[ i1,    in2, i3, rb_src_idx], # p2l
    only_2d ? old_potential : pssrb.potential[ i1, i2 + 1, i3, rb_src_idx], # p2r
    pssrb.potential[     i1,     i2,    in3, rb_src_idx], # p3l
    pssrb.potential[     i1,     i2, i3 + 1, rb_src_idx], # p3r
    ) 
end

@inline function get_sor_constant(pssrb::PotentialCalculationSetup{T, Cylindrical}, i::Int)::T where {T}
    @inbounds pssrb.sor_const[i]
end
@inline function get_sor_constant(pssrb::PotentialCalculationSetup{T, Cartesian}, i::Int)::T where {T}
    @inbounds pssrb.sor_const[1]
end

@inline function r0_handling_depletion_handling(
    np::NTuple{6, T}, ::Type{Cylindrical}, i::Int
) where {T}
    return (ifelse(i == 1, np[2], np[1]), np[2:6]...)
end
@inline function r0_handling_depletion_handling(
    np::NTuple{6, T}, ::Type{Cartesian}, i::Int
) where {T}
    return np
end