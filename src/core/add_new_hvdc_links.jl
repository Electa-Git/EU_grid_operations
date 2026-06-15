function add_hvdc_links(grid_data, links)

    # AC bus loactions: A-North: Emden Ost -> Osterath, Ultranet: Osterath -> Phillipsburg
    # Rating: 2 GW, 525 kV
    # Emden Ost: lat: 53.355716, lon: 7.244506
    # Osterath: lat: 51.26027036315153, lon: 6.627044464872153
    # Phillipsburg: lat: 49.255371 lon: 8.438422
    power_rating = 20.0
    dc_voltage = 525
    grid_data_inv = deepcopy(grid_data)
    for (key, link) in links
        if key == "Ultranet"
            # Conenction Emden Ost, Osterath first
            # First Step: ADD dc bus & converter in Emden Ost
            grid_data_inv, dc_bus_idx_em = add_dc_bus!(grid_data_inv, dc_voltage; lat = 53.355716, lon = 7.244506)
            ac_bus_idx = find_closest_bus(grid_data_inv, 53.355716, 7.244506)
            add_converter!(grid_data_inv, ac_bus_idx, dc_bus_idx_em, power_rating)
            # Second step: ADD dc bus & converter in Osterath and DC branch Emden -> Osterath
            grid_data_inv, dc_bus_idx_os = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.26027036315153, lon = 6.627044464872153)
            ac_bus_idx = find_closest_bus(grid_data_inv, 51.26027036315153, 6.627044464872153)
            add_converter!(grid_data_inv, ac_bus_idx, dc_bus_idx_os, power_rating)
            add_dc_branch!(grid_data_inv, dc_bus_idx_em, dc_bus_idx_os, power_rating)
            # Third step add dc bus and converter in Phillipsburg & branch Osterath - Phillipsburg
            grid_data_inv, dc_bus_idx_ph = add_dc_bus!(grid_data_inv, dc_voltage; lat = 49.255371, lon = 8.438422)
            ac_bus_idx = find_closest_bus(grid_data_inv, 49.255371, 8.438422)
            add_converter!(grid_data_inv, ac_bus_idx, dc_bus_idx_ph, power_rating)
            add_dc_branch!(grid_data_inv, dc_bus_idx_os, dc_bus_idx_ph, power_rating)
        elseif key == "Suedlink"
            # Brunsbuettel: 53.9160355330674, 9.235429411946734
            # Grossgartach: 49.1424721420109, 9.149063227242355
            power_rating = 40.0
            grid_data_inv, dc_bus_idx_bb = add_dc_bus!(grid_data_inv, dc_voltage; lat = 53.9160355330674, lon = 9.235429411946734)
            ac_bus_idx = find_closest_bus(grid_data_inv, 53.9160355330674, 9.235429411946734)
            add_converter!(grid_data_inv, ac_bus_idx, dc_bus_idx_bb, power_rating)
            grid_data_inv, dc_bus_idx_gg = add_dc_bus!(grid_data_inv, dc_voltage; lat = 49.1424721420109, lon = 9.149063227242355)
            ac_bus_idx = find_closest_bus(grid_data_inv, 49.1424721420109, 9.149063227242355)
            add_converter!(grid_data_inv, ac_bus_idx, dc_bus_idx_gg, power_rating)
            add_dc_branch!(grid_data_inv, dc_bus_idx_bb, dc_bus_idx_gg, power_rating)
        elseif key == "Suedostlink" 
            # Wolmirstedt: 52.26902204809363, 11.639982340653019
            # Isar: 48.60705,12.29723
            grid_data_inv, dc_bus_idx_ws = add_dc_bus!(grid_data_inv, dc_voltage; lat = 52.26902204809363, lon = 11.639982340653019)
            ac_bus_idx = find_closest_bus(grid_data_inv, 52.26902204809363, 11.639982340653019)
            add_converter!(grid_data_inv, ac_bus_idx, dc_bus_idx_ws, power_rating)
            grid_data_inv, dc_bus_idx_is = add_dc_bus!(grid_data_inv, dc_voltage; lat = 48.60705, lon = 12.29723)
            ac_bus_idx = find_closest_bus(grid_data_inv, 48.60705, 12.29723)
            add_converter!(grid_data_inv, ac_bus_idx, dc_bus_idx_is, power_rating)
            add_dc_branch!(grid_data_inv, dc_bus_idx_ws, dc_bus_idx_is, power_rating)
        end
    end
    return grid_data_inv
end

function find_closest_bus(grid_data, lat, lon)
    bus_lat_lon = zeros(length(grid_data["bus"]), 3)
    idx = 1
    for (b, bus) in grid_data["bus"]
        bus_lat_lon[idx, :] = [parse(Int, b), bus["lat"], bus["lon"]]
        idx = idx + 1
    end

    dist = (abs.(bus_lat_lon[:, 2] .- lat)).^2 .+ (abs.(bus_lat_lon[:, 3] .- lon)).^2
    mindist = findmin(dist)
    bus_idx = Int(bus_lat_lon[mindist[2], 1])

    return bus_idx
end

function add_dc_bus!(grid_data, dc_voltage; dc_bus_id = nothing, lat = 0, lon = 0)
    if isnothing(dc_bus_id)
        dc_bus_idx = maximum([bus["index"] for (b, bus) in grid_data["busdc"]]) + 1
    else
        dc_bus_idx = dc_bus_id
    end
    grid_data["busdc"]["$dc_bus_idx"] = Dict{String, Any}()  # create dictionary for each bus
    grid_data["busdc"]["$dc_bus_idx"]["busdc_i"] = dc_bus_idx # assign dc bus idx
    grid_data["busdc"]["$dc_bus_idx"]["grid"] = 1 # default, no meaning
    grid_data["busdc"]["$dc_bus_idx"]["Pdc"] = 0 # demand at DC bus, normally 0
    grid_data["busdc"]["$dc_bus_idx"]["Vdc"] = 1 # dc voltage set point 1 particular
    grid_data["busdc"]["$dc_bus_idx"]["basekVdc"] = dc_voltage # Binary indicator if reactor is installed
    grid_data["busdc"]["$dc_bus_idx"]["Vdcmax"] = 1.1 # maximum voltage 1.1 pu
    grid_data["busdc"]["$dc_bus_idx"]["Vdcmin"] = 0.9 # minimum voltage 0.9 pu
    grid_data["busdc"]["$dc_bus_idx"]["Cdc"] = 0 # not used
    grid_data["busdc"]["$dc_bus_idx"]["index"] = dc_bus_idx # not used
    grid_data["busdc"]["$dc_bus_idx"]["lat"] = lat
    grid_data["busdc"]["$dc_bus_idx"]["lon"] = lon

    return grid_data, dc_bus_idx
end

function add_ac_bus!(grid_data, ac_voltage; ac_bus_id = nothing, lat = 0, lon = 0)
    if isnothing(ac_bus_id)
        ac_bus_idx = maximum([bus["index"] for (b, bus) in grid_data["busdc"]]) + 1
    else
        ac_bus_idx = ac_bus_id
    end
    grid_data["bus"]["$ac_bus_idx"] = Dict{String, Any}()  # create dictionary for each bus
    grid_data["bus"]["$ac_bus_idx"]["lat"] = lat
    grid_data["bus"]["$ac_bus_idx"]["lon"] = lon
    grid_data["bus"]["$ac_bus_idx"]["bus_i"] = ac_bus_idx # assign dc bus idx
    grid_data["bus"]["$ac_bus_idx"]["name"] = "EI_BE"
    grid_data["bus"]["$ac_bus_idx"]["bus_type"] = 2 # assign bus type
    grid_data["bus"]["$ac_bus_idx"]["vmax"] = 1.05 # maximum voltage 1.1 pu
    grid_data["bus"]["$ac_bus_idx"]["qd"] = 0 # demand at DC bus, normally 0
    grid_data["bus"]["$ac_bus_idx"]["gs"] = 0 # demand at DC bus, normally 0
    grid_data["bus"]["$ac_bus_idx"]["bs"] = 0 # demand at DC bus, normally 0
    grid_data["bus"]["$ac_bus_idx"]["source_id"] = [] # demand at DC bus, normally 0
    push!(grid_data["bus"]["$ac_bus_idx"]["source_id"],"bus") # demand at DC bus, normally 0
    push!(grid_data["bus"]["$ac_bus_idx"]["source_id"],ac_bus_idx) # demand at DC bus, normally 0
    grid_data["bus"]["$ac_bus_idx"]["area"] = 1 # default, no meaning
    grid_data["bus"]["$ac_bus_idx"]["vmin"] = 0.95 # minimum voltage 0.9 pu
    grid_data["bus"]["$ac_bus_idx"]["index"] = ac_bus_idx # not used
    grid_data["bus"]["$ac_bus_idx"]["va"] = 0 # dc voltage set point 1 particular
    grid_data["bus"]["$ac_bus_idx"]["vm"] = 0 # dc voltage set point 1 particular
    grid_data["bus"]["$ac_bus_idx"]["base_kv"] = ac_voltage # Binary indicator if reactor is installed
    grid_data["bus"]["$ac_bus_idx"]["pd"] = 0 # demand at DC bus, normally 0
    return grid_data, ac_bus_idx
end

function add_ac_bus_offshore!(grid_data, ac_voltage, ac_bus_idx; lat = 0, lon = 0)
    grid_data["bus"]["$ac_bus_idx"] = Dict{String, Any}()  # create dictionary for each bus
    grid_data["bus"]["$ac_bus_idx"]["lat"] = lat
    grid_data["bus"]["$ac_bus_idx"]["lon"] = lon
    grid_data["bus"]["$ac_bus_idx"]["bus_i"] = ac_bus_idx # assign dc bus idx
    grid_data["bus"]["$ac_bus_idx"]["name"] = "EI_BE"
    grid_data["bus"]["$ac_bus_idx"]["bus_type"] = 2 # assign bus type
    grid_data["bus"]["$ac_bus_idx"]["vmax"] = 1.05 # maximum voltage 1.1 pu
    grid_data["bus"]["$ac_bus_idx"]["qd"] = 0 # demand at DC bus, normally 0
    grid_data["bus"]["$ac_bus_idx"]["gs"] = 0 # demand at DC bus, normally 0
    grid_data["bus"]["$ac_bus_idx"]["bs"] = 0 # demand at DC bus, normally 0
    grid_data["bus"]["$ac_bus_idx"]["source_id"] = [] # demand at DC bus, normally 0
    push!(grid_data["bus"]["$ac_bus_idx"]["source_id"],"bus") # demand at DC bus, normally 0
    push!(grid_data["bus"]["$ac_bus_idx"]["source_id"],ac_bus_idx) # demand at DC bus, normally 0
    grid_data["bus"]["$ac_bus_idx"]["area"] = 1 # default, no meaning
    grid_data["bus"]["$ac_bus_idx"]["vmin"] = 0.95 # minimum voltage 0.9 pu
    grid_data["bus"]["$ac_bus_idx"]["index"] = ac_bus_idx # not used
    grid_data["bus"]["$ac_bus_idx"]["va"] = 0 # dc voltage set point 1 particular
    grid_data["bus"]["$ac_bus_idx"]["vm"] = 0 # dc voltage set point 1 particular
    grid_data["bus"]["$ac_bus_idx"]["base_kv"] = ac_voltage # Binary indicator if reactor is installed
    grid_data["bus"]["$ac_bus_idx"]["pd"] = 0 # demand at DC bus, normally 0
    return grid_data, ac_bus_idx
end

function add_converter!(grid_data, ac_bus_idx, dc_bus_idx, power_rating; zone = nothing, islcc = 0, conv_id = nothing, status = 1)
    if isnothing(conv_id)
        conv_idx = maximum([conv["index"] for (c, conv) in grid_data["convdc"]]) + 1
    else
        conv_idx = conv_id
    end
    print("ac_bus_idx IS",ac_bus_idx,"\n")
    grid_data["convdc"]["$conv_idx"] = Dict{String, Any}()  # create dictionary for each converter
    grid_data["convdc"]["$conv_idx"]["busdc_i"] = dc_bus_idx  # assign dc bus idx
    grid_data["convdc"]["$conv_idx"]["busac_i"] = ac_bus_idx  # assign ac bus idx
    grid_data["convdc"]["$conv_idx"]["type_dc"] = 1  # 1 -> const. dc power, 2-> constant dc voltage, 3 -> dc slack for grid. Not relevant for OPF!
    grid_data["convdc"]["$conv_idx"]["type_ac"] = 1  # 1 -> PQ, 2-> PV. Not relevant for OPF!
    grid_data["convdc"]["$conv_idx"]["P_g"] = 0 # converter P set point input
    grid_data["convdc"]["$conv_idx"]["Q_g"] = 0 # converter Q set point input
    grid_data["convdc"]["$conv_idx"]["islcc"] = islcc # LCC converter or not?
    grid_data["convdc"]["$conv_idx"]["Vtar"] = 1 # Target voltage for droop converter, not relevant for OPF!
    grid_data["convdc"]["$conv_idx"]["rtf"] = 0.01 # Transformer resistance in p.u.
    grid_data["convdc"]["$conv_idx"]["xtf"] = 0.01 # Transformer reactance in p.u.
    grid_data["convdc"]["$conv_idx"]["transformer"] = 1 # Binary indicator if transformer is installed
    grid_data["convdc"]["$conv_idx"]["tm"] = 1 # Transformer tap ratio
    grid_data["convdc"]["$conv_idx"]["bf"] = 0.01 # Filter susceptance in p.u.
    grid_data["convdc"]["$conv_idx"]["filter"] = 1 # Binary indicator if transformer is installed
    grid_data["convdc"]["$conv_idx"]["rc"] = 0.01 # Reactor resistance in p.u.
    grid_data["convdc"]["$conv_idx"]["xc"] = 0.01 # Reactor reactance in p.u.
    grid_data["convdc"]["$conv_idx"]["reactor"] = 1 # Binary indicator if reactor is installed
    grid_data["convdc"]["$conv_idx"]["basekVac"] = grid_data["bus"]["$ac_bus_idx"]["base_kv"]
    grid_data["convdc"]["$conv_idx"]["Vmmax"] = 1.1 # Range for AC voltage
    grid_data["convdc"]["$conv_idx"]["Vmmin"] = 0.9 # Range for AC voltage
    grid_data["convdc"]["$conv_idx"]["Imax"] = power_rating  # maximum AC current of converter
    grid_data["convdc"]["$conv_idx"]["LossA"] = 0 #power_rating * 0.001  # Aux. losses parameter in MW
    grid_data["convdc"]["$conv_idx"]["LossB"] = 0 #0.6 / power_rating # 0.887  # Proportional losses losses parameter in MW
    grid_data["convdc"]["$conv_idx"]["LossCrec"] = 0#2.885  # Quadratic losses losses parameter in MW^2
    grid_data["convdc"]["$conv_idx"]["LossCinv"] = 0#2.885  # Quadratic losses losses parameter in MW^2
    grid_data["convdc"]["$conv_idx"]["droop"] = 0  # Power voltage droop, not relevant for OPF
    grid_data["convdc"]["$conv_idx"]["Pdcset"] = 0  # DC power setpoint for droop, not relevant OPF
    grid_data["convdc"]["$conv_idx"]["Vdcset"] = 0  # DC voltage setpoint for droop, not relevant OPF
    grid_data["convdc"]["$conv_idx"]["Pacmax"] =  power_rating   # maximum AC power
    grid_data["convdc"]["$conv_idx"]["Pacmin"] = -power_rating  # maximum AC power
    grid_data["convdc"]["$conv_idx"]["Pacrated"] =  power_rating * 1.1   # maximum AC power
    grid_data["convdc"]["$conv_idx"]["Qacrated"] =  0.4 * power_rating  * 1.1  # maximum AC reactive power -> assumption
    grid_data["convdc"]["$conv_idx"]["Qacmax"] =  0.4 * power_rating  # maximum AC reactive power -> assumption
    grid_data["convdc"]["$conv_idx"]["Qacmin"] =  -0.4 * power_rating  # maximum AC reactive power -> assumption
    grid_data["convdc"]["$conv_idx"]["index"] = conv_idx
    grid_data["convdc"]["$conv_idx"]["status"] = status
    grid_data["convdc"]["$conv_idx"]["inertia_constants"] = 10 # typical virtual inertia constant.
    if !isnothing(zone)
        grid_data["convdc"]["$conv_idx"]["zone"] = zone
    end

    return grid_data
end

# function add_generator!(grid_data, ac_bus_idx, gen_bus, power_rating, gen_cost, gen_zone; gen_id = nothing, status = 1) # To be done later
#     if isnothing(gen_id)
#         gen_idx = maximum([gen["index"] for (g, gen) in grid_data["gen"]]) + 1
#     else
#         gen_idx = gen_id
#     end
#     grid_data["gen"]["$gen_idx"] = Dict{String, Any}()  # create dictionary for each converter
#     grid_data["gen"]["$gen_idx"]["zone"] = gen_zone  
#     grid_data["gen"]["$gen_idx"]["type_tyndp"] = "Offshore Wind"  
#     grid_data["gen"]["$gen_idx"]["model"] = 2  
#     grid_data["gen"]["$gen_idx"]["gen_bus"] = gen_bus
#     grid_data["gen"]["$gen_idx"]["pmax"] = power_rating 
#     grid_data["gen"]["$gen_idx"]["country"] = 4
#     grid_data["gen"]["$gen_idx"]["vg"] = 1.0
#     grid_data["gen"]["$gen_idx"]["source_id"] = []
#     push!(grid_data["gen"]["$gen_idx"]["source_id"],"gen")
#     push!(grid_data["gen"]["$gen_idx"]["source_id"],gen_idx)
#     grid_data["gen"]["$gen_idx"]["index"] = gen_idx
#     grid_data["gen"]["$gen_idx"]["cost"] = []
#     push!(grid_data["gen"]["$gen_idx"]["cost"],gen_cost)
#     push!(grid_data["gen"]["$gen_idx"]["cost"],0.0)
#     grid_data["gen"]["$gen_idx"]["qmax"] = 6.0 
#     grid_data["gen"]["$gen_idx"]["gen_status"] = 1
#     grid_data["gen"]["$gen_idx"]["qmin"] = - 6.0 
#     grid_data["gen"]["$gen_idx"]["type"] = "Offshore"  
#     grid_data["gen"]["$gen_idx"]["pmin"] = 0.0 
#     grid_data["gen"]["$gen_idx"]["ncost"] = 2 
    
#     return grid_data
# end

function add_dc_branch!(grid_data, fbus_dc, tbus_dc, power_rating; status = 1, r = 0.006, branch_id = nothing)
    if isnothing(branch_id)
        dc_br_idx = maximum([branch["index"] for (br, branch) in grid_data["branchdc"]]) + 1
    else
        dc_br_idx = branch_id
    end
    grid_data["branchdc"]["$dc_br_idx"] = Dict{String, Any}()
    grid_data["branchdc"]["$dc_br_idx"]["fbusdc"] = fbus_dc
    grid_data["branchdc"]["$dc_br_idx"]["tbusdc"] = tbus_dc
    grid_data["branchdc"]["$dc_br_idx"]["r"] = r
    grid_data["branchdc"]["$dc_br_idx"]["l"] = 0   # zero in steady state
    grid_data["branchdc"]["$dc_br_idx"]["c"] = 0 # zero in steady state
    grid_data["branchdc"]["$dc_br_idx"]["rateA"] = power_rating
    grid_data["branchdc"]["$dc_br_idx"]["rateB"] = power_rating
    grid_data["branchdc"]["$dc_br_idx"]["rateC"] = power_rating
    grid_data["branchdc"]["$dc_br_idx"]["status"] = status
    grid_data["branchdc"]["$dc_br_idx"]["index"] = dc_br_idx
    grid_data["branchdc"]["$dc_br_idx"]["source_id"] = []
    push!(grid_data["branchdc"]["$dc_br_idx"]["source_id"],"branchdc")
    push!(grid_data["branchdc"]["$dc_br_idx"]["source_id"],dc_br_idx)

    return grid_data
end

function add_ac_branch!(grid_data, fbus, tbus, power_rating; status = 1, r = 0.001, branch_id = nothing)
    if isnothing(branch_id)
        br_idx = maximum([branch["index"] for (br, branch) in grid_data["branch"]]) + 1
    else
        br_idx = branch_id
    end
    grid_data["branch"]["$br_idx"] = Dict{String, Any}()
    grid_data["branch"]["$br_idx"]["f_bus"] = fbus
    grid_data["branch"]["$br_idx"]["t_bus"] = tbus
    grid_data["branch"]["$br_idx"]["br_r"] = r
    grid_data["branch"]["$br_idx"]["br_x"] = 0.001   # zero in steady state
    grid_data["branch"]["$br_idx"]["rate_a"] = power_rating
    grid_data["branch"]["$br_idx"]["rate_b"] = power_rating
    grid_data["branch"]["$br_idx"]["rate_c"] = power_rating
    grid_data["branch"]["$br_idx"]["status"] = status
    grid_data["branch"]["$br_idx"]["index"] = br_idx
    grid_data["branch"]["$br_idx"]["interconnector"] = false
    grid_data["branch"]["$br_idx"]["transformer"] = false
    grid_data["branch"]["$br_idx"]["type"] = "AC line"
    grid_data["branch"]["$br_idx"]["tap"] = 1.0
    grid_data["branch"]["$br_idx"]["g_to"] = 1.0
    grid_data["branch"]["$br_idx"]["g_fr"] = 1.0
    grid_data["branch"]["$br_idx"]["b_fr"] = 10.0
    grid_data["branch"]["$br_idx"]["b_to"] = 10.0
    grid_data["branch"]["$br_idx"]["base_kv"] = 220
    grid_data["branch"]["$br_idx"]["source_id"] = []
    push!(grid_data["branch"]["$br_idx"]["source_id"],"branch")
    push!(grid_data["branch"]["$br_idx"]["source_id"],br_idx)
    grid_data["branch"]["$br_idx"]["br_status"] = 1
    grid_data["branch"]["$br_idx"]["shift"] = 0.0
    grid_data["branch"]["$br_idx"]["ratio"] = 1
    grid_data["branch"]["$br_idx"]["angmin"] = - 1.0472
    grid_data["branch"]["$br_idx"]["angmax"] = 1.0472
    return grid_data
end

function add_Belgian_energy_island(grid_data,links)
    # AC bus locations: 
    # EI_AC_1: lat: 51.646504 , lon: 2.678687 
    # EI_AC_2: lat: 51.646504 , lon: 2.678687 (same as EI_AC_1)

    # DC bus locations:
    # EI_DC_1: lat: 51.6468 ,  lon: 2.778687 (Energy island)
    # EI_DC_2: lat: 51.780669, lon: 3.006469 (Switchyard)
    # EI_DC_3: lat: 51.888354, lon: 1.209372 (Onshore UK)
    # Gezelle DC bus: lat: 51.2747, lon: 3.22923 (Onshore BE)

    # Rating: 2 GW towards Belgium, 525 kV
    # Rating: 1.4 GW towards the UK, 525 kV

    power_rating_BE = 20.0
    power_rating_UK = 14.0

    dc_voltage = 525
    ac_voltage = 220 #kV
    grid_data_inv = deepcopy(grid_data)
    for (key, link) in links
        if key == "Energy Island"
            # First Step: Building the energy island with an AC bus
            grid_data_inv, ac_bus_idx_ei = add_ac_bus!(grid_data_inv, ac_voltage; lat = 51.646504 , lon = 2.678687)

            #Add 6 ac_branches to Gezelle
            add_ac_branch!(grid_data_inv, ac_bus_idx_ei, 131, 4.0)
            add_ac_branch!(grid_data_inv, ac_bus_idx_ei, 131, 4.0)
            add_ac_branch!(grid_data_inv, ac_bus_idx_ei, 131, 4.0)
            add_ac_branch!(grid_data_inv, ac_bus_idx_ei, 131, 4.0)
            add_ac_branch!(grid_data_inv, ac_bus_idx_ei, 131, 4.0)
            add_ac_branch!(grid_data_inv, ac_bus_idx_ei, 131, 4.0)

            grid_data_inv["branch"]["213"]["rate_a"] = grid_data["branch"]["213"]["rate_a"]*2 
            grid_data_inv["branch"]["214"]["rate_a"] = grid_data["branch"]["214"]["rate_a"]*2 
            grid_data_inv["branch"]["215"]["rate_a"] = grid_data["branch"]["215"]["rate_a"]*2 
            grid_data_inv["branch"]["216"]["rate_a"] = grid_data["branch"]["216"]["rate_a"]*2 
            grid_data_inv["branch"]["217"]["rate_a"] = grid_data["branch"]["217"]["rate_a"]*2
            grid_data_inv["branch"]["213"]["br_r"] = grid_data["branch"]["213"]["br_r"]/2 
            grid_data_inv["branch"]["214"]["br_r"] = grid_data["branch"]["214"]["br_r"]/2 
            grid_data_inv["branch"]["215"]["br_r"] = grid_data["branch"]["215"]["br_r"]/2 
            grid_data_inv["branch"]["216"]["br_r"] = grid_data["branch"]["216"]["br_r"]/2 
            grid_data_inv["branch"]["217"]["br_r"] = grid_data["branch"]["217"]["br_r"]/2 
            grid_data_inv["branch"]["213"]["br_x"] = grid_data["branch"]["213"]["br_x"]/2 
            grid_data_inv["branch"]["214"]["br_x"] = grid_data["branch"]["214"]["br_x"]/2 
            grid_data_inv["branch"]["215"]["br_x"] = grid_data["branch"]["215"]["br_x"]/2 
            grid_data_inv["branch"]["216"]["br_x"] = grid_data["branch"]["216"]["br_x"]/2 
            grid_data_inv["branch"]["217"]["br_x"] = grid_data["branch"]["217"]["br_x"]/2 

            # Second Step: Building the DC part of the energy island with three DC buses
            # DC bus energy island
            grid_data_inv, dc_bus_idx_ei = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.6468 , lon = 2.778687)
            add_converter!(grid_data_inv, ac_bus_idx_ei, dc_bus_idx_ei, 99.0) # Converter between AC and DC parts of the energy island

            # DC switchyard bus energy island
            grid_data_inv, dc_bus_idx_switchyard = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.7806 , lon = 3.006469)
            add_dc_branch!(grid_data_inv, dc_bus_idx_ei, dc_bus_idx_switchyard, 99.0)

            # DC UK bus energy island
            grid_data_inv, dc_bus_idx_uk = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.8883 , lon = 2.609372)
            add_dc_branch!(grid_data_inv, dc_bus_idx_uk, dc_bus_idx_switchyard, 14.0)

            # DC onshore UK bus energy island
            grid_data_inv, dc_bus_idx_uk_onshore = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.880090 , lon = 1.192580) # onshore
            ac_bus_idx_uk = find_closest_bus(grid_data_inv,51.880090 ,1.192580)
            grid_data_inv["bus"]["5779"]["base_kV"] = 400
            add_converter!(grid_data_inv, ac_bus_idx_uk, dc_bus_idx_uk_onshore, 14.0)
            add_dc_branch!(grid_data_inv, dc_bus_idx_uk_onshore, dc_bus_idx_uk, 14.0)

            # DC onshore BE bus energy island (next to Gezelle)
            grid_data_inv, dc_bus_idx_be_onshore = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.269453 , lon = 3.211539) # onshore
            add_converter!(grid_data_inv, 131, dc_bus_idx_be_onshore, 20.0)
            add_dc_branch!(grid_data_inv, dc_bus_idx_switchyard, dc_bus_idx_be_onshore, 20.0)

            # Adding generators for the energy island
            #add_generator!(grid_data_inv, ac_bus_idx_ei, ac_bus_idx_ei, 35.0; status = 1)
        end
    end
    return grid_data_inv
end

function add_full_Belgian_energy_island(grid_data, gen_cost)
    # AC bus locations: 
    # EI_AC_1: lat: 51.646504 , lon: 2.678687 
    # EI_AC_2: lat: 51.646504 , lon: 2.678687 (same as EI_AC_1)

    # DC bus locations:
    # EI_DC_1: lat: 51.6468 ,  lon: 2.778687 (Energy island)
    # EI_DC_2: lat: 51.780669, lon: 3.006469 (Switchyard)
    # EI_DC_3: lat: 51.888354, lon: 1.209372 (Onshore UK)
    # Gezelle DC bus: lat: 51.2747, lon: 3.22923 (Onshore BE)

    # Rating: 2 GW towards Belgium, 525 kV
    # Rating: 1.4 GW towards the UK, 525 kV

    power_rating_BE = 20.0
    power_rating_DK = 20.0
    power_rating_UK = 14.0

    offshore_wind_AC_BE = 21.0
    offshore_wind_DC_BE = 14.0
    offshore_wind_DK = 21.0
    offshore_wind_FR = 21.0

    dc_voltage = 525
    ac_voltage = 220 #kV
    grid_data_inv = deepcopy(grid_data)

    # First Step: Building the energy island with an AC bus
    grid_data_inv, ac_bus_idx_ei_AC = add_ac_bus_offshore!(grid_data_inv, ac_voltage, 10001; lat = 51.646504 , lon = 2.678687)
    grid_data_inv, ac_bus_idx_ei_DC = add_ac_bus_offshore!(grid_data_inv, ac_voltage, 10002; lat = 51.646510 , lon = 2.678687)

    #Add 6 ac_branches to Gezelle + switch on the island
    add_ac_branch!(grid_data_inv, ac_bus_idx_ei_AC, 131, 4.0)
    add_ac_branch!(grid_data_inv, ac_bus_idx_ei_AC, 131, 4.0)
    add_ac_branch!(grid_data_inv, ac_bus_idx_ei_AC, 131, 4.0)
    add_ac_branch!(grid_data_inv, ac_bus_idx_ei_AC, 131, 4.0)
    add_ac_branch!(grid_data_inv, ac_bus_idx_ei_AC, 131, 4.0)
    add_ac_branch!(grid_data_inv, ac_bus_idx_ei_AC, 131, 4.0)
    add_ac_branch!(grid_data_inv, ac_bus_idx_ei_AC, ac_bus_idx_ei_DC, 30.0)

    # Increasing the maximum power through the lines in BE (onshore)
    #grid_data_inv["branch"]["213"]["br_r"] = grid_data["branch"]["213"]["br_r"]/2 
    #grid_data_inv["branch"]["214"]["br_r"] = grid_data["branch"]["214"]["br_r"]/2 
    #grid_data_inv["branch"]["215"]["br_r"] = grid_data["branch"]["215"]["br_r"]/2 
    #grid_data_inv["branch"]["216"]["br_r"] = grid_data["branch"]["216"]["br_r"]/2 
    #grid_data_inv["branch"]["217"]["br_r"] = grid_data["branch"]["217"]["br_r"]/2 
    #grid_data_inv["branch"]["213"]["br_x"] = grid_data["branch"]["213"]["br_x"]/2 
    #grid_data_inv["branch"]["214"]["br_x"] = grid_data["branch"]["214"]["br_x"]/2 
    #grid_data_inv["branch"]["215"]["br_x"] = grid_data["branch"]["215"]["br_x"]/2 
    #grid_data_inv["branch"]["216"]["br_x"] = grid_data["branch"]["216"]["br_x"]/2 
    #grid_data_inv["branch"]["217"]["br_x"] = grid_data["branch"]["217"]["br_x"]/2 

    # Second Step: Building the DC part of the energy island with three DC buses
    # DC bus energy island
    grid_data_inv, dc_bus_idx_ei = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.6468 , lon = 2.778687)
    grid_data_inv["busdc"]["$dc_bus_idx_ei"]["name"] = "EI_DC_BE"
    add_converter!(grid_data_inv, ac_bus_idx_ei_DC, dc_bus_idx_ei, 20.5) # Converter between AC and DC parts of the energy island

    # DC switchyard bus energy island
    grid_data_inv, dc_bus_idx_switchyard = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.7806 , lon = 3.006469)
    grid_data_inv["busdc"]["$dc_bus_idx_switchyard"]["name"] = "EI_DC_SW"
    add_dc_branch!(grid_data_inv, dc_bus_idx_ei, dc_bus_idx_switchyard, 20.0)

    # Adding generators to the energy island
    add_generator!(grid_data_inv, ac_bus_idx_ei_AC, ac_bus_idx_ei_AC, 21.0, gen_cost, "BE"; status = 1)
    add_generator!(grid_data_inv, ac_bus_idx_ei_DC, ac_bus_idx_ei_DC, 14.0, gen_cost, "BE"; status = 1)
    
    ## Belgium
    # DC onshore BE bus energy island (next to Gezelle)
    grid_data_inv, dc_bus_idx_be_onshore = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.269453 , lon = 3.211539) # onshore
    grid_data_inv["busdc"]["$dc_bus_idx_be_onshore"]["name"] = "EI_DC_BE_ONSHORE"
    add_converter!(grid_data_inv, 131, dc_bus_idx_be_onshore, 20.0)
    add_dc_branch!(grid_data_inv, dc_bus_idx_switchyard, dc_bus_idx_be_onshore, 20.0)
    
    ## United Kingdom
    # DC UK bus energy island
    grid_data_inv, dc_bus_idx_uk_offshore = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.861320 , lon = 1.621487)
    grid_data_inv["busdc"]["$dc_bus_idx_uk_offshore"]["name"] = "EI_DC_UK"

    grid_data_inv, ac_bus_idx_uk_offshore = add_ac_bus_offshore!(grid_data_inv, ac_voltage, 10003; lat = 51.861320 , lon = 1.621487)
    add_converter!(grid_data_inv, ac_bus_idx_uk_offshore, dc_bus_idx_uk_offshore, 14.0)
    add_dc_branch!(grid_data_inv, dc_bus_idx_switchyard, dc_bus_idx_uk_offshore, 14.0)

    # Adding offshore UK generator
    add_generator!(grid_data_inv, ac_bus_idx_uk_offshore, ac_bus_idx_uk_offshore, 14.0, gen_cost, "UK"; status = 1)

    # DC onshore UK bus energy island
    grid_data_inv, dc_bus_idx_uk_onshore = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.880090 , lon = 1.192580) # onshore
    grid_data_inv["busdc"]["$dc_bus_idx_uk_onshore"]["name"] = "EI_DC_UK_ONSHORE"

    ac_bus_idx_uk = find_closest_bus(grid_data_inv, 51.880090, 1.192580)
    grid_data_inv["bus"]["$ac_bus_idx_uk"]["base_kV"] = 400
    add_converter!(grid_data_inv, ac_bus_idx_uk, dc_bus_idx_uk_onshore, 14.0)
    add_dc_branch!(grid_data_inv, dc_bus_idx_uk_onshore, dc_bus_idx_uk_offshore, 14.0)


    ## Denmark
    grid_data_inv, ac_bus_idx_offshore_1 = add_ac_bus_offshore!(grid_data_inv, ac_voltage, 10004; lat = 55.525756, lon = 7.171284)
    grid_data_inv, ac_bus_idx_offshore_2 = add_ac_bus_offshore!(grid_data_inv, ac_voltage, 10005; lat = 55.525756, lon = 7.071284)
    add_generator!(grid_data_inv, ac_bus_idx_offshore_1, ac_bus_idx_offshore_1, 20.0, gen_cost, "DK1"; status = 1)
    add_generator!(grid_data_inv, ac_bus_idx_offshore_2, ac_bus_idx_offshore_2, 14.0, gen_cost, "DK1"; status = 1)

    grid_data_inv, dc_bus_idx_dk_1 = add_dc_bus!(grid_data_inv, dc_voltage; lat = 55.525756, lon = 7.171284)
    grid_data_inv, dc_bus_idx_dk_2 = add_dc_bus!(grid_data_inv, dc_voltage; lat = 55.525756, lon = 7.071284)

    grid_data_inv["busdc"]["$dc_bus_idx_dk_1"]["name"] = "EI_DC_DK_1"
    grid_data_inv["busdc"]["$dc_bus_idx_dk_2"]["name"] = "EI_DC_DK_2"


    add_converter!(grid_data_inv, ac_bus_idx_offshore_1, dc_bus_idx_dk_1, 20.0)
    add_converter!(grid_data_inv, ac_bus_idx_offshore_2, dc_bus_idx_dk_2, 14.0)
    add_dc_branch!(grid_data_inv, dc_bus_idx_dk_1, dc_bus_idx_dk_2, 20.0)

    # Add triton and AC connection DK
    #grid_data_inv, dc_bus_idx_dk_sw = add_dc_bus!(grid_data_inv, dc_voltage; lat = 55.225756, lon = 7.121284)
    grid_data_inv, dc_bus_idx_ei_dk_sw = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.865323, lon = 2.781013)
    grid_data_inv["busdc"]["$dc_bus_idx_ei_dk_sw"]["name"] = "EI_DC_DK_SW"
    add_dc_branch!(grid_data_inv, dc_bus_idx_ei_dk_sw, dc_bus_idx_dk_1, 20.0) # -> Triton
    add_dc_branch!(grid_data_inv, dc_bus_idx_ei_dk_sw, dc_bus_idx_switchyard, 20.0) # Switchyeard EI -> 2nd EI

    # Onshore DK
    grid_data_inv, dc_bus_idx_dk_onshore = add_dc_bus!(grid_data_inv, dc_voltage; lat = 55.731232, lon = 8.422398)
    grid_data_inv["busdc"]["$dc_bus_idx_dk_onshore"]["name"] = "EI_DC_DK_ONSHORE"
    ac_bus_idx_dk = find_closest_bus(grid_data_inv,55.731232,8.422398)
    grid_data_inv["bus"]["$ac_bus_idx_dk"]["base_kV"] = 380
    add_converter!(grid_data_inv, ac_bus_idx_dk, dc_bus_idx_dk_onshore, 14.0)
    add_dc_branch!(grid_data_inv, dc_bus_idx_dk_onshore, dc_bus_idx_dk_2, 14.0)

    ## Belgium -> add second connection to Belgium
    grid_data_inv, dc_bus_idx_be_2 = add_dc_bus!(grid_data_inv, dc_voltage; lat = 51.382225, lon = 3.275118)
    grid_data_inv["busdc"]["$dc_bus_idx_be_2"]["name"] = "EI_DC_BE_ONSHORE_II"
    ac_bus_idx_be = find_closest_bus(grid_data_inv,51.382225,3.275118)
    grid_data_inv["bus"]["$ac_bus_idx_be"]["base_kV"] = 380
    add_converter!(grid_data_inv, ac_bus_idx_be, dc_bus_idx_be_2, 20.0)
    add_dc_branch!(grid_data_inv, dc_bus_idx_ei_dk_sw, dc_bus_idx_be_2, 20.0)

    return grid_data_inv
end
