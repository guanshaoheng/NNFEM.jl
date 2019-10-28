export AdjointAssembleStrain, AssembleStiffAndForce, AdjointAssembleStiff
@doc """
Compute the strain, based on the state in domain
and dstrain_dstate
"""->
function AdjointAssembleStrain(domain)
  neles = domain.neles
  eledim = domain.elements[1].eledim
  nstrain = div((eledim + 1)*eledim, 2)
  ngps_per_elem = length(domain.elements[1].weights)
  neqs = domain.neqs


  strain = zeros(Float64, neles*ngps_per_elem, nstrain)
  # dstrain_dstate = zeros(Float64, neles*ngps_per_elem, domain.neqs)
  ii = Int64[]; jj = Int64[]; vv = Float64[]

  # Loop over the elements in the elementGroup
  for iele  = 1:neles
    element = domain.elements[iele]

    # Get the element nodes
    el_nodes = getNodes(element)

    # Get the element nodes
    el_eqns = getEqns(domain,iele)

    el_dofs = getDofs(domain,iele)

    el_state  = getState(domain, el_dofs)

    # Get strain{ngps_per_elem, nstrain} 
    #     dstrain_dstate{ngps_per_elem*nstrain, neqs_per_elem}  
    strain[(iele-1)*ngps_per_elem+1 : iele*ngps_per_elem,:], ldstrain_dstate = 
    getStrainState(element, el_state)


      # Assemble in the global array
      el_eqns_active = el_eqns .>= 1
      el_eqns_active_idx = el_eqns[el_eqns_active]
    
      ldstrain_dstate_active = ldstrain_dstate[:,el_eqns_active]
    
      for i = 1:ngps_per_elem*nstrain
        for j = 1:length(el_eqns_active_idx)
          push!(ii, (iele-1)*ngps_per_elem*nstrain+i)
          push!(jj, el_eqns_active_idx[j])
          push!(vv, ldstrain_dstate_active[i,j])
        end
      end
  end
  # @show maximum(jj)
  # @show maximum(ii) 
  # @show neqs, neles*ngps_per_elem*nstrain
  dstrain_dstate_tran = sparse(jj, ii, vv, neqs, neles*ngps_per_elem*nstrain)
  return strain, dstrain_dstate_tran
end


@doc """
Compute the fint and stiff, based on the state and Dstate in domain
"""->
function AssembleStiffAndForce(domain, stress::Array{Float64}, dstress_dstrain::Array{Float64})
  neles = domain.neles
  ngps_per_elem = length(domain.elements[1].weights)
  neqs = domain.neqs
  
  
  fint = zeros(Float64, domain.neqs)
  # K = zeros(Float64, domain.neqs, domain.neqs)
  ii = Int64[]; jj = Int64[]; vv = Float64[]

  # Loop over the elements in the elementGroup
  for iele  = 1:neles
    element = domain.elements[iele]

    # Get the element nodes
    el_nodes = getNodes(element)

    # Get the element nodes
    el_eqns = getEqns(domain,iele)

    el_dofs = getDofs(domain,iele)

    #@show "iele", iele, el_dofs 
    
    #@show "domain.state", iele, domain.state 

    el_state  = getState(domain,el_dofs)

    gp_ids = (iele-1)*ngps_per_elem+1 : iele*ngps_per_elem
    
    lfint, lstiff  = getStiffAndForce(element, el_state, stress[gp_ids,:], dstress_dstrain[gp_ids,:,:])

    # Assemble in the global array
    el_eqns_active = el_eqns .>= 1
    # K[el_eqns[el_eqns_active], el_eqns[el_eqns_active]] += stiff[el_eqns_active,el_eqns_active]
    lstiff_active = lstiff[el_eqns_active,el_eqns_active]
    el_eqns_active_idx = el_eqns[el_eqns_active]
    for i = 1:length(el_eqns_active_idx)
      for j = 1:length(el_eqns_active_idx)
        push!(ii, el_eqns_active_idx[i])
        push!(jj, el_eqns_active_idx[j])
        push!(vv, lstiff_active[i,j])
      end
    end
    fint[el_eqns[el_eqns_active]] += lfint[el_eqns_active]
    # @info "Fint is ", Fint
  end
  stiff = sparse(ii, jj, vv, neqs, neqs)
  # @show norm(K-Array(Ksparse))
  return fint, stiff
end




@doc """
Compute the stiff and dfint_dstress, based on the state in domain
and dstrain_dstate
"""->
function AdjointAssembleStiff(domain, stress::Array{Float64}, dstress_dstrain::Array{Float64})
    neles = domain.neles
    eledim = domain.elements[1].eledim
    nstrain = div((eledim + 1)*eledim, 2)
    ngps_per_elem = length(domain.elements[1].weights)
    neqs = domain.neqs


    ii_stiff = Int64[]; jj_stiff = Int64[]; vv_stiff = Float64[]
    ii_dfint_dstress = Int64[]; jj_dfint_dstress = Int64[]; vv_dfint_dstress = Float64[]


    neles = domain.neles
  
    # Loop over the elements in the elementGroup
    for iele  = 1:neles
      element = domain.elements[iele]
  
      # Get the element nodes
      el_nodes = getNodes(element)
  
      # Get the element nodes
      el_eqns = getEqns(domain,iele)
  
      el_dofs = getDofs(domain,iele)
  
      el_state  = getState(domain, el_dofs)
  

      gp_ids = (iele-1)*ngps_per_elem+1 : iele*ngps_per_elem
      # Get the element contribution by calling the specified action
      stiff, dfint_dstress = getStiffAndDforceDstress(element, el_state, stress[gp_ids,:], dstress_dstrain[gp_ids,:,:])
      
   
      # Assemble in the global array
      el_eqns_active = el_eqns .>= 1
      el_eqns_active_idx = el_eqns[el_eqns_active]
      # K[el_eqns[el_eqns_active], el_eqns[el_eqns_active]] += stiff[el_eqns_active,el_eqns_active]
      stiff_active = stiff[el_eqns_active,el_eqns_active]
      dfint_dstress_active = dfint_dstress[el_eqns_active,:]
      el_eqns_active_idx = el_eqns[el_eqns_active]

      for i = 1:length(el_eqns_active_idx)
        for j = 1:length(el_eqns_active_idx)
          push!(ii_stiff, el_eqns_active_idx[i])
          push!(jj_stiff, el_eqns_active_idx[j])
          push!(vv_stiff, stiff_active[i,j])
        end
      end


      for i = 1:length(el_eqns_active_idx)
        for j = 1:ngps_per_elem*nstrain
          push!(ii_dfint_dstress, el_eqns_active_idx[i])
          push!(jj_dfint_dstress, (iele-1)*ngps_per_elem*nstrain+j)
          push!(vv_dfint_dstress, dfint_dstress_active[i,j])
        end
      end

     
    end

    stiff_tran = sparse(jj_stiff, ii_stiff, vv_stiff, neqs, neqs) 
    dfint_dstress_tran =  sparse(jj_dfint_dstress, ii_dfint_dstress, vv_dfint_dstress, neles*ngps_per_elem*nstrain, neqs)
  
    return stiff_tran, dfint_dstress_tran
  end

  

function computDJDstate(state, obs_state)
  #J = (state - obs_state).^2
  2.0*state
end

function computJ(state, obs_state)
  sum((state - obs_state).^2)
end

@doc """
    Implicit solver for Ma + C v + R(u) = P
    a, v, u are acceleration, velocity and displacement

    u_{n+1} = u_n + dtv_n + dt^2/2 ((1 - 2\beta)a_n + 2\beta a_{n+1})
    v_{n+1} = v_n + dt((1 - gamma)a_n + gamma a_{n+1})

    M a_{n+0.5} + fint(u_{n+0.f}) = fext_{n+0.5}

    αm = (2\rho_oo - 1)/(\rho_oo + 1)
    αf = \rho_oo/(\rho_oo + 1)
    
    β2 = 0.5*(1 - αm + αf)^2
    γ = 0.5 - αm + αf

    absolution error ε = 1e-8, 
    relative error ε0 = 1e-8  
    
    return true or false indicating converging or not
"""->
function BackwardNewmarkSolver(globdat, domain, theta::Array{Float64},
     T::Float64, NT::Int64, state::Array{Float64}, obs_state::Array{Float64},
      αm::Float64 = -1.0, αf::Float64 = 0.0)
    Δt = T/NT
    β2 = 0.5*(1 - αm + αf)^2
    γ = 0.5 - αm + αf
    neles, ngps_per_elem, neqs = domain.neles, length(domain.elements[1].weights), domain.neqs
    nstrain = 3

    adj_lambda = zeros(NT+2,neqs)
    adj_tau = zeros(NT+2,neqs)
    adj_kappa = zeros(NT+2,neqs)
    adj_sigma = zeros(NT+2,neles*ngps_per_elem, nstrain)

    MT = (globdat.M)'
    J = 0.0 
    dJ = zeros(length(theta)) 

    for i = NT:-1:1
        # get strain
        strain, dstrain_dstate_tran = AdjointAssembleStrain(domain)
        

        stress, output, _ =  nn_constitutive_law([strain strain_p stress_p], theta, nothing, true, false)

        pnn_pstrain_tran, pnn_pstrain_p_tran, pnn_pstress_p_tran = output[:,1:3,:], output[:,4:6,:], output[:,7:9,:]

        stiff_tran, dfint_dstress_tran = AdjointAssembleStiff(domain, stress, permutedims(pnn_pstrain_tran,[1,3,2]))

        #compute tau^i
        adj_tau[i,:] = Δt * adj_lambda[i+1,:] + adj_tau[i+1,:]

        #compute kappa^i
        temp = (Δt*Δt*(1-β2)/2.0*adj_lambda[i+1,:] + adj_tau[i,:]*Δt*γ + adj_tau[i+1,:]*Δt*(1.0-γ)) - MT*(αm*adj_kappa[i+1,:]) 

        # dstrain_dstate_tran = dE_i/d d_i
        # dstrain_dstate_tran_p = dE_{i+1}/d d_{i+1}

        # pnn_pstrain_tran = pnn(E^i, E^{i-1}, S^{i-1})/pE^i
        # pnn_pdstrain_tran = pnn(E^i, E^{i-1}, S^{i-1})/pE^{i-1}
        # pnn_pstress_tran = pnn(E^i, E^{i-1}, S^{i-1})/pS^{i-1}

        rhs = computDJDstate(state[i, :], obs_state[i,:]) + adj_lambda[i+1,:] 

        tempmult = Array{Float64}(undef, nstrain, neles*ngps_per_elem)
        for j = 1:neles*ngps_per_elem
          tempmult[:,j] = pnn_pstrain_p_tran[j,:,:]*adj_sigma[i+1,j,:] 
        end

        rhs +=  dstrain_dstate_tran* tempmult[:]

        for j = 1:neles*ngps_per_elem
          tempmult[:,j] = pnn_pstrain_tran[j, :, :] *(pnn_pstress_p_tran[j,:,:]*adj_sigma[i+1,j,:])
        end

        rhs +=  dstrain_dstate_tran*tempmult

        rhs = rhs*(Δt*Δt/2.0*β2) + temp

        adj_kappa[i,:] = (MT*(1 - αm) + stiff_tran*(Δt*Δt/2.0*β2))\rhs


        rhs = MT * ((1 - αm)*adj_kappa[i,:]) - temp 
        adj_lambda[i,:] = rhs/(Δt*Δt/2.0 * β2)


        for j = 1:neles*ngps_per_elem
          tempmult[:,j] = pnn_pstress_p_tran[j,:,:]*adj_sigma[i+1,j,:]
        end

        adj_sigma[i,:] = -dfint_dstress_tran*adj_kappa[i,:] + tempmult



        _, _, sigmaTdstressdtheta =  nn_constitutive_law([strain strain_p stress_p], theta, adj_sigma[i,:], false, true)

        dJ -= sigmaTdstressdtheta
        

        dstrain_dstate_tran_p = dstrain_dstate_tran
        pnn_pstrain_p_tran_p = pnn_pstrain_p_tran
        pnn_pstress_p_tran_p = pnn_pstress_p_tran

        strain_p = strain
        stress_p = stress

    end

    
end 


@doc """
    Implicit solver for Ma + C v + R(u) = P
    a, v, u are acceleration, velocity and displacement

    u_{n+1} = u_n + dtv_n + dt^2/2 ((1 - 2\beta)a_n + 2\beta a_{n+1})
    v_{n+1} = v_n + dt((1 - gamma)a_n + gamma a_{n+1})

    M a_{n+0.5} + fint(u_{n+0.f}) = fext_{n+0.5}

    αm = (2\rho_oo - 1)/(\rho_oo + 1)
    αf = \rho_oo/(\rho_oo + 1)
    
    β2 = 0.5*(1 - αm + αf)^2
    γ = 0.5 - αm + αf

    absolution error ε = 1e-8, 
    relative error ε0 = 1e-8  
    
    return true or false indicating converging or not
"""->
function ForwardNewmarkSolver(globdat, domain, theta::Array{Float64},
                  T::Float64, NT::Int64, state::Array{Float64}, obs_state::Array{Float64},
                  αm::Float64 = -1.0, αf::Float64 = 0.0, ε::Float64 = 1e-8, ε0::Float64 = 1e-8, maxiterstep::Int64=100, η::Float64 = 1.0)
  
  Δt = T/NT
  β2 = 0.5*(1 - αm + αf)^2
  γ = 0.5 - αm + αf
  neles, ngps_per_elem, neqs = domain.neles, length(domain.elements[1].weights), domain.neqs
  nstrain = 3

  # 1: initial condition, compute 2, 3, 4 ... NT+1
  state = zeros(NT+1,neqs)
  vel = zeros(NT+1,neqs)
  acce = zeros(NT+1,neqs)


  M = globdat.M
  J = 0.0 

  strain_p = zeros(neles*ngps_per_elem, nstrain) 
  stress_p = zeros(neles*ngps_per_elem, nstrain)
  stress = zeros(neles*ngps_per_elem, nstrain) 
  strain = zeros(neles*ngps_per_elem, nstrain)

  for i = 1:NT
    globdat.time  += (1 - αf)*Δt
    domain.Dstate = domain.state[:]
    updateDomainStateBoundary!(domain, globdat)

  
    ∂∂u = globdat.acce[:] #∂∂uⁿ
    u = globdat.state[:]  #uⁿ
    ∂u  = globdat.velo[:] #∂uⁿ
    fext = getExternalForce(domain, globdat)

    ∂∂up = ∂∂u[:]

    Newtoniterstep, Newtonconverge = 0, false

    norm0 = Inf

    while !Newtonconverge
      
      Newtoniterstep += 1
      
      domain.state[domain.eq_to_dof] = (1 - αf)*(u + Δt*∂u + 0.5 * Δt * Δt * ((1 - β2)*∂∂u + β2*∂∂up)) + αf*u

      strain[:,:], dstrain_dstate_tran = AdjointAssembleStrain(domain)
      stress[:,:], output, _ =  nn_constitutive_law([strain strain_p stress_p], theta, nothing, true, false)
      pnn_pstrain_tran = output[:,1:3,:]
      
      fint, stiff = AssembleStiffAndForce(domain, stress, pnn_pstrain_tran'|->Arrary)

      res = M * (∂∂up *(1 - αm) + αm*∂∂u)  + fint - fext
      # @show fint, fext
      if Newtoniterstep==1
          res0 = res 
      end

      A = M*(1 - αm) + (1 - αf) * 0.5 * β2 * Δt^2 * stiff
      
      Δ∂∂u = A\res

      #@info " norm(Δ∂∂u) ", norm(Δ∂∂u) 
      while η * norm(Δ∂∂u) > norm0
          η /= 2.0
          @info "η", η
      end

      ∂∂up -= η*Δ∂∂u


      println("$Newtoniterstep/$maxiterstep, $(norm(res))")
      if (norm(res)< ε || norm(res)< ε0*norm(res0) ||Newtoniterstep > maxiterstep)
          if Newtoniterstep > maxiterstep
            
              @error("Newton iteration cannot converge $(norm(res))");
          else
              Newtonconverge = true
              printstyled("[Newmark] Newton converged $Newtoniterstep\n", color=:green)
          end
      end

      η = min(1.0, 2η)
      norm0 = norm(Δ∂∂u)
      # println("================ time = $(globdat.time) $Newtoniterstep =================")
  end
  


  globdat.Dstate = globdat.state[:]
  globdat.state += Δt * ∂u + Δt^2/2 * ((1 - β2) * ∂∂u + β2 * ∂∂up)
  globdat.velo += Δt * ((1 - γ) * ∂∂u + γ * ∂∂up)
  globdat.acce = ∂∂up[:]
  globdat.time  += αf*Δt


  #save data 
  state[i+1,:] = globdat.state
  vel[i+1,:] = globdat.vel
  acce[i+1,:] = globdat.acce
  
  stress_p = stress[:,:]
  strain_p = strain[:,:]


  #update J 
  J += computeJ(state[i+1,:], obs_state[i+1,:])

  end
end