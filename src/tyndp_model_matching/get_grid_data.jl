#####################################
# get_grid_data.jl
# Author: Hakan Ergun 24.03.2022
# Funtions to extract grid data from the scenario data files
#######################################

# Function to extract ntcs, nodes, generation capacity,
# demand time series and list of generator types
# scenario{String}, e.g. "NT2025"

function get_grid_data(tyndp_version, scenario, year, climate_year)    
    if tyndp_version == "2020"
        return get_grid_data_2020(scenario, year, climate_year)
    elseif tyndp_version == "2024"
        return get_grid_data_2024(scenario, year, climate_year)
    else
        error("TYNDP version not supported")
    end
end

function get_grid_data_2020(scenario, year, climate_year)    
    # data source: https://www.entsoe.eu/Documents/TYNDP%20documents/TYNDP2020/Reference%20Grid%202025%20-%20TYNDP%202020.xlsx    
    file_lines = joinpath(BASE_DIR,"data_sources", "TYNDP2020","Reference Grid 2025 - TYNDP 2020.xlsx")
    # data source: https://2020.entsos-tyndp-scenarios.eu/wp-content/uploads/2020/06/TYNDP-2020-Scenario-Datafile.xlsx.zip
    file_data = joinpath(BASE_DIR,"data_sources", "TYNDP2020","TYNDP-2020-Scenario-Datafile.xlsx")
    # data source for all demand time series: https://tyndp.entsoe.eu/maps-data 
    file_demand = joinpath(BASE_DIR,"data_sources", "TYNDP2020", join([scenario,year,"_Demand_CY1984.csv"]))

    # Create dataframes from CSV/XLS files
    lines = _DF.DataFrame(XLSX.readtable(file_lines, "2025"))
    ntcs = _DF.DataFrame(Connection = lines[!, "Border Names Based on PEMMDB 3.0 convention"], NTC = lines[!, "Final Value for NTC (MW)"])

    nodes_ = _DF.DataFrame(XLSX.readtable(file_data, "Nodes - Dict"))
    nodes = _DF.DataFrame(node_id = nodes_[1:64, "node_id"], country_text = nodes_[1:64, "Unnamed: 1"], country = nodes_[1:64, "country"], previous_node = nodes_[1:64, "previous_node"], latitude = nodes_[1:64, "latitude"], longitude = nodes_[1:64, "longitude"], region = nodes_[1:64, "Region"], EU28 = nodes_[1:64, "EU28"])

    arcs_ = _DF.DataFrame(XLSX.readtable(file_data,"Line - Dict"))
    arcs = _DF.DataFrame(line_id = arcs_[!, "line_id"], node_a = arcs_[!, "node_a"], node_b = arcs_[!, "node_b"])

    capacity_ = _DF.DataFrame(XLSX.readtable(file_data, "Capacity"))
    capacity = _DF.DataFrame(Node_Line = capacity_[!, "Node/Line"], Generator_ID = capacity_[!, "Generator_ID"], Parameter = capacity_[!, "Parameter"], Category = capacity_[!, "Category"], 
    Case = capacity_[!, "Case"], Scenario = capacity_[!, "Scenario"], Year = capacity_[!, "Year"], ClimateYear = capacity_[!, "Climate Year"], 
    Value = capacity_[!, "Value"], Simulation_ID = capacity_[!, "Simulation_ID"], Node1 = capacity_[!, "Node 1"], 
    Path = capacity_[!, "Path"], Simulation_type = capacity_[!, "Simulation_type"], Sector = capacity_[!, "Sector"], Note = capacity_[!, "Note"])

    node_positions = nodes[:, [:latitude, :longitude]]

    demand = _DF.DataFrame(CSV.File(file_demand))

    gen_types = unique(capacity[!,"Generator_ID"])

    # Assign generation costs based on data provided in "Charts-and-Figure-Underlying-Data-for-TYNDP-2020, Figure 36
    # Choosing very good condition:
    # "Very good conditions
    # LCOE (Euro /MWh)"
    # CCGT CCS          €89 
    # CCGT New          €89 
    # Nuclear           €110 
    # Solar PV (com.)   €18 
    # Solar PV (res.)   €18 
    # Wind offshore     €59 
    # Wind onshre       €25
    # Assuming: 
    # Other RES = €60
    # hydro = battery = solar = €18
    # Solar thermal = CCGT CCS = 89
    # Gas. Coal, old CCGT = nuclear + 10€ = 120€
    # Oil = nuclear + 20€ = 150€
    # DSR > nuclear + 9  = 119€
    # VOLL = 10000€

    # Create dictionary with generation costs per generation type
    gen_costs = Dict{String, Any}(
        "DSR" => 119,
        "Other non-RES"  => 120,
        "Offshore Wind"  => 59,
        "Onshore Wind"  => 25,
        "Solar PV"  => 18,
        "Solar Thermal"  => 89,
        "Gas CCGT new" => 89,
        "Gas CCGT old 1"  => 89,
        "Gas CCGT old 2"  => 89,
        "Gas CCGT present 1"  => 89,
        "Gas CCGT present 2"  => 89,
        "Reservoir"  => 18,
        "Run-of-River"  => 18,
        "Gas conventional old 1"  => 120,
        "Gas conventional old 2"  => 120,
        "PS Closed"  => 120,
        "PS Open"  => 120,
        "Lignite new"  => 120,
        "Lignite old 1"  => 120,
        "Lignite old 2"  => 120,
        "Hard coal new"  => 120,
        "Hard coal old 1"  => 120,
        "Hard coal old 2"  => 120,
        "Gas CCGT old 2 Bio"  => 120,
        "Gas conventional old 2 Bio"  => 120,
        "Hard coal new Bio"  => 120,
        "Hard coal old 1 Bio"  => 120,
        "Hard coal old 2 Bio" => 120,
        "Heavy oil old 1 Bio"  => 120,
        "Lignite old 1 Bio"  => 120,
        "Oil shale new Bio"  => 120,
        "Gas OCGT new"  => 89,
        "Gas OCGT old"  => 120,
        "Heavy oil old 1"  => 150,
        "Heavy oil old 2"  => 120,
        "Nuclear" => 110,
        "Light oil" => 140,
        "Oil shale new" => 150,
        "P2G" => 120,
        "Other non-RES DE00 P" => 120,
        "Other non-RES DKE1 P" => 120,
        "Other non-RES DKW1 P" => 120,
        "Other non-RES FI00 P" => 120,
        "Other non-RES FR00 P" => 120,
        "Other non-RES MT00 P" => 120,
        "Other non-RES UK00 P" => 120,
        "Other RES" => 60,
        "Gas CCGT new CCS"  => 89,
        "Gas CCGT present 1 CCS"  => 60,
        "Gas CCGT present 2 CCS" => 60,
        "Battery"  => 119,
        "Lignite old 2 Bio"  => 120,
        "Oil shale old"  => 150,
        "Gas CCGT CCS"  => 89,
        "VOLL" => 10000,
        "HVDC" => 0
    )

    # other non-RES are assumed to have the same emissions as gas
    emission_factor = Dict{String, Any}( #kg/netGJ -> ton/MWh
        "DSR" => 0,
        "Other non-RES"  => 0,
        "Offshore Wind"  => 0,
        "Onshore Wind"  => 0,
        "Solar PV"  => 0,
        "Solar Thermal"  => 0,
        "Gas CCGT new"        => (57*3.6)*10^(-3),
        "Gas CCGT old 1"      => (57*3.6)*10^(-3),
        "Gas CCGT old 2"      => (57*3.6)*10^(-3),
        "Gas CCGT present 1"  => (57*3.6)*10^(-3),
        "Gas CCGT present 2"  => (57*3.6)*10^(-3),
        "Reservoir"  => 0,
        "Run-of-River"  => 0,
        "Gas conventional old 1"  => (57*3.6)*10^(-3),
        "Gas conventional old 2"  => (57*3.6)*10^(-3),
        "PS Closed"  => (57*3.6)*10^(-3),
        "PS Open"  =>   (57*3.6)*10^(-3),
        "Lignite new"  =>   (101*3.6)*10^(-3),
        "Lignite old 1"  => (101*3.6)*10^(-3),
        "Lignite old 2"  => (101*3.6)*10^(-3),
        "Hard coal new"  => (94*3.6)*10^(-3),
        "Hard coal old 1"  => (94*3.6)*10^(-3),
        "Hard coal old 2"  => (94*3.6)*10^(-3),
        "Gas CCGT old 2 Bio"          => (57*3.6)*10^(-3),
        "Gas conventional old 2 Bio"  => (57*3.6)*10^(-3),
        "Hard coal new Bio"  =>   (94*3.6)*10^(-3),
        "Hard coal old 1 Bio"  => (94*3.6)*10^(-3),
        "Hard coal old 2 Bio" =>  (94*3.6)*10^(-3),
        "Heavy oil old 1 Bio"  => (94*3.6)*10^(-3),
        "Lignite old 1 Bio"  => (101*3.6)*10^(-3),
        "Oil shale new Bio"  => (100*3.6)*10^(-3),
        "Gas OCGT new"  => (57*3.6)*10^(-3),
        "Gas OCGT old"  => (57*3.6)*10^(-3),
        "Heavy oil old 1"  => (78*3.6)*10^(-3),
        "Heavy oil old 2"  => (78*3.6)*10^(-3),
        "Nuclear" => 0,
        "Light oil" => (78*3.6)*10^(-3),
        "Oil shale new" => (100*3.6)*10^(-3),
        "P2G" => 0,
        "Other non-RES DE00 P" => (57*3.6)*10^(-3),
        "Other non-RES DKE1 P" => (57*3.6)*10^(-3),
        "Other non-RES DKW1 P" => (57*3.6)*10^(-3),
        "Other non-RES FI00 P" => (57*3.6)*10^(-3),
        "Other non-RES FR00 P" => (57*3.6)*10^(-3),
        "Other non-RES MT00 P" => (57*3.6)*10^(-3),
        "Other non-RES UK00 P" => (57*3.6)*10^(-3),
        "Other RES" => 0,
        "Gas CCGT new CCS"        => (5.7*3.6)*10^(-3),
        "Gas CCGT present 1 CCS"  => (5.7*3.6)*10^(-3),
        "Gas CCGT present 2 CCS"  => (5.7*3.6)*10^(-3),
        "Battery"  => 0,
        "Lignite old 2 Bio"  => (101*3.6)*10^(-3),
        "Oil shale old"  => (100*3.6)*10^(-3),
        "Gas CCGT CCS"  => (5.7*3.6)*10^(-3),
        "VOLL" => 0,
        "HVDC" => 0
    )

    inertia_constants = Dict{String, Any}(
        "DSR"                       => 0,
        "Other non-RES"             => 0,
        "Offshore Wind"             => 0,
        "Onshore Wind"              => 0,
        "Solar PV"                  => 0,
        "Solar Thermal"             => 0,
        "Gas CCGT new"              => 5,
        "Gas CCGT old 1"            => 5,
        "Gas CCGT old 2"            => 5,
        "Gas CCGT present 1"        => 5,
        "Gas CCGT present 2"        => 5,
        "Reservoir"                 => 3,
        "Run-of-River"              => 3,
        "Gas conventional old 1"    => 5,
        "Gas conventional old 2"    => 5,
        "PS Closed"                 => 3,
        "PS Open"                   => 3,
        "Lignite new"               => 4,
        "Lignite old 1"             => 4,
        "Lignite old 2"             => 4,
        "Hard coal new"             => 4,
        "Hard coal old 1"           => 4,
        "Hard coal old 2"           => 4,
        "Gas CCGT old 2 Bio"        => 5,
        "Gas conventional old 2 Bio"=> 5,
        "Hard coal new Bio"         => 4,
        "Hard coal old 1 Bio"       => 4,
        "Hard coal old 2 Bio"       => 4,
        "Heavy oil old 1 Bio"       => 4,
        "Lignite old 1 Bio"         => 4,
        "Oil shale new Bio"         => 4,
        "Gas OCGT new"              => 5,
        "Gas OCGT old"              => 5,
        "Heavy oil old 1"           => 4,
        "Heavy oil old 2"           => 4,
        "Nuclear"                   => 6,
        "Light oil"                 => 4,
        "Oil shale new"             => 4,
        "P2G"                       => 0,
        "Other non-RES DE00 P"      => 0,
        "Other non-RES DKE1 P"      => 0,
        "Other non-RES DKW1 P"      => 0,
        "Other non-RES FI00 P"      => 0,
        "Other non-RES FR00 P"      => 0,
        "Other non-RES MT00 P"      => 0,
        "Other non-RES UK00 P"      => 0,
        "Other RES"                 => 0,
        "Gas CCGT new CCS"          => 5,
        "Gas CCGT present 1 CCS"    => 5,
        "Gas CCGT present 2 CCS"    => 5,
        "Battery"                   => 0,
        "Lignite old 2 Bio"         => 4,
        "Oil shale old"             => 4,
        "Gas CCGT CCS"              => 5,
        "VOLL"                      => 0,
        "HVDC"                      => 0
    )

    start_up_cost = Dict{String, Any}( #EUR/MW/start
        "DSR" => 0,
        "Other non-RES"  => 90,
        "Offshore Wind"  => 0,
        "Onshore Wind"  => 0,
        "Solar PV"  => 0,
        "Solar Thermal"  => 0,
        "Gas CCGT new"        => 90,
        "Gas CCGT old 1"      => 90,
        "Gas CCGT old 2"      => 90,
        "Gas CCGT present 1"  => 90,
        "Gas CCGT present 2"  => 90,
        "Reservoir"  => 0,
        "Run-of-River"  => 0,
        "Gas conventional old 1"  => 90,
        "Gas conventional old 2"  => 90,
        "PS Closed"  => 150,
        "PS Open"  =>   150,
        "Lignite new"  =>   175,
        "Lignite old 1"  => 175,
        "Lignite old 2"  => 175,
        "Hard coal new"  => 175,
        "Hard coal old 1"  => 175,
        "Hard coal old 2"  => 175,
        "Gas CCGT old 2 Bio"          => 90,
        "Gas conventional old 2 Bio"  => 90,
        "Hard coal new Bio"  =>   175,
        "Hard coal old 1 Bio"  => 175,
        "Hard coal old 2 Bio" =>  175,
        "Heavy oil old 1 Bio"  => 150,
        "Lignite old 1 Bio"  => 175,
        "Oil shale new Bio"  => 150,
        "Gas OCGT new"  => 90,
        "Gas OCGT old"  => 90,
        "Heavy oil old 1"  => 150,
        "Heavy oil old 2"  => 150,
        "Nuclear" => 1000,
        "Light oil" =>     150,
        "Oil shale new" => 150,
        "P2G" => 0,
        "Other non-RES DE00 P" => 175,
        "Other non-RES DKE1 P" => 175,
        "Other non-RES DKW1 P" => 175,
        "Other non-RES FI00 P" => 175,
        "Other non-RES FR00 P" => 175,
        "Other non-RES MT00 P" => 175,
        "Other non-RES UK00 P" => 175,
        "Other RES" => 0,
        "Gas CCGT new CCS"        => 90,
        "Gas CCGT present 1 CCS"  => 90,
        "Gas CCGT present 2 CCS"  => 90,
        "Battery"  => 0,
        "Lignite old 2 Bio"  => 175,
        "Oil shale old"  => 150,
        "Gas CCGT CCS"  => 90,
        "VOLL" => 0,
        "HVDC" => 0
    )

    return ntcs, nodes, arcs, capacity, demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions
end

function get_grid_data_2024(scenario, year, climate_year)    
    # data source: https://2024.entsos-tyndp-scenarios.eu/download/#:~:text=Electricity%20and%20Hydrogen%20Reference%20Grid%20%26%20Investment%20Candidates%20After%20Public%20Consultation    
    file_lines = joinpath(pkgdir(EU_grid_operations),"data_sources", "TYNDP2024", "20231103 - Electricity and Hydrogen Reference Grid & Investment Candidates 3_modified.xlsx")
    # data source: https://2020.entsos-tyndp-scenarios.eu/wp-content/uploads/2020/06/TYNDP-2020-Scenario-Datafile.xlsx.zip
    file_nodes = joinpath(pkgdir(EU_grid_operations),"data_sources", "TYNDP2024","LIST OF NODES_2024.xlsx")
    # data source for all demand time series: https://tyndp.entsoe.eu/maps-data 
    file_demand = joinpath(pkgdir(EU_grid_operations),"data_sources", "TYNDP2024","Demand_Profiles","$(scenario)", "$(year)","Total_demand_$(scenario)$(year)_$(climate_year).csv")
    file_capacity = joinpath(pkgdir(EU_grid_operations),"data_sources", "TYNDP2024","PEMMDB2","$(scenario)", "$(year)","Installed_generation_capacity_$(scenario)$(year)_MW.csv")

    # Create dataframes from CSV/XLS files
    lines = _DF.DataFrame(XLSX.readtable(file_lines, "1. Elec Ref Grid"))
    lines_complete = []
    ntcs = []
    node_a_ = []
    node_b_ = []
    # for i in 1:length(lines[1][4]) # direction a -> b
    #     push!(lines_complete, "$(lines[1][4][i])-$(lines[1][5][i])")
    #     push!(ntcs, lines[1][2][i]) # direction a -> b
    #     push!(node_a_,lines[1][4][i])
    #     push!(node_b_,lines[1][5][i])
    # end
    # for i in 1:length(lines[1][4]) # direction b -> a
    #     push!(lines_complete, "$(lines[1][5][i])-$(lines[1][4][i])")
    #     push!(ntcs, lines[1][3][i]) # direction b -> a
    #     push!(node_a_,lines[1][5][i])
    #     push!(node_b_,lines[1][4][i])
    # end
    lines_complete = lines[!, :Border]
    ntcs = lines[!, "Summary Direction 1 (MW)"]
    nodes_a_ = lines[!, "node_a"]
    nodes_b_ = lines[!, "node_b"]
    ntcs = _DF.DataFrame(Connection = lines_complete, NTC = ntcs)
    
    nodes_ = _DF.DataFrame(XLSX.readtable(file_nodes, "Electricity"))
    nodes = _DF.DataFrame(node_id = nodes_[!,:NODE], country_text = nodes_[!,"Unnamed: 1"], country = nodes_[!,:country], previous_node = nodes_[!,:previous_node], latitude = nodes_[!,:latitude], longitude = nodes_[!,:longitude], region = nodes_[!,:Region], EU28 = nodes_[!,:EU28])
    #, country_text = nodes_[1][2][1:82], country = nodes_[1][3][1:82], previous_node = nodes_[1][4][1:82], latitude = nodes_[1][5][1:82], longitude = nodes_[1][6][1:82], region = nodes_[1][7][1:82], EU28 = nodes_[1][8][1:82])
    
    arcs = _DF.DataFrame(line_id = lines_complete, node_a = nodes_a_, node_b = nodes_b_)

    # Gen capacity installed
    capacity_ = _DF.DataFrame(CSV.File(file_capacity))

    # Building the same DataFrame as the 2020 version     
    node_positions = nodes[:, [:latitude, :longitude]]
    demand = _DF.DataFrame(CSV.File(file_demand))
    
    node_line_ = []       # Node/Line
    gen_id = []           # Generator_ID
    parameter_ = []       # Parameter
    category_ = []        # Category
    case_ = []            # Case
    scenario_ = []        # Scenario
    year_ = []            # Year
    climate_year_ = []    # ClimateYear
    value_ = []           # Value 
    simulation_id_ = []   # Simulation_ID 
    node_1_ = []          # Node1  
    path_ = []            # Path 
    simulation_type_ = [] # Simulation_type 
    sector_ = []          # Sector 
    note_ = []            # Note 

    gen_types = [String.(capacity_[:,1][i]) for i in 1:length(capacity_[:,1])]

    for i in 1:length(capacity_[:,1])
        for v in 2:length(capacity_[i,:])
          if capacity_[i,:][v] != 0.0
            push!(node_line_,names(capacity_)[v])
            push!(gen_id,capacity_[:,1][i])
            push!(parameter_,"Capacity")
            push!(category_,"Electricity Market")
            push!(case_,"1")
            push!(scenario_,scenario)
            push!(year_,year)
            push!(climate_year_,climate_year)
            push!(value_,capacity_[i,:][v])
            push!(simulation_id_,"$(scenario)$(year)_$(climate_year)")
            push!(node_1_,"1")
            push!(path_,"1")
            push!(simulation_type_,"1")
            push!(sector_,"1")
            push!(note_,"1")
          end
        end
    end
    
    capacity_2020_template = _DF.DataFrame(Node_Line = node_line_, Generator_ID = gen_id, Parameter = parameter_, Category = category_, Case = case_, Scenario = scenario_, 
    Year = year_, ClimateYear = climate_year_, Value = value_, Simulation_ID = simulation_id_, Node1 = node_1_, 
    Path = path_, Simulation_type = simulation_type_ , Sector = sector_, Note = note_)
    

    # TO BE MODIFIED
    # Assign generation costs based on data provided in "Charts-and-Figure-Underlying-Data-for-TYNDP-2020, Figure 36
    # CCGT CCS          €89 
    # CCGT New          €89 
    # Nuclear           €110 
    # Solar PV (com.)   €18 
    # Solar PV (res.)   €18 
    # Wind offshore     €59 
    # Wind onshre       €25
    # Assuming: 
    # Other RES = €60
    # hydro = battery = solar = €18
    # Solar thermal = CCGT CCS = 89
    # Gas. Coal, old CCGT = nuclear + 10€ = 120€
    # Oil = nuclear + 20€ = 150€
    # DSR > nuclear + 9  = 119€
    # VOLL = 10000€
    
    # Create dictionary with generation costs per generation type
    gen_costs = Dict{String, Any}(
        "DSR" => 119,
        "Other non-RES"  => 120,
        "Offshore Wind"  => 69,
        "Onshore Wind"  => 30,
        "Solar PV"  => 41,
        "Solar Thermal"  => 108,
        "Gas CCGT new" => 89,
        "Gas CCGT CCS" => 90,
        "Gas CCGT old 1"  => 90,
        "Gas CCGT old 2"  => 90,
        "Gas CCGT present 1"  => 90,
        "Gas CCGT present 2"  => 90,
        "Reservoir"  => 53,
        "Run-of-River"  => 53,
        "Gas Conventional old 1"  => 120,
        "Gas Conventional old 2"  => 120,
        "PS Closed"  => 120,
        "PS Open"  => 120,
        "Lignite new"  => 120,
        "Lignite old 1"  => 120,
        "Lignite old 2"  => 120,
        "Lignite CCS"  => 120,
        "Hard coal new"  => 120,
        "Hard coal CCS"  => 120,
        "Hard coal old 1"  => 120,
        "Hard coal old 2"  => 120,
        "Gas CCGT old 2 Bio"  => 120,
        "Gas Conventional old 2 Bio"  => 120,
        "Hard coal new Bio"  => 120,
        "Hard coal old 1 Bio"  => 120,
        "Hard coal old 2 Bio" => 120,
        "Heavy oil old 1 Bio"  => 120,
        "Lignite old 1 Bio"  => 120,
        "Oil shale new Bio"  => 120,
        "Gas OCGT new"  => 92,
        "Gas OCGT old"  => 120,
        "Heavy oil old 1"  => 150,
        "Heavy oil old 2"  => 120,
        "Nuclear" => 110,
        "Light oil" => 140,
        "Oil shale new" => 150,
        "P2G" => 120,
        "Other non-RES" => 120,
        "Other non-RES DE00 P" => 120,
        "Other non-RES DKE1 P" => 120,
        "Other non-RES DKW1 P" => 120,
        "Other non-RES FI00 P" => 120,
        "Other non-RES FR00 P" => 120,
        "Other non-RES MT00 P" => 120,
        "Other non-RES UK00 P" => 120,
        "Other RES" => 70,
        "Gas CCGT new CCS"  => 89,
        "Gas CCGT present 1 CCS"  => 180,
        "Gas CCGT present 2 CCS" => 180,
        "Battery"  => 119,
        "Lignite old 2 Bio"  => 120,
        "Oil shale old"  => 150,
        "Gas CCGT CCS"  => 180,
        "VOLL" => 10000,
        "HVDC" => 0
    )
    
    # other non-RES are assumed to have the same emissions as gas
    emission_factor = Dict{String, Any}( #kg/netGJ -> ton/MWh
        "DSR" => 0,
        "Other non-RES"  => 0,
        "Offshore Wind"  => 0,
        "Onshore Wind"  => 0,
        "Solar PV"  => 0,
        "Solar Thermal"  => 0,
        "Gas CCGT new"        => (57*3.6)*10^(-3),
        "Gas CCGT CCS"        => (57*3.6)*10^(-3),
        "Gas CCGT old 1"      => (57*3.6)*10^(-3),
        "Gas CCGT old 2"      => (57*3.6)*10^(-3),
        "Gas CCGT present 1"  => (57*3.6)*10^(-3),
        "Gas CCGT present 2"  => (57*3.6)*10^(-3),
        "Reservoir"  => 0,
        "Run-of-River"  => 0,
        "Gas Conventional old 1"  => (57*3.6)*10^(-3),
        "Gas Conventional old 2"  => (57*3.6)*10^(-3),
        "PS Closed"  => (57*3.6)*10^(-3),
        "PS Open"  =>   (57*3.6)*10^(-3),
        "Lignite new"  =>   (101*3.6)*10^(-3),
        "Lignite old 1"  => (101*3.6)*10^(-3),
        "Lignite old 2"  => (101*3.6)*10^(-3),
        "Lignite CCS"  => (101*3.6)*10^(-3),
        "Hard coal new"  => (94*3.6)*10^(-3),
        "Hard coal CCS"  => (94*3.6)*10^(-3),
        "Hard coal old 1"  => (94*3.6)*10^(-3),
        "Hard coal old 2"  => (94*3.6)*10^(-3),
        "Gas CCGT old 2 Bio"          => (57*3.6)*10^(-3),
        "Gas Conventional old 2 Bio"  => (57*3.6)*10^(-3),
        "Hard coal new Bio"  =>   (94*3.6)*10^(-3),
        "Hard coal old 1 Bio"  => (94*3.6)*10^(-3),
        "Hard coal old 2 Bio" =>  (94*3.6)*10^(-3),
        "Heavy oil old 1 Bio"  => (94*3.6)*10^(-3),
        "Lignite old 1 Bio"  => (101*3.6)*10^(-3),
        "Oil shale new Bio"  => (100*3.6)*10^(-3),
        "Gas OCGT new"  => (57*3.6)*10^(-3),
        "Gas OCGT old"  => (57*3.6)*10^(-3),
        "Heavy oil old 1"  => (78*3.6)*10^(-3),
        "Heavy oil old 2"  => (78*3.6)*10^(-3),
        "Nuclear" => 0,
        "Light oil" => (78*3.6)*10^(-3),
        "Oil shale new" => (100*3.6)*10^(-3),
        "P2G" => 0,
        "Other non-RES DE00 P" => (57*3.6)*10^(-3),
        "Other non-RES DKE1 P" => (57*3.6)*10^(-3),
        "Other non-RES DKW1 P" => (57*3.6)*10^(-3),
        "Other non-RES FI00 P" => (57*3.6)*10^(-3),
        "Other non-RES FR00 P" => (57*3.6)*10^(-3),
        "Other non-RES MT00 P" => (57*3.6)*10^(-3),
        "Other non-RES UK00 P" => (57*3.6)*10^(-3),
        "Other RES" => 0,
        "Gas CCGT new CCS"        => (5.7*3.6)*10^(-3),
        "Gas CCGT present 1 CCS"  => (5.7*3.6)*10^(-3),
        "Gas CCGT present 2 CCS"  => (5.7*3.6)*10^(-3),
        "Battery"  => 0,
        "Lignite old 2 Bio"  => (101*3.6)*10^(-3),
        "Oil shale old"  => (100*3.6)*10^(-3),
        "Gas CCGT CCS"  => (5.7*3.6)*10^(-3),
        "VOLL" => 0,
        "HVDC" => 0
    )
    
    inertia_constants = Dict{String, Any}(
        "DSR"                       => 0,
        "Other non-RES"             => 0,
        "Offshore Wind"             => 0,
        "Onshore Wind"              => 0,
        "Solar PV"                  => 0,
        "Solar Thermal"             => 0,
        "Gas CCGT new"              => 5,
        "Gas CCGT CCS"              => 5,
        "Gas CCGT old 1"            => 5,
        "Gas CCGT old 2"            => 5,
        "Gas CCGT present 1"        => 5,
        "Gas CCGT present 2"        => 5,
        "Reservoir"                 => 3,
        "Run-of-River"              => 3,
        "Gas Conventional old 1"    => 5,
        "Gas Conventional old 2"    => 5,
        "PS Closed"                 => 3,
        "PS Open"                   => 3,
        "Lignite new"               => 4,
        "Lignite old 1"             => 4,
        "Lignite old 2"             => 4,
        "Lignite CCS"               => 4,
        "Hard coal new"             => 4,
        "Hard coal CCS"             => 4,
        "Hard coal old 1"           => 4,
        "Hard coal old 2"           => 4,
        "Gas CCGT old 2 Bio"        => 5,
        "Gas Conventional old 2 Bio"=> 5,
        "Hard coal new Bio"         => 4,
        "Hard coal old 1 Bio"       => 4,
        "Hard coal old 2 Bio"       => 4,
        "Heavy oil old 1 Bio"       => 4,
        "Lignite old 1 Bio"         => 4,
        "Oil shale new Bio"         => 4,
        "Gas OCGT new"              => 5,
        "Gas OCGT old"              => 5,
        "Heavy oil old 1"           => 4,
        "Heavy oil old 2"           => 4,
        "Nuclear"                   => 6,
        "Light oil"                 => 4,
        "Oil shale new"             => 4,
        "P2G"                       => 0,
        "Other non-RES DE00 P"      => 0,
        "Other non-RES DKE1 P"      => 0,
        "Other non-RES DKW1 P"      => 0,
        "Other non-RES FI00 P"      => 0,
        "Other non-RES FR00 P"      => 0,
        "Other non-RES MT00 P"      => 0,
        "Other non-RES UK00 P"      => 0,
        "Other RES"                 => 0,
        "Gas CCGT new CCS"          => 5,
        "Gas CCGT present 1 CCS"    => 5,
        "Gas CCGT present 2 CCS"    => 5,
        "Battery"                   => 0,
        "Lignite old 2 Bio"         => 4,
        "Oil shale old"             => 4,
        "Gas CCGT CCS"              => 5,
        "VOLL"                      => 0,
        "HVDC"                      => 0
    )
    
    start_up_cost = Dict{String, Any}( #EUR/MW/start
        "DSR" => 0,
        "Other non-RES"  => 90,
        "Offshore Wind"  => 0,
        "Onshore Wind"  => 0,
        "Solar PV"  => 0,
        "Solar Thermal"  => 0,
        "Gas CCGT new"        => 89,
        "Gas CCGT CCS"        => 90,
        "Gas CCGT old 1"      => 90,
        "Gas CCGT old 2"      => 90,
        "Gas CCGT present 1"  => 90,
        "Gas CCGT present 2"  => 90,
        "Reservoir"  => 0,
        "Run-of-River"  => 0,
        "Gas Conventional old 1"  => 90,
        "Gas Conventional old 2"  => 90,
        "PS Closed"  => 150,
        "PS Open"  =>   150,
        "Lignite new"  =>   175,
        "Lignite old 1"  => 175,
        "Lignite old 2"  => 175,
        "Lignite CCS"=> 175,
        "Hard coal new"  => 175,
        "Hard coal CCS"    => 175,
        "Hard coal old 1"  => 175,
        "Hard coal old 2"  => 175,
        "Gas CCGT old 2 Bio"          => 90,
        "Gas Conventional old 2 Bio"  => 90,
        "Hard coal new Bio"  =>   175,
        "Hard coal old 1 Bio"  => 175,
        "Hard coal old 2 Bio" =>  175,
        "Heavy oil old 1 Bio"  => 150,
        "Lignite old 1 Bio"  => 175,
        "Oil shale new Bio"  => 150,
        "Gas OCGT new"  => 90,
        "Gas OCGT old"  => 90,
        "Heavy oil old 1"  => 150,
        "Heavy oil old 2"  => 150,
        "Nuclear" => 1000,
        "Light oil" =>     150,
        "Oil shale new" => 150,
        "P2G" => 0,
        "Other non-RES DE00 P" => 175,
        "Other non-RES DKE1 P" => 175,
        "Other non-RES DKW1 P" => 175,
        "Other non-RES FI00 P" => 175,
        "Other non-RES FR00 P" => 175,
        "Other non-RES MT00 P" => 175,
        "Other non-RES UK00 P" => 175,
        "Other RES" => 0,
        "Gas CCGT new CCS"        => 90,
        "Gas CCGT present 1 CCS"  => 90,
        "Gas CCGT present 2 CCS"  => 90,
        "Battery"  => 0,
        "Lignite old 2 Bio"  => 175,
        "Oil shale old"  => 150,
        "Gas CCGT CCS"  => 90,
        "VOLL" => 0,
        "HVDC" => 0
    )
    
    return ntcs, nodes, arcs, capacity_2020_template, demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions
end
    
function add_NOx_and_SOx_emissions(input_data)

    emission_factor_NOx = Dict{String, Any}( #g/kWh == kg/Mwh
    "DSR"                         => 0,
    "Other non-RES"               => 0.2587,
    "Offshore Wind"               => 0,
    "Onshore Wind"                => 0,
    "Solar PV"                    => 0,
    "Solar Thermal"               => 0,
    "Gas CCGT new"                => 0.2334,
    "Gas CCGT CCS"                => 0.2334,
    "Gas CCGT old 1"              => 0.2334,
    "Gas CCGT old 2"              => 0.2334,
    "Gas CCGT present 1"          => 0.2334,
    "Gas CCGT present 2"          => 0.2334,
    "Reservoir"                   => 0,
    "Run-of-River"                => 0,
    "Gas conventional old 1"      => 0.2334,
    "Gas conventional old 2"      => 0.2334,
    "PS Closed"                   => 0.2334,
    "PS Open"                     => 0.2334,
    "Lignite new"                 => 0.2587,
    "Lignite old 1"               => 0.2587,
    "Lignite old 2"               => 0.2587,
    "Lignite CCS"             => 0.2587,
    "Hard coal new"               => 0.2587,
    "Hard coal CCS"               => 0.2587,
    "Hard coal old 1"             => 0.2587,
    "Hard coal old 2"             => 0.2587,
    "Gas CCGT old 2 Bio"          => 0.2334,
    "Gas conventional old 2 Bio"  => 0.2334,
    "Hard coal new Bio"           => 0.2587,
    "Hard coal old 1 Bio"         => 0.2587,
    "Hard coal old 2 Bio"         => 0.2587,
    "Heavy oil old 1 Bio"         => 0.8049,
    "Lignite old 1 Bio"           => 0.2587,
    "Oil shale new Bio"           => 0.8049,
    "Gas OCGT new"                => 0.2334,
    "Gas OCGT old"                => 0.2334,
    "Heavy oil old 1"             => 0.8049,
    "Heavy oil old 2"             => 0.8049,
    "Nuclear"                     => 0,
    "Light oil"                   => 0.8049,
    "Oil shale new"               => 0.8049,
    "P2G"                         => 0,
    "Other non-RES DE00 P"        => 0.2334,
    "Other non-RES DKE1 P"        => 0.2334,
    "Other non-RES DKW1 P"        => 0.2334,
    "Other non-RES FI00 P"        => 0.2334,
    "Other non-RES FR00 P"        => 0.2334,
    "Other non-RES MT00 P"        => 0.2334,
    "Other non-RES UK00 P"        => 0.2334,
    "Other RES"                   => 0.2334,
    "Gas CCGT new CCS"            => 0.2334,
    "Gas CCGT present 1 CCS"      => 0.2334,
    "Gas CCGT present 2 CCS"      => 0.2334,
    "Battery"                     => 0,
    "Lignite old 2 Bio"           => 0.2587,
    "Oil shale old"               => 0.8049,
    "Gas CCGT CCS"                => 0.2334,
    "VOLL"                        => 0,
    "HVDC"                        => 0
    )

    emission_factor_SOx = Dict{String, Any}( #g/kWh == kg/Mwh
    "DSR"                         => 0,
    "Other non-RES"               => 0.3322,
    "Offshore Wind"               => 0,
    "Onshore Wind"                => 0,
    "Solar PV"                    => 0,
    "Solar Thermal"               => 0,
    "Gas CCGT new"                => 0.0046,
    "Gas CCGT CCS"                => 0.0046,
    "Gas CCGT old 1"              => 0.0046,
    "Gas CCGT old 2"              => 0.0046,
    "Gas CCGT present 1"          => 0.0046,
    "Gas CCGT present 2"          => 0.0046,
    "Reservoir"                   => 0,
    "Run-of-River"                => 0,
    "Gas conventional old 1"      => 0.0046,
    "Gas conventional old 2"      => 0.0046,
    "PS Closed"                   => 0.0046,
    "PS Open"                     => 0.0046,
    "Lignite new"                 => 0.3322,
    "Lignite old 1"               => 0.3322,
    "Lignite old 2"               => 0.3322,
    "Lignite CCS"             => 0.3322,
    "Hard coal new"               => 0.3322,
    "Hard coal CCS"               => 0.3322,
    "Hard coal old 1"             => 0.3322,
    "Hard coal old 2"             => 0.3322,
    "Gas CCGT old 2 Bio"          => 0.0046,
    "Gas conventional old 2 Bio"  => 0.0046,
    "Hard coal new Bio"           => 0.3322,
    "Hard coal old 1 Bio"         => 0.3322,
    "Hard coal old 2 Bio"         => 0.3322,
    "Heavy oil old 1 Bio"         => 1.1573,
    "Lignite old 1 Bio"           => 0.3322,
    "Oil shale new Bio"           => 1.1573,
    "Gas OCGT new"                => 0.0046,
    "Gas OCGT old"                => 0.0046,
    "Heavy oil old 1"             => 1.1573,
    "Heavy oil old 2"             => 1.1573,
    "Nuclear"                     => 0,
    "Light oil"                   => 1.1573,
    "Oil shale new"               => 1.1573,
    "P2G"                         => 0,
    "Other non-RES DE00 P"        => 0.0046,
    "Other non-RES DKE1 P"        => 0.0046,
    "Other non-RES DKW1 P"        => 0.0046,
    "Other non-RES FI00 P"        => 0.0046,
    "Other non-RES FR00 P"        => 0.0046,
    "Other non-RES MT00 P"        => 0.0046,
    "Other non-RES UK00 P"        => 0.0046,
    "Other RES"                   => 0.0046,
    "Gas CCGT new CCS"            => 0.0046,
    "Gas CCGT present 1 CCS"      => 0.0046,
    "Gas CCGT present 2 CCS"      => 0.0046,
    "Battery"                     => 0,
    "Lignite old 2 Bio"           => 0.3322,
    "Oil shale old"               => 1.1573,
    "Gas CCGT CCS"                => 0.0046,
    "VOLL"                        => 0,
    "HVDC"                        => 0
    )
 
 for (i_id,i) in input_data["gen"]
    for l in keys(emission_factor_NOx)
        if i["type"] == l
            i["NOx_emissions"] = emission_factor_NOx["$l"]
            i["SOx_emissions"] = emission_factor_SOx["$l"]
        end
    end
 end
 
    return input_data, emission_factor_NOx, emission_factor_SOx
end

