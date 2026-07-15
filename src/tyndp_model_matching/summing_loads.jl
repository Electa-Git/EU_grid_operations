using JSON
using Plots
using JuMP
using DataFrames; const _DF = DataFrames
using CSV
using Feather
using XLSX

# Add here the original data folder -> it should be adjusted
tyndp_data_folder = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Installed_capacity_scenario_ouputs"

###########################################################

scenarios = ["DE","GA"]
years = ["2035","2040","2050"]
climate_years = ["1995", "2008", "2009"]


df_capacity = CSV.read(joinpath(tyndp_data_folder, "DE2035CY1995","Market_zone_LOAD.csv"), DataFrame)
df_rete = CSV.read(joinpath(tyndp_data_folder, "DE2035CY1995","RETE_LOAD.csv"), DataFrame)
df_sres = CSV.read(joinpath(tyndp_data_folder, "DE2035CY1995","SRES_LOAD.csv"), DataFrame)
df_street = CSV.read(joinpath(tyndp_data_folder, "DE2035CY1995","Street_LOAD.csv"), DataFrame)

names(df_capacity)
names(df_rete)
names(df_sres)
names(df_street)
hours = collect(1:length(df_capacity[:,1])-24)


function create_capacity_dict(tyndp_data_folder,scenarios,years,climate_years)
    for scenario in scenarios
        for year in years
            for climate_year in climate_years
                df_capacity = CSV.read(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","Market_zone_LOAD.csv"), DataFrame)
                df_rete = CSV.read(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","RETE_LOAD.csv"), DataFrame)
                df_sres = CSV.read(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","SRES_LOAD.csv"), DataFrame)
                df_street = CSV.read(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","Street_LOAD.csv"), DataFrame)

                println("Processing scenario $(scenario)$(year)CY$(climate_year)")

                types = df_capacity[:,1]
                zones_capacity = names(df_capacity)[1:end]
                zones_capacity_names = [zones_capacity[i][1:4] for i in 1:length(zones_capacity)]

                zones_rete = names(df_rete)[1:end]
                zones_rete_names = [zones_rete[i][1:4] for i in 1:length(zones_rete)]

                zones_sres = names(df_sres)[1:end]
                zones_sres_names = [zones_sres[i][1:4] for i in 1:length(zones_sres)]

                zones_street = names(df_street)[1:end]
                zones_street_names = [zones_street[i][1:4] for i in 1:length(zones_street)]

                loads = Dict{String,Any}()
                for zone_id in 1:length(zones_capacity) 
                    println("Processing zone: ", zones_capacity_names[zone_id])
                    loads["$(zones_capacity_names[zone_id])"] = []
                    # Capacity
                    for hour in hours
                        push!(loads["$(zones_capacity_names[zone_id])"], df_capacity[hour, zone_id])
                    end
                    # Rete
                    for zone_rete_id in 1:length(zones_rete_names)
                        if zones_rete_names[zone_rete_id] == zones_capacity_names[zone_id]
                            println("ADD  RETE: ", zones_capacity_names[zone_rete_id])
                            for hour in hours
                                loads["$(zones_capacity_names[zone_id])"][hour] += df_rete[hour, zone_rete_id]
                            end
                        end
                    end

                    # SRES
                    for zone_sres_id in 1:length(zones_sres_names)
                        if zones_sres_names[zone_sres_id] == zones_capacity_names[zone_id]
                            println("ADD  SRES: ", zones_sres_names[zone_sres_id])
                            for hour in hours
                                loads["$(zones_capacity_names[zone_id])"][hour] += df_sres[hour, zone_sres_id]
                            end
                        end
                    end

                    # Street
                    for zone_street_id in 1:length(zones_street_names)
                        if zones_street_names[zone_street_id] == zones_capacity_names[zone_id]
                            println("ADD  STREET: ", zones_street_names[zone_street_id])
                            for hour in hours
                                loads["$(zones_capacity_names[zone_id])"][hour] += df_street[hour, zone_street_id]
                            end
                        end
                    end
                end

                json_loads = JSON.json(loads)
                open(joinpath(tyndp_data_folder, "$(scenario)$(year)CY$(climate_year)","Total_loads.json"),"w") do f 
                     write(f, json_loads) 
                end
            end
        end
    end
end

create_capacity_dict(tyndp_data_folder,scenarios,years,climate_years)


DE2035CY1995 = JSON.parsefile(joinpath(tyndp_data_folder, "DE2035CY1995","Total_loads.json"))
DE2040CY2008 = JSON.parsefile(joinpath(tyndp_data_folder, "DE2040CY2008","Total_loads.json"))


plot(DE2035CY1995["BE00"]/10^3)
