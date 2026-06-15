# Script to create the European grid
# Refer to Tosatto's paper
# 7th March 2023


function create_european_grid(;output_filename::String = "./data_sources/European_grid.json", no_nseh::Bool = false)

    # Uploading an example test system
    test_file = "./data_sources/case5_acdc.m"
    test_grid = _PM.parse_file(test_file)

    # Calling the Excel file
    if no_nseh == true
        xf = XLSX.readxlsx(joinpath("./data_sources/GRID_MODEL_NO_NSEH.xlsx"))
    else
        xf = XLSX.readxlsx(joinpath("./data_sources/GRID_MODEL.xlsx"))
    end
    XLSX.sheetnames(xf)

    # Creating a European grid dictionary in PowerModels format
    European_grid = Dict{String,Any}()
    European_grid["dcpol"] = 2
    European_grid["name"] = "European_grid"
    European_grid["baseMVA"] = 100
    European_grid["per_unit"] = true

    # Buses
    European_grid["bus"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["BUS"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = i - 1
            European_grid["bus"]["$idx"] = Dict{String,Any}()
            European_grid["bus"]["$idx"]["name"] = r[1] #buses_dict[:,1][i]
            European_grid["bus"]["$idx"]["index"] = r[2] #i
            European_grid["bus"]["$idx"]["bus_i"] = r[2] #buses_dict[:,2][i]
            European_grid["bus"]["$idx"]["bus_type"] = r[3] #buses_dict[:,3][i]
            European_grid["bus"]["$idx"]["pd"] = r[4] #buses_dict[:,4][i]
            European_grid["bus"]["$idx"]["qd"] = r[5] #buses_dict[:,5][i]
            European_grid["bus"]["$idx"]["gs"] = r[6] #buses_dict[:,6][i]
            European_grid["bus"]["$idx"]["bs"] = r[7] #buses_dict[:,7][i]
            European_grid["bus"]["$idx"]["area"] = r[8] #buses_dict[:,8][i]
            European_grid["bus"]["$idx"]["vm"] = r[9] #buses_dict[:,9][i]
            European_grid["bus"]["$idx"]["va"] = r[10] #buses_dict[:,10][i]
            European_grid["bus"]["$idx"]["base_kv"] = r[11] #buses_dict[:,11][i]
            European_grid["bus"]["$idx"]["country"] = r[12] #buses_dict[:,12][i]
            European_grid["bus"]["$idx"]["vmax"] = r[13] #buses_dict[:,13][i]
            European_grid["bus"]["$idx"]["vmin"] = r[14] #buses_dict[:,14][i]
            European_grid["bus"]["$idx"]["lat"] = r[16] #buses_dict[:,16][i]
            European_grid["bus"]["$idx"]["lon"] = r[17] #buses_dict[:,17][i]
            European_grid["bus"]["$idx"]["source_id"] = []
            push!(European_grid["bus"]["$idx"]["source_id"],"bus")
            push!(European_grid["bus"]["$idx"]["source_id"],r[2])
            for r_ in XLSX.eachrow(xf["BUS_OVERVIEW"])
                i_ = XLSX.row_number(r_)
                if i_ > 1
                    if  (r[2] >= r_[7]) && (r[2] <= r_[8])  
                        European_grid["bus"]["$idx"]["zone"] = r_[6] 
                    end
                end
            end
            if r[12] == 31
                European_grid["bus"]["$idx"]["zone"] = "XB_node"
            elseif r[12] == 32
                European_grid["bus"]["$idx"]["zone"] = "TYNDP"
            elseif r[12] == 33
                European_grid["bus"]["$idx"]["zone"] = "NSEH"
            end
            # treat DE-LU as DE!!!!!
            if r[2] >= 4764 &&  r[2] <= 4780  
                European_grid["bus"]["$idx"]["zone"] = "DE"
            end
        end
    end
    # The last two buses are north sea energy island buses
    # 5930 - 6125 are interconnection buses

    # Bus dc -> it can be commented out if you want to keep only the AC system
    European_grid["busdc"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["BUS_DC"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = r[2]
            European_grid["busdc"]["$idx"] = Dict{String,Any}()
            European_grid["busdc"]["$idx"]["name"] = r[1] #buses_dc_dict[:,1][i]
            European_grid["busdc"]["$idx"]["index"] = r[2] # idx
            European_grid["busdc"]["$idx"]["busdc_i"] = r[2] # buses_dc_dict[:,2][i]
            European_grid["busdc"]["$idx"]["bus_type"] = r[3] #buses_dc_dict[:,3][i]
            European_grid["busdc"]["$idx"]["pd"] = r[4] #buses_dc_dict[:,4][i]
            European_grid["busdc"]["$idx"]["qd"] = r[5] #buses_dc_dict[:,5][i]
            European_grid["busdc"]["$idx"]["gs"] = r[6] #buses_dc_dict[:,6][i]
            European_grid["busdc"]["$idx"]["bs"] = r[7] #buses_dc_dict[:,7][i]
            European_grid["busdc"]["$idx"]["area"] = r[8] #buses_dc_dict[:,8][i]
            European_grid["busdc"]["$idx"]["vm"] = r[9] #buses_dc_dict[:,9][i]
            European_grid["busdc"]["$idx"]["va"] = r[10] #buses_dc_dict[:,10][i]
            European_grid["busdc"]["$idx"]["basekVdc"] = r[11] #buses_dc_dict[:,11][i]
            European_grid["busdc"]["$idx"]["zone"] = r[12] #buses_dc_dict[:,12][i]
            European_grid["busdc"]["$idx"]["Vdcmax"] = r[13] #buses_dc_dict[:,13][i]
            European_grid["busdc"]["$idx"]["Vdcmin"] = r[14] #buses_dc_dict[:,14][i]
            European_grid["busdc"]["$idx"]["lat"] = r[16] #buses_dc_dict[:,16][i]
            European_grid["busdc"]["$idx"]["lon"] = r[17] #buses_dc_dict[:,17][i]
            European_grid["busdc"]["$idx"]["Vdc"] = 1
            European_grid["busdc"]["$idx"]["Pdc"] = 0
            European_grid["busdc"]["$idx"]["Cdc"] = 0
            European_grid["busdc"]["$idx"]["source_id"] = []
            push!(European_grid["busdc"]["$idx"]["source_id"],"busdc")
            push!(European_grid["busdc"]["$idx"]["source_id"],r[2])
        end
    end

    # Branches
    European_grid["branch"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["BRANCH"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = i - 1
            European_grid["branch"]["$idx"] = Dict{String,Any}()
            European_grid["branch"]["$idx"]["type"] = r[2] #branches_dict[:,2][i]
            if European_grid["branch"]["$idx"]["type"] ==  "AC line"
                European_grid["branch"]["$idx"]["transformer"] = false
            else
                European_grid["branch"]["$idx"]["transformer"] = true
            end
            European_grid["branch"]["$idx"]["index"] = idx
            if ismissing(r[1])
                European_grid["branch"]["$idx"]["interconnector"] = false
            else
                European_grid["branch"]["$idx"]["interconnector"] = true
            end
            European_grid["branch"]["$idx"]["f_bus"] = r[3] #branches_dict[:,3][i]
            European_grid["branch"]["$idx"]["t_bus"] = r[4] #branches_dict[:,4][i]
            European_grid["branch"]["$idx"]["br_r"] = r[5] #branches_dict[:,5][i]
            European_grid["branch"]["$idx"]["br_x"] = r[6] #branches_dict[:,6][i]
            European_grid["branch"]["$idx"]["b_fr"] = r[7]/2 #branches_dict[:,7][i]
            European_grid["branch"]["$idx"]["b_to"] = r[7]/2 #branches_dict[:,7][i]
            European_grid["branch"]["$idx"]["g_fr"] = 0.0
            European_grid["branch"]["$idx"]["g_to"] = 0.0
            European_grid["branch"]["$idx"]["rate_a"] = r[8] / European_grid["baseMVA"] #branches_dict[:,8][i]/European_grid["baseMVA"]  #Adjusting with pu values
            European_grid["branch"]["$idx"]["rate_b"] = r[9] / European_grid["baseMVA"]#branches_dict[:,9][i]/European_grid["baseMVA"] 
            European_grid["branch"]["$idx"]["rate_c"] = r[10]  / European_grid["baseMVA"] #branches_dict[:,10][i]/European_grid["baseMVA"] 
            European_grid["branch"]["$idx"]["ratio"] = r[11] #/ branches_dict[:,11][i]
            European_grid["branch"]["$idx"]["angmin"] = -pi #deepcopy(test_grid["branch"]["1"]["angmin"])
            European_grid["branch"]["$idx"]["angmax"] = pi #deepcopy(test_grid["branch"]["1"]["angmax"])
            European_grid["branch"]["$idx"]["br_status"] = 1
            European_grid["branch"]["$idx"]["tap"] = 1.0
            European_grid["branch"]["$idx"]["transformer"] = false
            European_grid["branch"]["$idx"]["shift"] = 0.0
            European_grid["branch"]["$idx"]["source_id"] = []
            push!(European_grid["branch"]["$idx"]["source_id"],"branch")
            push!(European_grid["branch"]["$idx"]["source_id"], idx)
        end
    end

    # DC Branches
    European_grid["branchdc"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["BRANCH_DC"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = i - 1
            European_grid["branchdc"]["$idx"] = Dict{String,Any}()
            European_grid["branchdc"]["$idx"]["type"] = r[2] #branches_dc_dict[:,2][i]
            European_grid["branchdc"]["$idx"]["name"] = r[1] #branches_dc_dict[:,1][i]
            European_grid["branchdc"]["$idx"]["index"] = idx
            European_grid["branchdc"]["$idx"]["fbusdc"] = r[3] #branches_dc_dict[:,3][i]
            European_grid["branchdc"]["$idx"]["tbusdc"] = r[4] #branches_dc_dict[:,4][i]
            European_grid["branchdc"]["$idx"]["r"] = r[5] #branches_dc_dict[:,5][i]
            European_grid["branchdc"]["$idx"]["c"] = r[6] #branches_dc_dict[:,6][i]
            European_grid["branchdc"]["$idx"]["l"] = r[7] #branches_dc_dict[:,7][i]
            European_grid["branchdc"]["$idx"]["status"] = 1
            European_grid["branchdc"]["$idx"]["rateA"] = r[8] #/ European_grid["baseMVA"] #branches_dc_dict[:,8][i]/European_grid["baseMVA"]  #Adjusting with pu values
            European_grid["branchdc"]["$idx"]["rateB"] = r[9] #/ European_grid["baseMVA"] #branches_dc_dict[:,9][i]/European_grid["baseMVA"] 
            European_grid["branchdc"]["$idx"]["rateC"] = r[10] #/ European_grid["baseMVA"] #branches_dc_dict[:,10][i]/European_grid["baseMVA"] 
            European_grid["branchdc"]["$idx"]["ratio"] = r[11] #/ European_grid["baseMVA"] ##branches_dc_dict[:,11][i]
            European_grid["branchdc"]["$idx"]["source_id"] = []
            push!(European_grid["branchdc"]["$idx"]["source_id"],"branchdc")
            push!(European_grid["branchdc"]["$idx"]["source_id"], idx)
        end
    end

    # DC Converters
    European_grid["convdc"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["CONVERTER"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = i - 1
            European_grid["convdc"]["$idx"] = Dict{String,Any}()
            European_grid["convdc"]["$idx"] = deepcopy(test_grid["convdc"]["1"])  # To fill in default values......
            European_grid["convdc"]["$idx"]["busdc_i"] = r[3] #conv_dc_dict[:,3][i]
            European_grid["convdc"]["$idx"]["busac_i"] = r[2] #conv_dc_dict[:,2][i]
            European_grid["convdc"]["$idx"]["index"] = idx
            if ismissing(r[1])
                European_grid["convdc"]["$idx"]["interconnector"] = false
            else
                European_grid["convdc"]["$idx"]["interconnector"] = true
            end
            European_grid["convdc"]["$idx"]["rtf"] = r[4] #conv_dc_dict[:,4][i]
            European_grid["convdc"]["$idx"]["rc"] = r[4] #conv_dc_dict[:,4][i]
            European_grid["convdc"]["$idx"]["xtf"] = 0.001 #conv_dc_dict[:,5][i]
            European_grid["convdc"]["$idx"]["xc"] = 0.001#conv_dc_dict[:,5][i]
            European_grid["convdc"]["$idx"]["bf"] = r[6] #conv_dc_dict[:,6][i]
            European_grid["convdc"]["$idx"]["status"] = 1
            European_grid["convdc"]["$idx"]["Pacmax"] =  r[7]#/European_grid["baseMVA"] #conv_dc_dict[:,7][i]/European_grid["baseMVA"]  #Adjusting with pu values
            European_grid["convdc"]["$idx"]["Pacmin"] = -r[7]#/European_grid["baseMVA"] #-conv_dc_dict[:,7][i]/European_grid["baseMVA"]  #Adjusting with pu values
            European_grid["convdc"]["$idx"]["Qacmin"] = -r[7]#/European_grid["baseMVA"]
            European_grid["convdc"]["$idx"]["Qacmax"] = r[7]#/European_grid["baseMVA"]
            European_grid["convdc"]["$idx"]["Imax"] = r[7]#/European_grid["baseMVA"]
            European_grid["convdc"]["$idx"]["Pg"] = 0.0 #Adjusting with pu values
            European_grid["convdc"]["$idx"]["ratio"] = r[10] #conv_dc_dict[:,10][i]
            European_grid["convdc"]["$idx"]["transformer"] = 1
            European_grid["convdc"]["$idx"]["reactor"] = 1
            European_grid["convdc"]["$idx"]["source_id"] = []
            push!(European_grid["convdc"]["$idx"]["source_id"],"convdc")
            push!(European_grid["convdc"]["$idx"]["source_id"], idx)
        end
    end

    # Load
    European_grid["load"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["DEMAND"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = i - 1
            European_grid["load"]["$idx"] = Dict{String,Any}()
            European_grid["load"]["$idx"]["country"] = r[1] #load_dict[:,1][i]
            European_grid["load"]["$idx"]["zone"] = r[2] #load_dict[:,2][i]
            European_grid["load"]["$idx"]["load_bus"] = r[3] #load_dict[:,3][i]
            European_grid["load"]["$idx"]["pmax"] = r[4] /European_grid["baseMVA"] #load_dict[:,4][i]/European_grid["baseMVA"] 
            if r[5] == "-"
                European_grid["load"]["$idx"]["cosphi"] = 1
            else
                European_grid["load"]["$idx"]["cosphi"] = r[5] #load_dict[:,5][i]
            end
            European_grid["load"]["$idx"]["pd"] = r[4] / European_grid["baseMVA"] # load_dict[:,4][i]/European_grid["baseMVA"] 
            European_grid["load"]["$idx"]["qd"] = r[4] / European_grid["baseMVA"] * sqrt(1 - European_grid["load"]["$idx"]["cosphi"]^2)
            European_grid["load"]["$idx"]["index"] = idx
            European_grid["load"]["$idx"]["status"] = 1
            European_grid["load"]["$idx"]["source_id"] = []
            push!(European_grid["load"]["$idx"]["source_id"],"bus")
            push!(European_grid["load"]["$idx"]["source_id"], idx)
        end
    end

    # Including load
    for (l_id,l) in European_grid["load"]
        for r in XLSX.eachrow(xf["DEMAND_OVERVIEW"])
            i = XLSX.row_number(r)
            if i > 1
                if l["zone"] == r[1]
                    l["country_peak_load"] = r[2] / European_grid["baseMVA"] 
                end
            end
        end
        l["powerportion"] = l["pmax"]/l["country_peak_load"]
    end

    ####### READ IN GENERATION DATA #######################
    European_grid["gen"] = Dict{String,Any}()
    for r in XLSX.eachrow(xf["GEN"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = i - 1
            European_grid["gen"]["$idx"] = Dict{String,Any}()
            European_grid["gen"]["$idx"]["index"] = idx
            European_grid["gen"]["$idx"]["country"] = r[4] #xf["GEN"]["D2:D1230"][idx]
            European_grid["gen"]["$idx"]["zone"] = r[5] #xf["GEN"]["E2:E1230"][idx]
            European_grid["gen"]["$idx"]["gen_bus"] = r[6] #xf["GEN"]["F2:F1230"][idx]
            European_grid["gen"]["$idx"]["pmax"] = r[8] / European_grid["baseMVA"]  #xf["GEN"]["H2:H1230"][idx]/European_grid["baseMVA"] 
            European_grid["gen"]["$idx"]["pmin"] = r[7] / European_grid["baseMVA"] #xf["GEN"]["G2:G1230"][idx]/European_grid["baseMVA"] 
            European_grid["gen"]["$idx"]["qmax"] =  European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["qmin"] = -European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["cost"] = [r[13] * European_grid["baseMVA"], 0.0]  # Assumption here, to be checked
            European_grid["gen"]["$idx"]["marginal_cost"] = r[11] * European_grid["baseMVA"]  # Assumption here, to be checked
            European_grid["gen"]["$idx"]["co2_add_on"] = r[12] * European_grid["baseMVA"]  # Assumption here, to be checked
            European_grid["gen"]["$idx"]["ncost"] = 2
            European_grid["gen"]["$idx"]["model"] = 2
            European_grid["gen"]["$idx"]["gen_status"] = 1
            European_grid["gen"]["$idx"]["vg"] = 1.0
            European_grid["gen"]["$idx"]["source_id"] = []
            European_grid["gen"]["$idx"]["name"] = r[1]  # Assumption here, to be checked
            push!(European_grid["gen"]["$idx"]["source_id"],"gen")
            push!(European_grid["gen"]["$idx"]["source_id"], idx)

            type = r[2]
            if type == "Gas"
                type_tyndp = "Gas CCGT new"
            elseif type == "Oil"
                type_tyndp = "Heavy oil old 1 Bio"
            elseif type == "Nuclear"
                type_tyndp = "Nuclear"
            elseif type == "Biomass"
                type_tyndp = "Other RES"
            elseif type == "Hard Coal"
                type_tyndp = "Hard coal old 2 Bio"
            elseif type == "Lignite"
                type_tyndp = "Lignite old 1"
            end
            European_grid["gen"]["$idx"]["type"] = type
            European_grid["gen"]["$idx"]["type_tyndp"] = type_tyndp
        end
    end

    # Run-off-river
    number_of_gens = maximum([gen["index"] for (g, gen) in European_grid["gen"]])
    for r in XLSX.eachrow(xf["ROR"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = number_of_gens + i - 1 # 
            European_grid["gen"]["$idx"] = Dict{String,Any}()
            European_grid["gen"]["$idx"]["index"] = idx 
            European_grid["gen"]["$idx"]["country"] = r[3] #gen_hydro_ror_dict[:,3][i]
            European_grid["gen"]["$idx"]["zone"] = r[4] #gen_hydro_ror_dict[:,4][i]
            European_grid["gen"]["$idx"]["gen_bus"] = r[5] #gen_hydro_ror_dict[:,5][i]
            European_grid["gen"]["$idx"]["type"] = r[1] #gen_hydro_ror_dict[:,1][i]
            European_grid["gen"]["$idx"]["type_tyndp"] = "Run-of-River"
            European_grid["gen"]["$idx"]["pmax"] = r[6] / European_grid["baseMVA"] #gen_hydro_ror_dict[:,6][i]/European_grid["baseMVA"] 
            European_grid["gen"]["$idx"]["pmin"] = 0.0
            European_grid["gen"]["$idx"]["qmax"] =  European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["qmin"] = -European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["cost"] = [25.0  * European_grid["baseMVA"], 0.0] # Assumption here, to be checked
            European_grid["gen"]["$idx"]["ncost"] = 2
            European_grid["gen"]["$idx"]["model"] = 2
            European_grid["gen"]["$idx"]["gen_status"] = 1
            European_grid["gen"]["$idx"]["vg"] = 1.0
            European_grid["gen"]["$idx"]["source_id"] = []
            push!(European_grid["gen"]["$idx"]["source_id"],"gen")
            push!(European_grid["gen"]["$idx"]["source_id"], idx)
        end
    end

    ##### ONSHORE WIND
    number_of_gens = maximum([gen["index"] for (g, gen) in European_grid["gen"]])
    for r in XLSX.eachrow(xf["ONSHORE"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = number_of_gens + i - 1 # 
            European_grid["gen"]["$idx"] = Dict{String,Any}()
            European_grid["gen"]["$idx"]["index"] = idx
            European_grid["gen"]["$idx"]["country"] = r[3] #gen_onshore_wind_dict[:,3][i]
            European_grid["gen"]["$idx"]["zone"] = r[4] #gen_onshore_wind_dict[:,4][i]
            European_grid["gen"]["$idx"]["gen_bus"] = r[5] #gen_onshore_wind_dict[:,5][i]
            European_grid["gen"]["$idx"]["type"] = r[1] #gen_onshore_wind_dict[:,1][i]
            European_grid["gen"]["$idx"]["type_tyndp"] = "Onshore Wind"
            European_grid["gen"]["$idx"]["pmax"] = r[6] /European_grid["baseMVA"] #gen_onshore_wind_dict[:,6][i]/European_grid["baseMVA"] 
            European_grid["gen"]["$idx"]["pmin"] = 0.0
            European_grid["gen"]["$idx"]["qmax"] =  European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["qmin"] = -European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["cost"] = [25.0  * European_grid["baseMVA"] ,0.0] 
            European_grid["gen"]["$idx"]["ncost"] = 2
            European_grid["gen"]["$idx"]["model"] = 2
            European_grid["gen"]["$idx"]["gen_status"] = 1
            European_grid["gen"]["$idx"]["vg"] = 1.0
            European_grid["gen"]["$idx"]["source_id"] = []
            push!(European_grid["gen"]["$idx"]["source_id"],"gen")
            push!(European_grid["gen"]["$idx"]["source_id"], idx)
        end
    end
    ####### OFFSHORE WIND
    number_of_gens = maximum([gen["index"] for (g, gen) in European_grid["gen"]])
    for r in XLSX.eachrow(xf["OFFSHORE"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = number_of_gens + i - 2 # Weird read in bug....
            European_grid["gen"]["$idx"] = Dict{String,Any}()
            European_grid["gen"]["$idx"]["index"] = idx
            European_grid["gen"]["$idx"]["country"] = r[3] #gen_offshore_wind_dict[:,3][i]
            European_grid["gen"]["$idx"]["zone"] = r[4] #gen_offshore_wind_dict[:,4][i]
            European_grid["gen"]["$idx"]["gen_bus"] = r[5] #gen_offshore_wind_dict[:,5][i]
            European_grid["gen"]["$idx"]["type"] = r[1] #gen_offshore_wind_dict[:,1][i]
            European_grid["gen"]["$idx"]["type_tyndp"] = "Offshore Wind"
            European_grid["gen"]["$idx"]["pmax"] = r[6] / European_grid["baseMVA"]  #gen_offshore_wind_dict[:,6][i]/European_grid["baseMVA"] 
            European_grid["gen"]["$idx"]["pmin"] = 0.0
            European_grid["gen"]["$idx"]["qmax"] =  European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["qmin"] = -European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["cost"] = [59.0 * European_grid["baseMVA"],0.0] 
            European_grid["gen"]["$idx"]["ncost"] = 2
            European_grid["gen"]["$idx"]["model"] = 2
            European_grid["gen"]["$idx"]["gen_status"] = 1
            European_grid["gen"]["$idx"]["vg"] = 1.0
            European_grid["gen"]["$idx"]["source_id"] = []
            push!(European_grid["gen"]["$idx"]["source_id"],"gen")
            push!(European_grid["gen"]["$idx"]["source_id"], idx)
        end
    end

    ##### SOLAR PV
    number_of_gens = maximum([gen["index"] for (g, gen) in European_grid["gen"]])
    for r in XLSX.eachrow(xf["SOLAR"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = number_of_gens + i - 1 # 
            European_grid["gen"]["$idx"] = Dict{String,Any}()
            European_grid["gen"]["$idx"]["index"] = idx
            European_grid["gen"]["$idx"]["country"] = r[3] #gen_solar_dict[:,3][i]
            European_grid["gen"]["$idx"]["zone"] = r[4] #gen_solar_dict[:,4][i]
            European_grid["gen"]["$idx"]["gen_bus"] = r[5] #gen_solar_dict[:,5][i]
            European_grid["gen"]["$idx"]["type"] = r[1] #gen_solar_dict[:,1][i]
            European_grid["gen"]["$idx"]["type_tyndp"] = "Solar PV"
            European_grid["gen"]["$idx"]["pmax"] = r[6] / European_grid["baseMVA"]  #gen_solar_dict[:,6][i]/European_grid["baseMVA"] 
            European_grid["gen"]["$idx"]["pmin"] = 0.0
            European_grid["gen"]["$idx"]["qmax"] =  European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["qmin"] = -European_grid["gen"]["$idx"]["pmax"] * 0.5
            European_grid["gen"]["$idx"]["cost"] = [18.0  * European_grid["baseMVA"],0.0] 
            European_grid["gen"]["$idx"]["ncost"] = 2
            European_grid["gen"]["$idx"]["model"] = 2
            European_grid["gen"]["$idx"]["gen_status"] = 1
            European_grid["gen"]["$idx"]["vg"] = 1.0
            European_grid["gen"]["$idx"]["source_id"] = []
            push!(European_grid["gen"]["$idx"]["source_id"],"gen")
            push!(European_grid["gen"]["$idx"]["source_id"], idx)
        end
    end


    # ####### Hydro reservoir as storage
    European_grid["storage"] = Dict{String, Any}()
    for r in XLSX.eachrow(xf["RES"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = i - 1 # 
            European_grid["storage"]["$idx"] = Dict{String,Any}()
            European_grid["storage"]["$idx"]["index"] = idx
            European_grid["storage"]["$idx"]["country"] = r[3] #hydro_res_dict[:,3][i]
            if r[4] == "DE-LU"   # FIX for Germany, weirdly zone is "DE-LU" in data model, altough country is DE
                European_grid["storage"]["$idx"]["zone"] = "DE" #hydro_res_dict[:,4][i]
            else
                European_grid["storage"]["$idx"]["zone"] = r[4]
            end
            European_grid["storage"]["$idx"]["storage_bus"] = r[5] #hydro_res_dict[:,5][i]
            European_grid["storage"]["$idx"]["type"] = r[1] #hydro_res_dict[:,1][i]
            European_grid["storage"]["$idx"]["type_tyndp"] = "Reservoir"
            European_grid["storage"]["$idx"]["ps"] = 0.0
            European_grid["storage"]["$idx"]["qs"] = 0.0
            European_grid["storage"]["$idx"]["energy"] = r[7] / European_grid["baseMVA"] #hydro_res_dict[:,7][i]/European_grid["baseMVA"]
            European_grid["storage"]["$idx"]["energy_rating"] = r[7] / European_grid["baseMVA"]
            European_grid["storage"]["$idx"]["charge_rating"] = 0.0
            European_grid["storage"]["$idx"]["discharge_rating"] = r[6] / European_grid["baseMVA"] 
            European_grid["storage"]["$idx"]["charge_efficiency"] = 1.0 
            European_grid["storage"]["$idx"]["discharge_efficiency"] = 0.95 
            European_grid["storage"]["$idx"]["thermal_rating"] = r[6] / European_grid["baseMVA"]
            European_grid["storage"]["$idx"]["qmax"] =  European_grid["storage"]["$idx"]["thermal_rating"] * 0.5
            European_grid["storage"]["$idx"]["qmin"] = -European_grid["storage"]["$idx"]["thermal_rating"] * 0.5
            European_grid["storage"]["$idx"]["r"] = 0.0
            European_grid["storage"]["$idx"]["x"] = 0.0
            European_grid["storage"]["$idx"]["p_loss"] = 0.0
            European_grid["storage"]["$idx"]["q_loss"] = 0.0
            European_grid["storage"]["$idx"]["status"] = 1
            European_grid["storage"]["$idx"]["cost"] = [r[8] * European_grid["baseMVA"] ,0.0] # Assumption here, to be checked
            European_grid["storage"]["$idx"]["source_id"] = []
            push!(European_grid["storage"]["$idx"]["source_id"],"storage")
            push!(European_grid["storage"]["$idx"]["source_id"], idx)
        end
    end

    # ####### Pumped hydro stroage
    number_of_strg = maximum([storage["index"] for (s, storage) in European_grid["storage"]])
    for r in XLSX.eachrow(xf["PHS"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            idx = number_of_strg + i - 1 # 
            European_grid["storage"]["$idx"] = Dict{String,Any}()
            European_grid["storage"]["$idx"]["index"] = idx
            European_grid["storage"]["$idx"]["country"] = r[3] #hydro_phs_dict[:,3][i]
            if r[4] == "DE-LU"   # FIX for Germany, weirdly zone is "DE-LU" in data model, altough country is DE
                European_grid["storage"]["$idx"]["zone"] = "DE" #hydro_res_dict[:,4][i]
            else
                European_grid["storage"]["$idx"]["zone"] = r[4]
            end
            European_grid["storage"]["$idx"]["storage_bus"] = r[5] #hydro_phs_dict[:,5][i]
            European_grid["storage"]["$idx"]["type"] = r[1] #hydro_phs_dict[:,1][i]
            European_grid["storage"]["$idx"]["type_tyndp"] = "Reservoir"
            European_grid["storage"]["$idx"]["ps"] = 0.0
            European_grid["storage"]["$idx"]["qs"] = 0.0
            European_grid["storage"]["$idx"]["energy"] = r[8] / European_grid["baseMVA"] / 2
            European_grid["storage"]["$idx"]["energy_rating"] = r[8]/European_grid["baseMVA"]
            European_grid["storage"]["$idx"]["charge_rating"] =  -r[7]/European_grid["baseMVA"]
            European_grid["storage"]["$idx"]["discharge_rating"] = r[6]/European_grid["baseMVA"] 
            European_grid["storage"]["$idx"]["charge_efficiency"] = 1.0 
            European_grid["storage"]["$idx"]["discharge_efficiency"] = 0.95 
            European_grid["storage"]["$idx"]["thermal_rating"] = r[6]/European_grid["baseMVA"]
            European_grid["storage"]["$idx"]["qmax"] =  European_grid["storage"]["$idx"]["thermal_rating"] * 0.5
            European_grid["storage"]["$idx"]["qmin"] = -European_grid["storage"]["$idx"]["thermal_rating"] * 0.5
            European_grid["storage"]["$idx"]["r"] = 0.0
            European_grid["storage"]["$idx"]["x"] = 0.0
            European_grid["storage"]["$idx"]["p_loss"] = 0.0
            European_grid["storage"]["$idx"]["q_loss"] = 0.0
            European_grid["storage"]["$idx"]["status"] = 1
            European_grid["storage"]["$idx"]["cost"] = [r[9] * European_grid["baseMVA"] ,0.0] # Assumption here, to be checked
            European_grid["storage"]["$idx"]["source_id"] = []
            push!(European_grid["storage"]["$idx"]["source_id"],"storage")
            push!(European_grid["storage"]["$idx"]["source_id"], idx)
        end
    end

    ############## OVERVIEW ###################
    # TO DO: Fix later with dynamic lenght of sheet.....
    zone_names = xf["BUS_OVERVIEW"]["F2:F43"]
    European_grid["zonal_generation_capacity"] = Dict{String, Any}()
    European_grid["zonal_peak_demand"] = Dict{String, Any}()

    for zone in zone_names
        idx = findfirst(zone .== zone_names)[1]
        # Generation
        European_grid["zonal_generation_capacity"]["$idx"] = Dict{String, Any}()
        European_grid["zonal_generation_capacity"]["$idx"]["zone"] = zone
            # Wind
            European_grid["zonal_generation_capacity"]["$idx"]["Onshore Wind"] =  xf["WIND_OVERVIEW"]["B2:B43"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["Offshore Wind"] =  xf["WIND_OVERVIEW"]["C2:C43"][idx]/European_grid["baseMVA"]
            # PV
            European_grid["zonal_generation_capacity"]["$idx"]["Solar PV"] =  xf["SOLAR_OVERVIEW"]["B2:B43"][idx]/European_grid["baseMVA"]
            # Hydro
            European_grid["zonal_generation_capacity"]["$idx"]["Run-of-River"] =  xf["HYDRO_OVERVIEW"]["B3:B44"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["Reservoir"] =  xf["HYDRO_OVERVIEW"]["C3:C44"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["Reservoir capacity"] =  xf["HYDRO_OVERVIEW"]["D3:D44"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["PHS"] =  xf["HYDRO_OVERVIEW"]["E3:E44"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["PHS capacity"] =  xf["HYDRO_OVERVIEW"]["F3:F44"][idx]/European_grid["baseMVA"]
            # Thermal -> This may need to be updated, no nuclear in BE instead of 5.943 GW ...
            European_grid["zonal_generation_capacity"]["$idx"]["Other RES"] =  xf["THERMAL_OVERVIEW"]["B2:B43"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["Gas CCGT existing 2"] =  xf["THERMAL_OVERVIEW"]["C2:C43"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["Hard coal old 2 Bio"] =  xf["THERMAL_OVERVIEW"]["D2:D43"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["Lignite old 1"] =  xf["THERMAL_OVERVIEW"]["E2:E43"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["Nuclear"] =  xf["THERMAL_OVERVIEW"]["F2:F43"][idx]/European_grid["baseMVA"]
            European_grid["zonal_generation_capacity"]["$idx"]["Heavy oil old 1 Bio"] =  xf["THERMAL_OVERVIEW"]["G2:G43"][idx]/European_grid["baseMVA"]
        # Demand
        European_grid["zonal_peak_demand"]["$idx"] = xf["DEMAND_OVERVIEW"]["B2:B44"][idx]/European_grid["baseMVA"]
    end
    ######
    # Making sure all the keys for PowerModels are there
    European_grid["source_type"] = deepcopy(test_grid["source_type"])
    European_grid["switch"] = deepcopy(test_grid["switch"])
    European_grid["shunt"] = deepcopy(test_grid["shunt"])
    European_grid["dcline"] = deepcopy(test_grid["dcline"])

    # Fixing NaN branches
    European_grid["branch"]["6282"]["br_r"] = 0.001
    European_grid["branch"]["8433"]["br_r"] = 0.001
    European_grid["branch"]["8439"]["br_r"] = 0.001
    European_grid["branch"]["8340"]["br_r"] = 0.001

    # add_sardinia_grid!(European_grid)

    string_data = JSON.json(European_grid)
    open(output_filename,"w" ) do f
        write(f,string_data)
    end
end


function add_sardinia_grid!(European_grid::Dict{String,Any})
    # Adding Sardinia grid from a separate file
    sardinia_filename = joinpath(BASE_DIR,"data_sources","sardinia_grid.xlsx")
    
    xlsx = XLSX.readxlsx(xlsx_file)
    sheet_name = "BUS_AC"
    df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)

    for row in eachrow(df)
        row[:ac_voltage]
        ac_voltage = row[:ac_voltage]   
        zone = row[:zone]
        name = row[:Bus_name]
        lat = hasproperty(row, :lat) ? row[:lat] : 0
        lon = hasproperty(row, :lon) ? row[:lon] : 0
        add_ac_bus!(EU_grid, ac_voltage, zone, name; lat=lat, lon=lon)
    end

    sheet_name = "BUS_DC"
    df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
    for row in eachrow(df)
        dc_voltage = row[:dc_voltage]   
        zone = row[:zone]
        name = row[:Bus_name]
        lat = hasproperty(row, :lat) ? row[:lat] : 0
        lon = hasproperty(row, :lon) ? row[:lon] : 0
        add_dc_bus!(EU_grid, dc_voltage, zone, name; lat=lat, lon=lon)
    end


    sheet_name = "Converter"
    df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
    for row in eachrow(df)
        ac_bus_idx = row[:ac_bus_idx]   
        dc_bus_idx = row[:dc_bus_idx] 
        power_rating = row[:power_rating]
        zone = row[:zone]
        converter_idx = row[:converter_idx]
        add_converter!(EU_grid, ac_bus_idx, dc_bus_idx, power_rating, zone = zone)
    end


    sheet_name = "branch ac"
    df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
    for row in eachrow(df)   
        fbus = row[:fbus]   
        tbus = row[:tbus] 
        power_rating = row[:power_rating]
        add_ac_branch!(EU_grid, fbus, tbus, power_rating)
    end


    sheet_name = "branch dc"
    df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
    for row in eachrow(df)
        fbus = row[:fbus]   
        tbus = row[:tbus] 
        power_rating = row[:power_rating]  
        _EUGO.add_dc_branch!(EU_grid, fbus, tbus, power_rating)
    end


    sheet_name = "gen"
    df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
    for row in eachrow(df)
        gen_bus = row[:gen_bus]   
        gen_zone = row[:gen_zone] 
        power_rating = row[:power_rating]
        gen_type = row[:gen_type]
        _EUGO.add_generator!(EU_grid, gen_bus, power_rating, gen_zone, gen_type)
    end

    sheet_name = "load"
    df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
    for row in eachrow(df)      
        load_bus = row[:load_bus]   
        load_zone = row[:load_zone] 
        peak_power = row[:peak_power]
        powerportion = row[:powerportion]
        country_peak_load = row[:country_peak_load]
        _EUGO.add_load!(EU_grid, load_bus, peak_power, load_zone, powerportion, country_peak_load)
    end
end
