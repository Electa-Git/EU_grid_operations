# This function maps the zone names in the EU Grid model to the zone names of the TYNDP model
function map_zones(;region_names = [])
    zone_mapping = Dict{String, Any}()
    zone_mapping["AL"] = ["AL00"]
    zone_mapping["AT"] = ["AT00"]
    zone_mapping["BA"] = ["BA00"]
    zone_mapping["BE"] = ["BE00"]
    zone_mapping["BG"] = ["BG00"]
    zone_mapping["CH"] = ["CH00"]
    zone_mapping["CZ"] = ["CZ00"]
    zone_mapping["DE"] = ["DE00"]
    zone_mapping["DE-LU"] = ["LUG1"]
    zone_mapping["DK1"] = ["DKE1"]
    zone_mapping["DK2"] = ["DKW1","DKKF"]
    zone_mapping["ES"] = ["ES00"]
    zone_mapping["FI"] = ["FI00"]
    zone_mapping["FR"] = ["FR00"]
    zone_mapping["GR"] = ["GR00"]
    zone_mapping["HR"] = ["HR00"]
    zone_mapping["HU"] = ["HU00"]
    zone_mapping["IE"] = ["IE00"]
    zone_mapping["IT-NORD"] = ["ITN1"]
    zone_mapping["IT-CNOR"] = ["ITCN"]
    zone_mapping["IT-CSUD"] = ["ITCS"]
    zone_mapping["IT-SUD"] = ["ITS1"]
    zone_mapping["IT-SICI"] = ["ITSI"]
    zone_mapping["LU"] = [ "LUB1", "LUF1", "LUV1"]
    zone_mapping["ME"] = ["ME00"]
    zone_mapping["MK"] = ["MK00"]
    zone_mapping["NL"] =  ["NL00"]
    zone_mapping["NO1"] = ["NOS0"] # NOS1 demand is always 0!
    zone_mapping["NO2"] = ["NOS0"]
    zone_mapping["NO3"] = ["NOM1"]
    zone_mapping["NO4"] = ["NON1"]
    zone_mapping["NO5"] = ["NOM1"] # NO5 not in tyndp model
    zone_mapping["PL"] =  ["PL00", "PL00I", "PL00E", "PLE0","PLI0"]
    zone_mapping["PT"] =  ["PT00"]
    zone_mapping["RO"] = ["RO00"]
    zone_mapping["RS"] = ["RS00"]
    zone_mapping["SE1"] = ["SE01"]
    zone_mapping["SE2"] = ["SE02"]
    zone_mapping["SE3"] = ["SE03"]
    zone_mapping["SE4"] =  ["SE04"]
    zone_mapping["SI"] = ["SI00"]
    zone_mapping["SK"] =  ["SK00"]
    zone_mapping["UK"] = ["UK00"]
    zone_mapping["NI"] = ["UKNI"]
    zone_mapping["IT-SA"] = ["ITSA"]
    map_zones_regions(zone_mapping, region_names)

  # TODO: Check these zones
  "CY00"
  "EE00"
  "FR15"
  "GR03"
  "IL00"
  "IS00"
  "ITCO"
  "ITSA"
  "LT00"
  "LV00"
  "MT00"
  "PLE0"
  "PLI0"
  "TN00"
  "TR00"
  "UA01"
  "UA02"
  return zone_mapping
end

function map_zones_regions(zone_mapping, region_names)
    for name in region_names
        if name == "IT"
            zone_mapping["IT-1"] = ["IT-1"]
            zone_mapping["IT-2"] = ["IT-2"]
            zone_mapping["IT-3"] = ["IT-3"]
            zone_mapping["IT-4"] = ["IT-4"]
            zone_mapping["IT-5"] = ["IT-5"]
            zone_mapping["IT-6"] = ["IT-6"]
            zone_mapping["IT-7"] = ["IT-7"]
            zone_mapping["IT-8"] = ["IT-8"]
            zone_mapping["IT-9"] = ["IT-9"]
            zone_mapping["IT-10"] = ["IT-10"]
            zone_mapping["IT-11"] = ["IT-11"]
            zone_mapping["IT-12"] = ["IT-12"]
            zone_mapping["IT-13"] = ["IT-13"]
            zone_mapping["IT-14"] = ["IT-14"]
            zone_mapping["IT-15"] = ["IT-15"]
            zone_mapping["IT-16"] = ["IT-16"]
            zone_mapping["IT-17"] = ["IT-17"]
            zone_mapping["IT-18"] = ["IT-18"]
            zone_mapping["IT-19"] = ["IT-19"]
            zone_mapping["IT-20"] = ["IT-20"]
        end
    end
end

function create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping; zones = nothing, run_of_river = _DF.DataFrame())
    if isnothing(zones)
        zones = [z for (z, zone) in zone_mapping]
    end
    timeseries_data = Dict{String, Any}(
    "wind_onshore" => Dict{String, Any}(),
    "wind_offshore" => Dict{String, Any}(),
    "solar_pv" => Dict{String, Any}(),
    "demand" => Dict{String, Any}(),
    "max_demand" => Dict{String, Any}(),
    "run_of_river" => Dict{String, Any}())

    print("creating RES time series for zone:" , "\n")
    for zone in zones
        print(zone, "\n")
        push!(timeseries_data["wind_onshore"], zone => [])
        push!(timeseries_data["wind_offshore"], zone => [])
        push!(timeseries_data["solar_pv"], zone => [])
        push!(timeseries_data["demand"], zone => [])
        push!(timeseries_data["max_demand"], zone => [])
        push!(timeseries_data["run_of_river"], zone => [])

        if haskey(zone_mapping, zone)
            tyndp_zone = zone_mapping[zone][1]
        end


        wind_series_onshore = wind_onshore[wind_onshore[!, "area"] .== tyndp_zone, climate_year]
        timeseries_data["wind_onshore"][zone] = wind_series_onshore

        wind_series_offshore = wind_offshore[wind_offshore[!, "area"] .== tyndp_zone, climate_year]
        timeseries_data["wind_offshore"][zone] = wind_series_offshore

        pv_series = pv[pv[!, "area"] .== tyndp_zone, climate_year]
        timeseries_data["solar_pv"][zone] = pv_series

        if !isempty(run_of_river)
            run_of_river_series = run_of_river[run_of_river[!, "area"] .== tyndp_zone, climate_year]
            timeseries_data["run_of_river"][zone] = run_of_river_series
        end

        for i in 1:length(wind_onshore[!,1])
            if i <= length(scenario_data[tyndp_zone]["demand"])
                push!(timeseries_data["demand"][zone], scenario_data[tyndp_zone]["demand"][i] / maximum(scenario_data[tyndp_zone]["demand"]))   
            end
        end
        timeseries_data["max_demand"][zone] = maximum(scenario_data[tyndp_zone]["demand"])
    end

    return timeseries_data
end


function hourly_grid_data!(grid_data, grid_data_orig, hour, timeseries_data; start_hour = 0)
    for (l, load) in grid_data["load"]
        if haskey(load, "country_name")
            zone = load["country_name"]
        else
            zone = load["zone"]
        end
        if haskey(timeseries_data["demand"], zone)
            ratio = (timeseries_data["max_demand"][zone] / grid_data["baseMVA"]) / load["country_peak_load"]
            if zone == "NO1" || zone == "NO2" # comes from the weird tyndp data where the demand for the NO zones is somewhat aggregated!!!!!
                ratio = ratio / 2
            end
            load["pd"] =  timeseries_data["demand"][zone][hour] * grid_data_orig["load"][l]["pd"] * ratio
        end 
    end
    for (g, gen) in grid_data["gen"]
        if haskey(gen, "country_name") && typeof(gen["country_name"]) == String
            zone = gen["country_name"]
        elseif haskey(gen, "country") && typeof(gen["country"]) == String
            zone = gen["country"]
        else
            zone = gen["zone"]
        end
        if gen["type_tyndp"] == "Onshore Wind" && haskey(timeseries_data["wind_onshore"], zone)
            gen["pg"] =  timeseries_data["wind_onshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"] 
            gen["pmax"] =  timeseries_data["wind_onshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
        elseif gen["type_tyndp"] == "Offshore Wind" && haskey(timeseries_data["wind_offshore"], zone)
            gen["pg"] =  timeseries_data["wind_offshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  timeseries_data["wind_offshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        elseif gen["type_tyndp"] == "Solar PV" && haskey(timeseries_data["solar_pv"], zone)
            gen["pg"] =  timeseries_data["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  timeseries_data["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        elseif gen["type_tyndp"] == "Run-of-River" && haskey(timeseries_data["run_of_river"], zone) && !isempty(timeseries_data["run_of_river"][zone])
            gen["pg"] =  timeseries_data["run_of_river"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  timeseries_data["run_of_river"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        end
    end
    h_idx = hour - start_hour + 1
    for (b, border) in grid_data["borders"]
        flow = timeseries_data["xb_flows"][border["name"]]["flow"][1, h_idx]
        if abs(flow) > border["border_cap"]
            border["flow"] = sign(flow) * border["border_cap"] * 0.95  # to avoid numerical infeasibility & compensate for possible HVDC losses
        else
            border["flow"] = flow
        end
        for (g, gen) in grid_data["gen"]
            if gen["zone"] == border["name"] 
                gen["cost"][1] = 0 * -sign(flow)
            end
        end
    end
    return grid_data
end

function multiperiod_grid_data(grid_data_orig, hour_start, hour_end, timeseries_data; use_regions = false)
    if use_regions == true
        return multiperiod_grid_data_regional(grid_data_orig, hour_start, hour_end, timeseries_data)
    else
        number_of_hours = hour_end - hour_start + 1
        mp_grid_data = InfrastructureModels.replicate(grid_data_orig, number_of_hours, Set{String}(["source_type", "name", "source_version", "per_unit"]))

        for (n, network) in mp_grid_data["nw"]
            hour = hour_start + parse(Int, n) - 1 # to make sure that the correct hour is chosen if start_hour ≠ 1
            for (l, load) in network["load"]
                if haskey(load, "country_name")
                    zone = load["country_name"]
                else
                    zone = load["zone"]
                end
                if haskey(timeseries_data["demand"], zone)
                    ratio = (timeseries_data["max_demand"][zone] / grid_data_orig["baseMVA"]) / load["country_peak_load"]
                    if zone == "NO1" || zone == "NO2" # comes from the weird tyndp data where the demand for the NO zones is somewhat aggregated!!!!!
                        ratio = ratio / 2
                    end
                    load["pd"] =  timeseries_data["demand"][zone][hour] * grid_data_orig["load"][l]["pd"] * ratio
                end
            end
            for (g, gen) in network["gen"]
                if haskey(gen, "country_name") && typeof(gen["country_name"]) == String
                    zone = gen["country_name"]
                elseif haskey(gen, "country") && typeof(gen["country"]) == String
                    zone = gen["country"]
                else
                    zone = gen["zone"]
                end
                if gen["type_tyndp"] == "Onshore Wind" && haskey(timeseries_data["wind_onshore"], zone)
                    gen["pg"] =  timeseries_data["wind_onshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"] 
                    gen["pmax"] =  timeseries_data["wind_onshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
                elseif gen["type_tyndp"] == "Offshore Wind" && haskey(timeseries_data["wind_offshore"], zone)
                    gen["pg"] =  timeseries_data["wind_offshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
                    gen["pmax"] =  timeseries_data["wind_offshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
                elseif gen["type_tyndp"] == "Solar PV" && haskey(timeseries_data["solar_pv"], zone)
                    gen["pg"] =  timeseries_data["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
                    gen["pmax"] =  timeseries_data["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
                elseif gen["type_tyndp"] == "Run-of-River" && haskey(timeseries_data["run_of_river"], zone) && !isempty(timeseries_data["run_of_river"][zone])
                    gen["pg"] =  timeseries_data["run_of_river"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
                    gen["pmax"] =  timeseries_data["run_of_river"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
                end
            end
            for (b, border) in network["borders"]
                flow = timeseries_data["xb_flows"][border["name"]]["flow"][1, hour]
                if abs(flow) > border["border_cap"]
                    border["flow"] = sign(flow) * border["border_cap"] * 0.95  # to avoid numerical infeasibility & compensate for possible HVDC losses
                else
                    border["flow"] = flow
                end
            end
        end
        return mp_grid_data
    end
end

function build_mn_data(file_name)
    mp_data = PowerModels.parse_file(file_name)
   
    PowerModelsACDC.process_additional_data!(mp_data1; tnep = true)
    return mp_data1
end


function build_uc_data(data, hour_ids, timeseries_data; contingencies = false, merge_zones = Dict{String, Any}())
    data_copy = deepcopy(data)
    number_of_hours = length(hour_ids)
    zones = deepcopy(data_copy["zones"])
    data_copy["zones"] = Dict{String, Any}()
    for z in 1:length(zones)
        data_copy["zones"]["$z"] = Dict{String, Any}("zone" => z, "zone_name" => zones[z])
    end

    data_copy["excluded_zones"] = []
    for (g, gen) in data_copy["gen"]
        core_zones = length(data_copy["zones"])
        core_zone_names = [zone["zone_name"] for (z, zone) in data_copy["zones"]]
        if !any(gen["zone"] .== core_zone_names)
            new_zone = core_zones + 1
            data_copy["zones"]["$new_zone"] =  Dict{String, Any}("zone" => new_zone, "zone_name" => gen["zone"])
            push!(data_copy["excluded_zones"], new_zone)
            gen["zone"] = new_zone
        else
            for (z, zone) in data_copy["zones"]
                if zone["zone_name"] == gen["zone"]
                    gen["country"] = deepcopy(gen["zone"])
                    gen["zone"] = zone["zone"]
                end
            end
        end
    end

    for (c, conv) in data_copy["convdc"]
        for (z, zone) in data_copy["zones"]
            if zone["zone_name"] == conv["zone"]
                conv["country"] = deepcopy(conv["zone"])
                conv["zone"] = zone["zone"]
            end
        end
    end

    for (s, storage) in data_copy["storage"]
        for (z, zone) in data_copy["zones"]
            if zone["zone_name"] == storage["zone"]
                storage["country"] = deepcopy(storage["zone"])
                storage["zone"] = zone["zone"]
            end
        end
    end

    merge_zones!(data_copy; merge_zones = merge_zones)


    if contingencies == false
        uc_data = _IM.replicate(data_copy, number_of_hours, Set{String}(["source_type", "name", "source_version", "per_unit"]))
        uc_data["hour_ids"] = 1:number_of_hours # to be fixed later
        uc_data["cont_ids"] = []
        uc_data["number_of_hours"] = number_of_hours
        uc_data["number_of_contingencies"] = 1 # to be fixed later
        for h in 1:number_of_hours
            hourly_grid_data!(uc_data["nw"]["$h"], data_copy, hour_ids[h], timeseries_data)
        end
    else
        # 1 N-0 contingency + (gen, storage, conv) contingency per zone......
        number_of_contingencies = 1 + 3 * length(data_copy["zones"])
        hour_idsx = [];
        cont_idsx = [];
        for i in 1:number_of_hours * number_of_contingencies
            if mod(i, number_of_contingencies) == 1
                push!(hour_idsx, i)
            else
                push!(cont_idsx, i)
            end
        end
        uc_data = _IM.replicate(data_copy, number_of_hours * number_of_contingencies, Set{String}(["source_type", "name", "source_version", "per_unit"]))
        uc_data["hour_ids"] = hour_idsx
        uc_data["cont_ids"] = cont_idsx
        uc_data["number_of_hours"] = number_of_hours
        uc_data["number_of_contingencies"] = number_of_contingencies

        for idx in 1:number_of_hours
            hour = hour_ids[idx]
            nw_start = 1 + (idx - 1) * (number_of_contingencies)
            nw_ids = nw_start:(nw_start + number_of_contingencies-1)
            for nw in nw_ids
                hourly_grid_data!(uc_data["nw"]["$nw"], data_copy, hour, timeseries_data)
            end
        end
    end



    return uc_data
end

function merge_zones!(data; merge_zones = Dict())
    if !isempty(merge_zones)
        max_zone_id = maximum(parse.(Int, keys(data["zones"])))
        idx = max_zone_id + 1
        for (target_zone, merged_zones) in merge_zones
            push!(data["zones"], "$idx" => Dict("zone" => idx, "zone_name" => target_zone))
            for (g, gen) in data["gen"]
                if any(gen["country"] .== merged_zones["merged_zones"])
                    gen["zone"] = idx
                    gen["area"] = idx
                end
            end
            for (c, conv) in data["convdc"]
                if any(conv["country"] .== merged_zones["merged_zones"])
                    conv["zone"] = idx
                    conv["area"] = idx
                end
            end
            for (l, load) in data["load"]
                if any(load["zone"] .== merged_zones["merged_zones"])
                    load["country_name"] = load["zone"]
                    load["zone"] = target_zone
                    load["area"] = idx
                end
            end
            for (b, bus) in data["bus"]
                if any(bus["zone"] .== merged_zones["merged_zones"])
                    bus["zone"] = target_zone
                    bus["area"] = idx
                end
            end
            for (s, storage) in data["storage"]
                if any(storage["country"] .== merged_zones["merged_zones"])
                    storage["zone"] = idx
                    storage["area"] = idx
                end
            end
            for (z, zone) in data["zones"]
                for merged_zone in merged_zones["merged_zones"]
                    if zone["zone_name"] == merged_zone
                        delete!(data["zones"], z)
                    end
                end
            end
            idx = idx + 1
        end
    end
end

function get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)
    zone = zone_grid["zones"][1]
    borders = Dict{String, Any}()
    for (b, border) in zone_grid["borders"]
        borders[border["name"]] = Dict{String, Any}("flow" => zeros(1, length(zonal_result)))
        if haskey(zone_mapping, border["name"])
            for idx in 1:length(zone_mapping[border["name"]])
                tyndp_zone_fr = zone_mapping[zone][1]
                tyndp_zone_to = zone_mapping[border["name"]][idx]
                int_name_fr = join([tyndp_zone_fr,"-",tyndp_zone_to])
                int_name_to = join([tyndp_zone_to,"-",tyndp_zone_fr])
                flow = 0
                r_idx = 1
                hours = sort(parse.(Int,collect(keys(zonal_result))))
                for h in hours
                    res = zonal_result["$h"]
                    for (b, branch) in zonal_input["branch"]
                        if branch["name"] == int_name_fr
                            flow = res["solution"]["branch"][b]["pf"]
                        elseif branch["name"] == int_name_to
                            flow = res["solution"]["branch"][b]["pt"]
                        end
                    end
                    borders[border["name"]]["flow"][1, r_idx] = borders[border["name"]]["flow"][1, r_idx] + flow
                    r_idx = r_idx + 1
                end   
            end
        end
     end
     return borders
end


function get_demand_reponse!(zone_grid, zonal_input, zone_mapping, timeseries_data; cost = 140)
    zone = zone_grid["zones"][1]
    tyndp_zone = zone_mapping[zone][1]
    dr_ratio = 0
    for (g, gen) in zonal_input["gen"]
        if gen["node"] == tyndp_zone && gen["type"] == "DSR"
            dr_ratio = gen["pmax"] / (timeseries_data["max_demand"][zone] / zone_grid["baseMVA"])
        end
    end
    for (l, load) in zone_grid["load"]
        load["pred_rel_max"] = dr_ratio
        load["cost_red"] = cost * zone_grid["baseMVA"] 
    end
    return zone_grid
end

function fix_data!(grid_data)

    for (b, branch) in grid_data["branch"]
        b_b = imag(1 / (branch["br_r"] + branch["br_x"]im))
        theta_max = branch["rate_a"] / b_b
        if theta_max > pi || theta_max < -pi
            print("Updating reactance of of branch ", b, " due to high reactance.", "\n")
            branch["rate_a"] = abs(pi * b_b)
        end

        # if theta_max > pi || theta_max < -pi
        #     print("Updating reactance of of branch ", b, " due to unrealistic value.", "\n")
        #     new_b = branch["rate_a"] / abs(theta_max)
        #     branch["br_x"] = (1 / new_b) * 0.9 # assume R/X ratio of 1/10
        #     branch["br_r"] = (1 / new_b) * 0.1 
        # end
    end

    return grid_data
end

function add_north_sea_wind_zonal!(input_data, nodal_data, power, co2_cost; branch_cap = 0)
    # first remove OWF capacity of the existing model for the particular zones
    for (g, gen) in input_data["gen"]
        if gen["type"] == "Offshore Wind"
            gen_bus = gen["gen_bus"]
            if any(input_data["bus"]["$gen_bus"]["string"] .== ["FR00", "UK00", "BE00", "NL00", "DE00", "NOS0","SE03", "DKW1"]) == true
                gen["pmax"] = 0.0
                gen["gen_status"] = 0
            end
        end
        if gen["type"] !== "Offshore Wind" && gen["type"] !== "Onshore Wind" && gen["type"] !== "Solar PV" && gen["type"] !== "Nuclear"
            gen["cost"][1] = gen["cost"][1] + co2_cost * input_data["baseMVA"]
        end
    end
    bus_id_ = maximum(parse.(Int, collect(keys(input_data["bus"]))))
    bus_id = maximum(parse.(Int, collect(keys(input_data["bus"])))) + 1
    input_data["bus"]["$bus_id"] = deepcopy(input_data["bus"]["$bus_id_"])
    input_data["bus"]["$bus_id"]["lat"] = 54.990994
    input_data["bus"]["$bus_id"]["lon"] = 3.279410
    input_data["bus"]["$bus_id"]["string"] = "NSOW"
    input_data["bus"]["$bus_id"]["source_id"] = ["bus", bus_id]
    input_data["bus"]["$bus_id"]["index"] = input_data["bus"]["$bus_id"]["number"] = bus_id

    gen_id_ = maximum(parse.(Int, collect(keys(input_data["gen"]))))
    gen_id = maximum(parse.(Int, collect(keys(input_data["gen"])))) + 1
    input_data["gen"]["$gen_id"] = deepcopy(input_data["gen"]["$gen_id_"])
    input_data["gen"]["$gen_id"]["source_id"] = ["gen", gen_id]
    input_data["gen"]["$gen_id"]["index"] = gen_id
    input_data["gen"]["$gen_id"]["gen_bus"] = bus_id
    input_data["gen"]["$gen_id"]["pmax"] = power / input_data["baseMVA"]
    input_data["gen"]["$gen_id"]["type"] = "Offshore Wind"
    input_data["gen"]["$gen_id"]["node"] = "NSOW"
    input_data["gen"]["$gen_id"]["cost"] = [0.0 3500.0 0.0]

    add_ns_branches!(input_data; branch_cap = branch_cap)

    nodal_data["NSOW"] = Dict{String, Any}("generation" => Dict("Offshore Wind" => Dict("timeseries" => [], "capacity" => (power))), "demand" => zeros(size(nodal_data["UK00"]["demand"])))
    nodal_data["NSOW"]["generation"]["Offshore Wind"]["timeseries"]= nodal_data["UK00"]["generation"]["Offshore Wind"]["timeseries"] ./ maximum(nodal_data["UK00"]["generation"]["Offshore Wind"]["timeseries"]) * power


    return input_data, nodal_data
end


function add_ns_branches!(input_data; branch_cap = 0)
    for zone in ["FR00", "UK00", "BE00", "NL00", "DE00", "NOS0","SE03", "DKW1"]
        branch_id_ = maximum(parse.(Int, collect(keys(input_data["branch"]))))
        branch_id = maximum(parse.(Int, collect(keys(input_data["branch"])))) + 1
        input_data["branch"]["$branch_id"] = deepcopy(input_data["branch"]["$branch_id_"])
        input_data["branch"]["$branch_id"]["index"] =  input_data["branch"]["$branch_id"]["number_id"] = branch_id
        input_data["branch"]["$branch_id"]["source_id"] = ["branch", branch_id]  
        input_data["branch"]["$branch_id"]["rate_a"] = input_data["branch"]["$branch_id"]["rate_i"] = input_data["branch"]["$branch_id"]["rate_p"] = branch_cap / input_data["baseMVA"]
        input_data["branch"]["$branch_id"]["delta_cap_max"]  = 1000.0
        input_data["branch"]["$branch_id"]["name"] = join(zone, "-NSOW")
        for (b, bus) in input_data["bus"]
            if bus["string"] == zone
                input_data["branch"]["$branch_id"]["f_bus"] = parse(Int, b)
            elseif bus["string"] == "NSOW"
                input_data["branch"]["$branch_id"]["t_bus"] = parse(Int, b)
            end
        end
        input_data["branch"]["$branch_id"]["offshore"] = true
    end

    return input_data
end


function branch_capacity_cost!(input_data)
    for (b, branch) in input_data["branch"]
        distance = latlon2distance(input_data, branch)
        if haskey(branch, "offshore") && branch["offshore"] == true
            # Assumption: 2M€ per km for 2 GW + 700 M€ for converter costs for 2 GW           
            branch["capacity_cost"] = ((1000.0 * distance + 3.5e5) / (25 * 8760)) * input_data["baseMVA"]

        else
            branch["delta_cap_max"] = branch["rate_a"] * 2 # Allow to double capacity
            # Assumption: 5M€ per km for 3 GVA
            # -> 167 k€ / km / (100 MVA)
            branch["capacity_cost"] = 167e5 * distance / (25 * 8760) 
        end
    end
end

function scale_costs!(input_data, hours)
    for (g, gen) in input_data["gen"]
        gen["cost"] = gen["cost"] .* 8760 / length(hours)
    end

    for (b, branch) in input_data["branch"]
        branch["capacity_cost"] = branch["capacity_cost"] .* 8760 / length(hours)
    end

    return input_data
end

function add_offshore_wind_farms!(input_data)
    xf = XLSX.readxlsx(joinpath("./data_sources/offshore_wind_farms.xlsx"))
    XLSX.sheetnames(xf)
    for r in XLSX.eachrow(xf["OWFHUBS"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            zone = r[1]
            rating = r[2]
            lat = r[3]
            lon = r[4]
            cost = 0 * input_data["baseMVA"]
            add_bus!(input_data, zone, lat, lon)
            node = maximum([bus["index"] for (b, bus) in input_data["bus"]])
            print(zone, "\n")
            add_gen!(input_data, zone, cost, node, rating, "Offshore Wind")
        end
    end

    return input_data
end

function add_offshore_wind_connections!(input_data)
    dc_voltage = 525
    for (g, gen) in input_data["gen"]
        if haskey(gen, "name") && gen["name"] == "OWFHUB"
            ow_bus = gen["gen_bus"]
            ow_zone = gen["zone"]
            distance = 5000
            onshore_bus = 0
            for (b, bus) in input_data["bus"]
                if bus["zone"] == ow_zone && bus["name"] != "OWFHUB"
                    d = latlon2distance(input_data, ow_bus, parse(Int, b))
                    if d <= distance
                        onshore_bus = parse(Int, b)
                        distance = d
                    end
                end
            end
            dc_bus_name_off = join([gen["zone"],"_OWFHUB_", gen["gen_bus"]])
            dc_bus_name_on = join([gen["zone"],"_ON_",input_data["bus"]["$onshore_bus"]["index"]])
            # Add offshore dc bus:
            input_data, dc_bus_idx_ow = add_dc_bus!(input_data, dc_voltage; lat = input_data["bus"]["$ow_bus"]["lat"], lon = input_data["bus"]["$ow_bus"]["lon"])
            # Add offshore converter:    
            add_converter!(input_data, ow_bus, dc_bus_idx_ow, gen["pmax"])
            # Add onshore dc bus:
            input_data, dc_bus_idx_on = add_dc_bus!(input_data, dc_voltage; lat = input_data["bus"]["$onshore_bus"]["lat"], lon = input_data["bus"]["$onshore_bus"]["lon"])
            # Add onshore converter:
            add_converter!(input_data, onshore_bus, dc_bus_idx_on, gen["pmax"])
            # Add offshore cable:
            add_dc_branch!(input_data, dc_bus_idx_ow, dc_bus_idx_on, gen["pmax"])
        end
    end

    return input_data
end

function add_offshore_hvdc_connections!(input_data)
    dc_voltage = 525

    add_dc_branch!(input_data, dc_bus_idx_ow, dc_bus_idx_on, pmax)
 

    return input_data
end


function distribute_addition!(grid_data, gen_costs, zone_key::AbstractString, zone::AbstractString, typ::AbstractString, add_mw::Real; percentage_scale::Bool=false)
    # determine share key based on technology family
    ltyp = lowercase(typ)
    is_offshore = occursin("offshore", ltyp)
    is_solar   = occursin("solar", ltyp) || occursin("pv", ltyp)
    is_onshore = (occursin("onshore", ltyp) || (occursin("wind", ltyp) && !is_offshore))
    share_key = is_solar ? "solarshare" : (is_offshore ? "windoffshare" : (is_onshore ? "windshare" : nothing))
 
    # helper to get bus node
    get_node_from_bus = (bkey, bus) -> (haskey(bus, "bus_i") ? bus["bus_i"] : (try parse(Int, bkey) catch; nothing end))
 
    # collect buses + shares
    bus_alloc = Vector{Tuple{Any,Float64}}()
    if percentage_scale && !isnothing(share_key)
        for (bkey, bus) in grid_data["bus"]
            if haskey(bus, zone_key) && bus[zone_key] == zone && haskey(bus, share_key)
                sh = try float(bus[share_key]) catch; continue end
                sh = (sh > 1.0) ? sh/100.0 : sh
                if sh > 0.0
                    node = get_node_from_bus(bkey, bus)
                    if !isnothing(node)
                        push!(bus_alloc, (node, sh))
                    end
                end
            end
        end
    end
 
    bidding_zone = zone  # keep previous convention: bidding zone = zone (works for both modes)
 
    # distribute if possible
    if !isempty(bus_alloc)
        total_sh = sum(x[2] for x in bus_alloc)
        if total_sh > 0
            for (node, sh) in [(x[1], x[2]/total_sh) for x in bus_alloc]
                alloc = add_mw * sh
                if alloc > 1e-6
                    add_cost = isempty(gen_costs) ? nothing : (haskey(gen_costs, typ) ? gen_costs[typ] : first(values(gen_costs)))
                    @info "Adding distributed $(typ) in $(zone_key)=$(zone) at bus $(node): $(alloc) MW (share=$(sh))"
                    add_gen_regional!(grid_data, bidding_zone, zone, add_cost, node, alloc, typ)
                end
            end
            return true
        end
    end
 
    # fallback: single-bus add
    node = select_bus_for_new_generator(grid_data, zone, typ)
    if isnothing(node)
        @warn "No bus found in $(zone_key)=$(zone) to attach new generator of type $(typ). Skipping addition of $(add_mw) MW."
        return false
    else
        add_cost = isempty(gen_costs) ? nothing : (haskey(gen_costs, typ) ? gen_costs[typ] : first(values(gen_costs)))
        @info "Adding fallback $(typ) in $(zone_key)=$(zone) at bus $(node): $(add_mw) MW"
        add_gen_regional!(grid_data, bidding_zone, zone, add_cost, node, add_mw, typ)
        return true
    end
end
 
function scale_generation!(tyndp_capacity, grid_data, tyndp_version, scenario, year, climate_year, zone_mapping;
                           ns_hub_cap = nothing,
                           exclude_offshore_wind::Bool = false,
                           use_regions::Bool = false,
                           add_generator::Bool = false,
                           percentage_scale::Bool = false,
                           gen_costs = Dict(),
                           zones_noscaling = String[],
                           keep_capacity::Bool = true)
 
    baseMVA = grid_data["baseMVA"]
    zone_key = use_regions ? "region" : "zone"
    if tyndp_version == "2020"
        scenario = join([scenario,year])
    end
 
    # list zones/regions from existing generators
    zones = unique([ gen[zone_key] for (_g, gen) in grid_data["gen"] if haskey(gen, zone_key) ])
 
    # helper to extract TYNDP capacity for (typ,tyndp_zone) and sum
    sum_tyndp_for_zone = function(typ, tyndp_zones)
        s = 0.0
        for tz in tyndp_zones
            if tyndp_version == "2024"
                v = get_generation_capacity_2024(tyndp_capacity, typ, tz)
            elseif tyndp_version == "2020"
                v = get_generation_capacity_2020(tyndp_capacity, scenario, typ, climate_year, tz)
            end
            if !isempty(v)
                s += float(v[1])
            end
        end
        return s
    end
 
    for zone in zones
        println("Processing $(zone_key): ", zone)
        if !isempty(zones_noscaling) && (zone in zones_noscaling)
            @info "Skipping $(zone_key)=$(zone) (in zones_noscaling)."
            continue
        end
 
        tyndp_zones = haskey(zone_mapping, zone) ? zone_mapping[zone] : String[]
 
        # build types set: from existing gens and from tyndp_capacity entries
        types_present = Set{String}()
        for (_g, gen) in grid_data["gen"]
            if haskey(gen, zone_key) && gen[zone_key] == zone
                if haskey(gen, "type_tyndp")
                    push!(types_present, string(gen["type_tyndp"]))
                elseif haskey(gen, "type")
                    push!(types_present, string(gen["type"]))
                end
            end
        end
 
        # include Generator_ID from tyndp_capacity when Node_Line == zone and Parameter == "Capacity"
        mask = (tyndp_capacity[!, :Node_Line] .== zone) .& (tyndp_capacity[!, :Parameter] .== "Capacity")

        if any(mask)
            for row in eachrow(tyndp_capacity[mask, :])
                if !ismissing(row.Generator_ID) && row.Generator_ID !== nothing
                    push!(types_present, strip(string(row.Generator_ID)))
                end
            end
        end
 
        for typ in collect(types_present)
            # optional offshore skip
            if exclude_offshore_wind && occursin("offshore", lowercase(typ))
                continue
            end
 
            zonal_tyndp_capacity_mw = sum_tyndp_for_zone(typ, tyndp_zones)
 
            # collect existing gens of this type in this zone
            existing_gens = [(g, gen) for (g, gen) in grid_data["gen"]
                              if haskey(gen, zone_key) && gen[zone_key] == zone &&
                                 ((haskey(gen,"type_tyndp") && string(gen["type_tyndp"]) == typ) ||
                                  (haskey(gen,"type") && string(gen["type"]) == typ)) ]
 
            existing_total_pu = sum((haskey(gen,"pmax") ? float(gen["pmax"]) : 0.0) for (_g, gen) in existing_gens; init = 0.0)
            existing_total_mw = existing_total_pu * baseMVA
 
            # if TYNDP target is zero -> set existing to zero (old behaviour)
            if isapprox(zonal_tyndp_capacity_mw, 0.0; atol=1e-12)
                if existing_total_mw > 0.0
                    @info "Setting to 0 MW all existing $(typ) in $(zone_key)=$(zone)."
                    for (_g, gen) in existing_gens
                        gen["pmax"] = 0.0
                    end
                end
                continue
            end
 
            # no existing gens
            if existing_total_mw <= 0.0
                if add_generator
                    @info "Adding full target $(zonal_tyndp_capacity_mw) MW for $(typ) in $(zone_key)=$(zone) (no existing)."
                    distribute_addition!(grid_data, gen_costs, zone_key, zone, typ, zonal_tyndp_capacity_mw; percentage_scale=percentage_scale)
                else
                    @info "No existing $(typ) in $(zone_key)=$(zone) and add_generator=false -> skipping."
                end
                continue
            end
            
            if keep_capacity == true
                    scaling_factor = max(1.0, zonal_tyndp_capacity_mw / existing_total_mw)
            else
                    scaling_factor = zonal_tyndp_capacity_mw / existing_total_mw
            end

            if zonal_tyndp_capacity_mw <= existing_total_mw + 1e-8
                # scale proportionally down (or up if slightly higher)
                @info "Scaling $(typ) in $(zone_key)=$(zone): $(existing_total_mw) -> $(zonal_tyndp_capacity_mw) MW; factor=$(scaling_factor)"
                for (_g, gen) in existing_gens
                    gen["pmax"] = float(gen["pmax"]) * scaling_factor
                end
            else
                # target > existing
                add_mw = zonal_tyndp_capacity_mw - existing_total_mw
                if add_generator
                    @info "Adding shortfall $(add_mw) MW for $(typ) in $(zone_key)=$(zone) (add_generator=true)."
                    distribute_addition!(grid_data, gen_costs, zone_key, zone, typ, add_mw; percentage_scale = percentage_scale)
                else
                    # old behaviour: scale up existing to meet target
                    @info "Scaling up $(typ) in $(zone_key)=$(zone): $(existing_total_mw) -> $(zonal_tyndp_capacity_mw) MW; factor=$(scaling_factor)"
                    for (_g, gen) in existing_gens
                        gen["pmax"] = float(gen["pmax"]) * scaling_factor
                    end
                end
            end
        end
    end
 
    # NSEH override (preserve previous behaviour)
    if !isnothing(ns_hub_cap)
        for (_g, gen) in grid_data["gen"]
            if haskey(gen, "zone") && gen["zone"] == "NSEH"
                gen["pmax"] = ns_hub_cap
            end
        end
    end
 
    return
end


function scale_generation!(tyndp_capacity, grid_data, scenario, climate_year, zone_mapping; ns_hub_cap = nothing, exclude_offshore_wind = false, tyndp = "2020")
    for (g, gen) in grid_data["gen"]
        zone = gen["zone"]

        # Check if generator type exists in input data
        if haskey(gen, "type_tyndp")
            type = gen["type_tyndp"]
        else
            print(g, "\n")
        end

        # Calculate zonal capacity: For LU there are three different zones coming from the TYNDP data
        zonal_tyndp_capacity = 0
        if haskey(zone_mapping, zone)
            tyndp_zones = zone_mapping[zone]
        else
            tyndp_zones = Dict{String, Any}()
        end
        for tyndp_zone in tyndp_zones
            # obtain 
            zonal_capacity = get_generation_capacity(tyndp_capacity, scenario, type, climate_year, tyndp_zone, tyndp = tyndp)
            if !isempty(zonal_capacity)
                zonal_tyndp_capacity =  zonal_tyndp_capacity + zonal_capacity[1]
            end
        end


        # If the zonal capacity is different than zero, scale "pmax" based on the ratios of the zonal capacities
        if zonal_tyndp_capacity !=0
            for (z, zone_) in grid_data["zonal_generation_capacity"]
                if zone_["zone"] == zone
                    scaling_factor = max(1, (zonal_tyndp_capacity / grid_data["baseMVA"] / zone_[type]) )
                    if type == "onshore_wind"
                        println(zone, scaling_factor)
                    end
                    if !exclude_offshore_wind
                        if gen["type"] != "Offshore Wind"
                            gen["pmax"] = gen["pmax"] * scaling_factor
                        end
                    else
                        gen["pmax"] = gen["pmax"] * scaling_factor
                    end
                end
            end
        end

        # Check if a different capacity should be written into the offshore wind generator NSEH
        if !isnothing(ns_hub_cap)
            if zone == "NSEH"
                gen["pmax"] = ns_hub_cap
            end
        end
    end 
end
 
"""
select_bus_for_new_generator(grid_data, zone, gen_type)
 
Select a bus index (Int) inside `zone` according to these rules:
 
- If gen_type is in the built-in special_types list:
    1) If an existing generator of that type exists in the same zone,
       return the bus of the first such generator found.
    2) Else return the bus in the same zone with the highest summed load
       (based on grid_data["load"] and bus["pd"] / load["pmax"]/pd/p).
    3) Else return the first bus found in the zone.
- If gen_type is not in special_types:
    - Return the first bus found in the zone.
 
Errors if no bus found in the zone.
"""
function select_bus_for_new_generator(grid_data::Dict{String,Any},
                                      zone::AbstractString,
                                      gen_type::AbstractString)
 
    # Hard-coded special types list (your provided list)
    special_types = [
        "Gas CCGT new", "Gas CCGT CCS", "Gas CCGT old 1", "Gas CCGT old 2", "Gas CCGT present 1", "Gas CCGT present 2",
        "Gas Conventional old 1", "Gas Conventional old 2", "PS Closed", "PS Open", "Lignite new", "Lignite old 1", "Lignite old 2", "Lignite CCS",
        "Hard coal new", "Hard coal CCS", "Hard coal old 1", "Hard coal old 2",
        "Gas CCGT old 2 Bio", "Gas Conventional old 2 Bio", "Hard coal new Bio", "Hard coal old 1 Bio", "Hard coal old 2 Bio",
        "Heavy oil old 1 Bio", "Lignite old 1 Bio", "Oil shale new Bio",
        "Gas OCGT new", "Gas OCGT old", "Heavy oil old 1", "Heavy oil old 2",
        "Nuclear", "Light oil", "Oil shale new", "P2G",
        "Gas CCGT new CCS", "Gas CCGT present 1 CCS", "Gas CCGT present 2 CCS"
    ]
 
    # helper to try converting various bus id representations to Int
    to_int(x) = begin
        if x === nothing
            return nothing
        elseif isa(x, Integer)
            return Int(x)
        elseif isa(x, AbstractString)
            s = strip(x)
            try
                return parse(Int, s)
            catch
                return nothing
            end
        else
            return nothing
        end
    end
 
    # Return list of integer bus indices in the zone (preserve the order found)
    function buses_in_zone(zone::AbstractString)
        res = Int[]
        if !haskey(grid_data, "bus")
            return res
        end
        for (bk, bdict) in grid_data["bus"]
            # some bus dictionaries may store zone under "zone"
            bus_zone = get(bdict, "region", nothing)
            if bus_zone == zone
                # prefer explicit bus_i field, else convert the dictionary key
                ib = nothing
                if haskey(bdict, "bus_i")
                    ib = to_int(bdict["bus_i"])
                else
                    ib = to_int(bk)
                end
                if !isnothing(ib)
                    push!(res, ib)
                end
            end
        end
        return res
    end
 
    # 1) If generator type is special, try to reuse an existing gen bus of same type in the same zone
    if gen_type in special_types && haskey(grid_data, "gen")
        for (gk, gdict) in grid_data["gen"]
            # read the generator type: prefer type_tyndp then type
            gtype = nothing
            if isa(gdict, Dict) && haskey(gdict, "type_tyndp")
                gtype = gdict["type_tyndp"]
            elseif isa(gdict, Dict) && haskey(gdict, "type")
                gtype = gdict["type"]
            end
            if gtype == gen_type && get(gdict, "zone", nothing) == zone
                # try common fields to get bus index
                if haskey(gdict, "gen_bus")
                    ib = to_int(gdict["gen_bus"])
                    if !isnothing(ib) return ib end
                end
                if haskey(gdict, "source_id") && isa(gdict["source_id"], AbstractVector) && length(gdict["source_id"]) >= 2
                    ib = to_int(gdict["source_id"][2])
                    if !isnothing(ib) return ib end
                end
                if haskey(gdict, "index")
                    ib = to_int(gdict["index"])
                    if !isnothing(ib) return ib end
                end
            end
        end
 
        # 1.b) no existing generator of that type in zone -> choose bus with highest summed load
        demand_by_bus = Dict{Int,Float64}()
        if haskey(grid_data, "load")
            for (_, ldict) in grid_data["load"]
                # determine bus index for the load
                bus_idx = nothing
                if haskey(ldict, "source_id") && isa(ldict["source_id"], AbstractVector) && length(ldict["source_id"]) >= 2
                    bus_idx = ldict["source_id"][2]
                elseif haskey(ldict, "bus")
                    bus_idx = ldict["bus"]
                elseif haskey(ldict, "bus_i")
                    bus_idx = ldict["bus_i"]
                end
                ib = to_int(bus_idx)
                if isnothing(ib)
                    continue
                end
                # prefer pmax then pd then p
                val = 0.0
                if haskey(ldict, "pmax")
                    val = float(ldict["pmax"])
                elseif haskey(ldict, "pd")
                    val = float(ldict["pd"])
                elseif haskey(ldict, "p")
                    val = float(ldict["p"])
                end
                demand_by_bus[ib] = get(demand_by_bus, ib, 0.0) + val
            end
        end
 
        # find bus in zone with highest demand
        best_bus = nothing
        best_demand = -Inf
        for ib in buses_in_zone(zone)
            d = get(demand_by_bus, ib, 0.0)
            # prefer explicit bus pd if available in bus dict
            bkey = string(ib)
            if haskey(grid_data["bus"], bkey)
                bdict = grid_data["bus"][bkey]
                if haskey(bdict, "pd")
                    d = float(bdict["pd"])
                end
            end
            if d > best_demand
                best_demand = d
                best_bus = ib
            end
        end
        if !isnothing(best_bus)
            return best_bus
        end
 
        # fallback: first bus in zone
        zone_buses = buses_in_zone(zone)
        if !isempty(zone_buses)
            return zone_buses[1]
        end
    else
        # gen_type not special -> return first bus in zone
        zone_buses = buses_in_zone(zone)
        if !isempty(zone_buses)
            return zone_buses[1]
        end
    end
 
    error("No suitable bus found in zone: $zone")
end