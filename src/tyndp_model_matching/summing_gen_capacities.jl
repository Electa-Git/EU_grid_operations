using JSON
using Plots
using JuMP
using DataFrames; const _DF = DataFrames
using CSV
using Feather
using XLSX

# Add here the original data folder
tyndp_data_folder = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Installed_capacity_scenario_ouputs"

###########################################################

scenarios = ["DE","GA"]
years = ["2035","2040","2050"]
climate_years = ["1995", "2008", "2009"]


#=
df_capacity = CSV.read(joinpath(tyndp_data_folder, "DE2035CY1995","Installed_capacity_per_zone.csv"), DataFrame)
df_rete = CSV.read(joinpath(tyndp_data_folder, "DE2035CY1995","RETE.csv"), DataFrame)
df_sres = CSV.read(joinpath(tyndp_data_folder, "DE2035CY1995","SRES.csv"), DataFrame)
df_street = CSV.read(joinpath(tyndp_data_folder, "DE2035CY1995","Street.csv"), DataFrame)

types = df_capacity[:,1]
zones_capacity = names(df_capacity)[2:end]

zones_rete = names(df_rete)[2:end]
zones_rete_names = [zones_rete[i][1:4] for i in 1:length(zones_rete)]

zones_sres = names(df_sres)[2:end]
zones_sres_names = [zones_sres[i][1:4] for i in 1:length(zones_sres)]

zones_street = names(df_street)[2:end]
zones_street_names = [zones_street[i][1:4] for i in 1:length(zones_street)]


installed_capacities = Dict{String,Any}()
for zone_id in 1:length(zones_capacity) 
    println("Processing zone: ", zones_capacity[zone_id])
    installed_capacities["$(zones_capacity[zone_id])"] = Dict{String,Any}()
    # Capacity
    for type_id in 1:length(types)
        installed_capacities["$(zones_capacity[zone_id])"]["$(types[type_id])"] = df[type_id, zone_id+1]
    end
    # Rete
    for zone_rete_id in 1:length(zones_rete_names)
        if zones_rete_names[zone_rete_id] == zones_capacity[zone_id]
            println("ADD  RETE: ", zones_rete_names[zone_rete_id])
            for type_id in 1:length(types)
                installed_capacities["$(zones_capacity[zone_id])"]["$(types[type_id])"] += df_rete[type_id, zone_rete_id+1]
            end
        end
    end
    
    # SRES
    for zone_sres_id in 1:length(zones_sres_names)
        if zones_sres_names[zone_sres_id] == zones_capacity[zone_id]
            println("ADD  SRES: ", zones_sres_names[zone_sres_id])
            for type_id in 1:length(types)
                installed_capacities["$(zones_capacity[zone_id])"]["$(types[type_id])"] += df_sres[type_id, zone_sres_id+1]
            end
        end
    end
    
    # Street
    for zone_street_id in 1:length(zones_street_names)
        if zones_street_names[zone_street_id] == zones_capacity[zone_id]
            println("ADD  STREET: ", zones_street_names[zone_street_id])
            for type_id in 1:length(types)
                installed_capacities["$(zones_capacity[zone_id])"]["$(types[type_id])"] += df_street[type_id, zone_street_id+1]
            end
        end
    end
end
=#


function create_capacity_dict(tyndp_data_folder,scenarios,years,climate_years)
    for scenario in scenarios
        for year in years
            for climate_year in climate_years
                df_capacity = CSV.read(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","Installed_capacity_per_zone.csv"), DataFrame)
                df_rete = CSV.read(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","RETE.csv"), DataFrame)
                df_sres = CSV.read(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","SRES.csv"), DataFrame)
                df_street = CSV.read(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","Street.csv"), DataFrame)

                println("Processing scenario $(scenario)$(year)CY$(climate_year)")

                types = df_capacity[:,1]
                zones_capacity = names(df_capacity)[2:end]

                zones_rete = names(df_rete)[2:end]
                zones_rete_names = [zones_rete[i][1:4] for i in 1:length(zones_rete)]

                zones_sres = names(df_sres)[2:end]
                zones_sres_names = [zones_sres[i][1:4] for i in 1:length(zones_sres)]

                zones_street = names(df_street)[2:end]
                zones_street_names = [zones_street[i][1:4] for i in 1:length(zones_street)]


                installed_capacities = Dict{String,Any}()
                for zone_id in 1:length(zones_capacity) 
                    println("Processing zone: ", zones_capacity[zone_id])
                    installed_capacities["$(zones_capacity[zone_id])"] = Dict{String,Any}()
                    # Capacity
                    for type_id in 1:length(types)
                        installed_capacities["$(zones_capacity[zone_id])"]["$(types[type_id])"] = df[type_id, zone_id+1]
                    end
                    # Rete
                    for zone_rete_id in 1:length(zones_rete_names)
                        if zones_rete_names[zone_rete_id] == zones_capacity[zone_id]
                            println("ADD  RETE: ", zones_rete_names[zone_rete_id])
                            for type_id in 1:length(types)
                                installed_capacities["$(zones_capacity[zone_id])"]["$(types[type_id])"] += df_rete[type_id, zone_rete_id+1]
                            end
                        end
                    end

                    # SRES
                    for zone_sres_id in 1:length(zones_sres_names)
                        if zones_sres_names[zone_sres_id] == zones_capacity[zone_id]
                            println("ADD  SRES: ", zones_sres_names[zone_sres_id])
                            for type_id in 1:length(types)
                                installed_capacities["$(zones_capacity[zone_id])"]["$(types[type_id])"] += df_sres[type_id, zone_sres_id+1]
                            end
                        end
                    end

                    # Street
                    for zone_street_id in 1:length(zones_street_names)
                        if zones_street_names[zone_street_id] == zones_capacity[zone_id]
                            println("ADD  STREET: ", zones_street_names[zone_street_id])
                            for type_id in 1:length(types)
                                installed_capacities["$(zones_capacity[zone_id])"]["$(types[type_id])"] += df_street[type_id, zone_street_id+1]
                            end
                        end
                    end
                end
                json_installed_capacities = JSON.json(installed_capacities)
                open(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","Total_installed_capacities.json"),"w") do f 
                     write(f, json_installed_capacities) 
                end
            end
        end
    end
end

create_capacity_dict(tyndp_data_folder,scenarios,years,climate_years)

DE2035CY1995 = JSON.parsefile(joinpath(tyndp_data_folder, "DE2035CY1995","Total_installed_capacities.json"))
DE2040CY2008 = JSON.parsefile(joinpath(tyndp_data_folder, "DE2040CY2008","Total_installed_capacities.json"))

DE2035CY1995["BE00"]
DE2040CY2008["BE00"]["Solar (Photovoltaic)"]

###########################################################



for type in types
    println(type)
end