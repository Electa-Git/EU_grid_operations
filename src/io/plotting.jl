function plot_grid(data, file_name; ac_only = false, color_branches = false, flows_ac = nothing, flows_dc = nothing, maximum_flows = false, plot_node_numbers_ac = false, plot_node_numbers_dc = false)
    # Creating a series of vectors to be added to a DataFrame dictionary
    # AC Buses (type 0) and DC Buses (type 1)
    nodes = []
    lat = []
    lon = []
    type = []
    for (b_id,b) in data["bus"]
        push!(nodes,b["index"])
        push!(lat,b["lat"])
        push!(lon,b["lon"])
        push!(type,0)
    end
    
    if ac_only == false
        for (c, conv) in data["convdc"]
            bus_ac = conv["busac_i"]
            bus_dc = conv["busdc_i"]
        
            data["busdc"]["$bus_dc"]["lat"] = data["bus"]["$bus_ac"]["lat"]
            data["busdc"]["$bus_dc"]["lon"] = data["bus"]["$bus_ac"]["lon"]
        end
        
        for (b_id,b) in data["busdc"]
            push!(nodes, b["index"])
            push!(lat, b["lat"])
            push!(lon, b["lon"])
            push!(type, 1)
        end
    end
     
    # Creating a series of vectors to be added to a DataFrame dictionary
    # AC Branches (type 0) and DC Branches (type 1)
     
    branches = []
    lat_fr = []
    lon_fr = []
    lat_to = []
    lon_to = []
    bus_fr = []
    bus_to = []
    bus_fr_ = []
    bus_to_ = []
    type_ = []
    overload = []
     
    for (b, branch) in data["branch"]
        bus_fr = branch["f_bus"]
        bus_to = branch["t_bus"]
        if haskey(data["bus"], "$bus_fr") && haskey(data["bus"], "$bus_to")
            push!(branches, branch["index"])
            push!(bus_fr_,deepcopy(branch["f_bus"]))
            push!(bus_to_,deepcopy(branch["t_bus"]))
            push!(lat_fr,data["bus"]["$bus_fr"]["lat"])
            push!(lon_fr,data["bus"]["$bus_fr"]["lon"])
            push!(lat_to,data["bus"]["$bus_to"]["lat"])
            push!(lon_to,data["bus"]["$bus_to"]["lon"])
            push!(type_,0)
        end
    end
    if ac_only == false
        for (b, branch) in data["branchdc"]
            bus_fr = branch["fbusdc"]
            bus_to = branch["tbusdc"]
            if haskey(data["busdc"], "$bus_fr") && haskey(data["busdc"], "$bus_to")
                push!(bus_fr_,branch["fbusdc"])
                push!(bus_to_,branch["tbusdc"])
                push!(branches, branch["index"])
                push!(lat_fr,data["busdc"]["$bus_fr"]["lat"])
                push!(lon_fr,data["busdc"]["$bus_fr"]["lon"])
                push!(lat_to,data["busdc"]["$bus_to"]["lat"])
                push!(lon_to,data["busdc"]["$bus_to"]["lon"])
            push!(type_,1)
            end
        end
    end
     
    dict_nodes = DataFrames.DataFrame("node"=>nodes,"lat"=>lat,"lon"=>lon, "type"=> type)
    map_ = DataFrames.DataFrame("from"=>bus_fr_,"to"=>bus_to_,"lat_fr"=>lat_fr,"lon_fr"=>lon_fr,"lat_to"=>lat_to,"lon_to"=>lon_to,"type"=>type_, "branch" => branches)
    txt_x=1
     
    ac_buses=filter(:type => ==(0), dict_nodes)       
    markerAC = PlotlyJS.attr(size=[txt_x],
                color="green")
    
    if ac_only == false
        dc_buses=filter(:type => ==(1), dict_nodes)       
        markerDC = PlotlyJS.attr(size=[txt_x],
                    color="blue")
    end
                
    if plot_node_numbers_ac == true            
        #AC buses legend
        traceAC = [PlotlyJS.scattergeo(;mode="markers+text",textfont=PlotlyJS.attr(size=txt_x),
        textposition="top center",text=string(row[:node][1]),
                    lat=[row[:lat]],lon=[row[:lon]],
                    marker=markerAC)  for row in eachrow(ac_buses)]
        
    else
        #AC buses legend
        traceAC = [PlotlyJS.scattergeo(;mode="markers",
                    lat=[row[:lat]],lon=[row[:lon]],
                    marker=markerAC)  for row in eachrow(ac_buses)]
        
    end
    if ac_only == false
        if  plot_node_numbers_dc == true 
                    #DC buses legend
                    traceDC = [PlotlyJS.scattergeo(;mode="markers+text",textfont=PlotlyJS.attr(size=txt_x),
                    textposition="top center",text=string(row[:node][1]),
                                lat=[row[:lat]],lon=[row[:lon]],
                            marker=markerDC)  for row in eachrow(dc_buses)]
        else
                #DC buses legend
                traceDC = [PlotlyJS.scattergeo(;mode="markers",
                lat=[row[:lat]],lon=[row[:lon]],
                marker=markerDC)  for row in eachrow(dc_buses)]
        end
    end
    
    if color_branches == false
        #DC line display
        if ac_only == false
            lineDC = PlotlyJS.attr(width=1*txt_x,color="red")
        end
        
        #AC line display
        lineAC = PlotlyJS.attr(width=1*txt_x,color="navy")#,dash="dash")
        
        #AC line legend
        trace_AC=[PlotlyJS.scattergeo(;mode="lines",
        lat=[row.lat_fr,row.lat_to],
        lon=[row.lon_fr,row.lon_to],
        line = lineAC)
        for row in eachrow(map_) if (row[:type]==0)]
        
        if ac_only == false
            trace_DC=[PlotlyJS.scattergeo(;mode="lines",
            lat=[row.lat_fr,row.lat_to],
            lon=[row.lon_fr,row.lon_to],
            #opacity = row.overload,
            line = lineDC)
            for row in eachrow(map_) if (row[:type]==1)]
        end
    else
        trace_AC = [PlotlyJS.scattergeo()]
        if ac_only == false
        trace_DC = [PlotlyJS.scattergeo()]
        end
        #AC line legend
        for row in eachrow(map_)
            if row[:type] == 0
                branch = row.branch
                if maximum_flows == true
                    flow =  maximum(flows_ac["$branch"])
                else
                    flow =  sum(flows_ac["$branch"]) / length(flows_ac["$branch"])
                end
                # color = Int(round(max(1, flow * 100)))
                lineAC = PlotlyJS.attr(width = 1 * txt_x, color = ColorSchemes.get(ColorSchemes.jet, flow))
                push!(trace_AC, PlotlyJS.scattergeo(;mode="lines", lat=[row.lat_fr,row.lat_to], lon=[row.lon_fr,row.lon_to], line = lineAC))
            else
                branch = row.branch
                if maximum_flows == true
                    flow =  maximum(flows_dc["$branch"])
                else
                    if ac_only == false
                        flow =  sum(flows_dc["$branch"]) / length(flows_dc["$branch"])
                    end
                color = Int(round(max(1, flow * 100)))
                lineDC = PlotlyJS.attr(width = 2 * txt_x, color =  ColorSchemes.get(ColorSchemes.jet, flow))
                push!(trace_DC, PlotlyJS.scattergeo(;mode="lines", lat=[row.lat_fr,row.lat_to], lon=[row.lon_fr,row.lon_to], line = lineDC))
                end
            end
        end
    end
     
    #combine plot data               
    if ac_only == true
        trace=vcat(trace_AC, traceAC) # only AC Branches and buses
    else
        trace=vcat(trace_AC, trace_DC, traceDC, traceAC) # both AC Branches and buses, DC Branches and buses
    end
    #set map location
    geo = PlotlyJS.attr(fitbounds="locations")
     
    #plot layput
    layout = PlotlyJS.Layout(geo = geo, geo_resolution = 50, width = 1000, height = 1100,
    showlegend = false,
    margin=PlotlyJS.attr(l=0, r=0, t=0, b=0))
    p = PlotlyJS.plot(trace, layout) # print figure
    PlotlyJS.savefig(PlotlyJS.plot(trace, layout), file_name)
    
    return p
end


function plot_marginal_zonal_prices(result, input_data, file_name; zones = nothing)

    print("Calculating and printing zonal marginal prices", "\n")
    print("-----------------------","\n")

    if isnothing(zones)
        zones = [load["node"] for (l, load) in input_data["load"]]
    end

    zonal_price = Dict{String, Any}()
    hours = sort(parse.(Int, collect(keys(result))))
    
    for hour in hours
        for (g, gen) in result["$hour"]["solution"]["gen"]
            if gen["pg"] > 0
            node = input_data["gen"][g]["gen_bus"]
                if any(input_data["bus"]["$node"]["string"] .== zones)
                    zone = input_data["bus"]["$node"]["string"]
                    if haskey(zonal_price, zone)
                        zonal_price[zone][hour] = max(zonal_price[zone][hour], input_data["gen"][g]["cost"][2]/input_data["baseMVA"])
                    else
                        zonal_price[zone] = zeros(length(hours))
                        zonal_price[zone][hour] = max(zonal_price[zone][hour], input_data["gen"][g]["cost"][2]/input_data["baseMVA"])
                    end
                end
            end
        end
    end

    p = Plots.plot()
    for k ∈ keys(zonal_price)
        p = Plots.plot!(zonal_price[k], label = k, seriestype = :scatter)
    end

    Plots.xlabel!("Hour of the year")
    Plots.ylabel!("Zonal marginal price in € / MWh")
    Plots.savefig(p, file_name)
end


function plot_average_zonal_costs(result, input_data, file_name; zones = nothing)

    print("Calculating and printing zonal average cost of generation", "\n")
    print("-----------------------","\n")

    if isnothing(zones)
        zones = [load["node"] for (l, load) in input_data["load"]]
    end

    zonal_price = Dict{String, Any}()
    hours = sort(parse.(Int, collect(keys(result))))
    
    for zone in zones
        zonal_price[zone] = zeros(length(hours))
        for hour in hours
            zonal_gen = 0
            cost = 0
            for (g, gen) in result["$hour"]["solution"]["gen"]
                gen_bus = input_data["gen"][g]["gen_bus"]
                node = input_data["bus"]["$gen_bus"]["string"]
                if node .== zone
                    cost = cost + result["$hour"]["solution"]["gen"][g]["pg"] * input_data["gen"][g]["cost"][2]
                    zonal_gen = result["$hour"]["solution"]["gen"][g]["pg"] * input_data["baseMVA"]
                end
            end
            zonal_price[zone][hour] = cost / zonal_gen
        end
    end

    p = Plots.plot()
    for k ∈ keys(zonal_price)
        p = Plots.plot!(zonal_price[k], label = k, seriestype = :scatter)
    end

    Plots.xlabel!("Hour of the year")
    Plots.ylabel!("Average cost of generation € / MWh")
    Plots.savefig(p, file_name)

    return p
end
