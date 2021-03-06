export readMesh, save, load, read_data, write_data, convert_mat, read_strain_stress, 
        meshread, load_mesh


"""
    meshread(gmshfile::String)

Reads a gmsh file `gmshfile` and return (nodes, elements) tuple.
"""
function meshread(gmshfile::String)
    cnt = read(gmshfile, String)
    r = r"\$MeshFormat\n(\S*).*\n\$EndMeshFormat"s
    version = match(r, cnt)[1]
    println("Gmsh file version ... $version")

    r = r"\$Nodes\n(.*)\n\$EndNodes"s
    nodes = match(r, cnt)[1]
    nodes = split(nodes,'\n')
    nodes = [parse.(Float64, split(x)) for x in nodes]
    nodes = filter(x->length(x)==3,nodes)
    nodes = hcat(nodes...)'[:,1:2]
    println("Nodes ... $(size(nodes,1))")

    r = r"\$Elements\n(.*)\n\$EndElements"s
    elems = match(r, cnt)[1]
    elems = split(elems,'\n')
    elems = [parse.(Int64, split(x)) for x in elems]
    elems = filter(x->length(x)==5,elems)
    elems = hcat(elems...)'[:,2:5]
    println("Elements ... $(size(elems,1))")

    println("Remove redundant nodes...")
    s = Set(unique(elems[:]))
    k = 1
    node_new_id = Dict()
    new_id = Int64[]
    for i = 1:size(nodes, 1)
        if i in s 
            node_new_id[i] = k 
            push!(new_id, i)
            k += 1
        end
    end
    for i = 1:size(elems,1)
        for j = 1:4
            elems[i,j] = node_new_id[elems[i,j]]
        end
    end
    nodes = nodes[new_id,:]
    println("Preprocessed nodes ... $(size(nodes,1))")
    println("Preprocessed elements ... $(size(elems,1))")



    return nodes, elems 
end

"""
    readMesh(gmshFile::String)

Reads a `gmsh` file and extracts element, coordinates and boundaries.
"""
function readMesh(gmshFile::String)
    fp = open(gmshFile);
    boundaries = Dict{String, Array}()
    physicalnames = Dict{Int64, String}()
    nodes = nothing
    elements = nothing
    
    line = readline(fp)
    if (line == "\$MeshFormat")
        format = readline(fp)
        @assert(readline(fp) == "\$EndMeshFormat")
    end

    line = readline(fp)
    if (line == "\$PhysicalNames")
        nphys = parse(Int64,readline(fp))
        for i = 1:nphys
            line = readline(fp)
            physicalid = parse(Int64, split(line)[2])
            physicalnames[physicalid] = split(line)[3]
            boundaries[split(line)[3]] = []
        end
        @assert(readline(fp) == "\$EndPhysicalNames")
    end

    line = readline(fp)
    if (line == "\$Nodes")
        nnodes = parse(Int64, readline(fp))
        nodes = zeros(nnodes,2)
        for i = 1:nnodes
            l = readline(fp)|>split
            nodes[i,1] = parse(Float64, l[2])
            nodes[i,2] = parse(Float64, l[3])
        end
        @assert(readline(fp) == "\$EndNodes")
    end
    # println(physicalnames)
    # error()
    line = readline(fp)
    if (line == "\$Elements")
        nelems = readline(fp)
        nelems = parse(Int64,nelems)
        elements = []
        for i = 1:nelems
            l = readline(fp)|>split 
            l4 = parse(Int64, l[4])
            physicalname = physicalnames[l4]
            if startswith(physicalname,"\"Dirichlet")
                k1,k2 = parse(Int64, l[6]),parse(Int64, l[7])
                push!(boundaries[physicalname],[k1;k2])
            elseif startswith(physicalname,"\"Neumann")
                k1,k2 = parse(Int64, l[6]),parse(Int64, l[7])
                push!(boundaries[physicalname],[k1;k2])
            else 
                # println(physicalnames[l[4]], startswith(physicalnames[l[4]],"Dirichlet"))
                # println(l)
                k = [parse(Int64, l[i]) for i = 6:9]
                push!(elements, k)
            end
        end
        # elem = zeros(length(elements),4)
        # for i = 1:length(elements)
        #     elem[i,:] = elements[i]
        # end
        @assert(readline(fp) == "\$EndElements")
    end
    @warn("Jobs are not finished!!! Users need to compute EBC, g, NBC, f.")
    return elements, nodes, boundaries
end

function save(file::String, domain::Domain, globaldata::GlobalData)
    @save file domain globaldata
end

function load(file::String)
    @load file domain globaldata
    return domain, globaldata
end


# domain.state, domain.fint, fext
function write_data(file::String, domain::Domain)
    file = matopen(file, "w")
    write(file, "state", domain.history["state"])
    write(file, "fext", domain.history["fext"])
    write(file, "fint", domain.history["fint"])
    write(file, "strain", domain.history["strain"])
    write(file, "stress", domain.history["stress"])
    close(file)
end

# state, fext
function read_data(file::String)
    vars = matread(file)
    #use fint, strain, stress, for debugging purpose
    vars["state"], vars["fext"]
end

# state, fext
function read_strain_stress(file::String)
    vars = matread(file)
    #use fint, strain, stress, for debugging purpose
    vars["strain"], vars["stress"]
end

# type == nn2array: read mat convert to 1D array
# type == array2nn: read 1D array convert to mat
function convert_mat(type::String, nnlayers::Array{Int64}, file1::String)
    if type == "nn2array" 
       nn = matread(file1)
       nnlayerNum = length(nnlayers) - 1
       theta_indptr = ones(Int64, 2*nnlayerNum+1)
       for i = 1:nnlayerNum
       	   theta_indptr[2*i]   = theta_indptr[2*i-1] + nnlayers[i]*nnlayers[i+1]
	       theta_indptr[2*i+1] = theta_indptr[2*i] + nnlayers[i+1]
       end

       
       theta = zeros(Float64, theta_indptr[end]-1)
       for i = 1:nnlayerNum
           for name in nn
               if occursin("connected_" * string(i) * "backslashweights", name.first)
                   theta[theta_indptr[2*(i+1)-1]:theta_indptr[2*(i+1)]-1] = transpose(name.second)[:]
               end
  	       if occursin("connected_" * string(i) * "backslashbiases", name.first)
                   theta[theta_indptr[2*(i+1)]:theta_indptr[2*(i+1)+1]-1] = transpose(name.second)[:]
               end
  	       if occursin("connectedbackslashweights", name.first)
                   theta[theta_indptr[1]:theta_indptr[2]-1] = transpose(name.second)[:]
               end
  	       if occursin("connectedbackslashbiases", name.first)
                   theta[theta_indptr[2]:theta_indptr[3]-1] = transpose(name.second)[:]
               end
           end
       end    

       return theta
   end
end

"""
    load_mesh(s::String = "holes")

Load built-in meshes from `$(abspath(joinpath(@__DIR__, "../../deps/Data/")))`.
"""
function load_mesh(s::String = "holes")
    meshdata = joinpath(@__DIR__, "../../deps/Data/$s.mat")
    data = matread(meshdata)
    data["node"], data["elem"]
end