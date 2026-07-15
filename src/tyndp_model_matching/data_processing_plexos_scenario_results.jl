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

function create_dict(dict,indices,file,row_values,gen_types,name,tyndp_data_folder,scenario_folder)
    for index in indices
        dict["$(row_values[index])"] = []
        for row in 173:224
            push!(dict["$(row_values[index])"], file["Yearly Outputs"][row,index])
        end
    end

    df = DataFrame()
    df[!, "Gen_Types"] = gen_types
    
    for (col_name, col_values) in dict
        df[!, col_name] = col_values
    end
    
    CSV.write(joinpath(tyndp_data_folder, scenario_folder, "$(name).csv"), df)
    return dict
end

for scenario in scenarios
    for year in years
        for climate_year in climate_years
            scenario_folder = "$(scenario)$(year)CY$(climate_year)"
            println(" Processing scenario folder: ", scenario_folder)
            file = XLSX.readxlsx(joinpath(tyndp_data_folder, scenario_folder,"MMStandardOutputFile_$(scenario)$(year)_Plexos_CY$(climate_year)_v11_SoS.xlsx"))
        
            gen_types = []
            for row in 173:224
                push!(gen_types, file["Yearly Outputs"][row, 2])
            end
            
            # Check the names of the columns
            row_num = 6
            max_col = 224
            row_values = [file["Yearly Outputs"][row_num, col] for col in 1:max_col]
            
            indices_with_rete = findall(x -> occursin("RETE", x), row_values)
            indices_with_sres = findall(x -> occursin("SRES", x), row_values)
            indices_with_prosumer = findall(x -> occursin("Prosumer", x), row_values)
            indices_with_street = findall(x -> occursin("Street", x), row_values)
            market_zones = findall(x -> length(x) < 5, row_values)
            
            rete_values = [row_values[i] for i in indices_with_rete]
            sres_values = [row_values[i] for i in indices_with_sres]
            prosumer_values = [row_values[i] for i in indices_with_prosumer]
            street_values = [row_values[i] for i in indices_with_street]
            market_zone_values = [row_values[i] for i in market_zones]
                
            rete_dict = Dict{String, Any}()
            create_dict(rete_dict, indices_with_rete, file, row_values,gen_types,"RETE",tyndp_data_folder,scenario_folder)
            
            sres_dict = Dict{String, Any}()
            create_dict(sres_dict, indices_with_sres, file, row_values,gen_types,"SRES",tyndp_data_folder,scenario_folder)

            prosumer_dict = Dict{String, Any}()
            create_dict(prosumer_dict, indices_with_prosumer, file, row_values,gen_types,"Prosumer",tyndp_data_folder,scenario_folder)

            street_dict = Dict{String, Any}()
            create_dict(street_dict, indices_with_street, file, row_values,gen_types,"Street",tyndp_data_folder,scenario_folder)

            market_zone_dict = Dict{String, Any}()
            create_dict(market_zone_dict, market_zones, file, row_values,gen_types,"Installed_capacity_per_zone",tyndp_data_folder,scenario_folder)
        end
    end
end 

###########################################################
# Processing load time series
function create_load_dict(dict, file, indices, headers, first_hour, last_hour, tyndp_data_folder, scenario_folder, name)
    for index in indices
        dict["$(headers[index])"] = []
        for row in first_hour:last_hour
            push!(dict["$(headers[index])"], file["Hourly Market Data emarket"][row,index])
        end
    end
    
    df = DataFrame()
    
    for (col_name, col_values) in dict
        df[!, col_name] = col_values
    end

    CSV.write(joinpath(tyndp_data_folder, scenario_folder, "$(name).csv"), df)
    return dict
end

for scenario in scenarios
    for year in years
        for climate_year in climate_years
            scenario_folder = "$(scenario)$(year)CY$(climate_year)"
            println("----------------------------")
            println(" Processing scenario folder: ", scenario_folder)
            println("----------------------------")
            file = XLSX.readxlsx(joinpath(tyndp_data_folder, scenario_folder,"MMStandardOutputFile_$(scenario)$(year)_Plexos_CY$(climate_year)_v11_SoS.xlsx"))
        
            first_hour = 14
            last_hour = 14 + 8760 - 1
            collect(first_hour:last_hour)
                    
            row_num = 1
            max_col = 12656
            headers_11 = [file["Hourly Market Data emarket"][11, col] for col in 1:max_col]
            headers_12 = [file["Hourly Market Data emarket"][12, col] for col in 1:max_col]
            headers_13 = [file["Hourly Market Data emarket"][13, col] for col in 1:max_col]
            

            # Check the names of the columns
            all_indices_with_load = findall(x -> occursin("LOAD", x), headers_13)

            indices_with_sresload = findall(x -> occursin("SRES_LOAD", x), headers_13)
            indices_with_reteload = findall(x -> occursin("RETE_LOAD", x), headers_13)
            indices_with_prosumerload = findall(x -> occursin("Prosumer_LOAD", x), headers_13)
            indices_with_streetload = findall(x -> occursin("Street_LOAD", x), headers_13)
            indices_with_load = findall(x -> (length(x) < 10 && occursin("LOAD", x)), headers_13)
            
            sresloads_headers_13 = [headers_13[i] for i in indices_with_sresload]
            reteloads_headers_13 = [headers_13[i] for i in indices_with_reteload]
            prosumerloads_headers_13 = [headers_13[i] for i in indices_with_prosumerload]
            streetloads_headers_13 = [headers_13[i] for i in indices_with_streetload]
            load_headers_13 = [headers_13[i] for i in indices_with_load]
            
                
            rete_dict = Dict{String, Any}()
            create_load_dict(rete_dict, file, indices_with_reteload, headers_13, first_hour, last_hour,tyndp_data_folder, scenario_folder,"RETE_LOAD")
            
            sres_dict = Dict{String, Any}()
            create_load_dict(sres_dict, file, indices_with_sresload, headers_13, first_hour, last_hour,tyndp_data_folder, scenario_folder,"SRES_LOAD")

            prosumer_dict = Dict{String, Any}()
            create_load_dict(prosumer_dict, file, indices_with_prosumerload, headers_13, first_hour, last_hour,tyndp_data_folder, scenario_folder,"Prosumer_LOAD")

            street_dict = Dict{String, Any}()
            create_load_dict(street_dict, file, indices_with_streetload, headers_13, first_hour, last_hour,tyndp_data_folder, scenario_folder,"Street_LOAD")

            demand_dict = Dict{String, Any}()
            create_load_dict(demand_dict, file, indices_with_load, headers_13, first_hour, last_hour,tyndp_data_folder, scenario_folder,"Market_zone_LOAD")
        end
    end
end 


