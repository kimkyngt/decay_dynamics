# Base package for the project
using QuantumOptics, WignerSymbols, LinearAlgebra, SparseArrays, Interpolations
import Rotations: RotX, RotZ

""" 
Get |F, m⟩
"""
function Fm_state(F, m)
    if abs(m) > F
        throw(ArgumentError("m must be in the range [-F, F]"))
    end
    # b = SpinBasis(F)
    # return normalize(sigmam(b)^Int(F - m) *spinup(b))
    ψ = Ket(SpinBasis(F))
    ψ.data[Integer(1 + F - m)] = 1
    return ψ
end

"""
spherical basis vectors
"""
function ϵ_q(q::Int)
    if q == 0
        return transpose([0, 0, 1])
    elseif abs(q) == 1
        return -q/sqrt(2) * transpose([1, q*im, 0])
    else 
        throw(ArgumentError("Argument q must be one of [-1, 0, 1]"))
    end
end

""" 
Atomic coherence operator. |F_1, m_1⟩⟨F_2, m_2|.
"""
function σ(F_1::Number, m_1::Number, F_2::Number, m_2::Number)
    ψe = Fm_state(F_1, m_1)⊕ Ket(SpinBasis(F_2))
    ψg = Ket(SpinBasis(F_1)) ⊕ Fm_state(F_2, m_2)
    return sparse(ψe ⊗ dagger(ψg))
end


"""
Σ_q(q::Real, F_i::Vector, k::Int=1, l::Int=2)
    
Atomic lowering operator with hyperfine structure. `F_i[k]` → `F_i[l]`.
- `q`: -1, 0, 1
- `F_i`: Vector of the spin of each level.
- `k`: index for the upper state.
- `l`: index for the lower state.
"""
function Σ_q(q::Real, F_i::Vector, k::Int, l::Int)
    if abs(q) > 1
        throw(ArgumentError("Argument q must be one of [-1, 0, 1]"))
    end
    
    sparse(embed(
        directsum([SpinBasis(F) for F in F_i]...),
        directsum([SpinBasis(F) for F in F_i]...),
        [k, l],
        # sparse(sqrt(2*F_i[k]+1)*sum(dagger((-1)^(Int(F_i[l] - m)) * wigner3j(F_i[l], 1, F_i[k], -m, q, m-q) * σ(F_i[k], m - q, F_i[l], m)) for m = -F_i[l]:1:F_i[l] if abs(m - q) <= F_i[k]))
        # sqrt((2*F_i[k]+1)/(2*F_i[l]+1))*sparse(sum(clebschgordan(F_i[k], m-q, 1, q, F_i[l]) * dagger(σ(F_i[k], m - q, F_i[l], m)) for m = -F_i[l]:1:F_i[l] if abs(m - q) <= F_i[k]))
        sum((-1)^(2*m - q)*clebschgordan(F_i[l], m, 1, -q, F_i[k]) * dagger(σ(F_i[k], m - q, F_i[l], m)) for m = -F_i[l]:1:F_i[l] if abs(m - q) <= F_i[k])
    ))
end

"""
    Σ_iq(i::Int, q::Int, F_i::Vector{Rational} ; kindx::Int=1)

Hyperfine lowering operator for multilevel two atoms. 
- `i`: index of the atom under interest.
- `q`: -1, 0, 1
- `F_i`: Array of the spin of each level.
- `k`: index for the upper state.
- `l`: index for the lower state.
"""
function Σ_iq(i::Int, q::Int, F_i::Vector, k::Int=1, l::Int=2)
    if i > 2
        throw(ArgumentError("Argument i must be one of [1, 2]"))
    end
    if abs(q) > 1
        throw(ArgumentError("Argument q must be one of [-1, 0, 1]"))
    end
    sigma_single = Σ_q(q, F_i, k, l)
    embed(sigma_single.basis_l ⊗ sigma_single.basis_l, [i], [sigma_single])
end


"""
Convert polar coordinate to Cartesian for plotting.
"""
function polar_2_xyz(θ, ϕ, r=1)
    x = [sin(θi)*cos(ϕj) for θi ∈ θ,  ϕj ∈ ϕ].*r
    y = [sin(θi)*sin(ϕj) for θi ∈ θ,  ϕj ∈ ϕ].*r
    z = [cos(θi) 	     for θi ∈ θ,  ϕj ∈ ϕ].*r
    return x, y, z
end

"""
convert Cartesian coordinate to polar
"""
function xyz_2_polar(x, y, z)
    r = sqrt.(x.^2 + y.^2 + z.^2)
    θ = acos.(z./r)
    ϕ = atan.(y, x)
    return θ, ϕ, r
end


"""
Draw a unit sphere. Nsample determines the density
"""
function draw_unit_sphere(Nsample=20, )
    θ = range(0, π, length = Nsample)
    ϕ = range(0, 2π, length  = Nsample)
    fig = plot(
        polar_2_xyz(θ, ϕ, ones(length(θ))),
        st=:surface,
        color=:grey, 
        legend=false,
        )
    return fig
end

"""
Randomly sample unit vectors in NA centered at (theta, phi).
Returns unit vector components x, y, z
test: plot(sample_omega_on_sphere(10, 0.5, pi/2, pi), st=:scatter)
"""
function sample_omega_on_sphere(Nsample::Int, NA::Number, theta::Number, phi::Number)
    ang = asin(NA)
    theta_sample = 2*ang*(rand(Nsample) .- 0.5)
    phi_sample = 2*pi*rand(Nsample)
    u = []
    for ii in eachindex(theta_sample)
        push!(u, RotZ(phi)*RotX(theta)*[
            sin(theta_sample[ii])*cos(phi_sample[ii]), 
            sin(theta_sample[ii])*sin(phi_sample[ii]), 
            cos(theta_sample[ii])
            ])
    end
    x, y, z = [], [], []
    for ii in eachindex(u)
        push!(x, u[ii][1]) 
        push!(y, u[ii][2])
        push!(z, u[ii][3])
    end
    return x, y, z
end

"""
Sample uniform random points on the unit sphere
"""
function sample_sphere(Nsample::Int)
    x, y, z, = [], [], []
    for ii in range(1, Nsample)
        theta = acos(1 .- 2*rand())
        phi = 2*pi*rand()
        push!(x, sin(theta)*cos(phi))
        push!(y, sin(theta)*sin(phi))
        push!(z, cos(theta))
    end
    if Nsample == 1
        return x[1], y[1], z[1]
    else
        return x, y, z
    end
end

"""
Fibonacci lattice for uniform looking points on the sphere for the visual purpose.
"""
function sample_sphere_uniform(Nsample::Int)
    num_pts = Nsample
    indices = collect(range(0, stop=num_pts-1, length=num_pts)) .+ 0.5
    
    theta = acos.(1 .- 2 .* indices ./ num_pts)
    phi = pi .* (1 .+ 5^0.5) .* indices
    
    x, y, z = cos.(phi) .* sin.(theta), sin.(phi) .* sin.(theta), cos.(theta)
    
    return x, y, z
end


"""
    GreenTensor(r::Vector, k::Real)
Modified from CollectiveSpins.jl package. 
Static limit, imaginary part goes to 2/3. k_0/4π factor goes to Gamma and Omega
"""
function GreenTensor(r::Vector, k::Real=1)
    n = norm(r)
    if n == 0
        return sparse(im*Matrix(I,3,3))*2/3
    else
        rn = r/n
        return exp(im*k*n)*(
            (1/(k*n) + im/(k*n)^2 - 1/(k*n)^3) .* Matrix(I,3,3) +
            -(1/(k*n) + 3im/(k*n)^2 - 3/(k*n)^3) .* (rn*rn')
        )
    end
end


"""
Custom file name generator
"""
function rational2str(x)
    a = string.(round.(float.(x), digits=3))
    if a isa String
            return a
    else
            return join(a, ",")
    end
end



