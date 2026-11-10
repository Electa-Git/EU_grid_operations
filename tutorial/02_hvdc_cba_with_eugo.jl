### A Pluto.jl notebook ###
# v1.1.0

using Markdown
using InteractiveUtils

# ╔═╡ f5dff1da-d308-5bad-b07d-9de08588840e
begin
	import Pkg
	Pkg.activate(joinpath(@__DIR__, "tutorial_env"); io = devnull)

	import PowerModels;        const PM = PowerModels
	import PowerModelsACDC;    const PMACDC = PowerModelsACDC
	import EU_grid_operations; const EUGO = EU_grid_operations
	import JuMP
	import HiGHS
	import DataFrames;         const DF = DataFrames
	import CSV
	import Plots
	import Memento

	PM.silence()
	Memento.setlevel!(Memento.getlogger(PMACDC), "error")

	highs = JuMP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)
end;

# ╔═╡ 1f28504f-23e3-55b9-840e-d827358d9a2c
md"""
# Part 2 — Cost-benefit analysis of new HVDC links with EUGO

In Part 1 you solved single OPFs and learned to read the results. A cost-benefit analysis (CBA) of a grid investment is the same thing repeated: solve the system **without** the project and **with** the project for many hours, and compare.

This notebook follows `PowerModelsACDC.jl/tutorials/cba_german_hvdc.jl` and adds the pieces you need to assess **your own** HVDC link.

## The method in one picture

```
 TYNDP scenario data            European nodal grid model
 (capacities, demand, NTCs)     (EUGO, ~6000 buses)
          |                               |
          v                               v
 1. ZONAL model, all of Europe   3. cut out ONE zone (here Germany),
    one node per bidding zone       scale generation to the scenario
          |                               |
          v                               |
 2. zonal OPF per hour  ---- border flows ----> 4. NODAL OPF per hour
    (market dispatch)                              a) base grid
                                                   b) base grid + candidate HVDC link(s)
                                                          |
                                                          v
                                          5. benefit = result (a) - result (b)
                                             cost, RES curtailment, CO2, load shedding
```

Steps 1–2 answer "how much does Germany exchange with its neighbours in each hour?". Steps 3–4 answer "can the German grid transport that dispatch, and at what cost?". A new HVDC link inside Germany changes the answer to the second question; the difference is its benefit.

!!! info "PINT and TOOT"
    Adding one project to a grid without it and measuring the difference is called **PINT** (put in one at a time) in the ENTSO-E CBA guideline. The opposite, removing one project from a grid that contains all of them, is **TOOT** (take out one at a time). This notebook does PINT for each candidate, and also evaluates all candidates together. The benefits of the individual links do not add up to the benefit of the portfolio — you will see that in the results.
"""

# ╔═╡ 89c4ef3c-e448-599f-b4b3-7f7641546fe4
begin
	# small helpers used throughout the notebook
	is_solved(result) = result["termination_status"] == JuMP.OPTIMAL || result["termination_status"] == JuMP.LOCALLY_SOLVED
	sorted_ids(components) = sort(collect(keys(components)); by = id -> parse(Int, id))
	quiet(f) = redirect_stdout(f, devnull)     # run f() without the progress text some EUGO functions print
end;

# ╔═╡ 4435c046-51f6-5d8f-ac92-a26b0f797c51
md"""
## 1. Input parameters

Everything you will normally change is in the next cell.

| Parameter | Meaning |
|:--|:--|
| `tyndp_version` | which ENTSO-E Ten-Year Network Development Plan data set: `"2020"` or `"2024"` |
| `scenario`, `year` | TYNDP scenario and target year. `"DE"` = Distributed Energy, `"GA"` = Global Ambition, `"NT"` = National Trends |
| `climate_year` | historical weather year used for the wind and solar profiles |
| `start_hour`, `number_of_hours` | which hours of the year to simulate (1 to 8760). Hour 3320 is in the morning of 19 May |
| `zones_to_keep` | the zone that is modelled in nodal detail. `"DEKF"` is the German part of the Kriegers Flak offshore area |
| `border_slack` | tolerance on the fixed cross-border flows: 0.003 lets every border deviate by 0.3 % from the zonal result |

Start with 24 hours (about two to three minutes of computing). When everything works, go to one week (`168`) and beyond.
"""

# ╔═╡ 1070bd8a-d3ea-5665-b6bf-ba912f6cfca3
begin
	tyndp_version   = "2020"
	scenario        = "DE"
	year            = "2040"
	climate_year    = "2007"

	start_hour      = 3320
	number_of_hours = 24
	hours           = collect(start_hour:start_hour + number_of_hours - 1)

	zones_to_keep   = ["DE", "DEKF"]
	border_slack    = 0.003
end;

# ╔═╡ 65206b3a-70b4-5dff-9993-dec31f9220a5
md"""
## 2. Load the scenario data

### 2.1 Wind and solar time series

`EUGO.load_res_data()` reads the three PECD files from `data_sources`. Each has one row per zone and hour and one column per climate year, with the capacity factor (0 to 1).
"""

# ╔═╡ 8f41b023-f351-5360-b8f4-286380292c33
begin
	for f in ["PECD-MAF2019-wide-PV.feather", "PECD-MAF2019-wide-WindOnshore.feather", "PECD-MAF2019-wide-WindOffshore.feather"]
		isfile(joinpath(pkgdir(EUGO), "data_sources", f)) || error("Missing file data_sources/$f. Download links are in data_sources/download_links.txt and in the README of this tutorial.")
	end
	pv, wind_onshore, wind_offshore = EUGO.load_res_data()
	wind_onshore[wind_onshore.area .== "DE00", ["area", "day", "month", "hour", climate_year]][hours[1]:hours[1] + 4, :]
end

# ╔═╡ 6488991b-aa69-54b1-b769-9249162c66df
md"""
### 2.2 TYNDP capacities, demand, transfer capacities and costs

`EUGO.get_grid_data` reads the TYNDP Excel and CSV files in `data_sources` and returns eleven objects. The ones you will look at most:

- `ntcs` — net transfer capacities between zones (MW);
- `capacity` — installed generation capacity per zone and technology;
- `demand` — hourly demand per zone;
- `gen_costs`, `emission_factor` — cost and CO2 factor per technology.
"""

# ╔═╡ 83654c29-f1eb-57fe-b6d6-8434ca8eaa94
ntcs, nodes, arcs, capacity, demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions =
	EUGO.get_grid_data(tyndp_version, scenario, year, climate_year);

# ╔═╡ 4fbe56c8-9764-51db-8667-17d42216580b
(zones = DF.nrow(nodes), borders_with_ntc = DF.nrow(ntcs), technologies = length(gen_types), german_borders = ntcs[occursin.("DE00", string.(ntcs.Connection)), :])

# ╔═╡ c0e559ca-6ee8-5979-8200-12914d91cc4e
md"""
!!! warning "Know your input data"
    - For TYNDP 2020 the repository only contains demand profiles for climate year 1984 (`..._Demand_CY1984.csv`). `climate_year` therefore selects the wind and solar year and the capacity table, but the demand profile is always the 1984 one.
    - `gen_costs` are the cost assumptions hard-coded in `get_grid_data.jl` (source noted there). Read that function before you quote absolute costs in your thesis.

## 3. The zonal model and its OPF

`EUGO.construct_data_dictionary` turns the tables into a PowerModels dictionary with **one bus per zone**, one generator per zone and technology, and one branch per border with the NTC as rating. It returns two things:

- `tyndp_zonal` — the network dictionary (same structure as `case5` in Part 1);
- `tyndp_timeseries` — hourly demand and wind/solar generation per zone, used to update the network for each hour.

(In the EUGO scripts these two are usually called `input_data` and `nodal_data`.)
"""

# ╔═╡ 927c508c-c349-5b0a-ac81-b9488526c3c7
tyndp_zonal, tyndp_timeseries = quiet() do
	EUGO.construct_data_dictionary(tyndp_version, ntcs, arcs, capacity, nodes, demand, scenario, year, climate_year,
		gen_types, pv, wind_onshore, wind_offshore, gen_costs, emission_factor, inertia_constants, node_positions)
end;

# ╔═╡ c5dc6c48-5a99-56a1-ab6e-28ab4dccd80e
(zones = length(tyndp_zonal["bus"]), generators = length(tyndp_zonal["gen"]), borders = length(tyndp_zonal["branch"]))

# ╔═╡ 1442e29d-0eb7-5564-8a15-8007cb38db84
md"""
What do the selected hours look like for Germany? The profiles below are what the zonal model sees for zone `DE00`.
"""

# ╔═╡ 3d674f65-6383-57a9-b197-943d15d9d0cf
let
	profile(technology) = vec(collect(tyndp_timeseries["DE00"]["generation"][technology]["timeseries"]))[hours] ./ 1000
	p = Plots.plot(hours, tyndp_timeseries["DE00"]["demand"][hours] ./ 1000; label = "demand", lw = 3, color = :black,
		xlabel = "hour of the year", ylabel = "GW", title = "Germany (DE00): demand and available wind and solar", legend = :outerright, size = (800, 380), left_margin = 6Plots.mm, bottom_margin = 6Plots.mm)
	Plots.plot!(p, hours, profile("Onshore Wind"); label = "onshore wind", lw = 2)
	Plots.plot!(p, hours, profile("Offshore Wind"); label = "offshore wind", lw = 2)
	Plots.plot!(p, hours, profile("Solar PV"); label = "solar PV", lw = 2)
	p
end

# ╔═╡ 0fb203da-3c7c-5d79-8446-2ee47d5c15af
md"""
Now the hourly zonal OPF. `EUGO.prepare_hourly_data!` writes the demand and the available wind and solar power of hour `h` into the network; `PM.solve_opf` with `PM.NFAPowerModel` solves a transport model: power balance per zone, flows limited by the NTCs, no physical flow laws.

The loop works on a copy (`grid_h`), so `tyndp_zonal` itself stays untouched.
"""

# ╔═╡ ca51a26b-7605-5151-b449-2a856921cb37
zonal_result = let
	grid_h = deepcopy(tyndp_zonal)
	results = Dict{String, Any}()
	for h in hours
		EUGO.prepare_hourly_data!(grid_h, tyndp_timeseries, h)
		results[string(h)] = PM.solve_opf(grid_h, PM.NFAPowerModel, highs)
	end
	results
end;

# ╔═╡ e249e704-84e5-5fad-8c68-5b7ced648289
zonal_summary = DF.DataFrame(
	hour             = hours,
	status           = [string(zonal_result[string(h)]["termination_status"]) for h in hours],
	cost_meur        = [round(zonal_result[string(h)]["objective"] / 1e6; digits = 3) for h in hours],
	load_shedding_mw = [round(sum(gen["pg"] for (g, gen) in zonal_result[string(h)]["solution"]["gen"] if tyndp_zonal["gen"][g]["type"] == "ENS") * tyndp_zonal["baseMVA"]; digits = 1) for h in hours],
)

# ╔═╡ 139f4e29-0b98-5523-ab19-d8b960757e2a
all(is_solved(zonal_result[string(h)]) for h in hours) || error("Some zonal OPFs did not solve: check zonal_summary before going on.")

# ╔═╡ d8761dd6-7ae1-5a78-982a-cf257592947f
md"""
## 4. The nodal model of Germany

This cell does the work of step 3 in the picture. Read it line by line; each call is one EUGO building block.

| Call | What it does |
|:--|:--|
| `PM.parse_file`, `process_additional_data!`, `add_load_and_pst_properties!` | load the European nodal grid, as in Part 1 |
| `EUGO.map_zones()` | table linking the zone names of the nodal grid (`"DE"`) to the TYNDP names (`"DE00"`) |
| `EUGO.scale_generation!` | scale the installed capacity of every generator so that the total per zone and technology matches the TYNDP scenario |
| `EUGO.fix_data!` | repair branch ratings that are inconsistent with the branch reactance |
| `EUGO.isolate_zones` | keep only the buses, lines, generators and loads of `zones_to_keep`; every border becomes a "border" object with a dummy generator that represents the exchange |
| `EUGO.create_res_and_demand_time_series` | hourly demand and wind/solar capacity factors for the zone |
| `EUGO.get_xb_flows` | read the hourly flow on each border from the zonal result |
| `EUGO.get_demand_reponse!` | give the loads the demand-response potential of the scenario |

Two data repairs follow, both taken from the existing tutorial for this scenario:

- `apply_manual_cleanup` removes one generator, one bus and one branch of the German grid, exactly as the existing tutorial does for this case;
- `limit_internal_lines!` relaxes the angle-difference limits to plus or minus pi and replaces the rating of internal lines that carry about 5000 MVA or more (inconsistent data) by `internal_rate_limit_pu` (15 pu = 1500 MVA). Skip this step and you will most likely see `INFEASIBLE` in section 7.1.
"""

# ╔═╡ ccfaef4c-e8fa-5d44-b517-bb23ced808be
begin
	apply_manual_cleanup   = true
	internal_rate_limit_pu = 15.0

	function manual_cleanup_2020_de!(grid)
		haskey(grid["gen"], "4906") && delete!(grid["gen"], "4906")
		haskey(grid["bus"], "234") && delete!(grid["bus"], "234")
		haskey(grid["branch"], "392") && delete!(grid["branch"], "392")
		if haskey(grid["borders"], "5") && haskey(grid["borders"]["5"]["xb_lines"], "392")
			delete!(grid["borders"]["5"]["xb_lines"], "392")
		end
		return grid
	end

	function limit_internal_lines!(grid; rate_limit = 15.0)
		for (b, branch) in grid["branch"]
			branch["angmin"] = -pi
			branch["angmax"] = pi
			is_border_line = any(haskey(border["xb_lines"], b) for (_, border) in grid["borders"])
			if branch["rate_a"] >= 49.9 && !is_border_line
				branch["rate_a"] = rate_limit
				branch["rate_b"] = rate_limit
				branch["rate_c"] = rate_limit
			end
		end
		return grid
	end
end;

# ╔═╡ 127596c8-11d3-5d90-b6c0-3886d7089d4e
german_grid, timeseries_data = let
	eu_grid = PM.parse_file(joinpath(pkgdir(EUGO), "data_sources", "European_grid_no_nseh.json"))
	PMACDC.process_additional_data!(eu_grid)
	EUGO.add_load_and_pst_properties!(eu_grid)

	zone_mapping = EUGO.map_zones()

	quiet() do
		# the TYNDP 2024 data need the other method of this function:
		# EUGO.scale_generation!(capacity, eu_grid, tyndp_version, scenario, year, climate_year, zone_mapping)
		EUGO.scale_generation!(capacity, eu_grid, scenario, climate_year, zone_mapping; tyndp = tyndp_version)
		EUGO.fix_data!(eu_grid)
	end

	grid = quiet(() -> EUGO.isolate_zones(eu_grid, zones_to_keep; border_slack = border_slack))
	apply_manual_cleanup && manual_cleanup_2020_de!(grid)

	timeseries = quiet(() -> EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, tyndp_timeseries, climate_year, zone_mapping; zones = ["DE"]))
	timeseries["xb_flows"] = EUGO.get_xb_flows(grid, zonal_result, tyndp_zonal, zone_mapping)
	EUGO.get_demand_reponse!(grid, tyndp_zonal, zone_mapping, timeseries)

	limit_internal_lines!(grid; rate_limit = internal_rate_limit_pu)
	grid, timeseries
end;

# ╔═╡ daf728f3-3f77-57b8-a105-a3347edb7dcf
german_grid_size = DF.DataFrame(
	component = ["bus", "branch", "gen", "load", "busdc", "branchdc", "convdc", "borders"],
	count     = [length(german_grid[c]) for c in ["bus", "branch", "gen", "load", "busdc", "branchdc", "convdc", "borders"]],
)

# ╔═╡ 149647af-dd55-57fb-a659-62b338095f50
md"""
The installed capacity after scaling to the scenario. `XB_dummy` are the border generators; their size has no meaning.
"""

# ╔═╡ 00e9cde2-c250-56df-84a6-682f4c1f78ec
german_capacity = let
	types = sort(unique([gen["type"] for (g, gen) in german_grid["gen"] if gen["type"] != "XB_dummy"]))
	DF.DataFrame(
		type        = types,
		units       = [count(gen["type"] == t for (g, gen) in german_grid["gen"]) for t in types],
		capacity_gw = [round(sum(gen["pmax"] for (g, gen) in german_grid["gen"] if gen["type"] == t) * german_grid["baseMVA"] / 1000; digits = 1) for t in types],
	)
end

# ╔═╡ 6c52f9fc-6d93-5334-b012-8018bea874d1
md"""
The exchange with the neighbours, as decided by the zonal model. Positive = export from Germany. In the nodal OPF these flows are **fixed** (within `border_slack`), which is what the setting `"fix_cross_border_flows" => true` does.
"""

# ╔═╡ 614fd9e2-b5a8-53b5-924f-a8216b738956
let
	p = Plots.plot(; xlabel = "hour of the year", ylabel = "GW (positive = export from Germany)", title = "Cross-border flows from the zonal OPF", legend = :outerright, size = (800, 400), left_margin = 6Plots.mm, bottom_margin = 6Plots.mm)
	for name in sort(collect(keys(timeseries_data["xb_flows"])))
		Plots.plot!(p, hours, vec(timeseries_data["xb_flows"][name]["flow"]) .* german_grid["baseMVA"] ./ 1000; label = name, lw = 2)
	end
	p
end

# ╔═╡ 9c366d7c-a961-5695-8d37-776a144bf722
md"""
## 5. Define the candidate HVDC links

### 5.1 The three links that EUGO knows by name

`EUGO.add_hvdc_links(grid, Dict(name => []))` returns a copy of the grid with one of three German corridors added. Their terminals and ratings are written in `src/core/add_new_hvdc_links.jl`:

| Name | Terminals | Rating in EUGO |
|:--|:--|:--|
| `"Ultranet"` | Emden Ost – Osterath – Philippsburg (three terminals: the A-Nord and Ultranet sections together) | 2 GW |
| `"Suedlink"` | Brunsbüttel – Großgartach | 4 GW |
| `"Suedostlink"` | Wolmirstedt – Isar | 2 GW |

### 5.2 Your own link

A point-to-point HVDC link in the model is two DC buses, two converters and one DC branch. EUGO has a function for each of them. The function `add_p2p_hvdc_link!` below combines them so that you only have to give two coordinates and a rating:

1. `closest_bus` finds the nearest AC substation (in the chosen zone, at or above a minimum voltage) for each terminal;
2. `EUGO.add_dc_bus!` creates a DC bus at each terminal;
3. `EUGO.add_converter!` connects each DC bus to its AC bus;
4. `EUGO.add_dc_branch!` connects the two DC buses.

!!! warning "What this simple model of a link contains"
    Converters added with `EUGO.add_converter!` have zero losses, and the DC approximation neglects the DC cable losses. The link is a lossless, fully controllable connection between two AC buses. Good enough for a first benefit estimate; state it as an assumption.
"""

# ╔═╡ bc7b3db8-2966-5f47-84b6-7b9fda89dcff
begin
	function distance_km(lat1, lon1, lat2, lon2)
		# great-circle distance (haversine formula)
		a = sind((lat2 - lat1) / 2)^2 + cosd(lat1) * cosd(lat2) * sind((lon2 - lon1) / 2)^2
		return 2 * 6371 * asin(sqrt(a))
	end

	function closest_bus(grid, lat, lon; zone = "DE", min_kv = 380)
		best_bus, best_distance = 0, Inf
		for (b, bus) in grid["bus"]
			if get(bus, "zone", "") == zone && bus["base_kv"] >= min_kv && haskey(bus, "lat")
				d = distance_km(lat, lon, bus["lat"], bus["lon"])
				if d < best_distance
					best_bus, best_distance = bus["index"], d
				end
			end
		end
		best_bus == 0 && error("No bus found in zone $zone at or above $min_kv kV")
		return best_bus, best_distance
	end

	function add_p2p_hvdc_link!(grid, link; dc_voltage_kv = 525, zone = "DE", min_kv = 380)
		rating_pu = link.rating_mw / grid["baseMVA"]
		dc_buses = Int[]
		for terminal in (link.from, link.to)
			ac_bus, _ = closest_bus(grid, terminal.lat, terminal.lon; zone = zone, min_kv = min_kv)
			_, dc_bus = EUGO.add_dc_bus!(grid, dc_voltage_kv; lat = terminal.lat, lon = terminal.lon)
			quiet(() -> EUGO.add_converter!(grid, ac_bus, dc_bus, rating_pu))
			push!(dc_buses, dc_bus)
		end
		EUGO.add_dc_branch!(grid, dc_buses[1], dc_buses[2], rating_pu)
		return grid
	end
end;

# ╔═╡ 5c803d79-a0da-5a51-815c-2661ccde9856
md"""
Define your links here. The example is a 2 GW north–south link from the Heide area (Schleswig-Holstein) to the northern Ruhr area. **The coordinates are approximate and only an example — replace them with the terminals of the project you study.** Add more links by adding entries to the list.
"""

# ╔═╡ 1df12f6c-7667-57ea-880c-9b73b1b3e2ed
my_links = [
	(name = "My new link", from = (lat = 54.20, lon = 9.10), to = (lat = 51.63, lon = 7.06), rating_mw = 2000.0),
]

# ╔═╡ 211f9d3e-08e2-5204-8179-52b65f7eb3b4
md"""
### 5.3 Build one grid per case

Each candidate is evaluated alone, then all together. `case_grids` maps a case name to its grid dictionary; the base grid is never modified because every case starts from a `deepcopy`.
"""

# ╔═╡ 6ce2abf0-5896-571e-a7bc-338559ae8651
begin
	builtin_links = ["Suedostlink", "Suedlink", "Ultranet"]

	function build_case(base_grid, builtin_names, own_links)
		grid = deepcopy(base_grid)
		for name in builtin_names          # one call per link, so that each link keeps its own rating
			grid = quiet(() -> EUGO.add_hvdc_links(grid, Dict(name => [])))
		end
		for link in own_links
			add_p2p_hvdc_link!(grid, link)
		end
		return grid
	end

	case_names = vcat(["Only " * name for name in builtin_links], ["Only " * link.name for link in my_links], ["All links"])

	case_grids = Dict{String, Any}()
	for name in builtin_links
		case_grids["Only " * name] = build_case(german_grid, [name], [])
	end
	for link in my_links
		case_grids["Only " * link.name] = build_case(german_grid, String[], [link])
	end
	case_grids["All links"] = build_case(german_grid, builtin_links, my_links)

	# ids of the DC branches and converters that each case adds to the base grid
	new_dc_branches = Dict(name => sort(collect(setdiff(keys(case_grids[name]["branchdc"]), keys(german_grid["branchdc"])))) for name in case_names)
	new_converters  = Dict(name => sort(collect(setdiff(keys(case_grids[name]["convdc"]), keys(german_grid["convdc"])))) for name in case_names)
end;

# ╔═╡ e30c51a5-3193-50e6-ad8a-52c6d832db07
md"""
**Always check where your link was connected.** The table lists every converter that the cases add: the AC bus it was attached to, the voltage of that bus and how far the bus is from the coordinate you asked for. A terminal that lands tens of kilometres away, or on the wrong side of a bottleneck, changes the result completely.
"""

# ╔═╡ 22ca8b2a-60f4-53e5-b30f-a2769c4d5609
new_terminals = let
	rows = DF.DataFrame(case = String[], converter = String[], ac_bus = Int[], bus_name = String[], kv = Float64[], bus_lat = Float64[], bus_lon = Float64[], distance_to_request_km = Float64[], rating_mw = Float64[])
	for name in case_names[1:end-1], c in new_converters[name]
		grid = case_grids[name]
		conv = grid["convdc"][c]
		bus = grid["bus"][string(conv["busac_i"])]
		dc_bus = grid["busdc"][string(conv["busdc_i"])]
		push!(rows, (name, c, conv["busac_i"], string(get(bus, "name", "")), bus["base_kv"], bus["lat"], bus["lon"],
			round(distance_km(dc_bus["lat"], dc_bus["lon"], bus["lat"], bus["lon"]); digits = 1), conv["Pacmax"] * grid["baseMVA"]))
	end
	rows
end

# ╔═╡ f032b4ca-509e-51f0-bd33-18026a877adb
let
	xs, ys = Float64[], Float64[]
	for (b, branch) in german_grid["branch"]
		f, t = string(branch["f_bus"]), string(branch["t_bus"])
		if haskey(german_grid["bus"], f) && haskey(german_grid["bus"], t)
			append!(xs, [german_grid["bus"][f]["lon"], german_grid["bus"][t]["lon"], NaN])
			append!(ys, [german_grid["bus"][f]["lat"], german_grid["bus"][t]["lat"], NaN])
		end
	end
	p = Plots.plot(xs, ys; color = :lightgray, lw = 0.6, label = "AC grid in the model", xlabel = "longitude", ylabel = "latitude",
		aspect_ratio = 1.6, size = (650, 700), legend = :outerbottom, title = "Candidate HVDC links")
	for (i, name) in enumerate(case_names[1:end-1])
		grid = case_grids[name]
		for (k, b) in enumerate(new_dc_branches[name])
			f = grid["busdc"][string(grid["branchdc"][b]["fbusdc"])]
			t = grid["busdc"][string(grid["branchdc"][b]["tbusdc"])]
			Plots.plot!(p, [f["lon"], t["lon"]], [f["lat"], t["lat"]]; color = i, lw = 4, marker = :circle, label = k == 1 ? replace(name, "Only " => "") : "")
		end
	end
	p
end

# ╔═╡ 005b3cca-1d05-5c81-b2d7-3f37a9c0fc70
md"""
## 6. Run the hourly OPFs, with and without the links

For every hour and every case:

1. `EUGO.hourly_grid_data!` writes the demand, the available wind and solar power and the border flows of that hour into a copy of the grid;
2. `PMACDC.solve_acdcopf` solves the DC OPF, exactly as in Part 1;
3. `hourly_indicators` reads the numbers we need from the result.

The indicator functions are written out here on purpose: you should know exactly what is counted.

| Indicator | Definition used here |
|:--|:--|
| operating cost | the OPF objective: generation cost plus the cost of demand response and load shedding |
| energy not served | sum of `pcurt` over all loads |
| RES generation | dispatch of onshore wind, offshore wind, solar PV and run-of-river |
| RES curtailment | available minus dispatched power of those technologies |
| CO2 | dispatch times the TYNDP emission factor of the generator's technology (`type_tyndp`) |

!!! warning "Infeasible hours"
    An OPF that ends with a status other than `OPTIMAL` is stored with `solved = false` and is left out of all sums in section 7. HiGHS returns numbers even for an infeasible problem; adding them up would give a wrong CBA.
"""

# ╔═╡ 1c7ceb5b-0ae2-5edf-8b58-b62103c14b6c
begin
	nodal_settings = Dict(
		"output" => Dict("branch_flows" => true),
		"conv_losses_mp" => true,
		"fix_cross_border_flows" => true,
		"objective_components" => ["gen", "demand"],
	)

	res_technologies = ["Onshore Wind", "Offshore Wind", "Solar PV", "Run-of-River"]

	function solve_hour(grid, hour, timeseries, solver, settings; start_hour)
		grid_h = deepcopy(grid)
		EUGO.hourly_grid_data!(grid_h, grid, hour, timeseries; start_hour = start_hour)
		result = PMACDC.solve_acdcopf(grid_h, PM.DCPPowerModel, solver; setting = settings)
		return grid_h, result
	end

	function hourly_indicators(case, hour, grid_h, result, emission_factor)
		status = string(result["termination_status"])
		if !is_solved(result)
			return (case = case, hour = hour, status = status, solved = false, cost_eur = 0.0, ens_mwh = 0.0, res_mwh = 0.0, res_curtailment_mwh = 0.0, co2_t = 0.0)
		end
		base = grid_h["baseMVA"]
		ens, res, curtailment, co2 = 0.0, 0.0, 0.0, 0.0
		for (l, load) in result["solution"]["load"]
			ens += get(load, "pcurt", 0.0) * base
		end
		for (g, gen) in result["solution"]["gen"]
			technology = grid_h["gen"][g]["type_tyndp"]
			if technology in res_technologies
				res += gen["pg"] * base
				curtailment += (grid_h["gen"][g]["pmax"] - gen["pg"]) * base
			elseif technology != "XB_dummy"
				co2 += gen["pg"] * base * get(emission_factor, technology, 0.0)
			end
		end
		return (case = case, hour = hour, status = status, solved = true, cost_eur = result["objective"], ens_mwh = ens, res_mwh = res, res_curtailment_mwh = curtailment, co2_t = co2)
	end
end;

# ╔═╡ 76acdb48-8c2d-5737-be69-4bf37ce0241d
md"""
The next cell is the long one: `number_of_hours` times (number of cases + 1) OPFs, each well under a second after the first. Progress is printed below the cell.
"""

# ╔═╡ 424539bb-a20b-52a2-a70c-8ca67b1ab2cd
hourly, link_flows = let
	indicators = DF.DataFrame(case = String[], hour = Int[], status = String[], solved = Bool[], cost_eur = Float64[], ens_mwh = Float64[], res_mwh = Float64[], res_curtailment_mwh = Float64[], co2_t = Float64[])
	flows = DF.DataFrame(case = String[], hour = Int[], dc_branch = String[], flow_mw = Float64[], rating_mw = Float64[])

	for hour in hours
		grid_h, result = solve_hour(german_grid, hour, timeseries_data, highs, nodal_settings; start_hour = start_hour)
		push!(indicators, hourly_indicators("Base", hour, grid_h, result, emission_factor))

		for name in case_names
			grid_h, result = solve_hour(case_grids[name], hour, timeseries_data, highs, nodal_settings; start_hour = start_hour)
			push!(indicators, hourly_indicators(name, hour, grid_h, result, emission_factor))
			if is_solved(result)
				for b in new_dc_branches[name]
					push!(flows, (name, hour, b, result["solution"]["branchdc"][b]["pf"] * grid_h["baseMVA"], grid_h["branchdc"][b]["rateA"] * grid_h["baseMVA"]))
				end
			end
		end
		println("hour ", hour, " done (", hour - start_hour + 1, " of ", number_of_hours, ")")
	end
	indicators, flows
end;

# ╔═╡ 7a676dcb-b4c9-53f9-b8f4-31e1812bd6eb
md"""
## 7. Results

### 7.1 First: did everything solve?
"""

# ╔═╡ 784c9a36-dfa9-59b3-9b9c-4f2c8212b142
solve_overview = DF.combine(DF.groupby(hourly, :case), :solved => sum => :hours_solved, :solved => length => :hours_total, :status => (s -> join(unique(s), ", ")) => :statuses)

# ╔═╡ 657ded7e-14f1-5f08-805e-6e018c40dc9a
md"""
If a case has unsolved hours, look at which hours they are (`hourly[.!hourly.solved, :]`) before interpreting anything. Typical reasons are border flows that the nodal grid cannot carry (try a larger `border_slack`) and data problems in a single component.

### 7.2 The hourly table

One row per case and hour. This is the raw material of the CBA; everything below is computed from it.
"""

# ╔═╡ 0abacd02-7b68-51f3-9179-26d4b795b13b
hourly

# ╔═╡ 1fa206cd-73c3-59b5-a0b1-bc2a9b919174
md"""
### 7.3 Benefit of each case against the base grid

For every case, the hours where both the base and the case solved are compared. All columns are defined so that **positive = improvement**:

- `cost_saving_keur` — reduction of operating cost (the socio-economic welfare gain, as far as this model sees it);
- `res_curtailment_avoided_mwh` — renewable energy that is no longer curtailed;
- `co2_avoided_t` — reduction of emissions;
- `ens_avoided_mwh` — reduction of energy not served.
"""

# ╔═╡ 95672686-5b16-5057-be44-4b9c288cd932
function cba_summary(hourly, case_names)
	base = DF.select(hourly[hourly.case .== "Base", :], DF.Not(:case))
	summary = DF.DataFrame(case = String[], hours_compared = Int[], cost_saving_keur = Float64[], res_curtailment_avoided_mwh = Float64[], co2_avoided_t = Float64[], ens_avoided_mwh = Float64[])
	for name in case_names
		project = DF.select(hourly[hourly.case .== name, :], DF.Not(:case))
		both = DF.innerjoin(base, project; on = :hour, renamecols = "_base" => "_project")
		both = both[both.solved_base .& both.solved_project, :]
		push!(summary, (
			name,
			DF.nrow(both),
			round(sum(both.cost_eur_base .- both.cost_eur_project) / 1e3; digits = 1),
			round(sum(both.res_curtailment_mwh_base .- both.res_curtailment_mwh_project); digits = 1),
			round(sum(both.co2_t_base .- both.co2_t_project); digits = 1),
			round(sum(both.ens_mwh_base .- both.ens_mwh_project); digits = 1),
		))
	end
	return summary
end

# ╔═╡ 966cb978-935f-5730-b860-99104a8642cd
summary_table = cba_summary(hourly, case_names)

# ╔═╡ d1003431-b22f-5851-bd93-44d8ed45358d
Plots.bar(replace.(summary_table.case, "Only " => ""), summary_table.cost_saving_keur; legend = false, ylabel = "k EUR over the simulated hours",
	title = "Operating-cost saving per case", xrotation = 15, size = (750, 400), left_margin = 6Plots.mm, bottom_margin = 6Plots.mm)

# ╔═╡ 108bb244-e63f-5194-9193-dbdc420a4343
let
	p = Plots.plot(; xlabel = "hour of the year", ylabel = "k EUR per hour", title = "Hourly operating-cost saving against the base grid", legend = :outerright, size = (850, 400), left_margin = 6Plots.mm, bottom_margin = 6Plots.mm)
	base = hourly[hourly.case .== "Base", :]
	for name in case_names
		project = hourly[hourly.case .== name, :]
		ok = base.solved .& project.solved
		Plots.plot!(p, base.hour[ok], (base.cost_eur[ok] .- project.cost_eur[ok]) ./ 1e3; label = replace(name, "Only " => ""), lw = 2)
	end
	p
end

# ╔═╡ d0be4f25-0a92-56dd-90d8-aa0fb3ce4cc0
md"""
!!! tip "Questions to answer from these results"
    1. Is the saving of "All links" equal to the sum of the single-link savings? Why not?
    2. In which hours is the saving largest? Go back to the wind and demand plot of section 3 and to the border flows of section 4.
    3. A saving that is negative or exactly zero in many hours is a signal, not noise: either the link is not needed in those hours, or its terminals are not where the congestion is.

### 7.4 How is the new link used?

A link that is never loaded brings no benefit; a link that is always at its limit suggests a larger rating would bring more.
"""

# ╔═╡ 18ccc5fa-e111-5b80-90f0-58c2923a8bde
link_usage = DF.combine(
	DF.groupby(link_flows, [:case, :dc_branch]),
	:rating_mw => first => :rating_mw,
	:flow_mw => (f -> round(sum(abs.(f)) / length(f); digits = 1)) => :mean_abs_flow_mw,
	:flow_mw => (f -> round(maximum(abs.(f)); digits = 1)) => :max_abs_flow_mw,
	[:flow_mw, :rating_mw] => ((f, r) -> count(abs.(f) .>= 0.99 .* r)) => :hours_at_limit,
)

# ╔═╡ 4c51992f-a5bd-50c4-b199-f5a429a6264e
let
	single = link_flows[link_flows.case .!= "All links", :]
	p = Plots.plot(; xlabel = "hour of the year", ylabel = "MW (positive = from first to second terminal)", title = "Flow on the new DC branches (single-link cases)", legend = :outerright, size = (850, 400), left_margin = 6Plots.mm, bottom_margin = 6Plots.mm)
	for key in unique(zip(single.case, single.dc_branch))
		rows = single[(single.case .== key[1]) .& (single.dc_branch .== key[2]), :]
		Plots.plot!(p, rows.hour, rows.flow_mw; label = replace(key[1], "Only " => "") * " (branch " * key[2] * ")", lw = 2)
	end
	p
end

# ╔═╡ 1f35c90e-acde-5f92-8c6d-fb43b3a068f3
md"""
## 8. From simulated hours to a cost-benefit figure

A CBA compares **annual** benefits over the lifetime of the asset with its cost. Two steps are missing: scaling the simulated hours to a year, and discounting.

!!! danger "Read this before you use the numbers below"
    - Scaling 24 hours (or one week) to a year by multiplying is only arithmetic. The result is meaningful only if the simulated hours are representative of the year. For a real result simulate the whole year (`start_hour = 1`, `number_of_hours = 8760`), or a set of representative weeks with proper weights.
    - `capex_meur` is **empty on purpose**. Fill in the investment cost of your project from a source you can cite. Without it the table shows the present value of the benefits only.
    - The discount rate and the assessment period below are the values commonly used with the ENTSO-E CBA guideline (4 % real, 25 years). Check the guideline version you refer to.
"""

# ╔═╡ 91151ea6-418e-53a1-86e3-90e4f22b57d6
begin
	discount_rate      = 0.04
	assessment_years   = 25
	annual_opex_share  = 0.0          # yearly operation and maintenance cost as a share of CAPEX, e.g. 0.01
	capex_meur         = Dict{String, Float64}()      # e.g. Dict("Only My new link" => 3000.0)
end;

# ╔═╡ 219beca5-f336-5fed-97d3-1b7cf8bca98e
npv_table = let
	annuity_factor = sum(1 / (1 + discount_rate)^t for t in 1:assessment_years)
	table = DF.DataFrame(case = String[], annual_cost_saving_meur = Float64[], pv_benefits_meur = Float64[], capex_meur = Union{Missing, Float64}[], npv_meur = Union{Missing, Float64}[], benefit_cost_ratio = Union{Missing, Float64}[])
	for row in eachrow(summary_table)
		row.hours_compared == 0 && continue
		annual = row.cost_saving_keur / 1e3 * 8760 / row.hours_compared
		pv_benefits = annual * annuity_factor
		if haskey(capex_meur, row.case)
			capex = capex_meur[row.case]
			pv_costs = capex + capex * annual_opex_share * annuity_factor
			push!(table, (row.case, round(annual; digits = 1), round(pv_benefits; digits = 1), capex, round(pv_benefits - pv_costs; digits = 1), round(pv_benefits / pv_costs; digits = 2)))
		else
			push!(table, (row.case, round(annual; digits = 1), round(pv_benefits; digits = 1), missing, missing, missing))
		end
	end
	table
end

# ╔═╡ 13414e5c-d959-5cc2-9a9e-0b875f0d41f2
md"""
## 9. Save the results

Set `save_results = true` to write the three result tables as CSV files into the folder `results_tutorial` next to this notebook. The file names contain the scenario so that runs do not overwrite each other.
"""

# ╔═╡ 1aaa4738-4f22-554f-bd1b-2417283d38d1
begin
	save_results = false
	if save_results
		result_dir = joinpath(@__DIR__, "results_tutorial")
		mkpath(result_dir)
		tag = join([tyndp_version, scenario * year, climate_year, "h" * string(start_hour), string(number_of_hours) * "h"], "_")
		CSV.write(joinpath(result_dir, "hourly_" * tag * ".csv"), hourly)
		CSV.write(joinpath(result_dir, "summary_" * tag * ".csv"), summary_table)
		CSV.write(joinpath(result_dir, "link_flows_" * tag * ".csv"), link_flows)
		"saved to " * result_dir
	else
		"not saved"
	end
end

# ╔═╡ c6a172e4-f0bd-5f0a-8f80-d091377830a6
md"""
## 10. A link between two zones: start in the zonal model

Everything above is for a link **inside** one zone. There the exchange with the neighbours is an input, so the benefit you measure is the cheaper dispatch inside Germany once internal congestion is relieved.

A new **interconnector** is different: its first effect is that the two markets can exchange more. That effect lives in the zonal model, where the project is simply a larger NTC on one border. The cell below does this PINT in the zonal model for the same hours: it raises the rating of one zonal branch and compares the total European dispatch cost.

Look up the border names with `[branch["name"] for (b, branch) in tyndp_zonal["branch"]]`.
"""

# ╔═╡ 52109613-f9e1-58fe-b976-497942933707
begin
	interconnector_border = "DE00-UK00"
	interconnector_mw     = 1400.0
end;

# ╔═╡ 0281998b-02a9-5e8e-9079-2365de222264
interconnector_benefit = let
	ids = [b for (b, branch) in tyndp_zonal["branch"] if branch["name"] == interconnector_border]
	isempty(ids) && error("No zonal branch named $interconnector_border. Mind the order of the two zones in the name.")
	with_project = deepcopy(tyndp_zonal)
	with_project["branch"][ids[1]]["rate_a"] += interconnector_mw / with_project["baseMVA"]

	base_h, project_h = deepcopy(tyndp_zonal), deepcopy(with_project)
	table = DF.DataFrame(hour = Int[], cost_base_keur = Float64[], cost_project_keur = Float64[], saving_keur = Float64[], flow_base_mw = Float64[], flow_project_mw = Float64[])
	for h in hours
		EUGO.prepare_hourly_data!(base_h, tyndp_timeseries, h)
		EUGO.prepare_hourly_data!(project_h, tyndp_timeseries, h)
		settings = Dict("output" => Dict("branch_flows" => true))
		r_base = PM.solve_opf(base_h, PM.NFAPowerModel, highs; setting = settings)
		r_project = PM.solve_opf(project_h, PM.NFAPowerModel, highs; setting = settings)
		(is_solved(r_base) && is_solved(r_project)) || continue
		push!(table, (h, round(r_base["objective"] / 1e3; digits = 1), round(r_project["objective"] / 1e3; digits = 1), round((r_base["objective"] - r_project["objective"]) / 1e3; digits = 1),
			round(r_base["solution"]["branch"][ids[1]]["pf"] * base_h["baseMVA"]; digits = 1), round(r_project["solution"]["branch"][ids[1]]["pf"] * base_h["baseMVA"]; digits = 1)))
	end
	table
end

# ╔═╡ 291435f6-9ca9-53e5-9b09-d6b297ba9769
(border = interconnector_border, added_mw = interconnector_mw, hours = DF.nrow(interconnector_benefit), total_saving_keur = round(sum(interconnector_benefit.saving_keur); digits = 1))

# ╔═╡ 82c52c44-e7b4-535d-8e6d-78852d1a7b30
md"""
For a complete interconnector study you would then feed the new zonal result into the nodal models of the zones at both ends, as in sections 4 to 7, to see whether the internal grids can carry the extra exchange.

## 11. Where to go from here

**Longer runs.** One week is `number_of_hours = 168`; a year is 8760. Count roughly half a second per OPF on a laptop, times (number of cases + 1). For a full year, move the code into a plain `.jl` script, save the results to file as you go, and run it from the terminal with `julia --project=tutorial_env my_script.jl`. A Pluto notebook file is itself a valid Julia script.

**Other scenarios and climate years.** Change the parameters in section 1. Which combinations exist depends on the files in `data_sources/TYNDP2020` and `data_sources/TYNDP2024`.

**TYNDP 2024.** Set `tyndp_version = "2024"` and switch to the other `scale_generation!` call (commented in section 4). The repair steps of section 4 were tuned for the 2020 case, so expect to revisit them: check `solve_overview` and try a larger `border_slack` if hours are infeasible.

**Another country.** Change `zones_to_keep` and the `zones = ["DE"]` argument in section 4, and the `zone` argument of `closest_bus`. The three named links of section 5.1 are German; use `my_links` only.

**Limits of this analysis — write them in your report.**

- DC approximation: no losses, no voltage or reactive-power constraints; new links are lossless.
- One zone in nodal detail with fixed exchanges: benefits outside that zone are not counted.
- No unit commitment, no storage optimisation over time, no N-1 security: every hour is solved on its own.
- Costs and emission factors are scenario assumptions; verify their units and sources before quoting absolute values.
- A benefit measured over a few hours says nothing about a year.

!!! tip "Exercises"
    1. Change the rating of your link to 4000 MW. Does the saving double?
    2. Move the southern terminal of your link 100 km to the south. What changes in `new_terminals`, in `link_usage` and in the saving?
    3. Run one week in winter (`start_hour = 337`, `number_of_hours = 168`) and one in summer. Which link ranks first in each?
    4. Compute the ranking of the links by saving per MW of rating.
"""

# ╔═╡ Cell order:
# ╟─1f28504f-23e3-55b9-840e-d827358d9a2c
# ╠═f5dff1da-d308-5bad-b07d-9de08588840e
# ╟─89c4ef3c-e448-599f-b4b3-7f7641546fe4
# ╟─4435c046-51f6-5d8f-ac92-a26b0f797c51
# ╠═1070bd8a-d3ea-5665-b6bf-ba912f6cfca3
# ╟─65206b3a-70b4-5dff-9993-dec31f9220a5
# ╠═8f41b023-f351-5360-b8f4-286380292c33
# ╟─6488991b-aa69-54b1-b769-9249162c66df
# ╠═83654c29-f1eb-57fe-b6d6-8434ca8eaa94
# ╠═4fbe56c8-9764-51db-8667-17d42216580b
# ╟─c0e559ca-6ee8-5979-8200-12914d91cc4e
# ╠═927c508c-c349-5b0a-ac81-b9488526c3c7
# ╠═c5dc6c48-5a99-56a1-ab6e-28ab4dccd80e
# ╟─1442e29d-0eb7-5564-8a15-8007cb38db84
# ╠═3d674f65-6383-57a9-b197-943d15d9d0cf
# ╟─0fb203da-3c7c-5d79-8446-2ee47d5c15af
# ╠═ca51a26b-7605-5151-b449-2a856921cb37
# ╠═e249e704-84e5-5fad-8c68-5b7ced648289
# ╠═139f4e29-0b98-5523-ab19-d8b960757e2a
# ╟─d8761dd6-7ae1-5a78-982a-cf257592947f
# ╠═ccfaef4c-e8fa-5d44-b517-bb23ced808be
# ╠═127596c8-11d3-5d90-b6c0-3886d7089d4e
# ╠═daf728f3-3f77-57b8-a105-a3347edb7dcf
# ╟─149647af-dd55-57fb-a659-62b338095f50
# ╠═00e9cde2-c250-56df-84a6-682f4c1f78ec
# ╟─6c52f9fc-6d93-5334-b012-8018bea874d1
# ╠═614fd9e2-b5a8-53b5-924f-a8216b738956
# ╟─9c366d7c-a961-5695-8d37-776a144bf722
# ╠═bc7b3db8-2966-5f47-84b6-7b9fda89dcff
# ╟─5c803d79-a0da-5a51-815c-2661ccde9856
# ╠═1df12f6c-7667-57ea-880c-9b73b1b3e2ed
# ╟─211f9d3e-08e2-5204-8179-52b65f7eb3b4
# ╠═6ce2abf0-5896-571e-a7bc-338559ae8651
# ╟─e30c51a5-3193-50e6-ad8a-52c6d832db07
# ╠═22ca8b2a-60f4-53e5-b30f-a2769c4d5609
# ╠═f032b4ca-509e-51f0-bd33-18026a877adb
# ╟─005b3cca-1d05-5c81-b2d7-3f37a9c0fc70
# ╠═1c7ceb5b-0ae2-5edf-8b58-b62103c14b6c
# ╟─76acdb48-8c2d-5737-be69-4bf37ce0241d
# ╠═424539bb-a20b-52a2-a70c-8ca67b1ab2cd
# ╟─7a676dcb-b4c9-53f9-b8f4-31e1812bd6eb
# ╠═784c9a36-dfa9-59b3-9b9c-4f2c8212b142
# ╟─657ded7e-14f1-5f08-805e-6e018c40dc9a
# ╠═0abacd02-7b68-51f3-9179-26d4b795b13b
# ╟─1fa206cd-73c3-59b5-a0b1-bc2a9b919174
# ╠═95672686-5b16-5057-be44-4b9c288cd932
# ╠═966cb978-935f-5730-b860-99104a8642cd
# ╠═d1003431-b22f-5851-bd93-44d8ed45358d
# ╠═108bb244-e63f-5194-9193-dbdc420a4343
# ╟─d0be4f25-0a92-56dd-90d8-aa0fb3ce4cc0
# ╠═18ccc5fa-e111-5b80-90f0-58c2923a8bde
# ╠═4c51992f-a5bd-50c4-b199-f5a429a6264e
# ╟─1f35c90e-acde-5f92-8c6d-fb43b3a068f3
# ╠═91151ea6-418e-53a1-86e3-90e4f22b57d6
# ╠═219beca5-f336-5fed-97d3-1b7cf8bca98e
# ╟─13414e5c-d959-5cc2-9a9e-0b875f0d41f2
# ╠═1aaa4738-4f22-554f-bd1b-2417283d38d1
# ╟─c6a172e4-f0bd-5f0a-8f80-d091377830a6
# ╠═52109613-f9e1-58fe-b976-497942933707
# ╠═0281998b-02a9-5e8e-9079-2365de222264
# ╠═291435f6-9ca9-53e5-9b09-d6b297ba9769
# ╟─82c52c44-e7b4-535d-8e6d-78852d1a7b30
