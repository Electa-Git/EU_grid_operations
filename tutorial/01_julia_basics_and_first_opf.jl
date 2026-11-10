### A Pluto.jl notebook ###
# v1.1.0

using Markdown
using InteractiveUtils

# ╔═╡ ef3c7fc7-ccef-5320-b9b0-bc090a09902b
begin
	import Pkg
	Pkg.activate(joinpath(@__DIR__, "tutorial_env"); io = devnull)

	import PowerModels;        const PM = PowerModels
	import PowerModelsACDC;    const PMACDC = PowerModelsACDC
	import EU_grid_operations; const EUGO = EU_grid_operations
	import JuMP
	import HiGHS, Ipopt
	import DataFrames;         const DF = DataFrames
	import Plots
	import Memento

	# PowerModels and PowerModelsACDC print many [info]/[warn] lines; keep only errors.
	PM.silence()
	Memento.setlevel!(Memento.getlogger(PMACDC), "error")
end;

# ╔═╡ d14cf719-963b-5ffb-8e6f-ea4f21eaa1b3
md"""
# Part 1 — Julia basics and your first optimal power flow

This notebook is the first of two:

1. **Part 1 (this notebook)** — just enough Julia to read and write power-system scripts, then one optimal power flow (OPF) on a 5-bus AC/DC test case, and one on the full European grid model. The focus is on *how to look at the results*.
2. **Part 2** — a cost-benefit analysis (CBA) of new HVDC links in the German grid with `EU_grid_operations.jl` (EUGO).

It builds on the two notebooks in `PowerModelsACDC.jl/tutorials` (`opf.jl` and `cba_german_hvdc.jl`).

!!! info "How a Pluto notebook works"
    - A notebook is a list of **cells**. Click in a cell, edit it, and press **Shift + Enter** to run it.
    - The output of a cell is shown **above** the code. Text printed with `println` appears below it.
    - Pluto is **reactive**: when you change a variable, every cell that uses it re-runs automatically. For the same reason a variable name can only be defined in **one** cell.
    - A cell holds one expression. Several lines go inside `begin ... end`.
    - Click the eye icon on the left of a cell to show or hide its code.

!!! warning "Before you start"
    Run `julia setup_environment.jl` once from a terminal in this folder (see `README.md`). It creates the folder `tutorial_env` with all packages. The first cell below only *activates* that environment.
"""

# ╔═╡ e0040758-6919-5aee-b639-19c460e1759a
md"""
!!! info "import, using and the short names"
    `import PowerModels` loads a package; you then call its functions as `PowerModels.parse_file(...)`. Because that is long, the scripts in our group define short aliases: `PM` (PowerModels), `PMACDC` (PowerModelsACDC), `EUGO` (`EU_grid_operations`) and `DF` (DataFrames). In older scripts you will see the same aliases with an underscore: `_PM`, `_PMACDC`, `_EUGO`.

    `using PowerModels` would also work and lets you write `parse_file(...)` directly, but then you no longer see which package a function comes from.
"""

# ╔═╡ da08ca9f-1a84-52ea-8707-5a560afe71fc
md"""
## 1. Julia in ten minutes

Skip this section if you already know Julia. Everything here is used later in the two notebooks.

### 1.1 Numbers, strings, vectors
"""

# ╔═╡ 6fb2a09d-5d39-518a-972d-264d6f2a2b48
begin
	voltage_kv = 380            # an integer
	rating_mva = 1790.5         # a floating-point number
	line_name  = "Line A-B"     # a string, always with double quotes
	loads_mw   = [120.0, 80.0, 45.5]   # a vector

	println("First load: ", loads_mw[1], " MW")       # indexing starts at 1, not 0
	println("Last load:  ", loads_mw[end], " MW")
	println("Total load: ", sum(loads_mw), " MW")
	println("Name and voltage: $line_name at $voltage_kv kV")   # $ inserts a value in a string
end

# ╔═╡ 83995c0f-b931-52ad-9a56-d6016d0d895e
md"""
### 1.2 The dot: apply a function to every element

`f.(x)` or `x .* 2` applies the operation element by element ("broadcasting"). You will use it all the time to convert between MW and per unit.
"""

# ╔═╡ 3cc8d2f9-6902-5cbc-afd7-bc3d482cd037
begin
	base_mva = 100.0
	loads_pu = loads_mw ./ base_mva          # element-wise division
	loads_rounded = round.(loads_pu; digits = 2)
	(loads_pu = loads_pu, loads_rounded = loads_rounded, any_above_1pu = any(loads_pu .> 1.0))
end

# ╔═╡ 6619b8f7-486f-542d-b8b2-b622f616bf07
md"""
### 1.3 Functions

Two ways to write a function. Arguments after the `;` are keyword arguments with a default value. By convention a function whose name ends in `!` **modifies** its argument — PowerModels and EUGO follow this strictly (`process_additional_data!`, `scale_generation!`, ...).
"""

# ╔═╡ 4491f63d-7fb8-588f-bbf9-457ae6465a70
begin
	# short form
	to_mw(p_pu; base = 100.0) = p_pu * base

	# long form
	function loading_percent(flow_mw, rating_mw)
		return 100 * abs(flow_mw) / rating_mw
	end

	# a function that modifies its argument: note the !
	function scale_loads!(loads, factor)
		for i in eachindex(loads)
			loads[i] = loads[i] * factor
		end
		return loads
	end

	(to_mw(0.45), to_mw(0.45; base = 1000.0), loading_percent(-850.0, 1000.0))
end

# ╔═╡ 991a0df4-930b-529e-88fb-db402c8f3107
md"""
### 1.4 Dictionaries — the most important data structure here

PowerModels stores a whole network as **nested dictionaries**: `data["gen"]["1"]["pmax"]` is the maximum power of generator 1. Three things to remember:

- keys of the components are **strings** (`"1"`, not `1`);
- power values are in **per unit** (multiply by `data["baseMVA"]` to get MW);
- a dictionary has **no order**. Sort the keys yourself when the order matters.
"""

# ╔═╡ b51b6b49-4714-5c6c-93c1-0c0bb66472c0
mini_grid = Dict(
	"baseMVA" => 100.0,
	"gen" => Dict(
		"1" => Dict("gen_bus" => 1, "pmax" => 2.5, "cost_per_mwh" => 20.0, "type" => "Wind"),
		"2" => Dict("gen_bus" => 2, "pmax" => 4.0, "cost_per_mwh" => 60.0, "type" => "Gas"),
		"3" => Dict("gen_bus" => 2, "pmax" => 1.0, "cost_per_mwh" => 90.0, "type" => "Gas"),
	),
)

# ╔═╡ cb43b9cc-ad1d-5c8c-a907-1bcf2bae2da0
begin
	println("pmax of generator 2: ", mini_grid["gen"]["2"]["pmax"], " pu")
	println("available keys:      ", keys(mini_grid["gen"]["2"]))
	println("is there a gen 7?    ", haskey(mini_grid["gen"], "7"))
end

# ╔═╡ 2b6bce34-6971-5c76-aa6b-cb848c3ff227
md"""
### 1.5 Loops and comprehensions over a dictionary

`for (id, gen) in mini_grid["gen"]` gives you the key and the value of each entry. The one-line version in square brackets is called a *comprehension*; you can add an `if` at the end to filter. Nearly every result you extract in Part 2 is a comprehension like these.
"""

# ╔═╡ 2a807c6f-f9a3-5119-a856-9d187728da5c
begin
	for (id, gen) in mini_grid["gen"]
		println("gen ", id, ": ", gen["type"], ", ", gen["pmax"] * mini_grid["baseMVA"], " MW")
	end

	all_pmax_mw    = [gen["pmax"] * mini_grid["baseMVA"] for (id, gen) in mini_grid["gen"]]
	gas_capacity   = sum(gen["pmax"] for (id, gen) in mini_grid["gen"] if gen["type"] == "Gas") * mini_grid["baseMVA"]
	sorted_gen_ids = sort(collect(keys(mini_grid["gen"])); by = id -> parse(Int, id))

	(all_pmax_mw = all_pmax_mw, gas_capacity_mw = gas_capacity, sorted_gen_ids = sorted_gen_ids)
end

# ╔═╡ 302e44d5-0fa0-53f7-a0d8-8be021b0aaf4
md"""
### 1.6 Copies: the classic mistake

`b = a` does **not** copy a dictionary: both names point to the same object, so changing `b` also changes `a`. When you build a variant of a network (more load, an extra HVDC link) always start from `deepcopy`.
"""

# ╔═╡ 7922d52c-a148-5a93-a900-8004707a1484
begin
	same_object = mini_grid                  # NOT a copy
	real_copy   = deepcopy(mini_grid)        # an independent copy
	real_copy["gen"]["1"]["pmax"] = 99.0     # only changes the copy

	(original = mini_grid["gen"]["1"]["pmax"], copy = real_copy["gen"]["1"]["pmax"], same_object_is_original = same_object === mini_grid)
end

# ╔═╡ 00c7a91e-9936-5454-8e8e-5b5e2031a98c
md"""
### 1.7 Tables with DataFrames

A `DataFrame` is a table. We build small ones from the dictionaries to get a readable overview of inputs and results.
"""

# ╔═╡ 9595fcaa-beef-5c5f-bd78-212cd8e061f7
mini_table = DF.DataFrame(
	gen       = sorted_gen_ids,
	type      = [mini_grid["gen"][id]["type"] for id in sorted_gen_ids],
	pmax_mw   = [mini_grid["gen"][id]["pmax"] * mini_grid["baseMVA"] for id in sorted_gen_ids],
	cost      = [mini_grid["gen"][id]["cost_per_mwh"] for id in sorted_gen_ids],
)

# ╔═╡ c98862f5-46fc-5031-92ca-0ffa80d46e42
# filter rows, pick a column, sort
(gas_rows = mini_table[mini_table.type .== "Gas", :], cheapest_first = sort(mini_table, :cost).gen)

# ╔═╡ 95b68842-6671-5de7-8ba6-4e0d26c7b417
md"""
!!! tip "Getting help"
    In the Julia REPL type `?` followed by a function name (`?sum`) to read its documentation. In Pluto, click on a function name and open the *Live Docs* panel at the bottom right.
"""

# ╔═╡ eeb01345-cfe9-5df4-9a9f-3e581b588f98
md"""
## 2. The 5-bus AC/DC test case

`case5_acdc.m` is the small test network used throughout PowerModelsACDC: 5 AC buses, 2 generators, 7 AC lines and a 3-terminal DC grid. A copy ships with EUGO in `data_sources`.

Reading a network takes two steps: `PM.parse_file` reads the MATPOWER file into a dictionary, and `PMACDC.process_additional_data!` converts the DC-grid tables (DC buses, DC branches, converters) to per unit.
"""

# ╔═╡ 6b9dac6a-8b08-526d-938e-8cdd7876f534
begin
	case_file = joinpath(pkgdir(EUGO), "data_sources", "case5_acdc.m")
	case5 = PM.parse_file(case_file)
	PMACDC.process_additional_data!(case5)
	sort(collect(keys(case5)))
end

# ╔═╡ 6db8d2a5-8011-5af6-a307-620ad9ae1b22
# helper used in all tables below: component ids in numerical order
sorted_ids(components) = sort(collect(keys(components)); by = id -> parse(Int, id))

# ╔═╡ 92993932-386b-52a4-bf1e-a18d5bf1661d
case5_size = DF.DataFrame(
	component = ["bus", "gen", "load", "branch", "busdc", "branchdc", "convdc"],
	meaning   = ["AC buses", "generators", "loads", "AC lines and transformers", "DC buses", "DC lines and cables", "AC/DC converters"],
	count     = [length(case5[c]) for c in ["bus", "gen", "load", "branch", "busdc", "branchdc", "convdc"]],
)

# ╔═╡ 20707b0e-8f05-5a90-9bbd-4395dd50f728
md"""
The generators. In PowerModels the cost of a generator is a polynomial stored in `gen["cost"]`; with two entries `[c1, c0]` the cost is `c1 * pg + c0`, with `pg` in per unit. Dividing `c1` by `baseMVA` therefore gives a price per MWh.
"""

# ╔═╡ 5bbf8b26-4650-52bb-850a-8e282abbbc9f
case5_generators = DF.DataFrame(
	gen           = sorted_ids(case5["gen"]),
	bus           = [case5["gen"][g]["gen_bus"] for g in sorted_ids(case5["gen"])],
	pmin_mw       = [case5["gen"][g]["pmin"] * case5["baseMVA"] for g in sorted_ids(case5["gen"])],
	pmax_mw       = [case5["gen"][g]["pmax"] * case5["baseMVA"] for g in sorted_ids(case5["gen"])],
	cost_per_mwh  = [case5["gen"][g]["cost"][1] / case5["baseMVA"] for g in sorted_ids(case5["gen"])],
)

# ╔═╡ 92b58112-03a6-5b51-a54b-b7a7a963b9d7
case5_loads = DF.DataFrame(
	load  = sorted_ids(case5["load"]),
	bus   = [case5["load"][l]["load_bus"] for l in sorted_ids(case5["load"])],
	pd_mw = [case5["load"][l]["pd"] * case5["baseMVA"] for l in sorted_ids(case5["load"])],
)

# ╔═╡ 78bb5b0a-c0f5-552a-9728-8a19736c31cc
md"""
## 3. Solve one OPF

An OPF call needs four things:

| Ingredient | Here | Meaning |
|:--|:--|:--|
| network data | `case5` | the dictionary from section 2 |
| formulation | `PM.DCPPowerModel` | linear "DC" approximation: active power only, no losses on AC lines, all voltages 1 pu |
| solver | `highs` | HiGHS, an open-source solver for linear problems |
| settings | `opf_settings` | options for PowerModelsACDC |

`"branch_flows" => true` asks for the line flows in the result. `"conv_losses_mp" => true` selects how the converter losses are written in the linear formulation (as an equality: loss = a + b times the converter power). The DC formulation needs this key to be present.
"""

# ╔═╡ 7b46baaa-7692-5a6b-82c7-b67bd55c1208
begin
	highs = JuMP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)
	ipopt = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0, "sb" => "yes")
	opf_settings = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
end;

# ╔═╡ 0c5245b1-e852-5ad5-81c9-f25de720e66f
result_dc = PMACDC.solve_acdcopf(case5, PM.DCPPowerModel, highs; setting = opf_settings)

# ╔═╡ a0cc56aa-5217-5dd4-896a-6e0f4c4e7d04
md"""
## 4. Check the results

### 4.1 First question, always: did the solver find an optimum?

The result is again a dictionary. **Look at `termination_status` before anything else.** A solver that stops with `INFEASIBLE` or hits a limit often still returns numbers in `result["solution"]`, and they are meaningless. This matters in Part 2, where you solve hundreds of OPFs in a loop.

- `OPTIMAL` — what a linear solver (HiGHS) returns on success;
- `LOCALLY_SOLVED` — what a nonlinear solver (Ipopt) returns on success.
"""

# ╔═╡ 4c7955a8-81c3-58b0-8478-d69a74dfa355
is_solved(result) = result["termination_status"] == JuMP.OPTIMAL || result["termination_status"] == JuMP.LOCALLY_SOLVED

# ╔═╡ d4f7026f-5247-5594-aa13-760c8ddc2ab7
(
	status         = result_dc["termination_status"],
	solved         = is_solved(result_dc),
	cost_per_hour  = round(result_dc["objective"]; digits = 2),
	solve_time_s   = round(result_dc["solve_time"]; digits = 4),
	solution_parts = sort(collect(keys(result_dc["solution"]))),
)

# ╔═╡ 5788ae5e-4146-5f8a-a6b0-fb718ccc0c27
md"""
The objective is the total generation cost for this one hour, in the currency of the cost data.

### 4.2 Generator dispatch

`result["solution"]["gen"]["1"]["pg"]` is the active power of generator 1 in per unit. The functions below turn the solution into tables; read them once, you will write many like them.
"""

# ╔═╡ 8872ed4a-01d7-5522-906b-d6f05df386e8
function generator_table(data, result)
	ids = sorted_ids(result["solution"]["gen"])
	base = data["baseMVA"]
	return DF.DataFrame(
		gen           = ids,
		bus           = [data["gen"][g]["gen_bus"] for g in ids],
		pg_mw         = [round(result["solution"]["gen"][g]["pg"] * base; digits = 1) for g in ids],
		pmax_mw       = [round(data["gen"][g]["pmax"] * base; digits = 1) for g in ids],
		used_percent  = [round(100 * result["solution"]["gen"][g]["pg"] / data["gen"][g]["pmax"]; digits = 1) for g in ids],
		cost_per_hour = [round(data["gen"][g]["cost"][1] * result["solution"]["gen"][g]["pg"]; digits = 1) for g in ids],
	)
end

# ╔═╡ 93b0587f-314b-51bb-925b-027b8c2e2dc4
generator_table(case5, result_dc)

# ╔═╡ dcddaef8-565f-5aca-8a74-124ed423506d
md"""
Generator 1 is the cheaper one, so the OPF lets it cover almost all of the demand. Generator 2 only produces its minimum (`pmin_mw` in the table of section 2).

### 4.3 AC line flows and loading

`pf` is the power entering the line at its *from* bus, `pt` at its *to* bus. In the DC approximation `pf = -pt` (no losses).
"""

# ╔═╡ 41c67974-407d-5a04-b3b2-5eb71f86a475
function branch_table(data, result)
	ids = sorted_ids(result["solution"]["branch"])
	base = data["baseMVA"]
	return DF.DataFrame(
		branch          = ids,
		from_bus        = [data["branch"][b]["f_bus"] for b in ids],
		to_bus          = [data["branch"][b]["t_bus"] for b in ids],
		flow_mw         = [round(result["solution"]["branch"][b]["pf"] * base; digits = 1) for b in ids],
		rating_mva      = [round(data["branch"][b]["rate_a"] * base; digits = 1) for b in ids],
		loading_percent = [round(100 * abs(result["solution"]["branch"][b]["pf"]) / data["branch"][b]["rate_a"]; digits = 1) for b in ids],
	)
end

# ╔═╡ bff978dc-9e94-5d81-8d7c-ad8320c1742e
branch_table(case5, result_dc)

# ╔═╡ fe80c112-bb99-5934-b3cd-7b2841cc0a4b
md"""
### 4.4 The DC grid: converters and DC branches

For a converter, `pgrid` is the power it takes **from the AC grid** (positive = rectifier, AC to DC; negative = inverter, DC to AC) and `pdc` is the power it takes from the DC grid. Their sum is the converter loss.
"""

# ╔═╡ fc1f6660-f2e8-5ffa-9fb6-1f5bd0b212f3
function converter_table(data, result)
	ids = sorted_ids(result["solution"]["convdc"])
	base = data["baseMVA"]
	return DF.DataFrame(
		converter     = ids,
		ac_bus        = [data["convdc"][c]["busac_i"] for c in ids],
		dc_bus        = [data["convdc"][c]["busdc_i"] for c in ids],
		p_from_ac_mw  = [round(result["solution"]["convdc"][c]["pgrid"] * base; digits = 1) for c in ids],
		p_from_dc_mw  = [round(result["solution"]["convdc"][c]["pdc"] * base; digits = 1) for c in ids],
		loss_mw       = [round((result["solution"]["convdc"][c]["pgrid"] + result["solution"]["convdc"][c]["pdc"]) * base; digits = 2) for c in ids],
		rating_mw     = [round(data["convdc"][c]["Pacmax"] * base; digits = 1) for c in ids],
	)
end

# ╔═╡ bf85147f-48b6-56d8-9105-faf5ecfb60ab
converter_table(case5, result_dc)

# ╔═╡ 0c2aef1d-dd96-5e8a-926f-9423f62107df
function dc_branch_table(data, result)
	ids = sorted_ids(result["solution"]["branchdc"])
	base = data["baseMVA"]
	return DF.DataFrame(
		dc_branch       = ids,
		from_dc_bus     = [data["branchdc"][b]["fbusdc"] for b in ids],
		to_dc_bus       = [data["branchdc"][b]["tbusdc"] for b in ids],
		flow_mw         = [round(result["solution"]["branchdc"][b]["pf"] * base; digits = 1) for b in ids],
		rating_mw       = [round(data["branchdc"][b]["rateA"] * base; digits = 1) for b in ids],
		loading_percent = [round(100 * abs(result["solution"]["branchdc"][b]["pf"]) / data["branchdc"][b]["rateA"]; digits = 1) for b in ids],
	)
end

# ╔═╡ f62747f5-c58f-5a8c-a940-ee8ed0d8140b
dc_branch_table(case5, result_dc)

# ╔═╡ 49e21171-e064-5370-bce4-df594b4656a8
md"""
### 4.5 A sanity check you should always do: the power balance

Generation must equal demand plus losses. If it does not, you are reading the result wrongly (wrong units, a component you forgot).
"""

# ╔═╡ 408fc802-0696-5ab4-b3e7-87f4cad29f59
function power_balance(data, result)
	base = data["baseMVA"]
	generation = sum(gen["pg"] for (g, gen) in result["solution"]["gen"]) * base
	demand     = sum(load["pd"] for (l, load) in data["load"]) * base
	shed       = sum(get(load, "pcurt", 0.0) for (l, load) in result["solution"]["load"]) * base
	return (generation_mw = round(generation; digits = 2), demand_mw = round(demand; digits = 2), load_shedding_mw = round(shed; digits = 2), losses_mw = round(generation - (demand - shed); digits = 2))
end

# ╔═╡ bf69c878-8466-53ca-a4a3-1337b00e2b3f
power_balance(case5, result_dc)

# ╔═╡ 4ad863b8-64e6-5256-858d-dd1dd6ac2279
md"""
The losses of the DC OPF are only the converter losses from the table in 4.4: the linear model neglects the losses in the AC lines.

## 5. The same case with the full AC equations

Only two arguments change: the formulation (`PM.ACPPowerModel`, the nonlinear AC power-flow equations in polar coordinates) and the solver (Ipopt, because the problem is no longer linear).
"""

# ╔═╡ 45f2f3e5-c54f-5cce-a366-14c6822e4d91
result_ac = PMACDC.solve_acdcopf(case5, PM.ACPPowerModel, ipopt; setting = opf_settings);

# ╔═╡ 94c0b0ea-8541-5bcd-bb88-7128403da0c4
formulation_comparison = DF.DataFrame(
	formulation   = ["DC approximation (DCPPowerModel)", "AC polar (ACPPowerModel)"],
	solver        = ["HiGHS", "Ipopt"],
	status        = [string(result_dc["termination_status"]), string(result_ac["termination_status"])],
	cost_per_hour = [round(result_dc["objective"]; digits = 2), round(result_ac["objective"]; digits = 2)],
	generation_mw = [power_balance(case5, result_dc).generation_mw, power_balance(case5, result_ac).generation_mw],
	losses_mw     = [power_balance(case5, result_dc).losses_mw, power_balance(case5, result_ac).losses_mw],
)

# ╔═╡ b24549db-ed30-555b-a79e-a8e79e712138
md"""
The AC OPF is more expensive because it has to generate the line losses too, and it also has to respect voltage and reactive-power limits. The AC result contains quantities that do not exist in the DC approximation, for example the voltage magnitudes:
"""

# ╔═╡ 9ae7eaeb-303d-57d5-97aa-d7cc90d3db3f
case5_voltages = DF.DataFrame(
	bus          = sorted_ids(result_ac["solution"]["bus"]),
	vm_pu        = [round(result_ac["solution"]["bus"][b]["vm"]; digits = 4) for b in sorted_ids(result_ac["solution"]["bus"])],
	va_degrees   = [round(rad2deg(result_ac["solution"]["bus"][b]["va"]); digits = 2) for b in sorted_ids(result_ac["solution"]["bus"])],
	vmin_pu      = [case5["bus"][b]["vmin"] for b in sorted_ids(result_ac["solution"]["bus"])],
	vmax_pu      = [case5["bus"][b]["vmax"] for b in sorted_ids(result_ac["solution"]["bus"])],
)

# ╔═╡ 65b77f8c-cd7c-5fe8-8380-202d69d36e26
md"""
!!! info "Why Part 2 uses the DC approximation"
    A CBA needs thousands of OPFs on a grid with more than a thousand buses. The linear DC approximation solves each of them in well under a second and always converges to the global optimum, which is why it is the standard choice for this kind of study. The price is that losses and voltage problems are not represented.

## 6. Change the input and solve again

The workflow for any "what if" question is always the same: `deepcopy` the data, change the copy, solve, compare.

Here: what happens if all loads grow by a factor `load_growth`? Change the number and watch the cells below update.
"""

# ╔═╡ c945f0fd-bc00-5dfa-85b5-2a42d26bd86f
load_growth = 1.2

# ╔═╡ ae41ce96-313f-5860-9d4f-cf3974b89840
begin
	case5_more_load = deepcopy(case5)
	for (l, load) in case5_more_load["load"]
		load["pd"] = load["pd"] * load_growth
		load["qd"] = load["qd"] * load_growth
	end
	result_more_load = PMACDC.solve_acdcopf(case5_more_load, PM.DCPPowerModel, highs; setting = opf_settings)
	(status = result_more_load["termination_status"], cost_per_hour = round(result_more_load["objective"]; digits = 2), increase_percent = round(100 * (result_more_load["objective"] / result_dc["objective"] - 1); digits = 1))
end

# ╔═╡ 892e6151-282d-56fc-9edf-2d7129fe5bb3
generator_table(case5_more_load, result_more_load)

# ╔═╡ da54fdbc-85fc-5908-8aaa-26a7a5923c45
md"""
!!! tip "Try it yourself"
    1. Set `load_growth` to `1.5`, then to `3.0`. At which point does the status change, and why?
    2. In a new cell, make a copy of `case5`, set `rate_a` of branch `"1"` to `0.5` (50 MVA) and solve again. Which generator has to produce more? What happens to the cost?
    3. Take converter `"2"` out of service in a copy (`data["convdc"]["2"]["status"] = 0`) and compare the AC line loadings with `branch_table`.

## 7. One OPF on the European grid

EUGO ships a nodal model of the European transmission grid as a PowerModels dictionary in JSON format. `European_grid_no_nseh.json` is the version without the North Sea energy hub. Loading it works exactly like the 5-bus case, with one extra EUGO call that adds the fields PowerModelsACDC needs for flexible demand and phase-shifting transformers.
"""

# ╔═╡ f6975078-5be2-5cd4-ae0b-e7d7abfe171c
begin
	eu_grid = PM.parse_file(joinpath(pkgdir(EUGO), "data_sources", "European_grid_no_nseh.json"))
	PMACDC.process_additional_data!(eu_grid)
	EUGO.add_load_and_pst_properties!(eu_grid)

	eu_size = DF.DataFrame(
		component = ["bus", "gen", "load", "branch", "busdc", "branchdc", "convdc"],
		count     = [length(eu_grid[c]) for c in ["bus", "gen", "load", "branch", "busdc", "branchdc", "convdc"]],
	)
end

# ╔═╡ a179ee9c-546c-550d-a53b-843d6e6b3181
md"""
Compared with the 5-bus case every component carries extra information. The fields you will use most are `zone` (bidding zone), `type` (technology) and, for buses, `lat` and `lon`.
"""

# ╔═╡ ce562c96-9838-5d64-b36c-b4f851274607
(example_generator = eu_grid["gen"]["100"], example_bus = eu_grid["bus"]["100"])

# ╔═╡ c4dc4eca-cf0b-54b2-823d-337156dd61d4
installed_capacity_gw = let
	types = sort(unique([gen["type"] for (g, gen) in eu_grid["gen"]]))
	DF.DataFrame(
		type        = types,
		units       = [count(gen["type"] == t for (g, gen) in eu_grid["gen"]) for t in types],
		capacity_gw = [round(sum(gen["pmax"] for (g, gen) in eu_grid["gen"] if gen["type"] == t) * eu_grid["baseMVA"] / 1000; digits = 1) for t in types],
	)
end

# ╔═╡ cecae9dd-b4be-549a-8070-39507f0260fd
md"""
Now solve one DC OPF for the whole continent. This is the snapshot stored in the file: every generator is available at its installed capacity and every load is at the value in the file. It is not a particular hour of a particular year — hourly demand and wind/solar profiles come in Part 2.

Two extra settings appear: `"objective_components" => ["gen", "demand"]` adds the cost of load shedding to the objective next to the generation cost, and `"fix_cross_border_flows" => false` leaves the flows between countries free.

The solve takes about 20 to 60 seconds.
"""

# ╔═╡ 44f23217-ef9a-5709-81ec-219fed58d549
begin
	eu_settings = Dict(
		"output" => Dict("branch_flows" => true),
		"conv_losses_mp" => true,
		"fix_cross_border_flows" => false,
		"objective_components" => ["gen", "demand"],
	)
	result_eu = PMACDC.solve_acdcopf(eu_grid, PM.DCPPowerModel, highs; setting = eu_settings)
	(status = result_eu["termination_status"], solved = is_solved(result_eu), objective = round(result_eu["objective"]), solve_time_s = round(result_eu["solve_time"]; digits = 1))
end

# ╔═╡ ffd6b71c-111b-589c-a646-ed22c49e7f70
md"""
With more than 7000 generators a table per unit is useless. Aggregate instead, first per technology:
"""

# ╔═╡ 452edcc8-423d-5e09-952c-68761badf122
eu_dispatch_by_type = let
	base = eu_grid["baseMVA"]
	types = sort(unique([gen["type"] for (g, gen) in eu_grid["gen"]]))
	dispatch = [sum(result_eu["solution"]["gen"][g]["pg"] for (g, gen) in eu_grid["gen"] if gen["type"] == t) * base / 1000 for t in types]
	capacity = [sum(gen["pmax"] for (g, gen) in eu_grid["gen"] if gen["type"] == t) * base / 1000 for t in types]
	DF.DataFrame(type = types, dispatch_gw = round.(dispatch; digits = 1), capacity_gw = round.(capacity; digits = 1), used_percent = round.(100 .* dispatch ./ capacity; digits = 1))
end

# ╔═╡ 351b9f23-8c5f-5a5a-97c7-8b2a5eec4230
Plots.bar(
	eu_dispatch_by_type.type,
	[eu_dispatch_by_type.capacity_gw eu_dispatch_by_type.dispatch_gw];
	label = ["installed capacity" "dispatch in this snapshot"],
	ylabel = "GW", xrotation = 30, legend = :topleft, size = (750, 420), left_margin = 6Plots.mm, bottom_margin = 8Plots.mm,
	title = "European grid snapshot: capacity and dispatch by technology",
)

# ╔═╡ 6b2aac56-0b2b-5b59-9e3a-0cf45002c141
md"""
Does the power balance close? The dispatch above adds up to far less than the demand, so something is missing. The European model also contains **storage** units (pumped hydro and reservoirs). In PowerModels `ps` is the power a storage unit takes from the grid, so a negative `ps` is discharging. With storage included the balance closes, up to the converter losses:
"""

# ╔═╡ 9c6968ca-ae01-548b-acca-3e7bf4b7a9a8
eu_power_balance = let
	base = eu_grid["baseMVA"] / 1000
	generation = sum(gen["pg"] for (g, gen) in result_eu["solution"]["gen"]) * base
	storage    = -sum(storage["ps"] for (s, storage) in result_eu["solution"]["storage"]) * base
	demand     = sum(load["pd"] for (l, load) in eu_grid["load"]) * base
	shed       = sum(load["pcurt"] for (l, load) in result_eu["solution"]["load"]) * base
	(generation_gw = round(generation; digits = 1), storage_discharge_gw = round(storage; digits = 1), demand_gw = round(demand; digits = 1), load_shedding_gw = round(shed; digits = 2), remainder_gw = round(generation + storage - (demand - shed); digits = 2))
end

# ╔═╡ b1563f51-018f-5e35-89a9-7348c0aa59d5
md"""
Now per bidding zone. `pcurt` in the load results is the load that could not be served (load shedding). The column `net_export_gw` counts generators only, so zones with a lot of storage look like importers.
"""

# ╔═╡ 9a2f0218-ccea-5a0a-9980-3c67e5f6da46
eu_balance_by_zone = let
	base = eu_grid["baseMVA"]
	zones = sort(unique([load["zone"] for (l, load) in eu_grid["load"]]))
	generation = [sum((result_eu["solution"]["gen"][g]["pg"] for (g, gen) in eu_grid["gen"] if gen["zone"] == z); init = 0.0) * base / 1000 for z in zones]
	demand     = [sum((load["pd"] for (l, load) in eu_grid["load"] if load["zone"] == z); init = 0.0) * base / 1000 for z in zones]
	shed       = [sum((result_eu["solution"]["load"][l]["pcurt"] for (l, load) in eu_grid["load"] if load["zone"] == z); init = 0.0) * base for z in zones]
	table = DF.DataFrame(zone = zones, generation_gw = round.(generation; digits = 1), demand_gw = round.(demand; digits = 1), net_export_gw = round.(generation .- demand; digits = 1), load_shedding_mw = round.(shed; digits = 1))
	sort(table, :demand_gw; rev = true)
end

# ╔═╡ bafa03d7-b154-5bc4-99bf-e9257cea4f41
md"""
Finally the grid itself: how many AC branches are at their limit? These are the congested elements that a new HVDC link could relieve.
"""

# ╔═╡ 44fcd3f6-3bdc-5d63-8774-ae5b8cfc7ecc
eu_congestion = let
	loading = [100 * abs(result_eu["solution"]["branch"][b]["pf"]) / branch["rate_a"] for (b, branch) in eu_grid["branch"] if haskey(result_eu["solution"]["branch"], b) && branch["rate_a"] > 0]
	(branches = length(loading), loaded_above_99_percent = count(loading .> 99), loaded_above_80_percent = count(loading .> 80), median_loading_percent = round(sort(loading)[div(length(loading), 2)]; digits = 1))
end

# ╔═╡ 74a682ff-67af-59a3-b970-bae095a10bbe
let
	loading = [100 * abs(result_eu["solution"]["branch"][b]["pf"]) / branch["rate_a"] for (b, branch) in eu_grid["branch"] if haskey(result_eu["solution"]["branch"], b) && branch["rate_a"] > 0]
	Plots.histogram(loading; bins = 0:5:105, xlabel = "loading (%)", ylabel = "number of AC branches", legend = false, title = "AC branch loading in the European snapshot", size = (750, 380), left_margin = 6Plots.mm, bottom_margin = 6Plots.mm)
end

# ╔═╡ d1ed2006-9318-5f68-a7b8-4cc9bcb7f2b8
md"""
## What you should take away

- A network and an OPF result are both nested dictionaries: `data[component][id][field]`, with string ids and per-unit values.
- One OPF = data + formulation + solver + settings. Everything else is preparing the data and reading the result.
- Check `termination_status` before you read a single number, and check the power balance when you write a new post-processing function.
- For a variant of a network: `deepcopy`, change, solve, compare. A cost-benefit analysis is exactly this, repeated for many hours — that is Part 2.

!!! tip "Exercises before moving on"
    1. Make the table of section 7 for Germany only: dispatch per technology for the generators with `gen["zone"] == "DE"`.
    2. Which five AC branches in zone `"DE"` are the most loaded? (Hint: a bus has a `zone`; a branch has `f_bus` and `t_bus`.)
    3. List the HVDC converters located in Germany with their rating (`Pacmax`) and their power in the snapshot (`pgrid`).
"""

# ╔═╡ Cell order:
# ╟─d14cf719-963b-5ffb-8e6f-ea4f21eaa1b3
# ╠═ef3c7fc7-ccef-5320-b9b0-bc090a09902b
# ╟─e0040758-6919-5aee-b639-19c460e1759a
# ╟─da08ca9f-1a84-52ea-8707-5a560afe71fc
# ╠═6fb2a09d-5d39-518a-972d-264d6f2a2b48
# ╟─83995c0f-b931-52ad-9a56-d6016d0d895e
# ╠═3cc8d2f9-6902-5cbc-afd7-bc3d482cd037
# ╟─6619b8f7-486f-542d-b8b2-b622f616bf07
# ╠═4491f63d-7fb8-588f-bbf9-457ae6465a70
# ╟─991a0df4-930b-529e-88fb-db402c8f3107
# ╠═b51b6b49-4714-5c6c-93c1-0c0bb66472c0
# ╠═cb43b9cc-ad1d-5c8c-a907-1bcf2bae2da0
# ╟─2b6bce34-6971-5c76-aa6b-cb848c3ff227
# ╠═2a807c6f-f9a3-5119-a856-9d187728da5c
# ╟─302e44d5-0fa0-53f7-a0d8-8be021b0aaf4
# ╠═7922d52c-a148-5a93-a900-8004707a1484
# ╟─00c7a91e-9936-5454-8e8e-5b5e2031a98c
# ╠═9595fcaa-beef-5c5f-bd78-212cd8e061f7
# ╠═c98862f5-46fc-5031-92ca-0ffa80d46e42
# ╟─95b68842-6671-5de7-8ba6-4e0d26c7b417
# ╟─eeb01345-cfe9-5df4-9a9f-3e581b588f98
# ╠═6b9dac6a-8b08-526d-938e-8cdd7876f534
# ╟─6db8d2a5-8011-5af6-a307-620ad9ae1b22
# ╠═92993932-386b-52a4-bf1e-a18d5bf1661d
# ╟─20707b0e-8f05-5a90-9bbd-4395dd50f728
# ╠═5bbf8b26-4650-52bb-850a-8e282abbbc9f
# ╠═92b58112-03a6-5b51-a54b-b7a7a963b9d7
# ╟─78bb5b0a-c0f5-552a-9728-8a19736c31cc
# ╠═7b46baaa-7692-5a6b-82c7-b67bd55c1208
# ╠═0c5245b1-e852-5ad5-81c9-f25de720e66f
# ╟─a0cc56aa-5217-5dd4-896a-6e0f4c4e7d04
# ╠═4c7955a8-81c3-58b0-8478-d69a74dfa355
# ╠═d4f7026f-5247-5594-aa13-760c8ddc2ab7
# ╟─5788ae5e-4146-5f8a-a6b0-fb718ccc0c27
# ╠═8872ed4a-01d7-5522-906b-d6f05df386e8
# ╠═93b0587f-314b-51bb-925b-027b8c2e2dc4
# ╟─dcddaef8-565f-5aca-8a74-124ed423506d
# ╠═41c67974-407d-5a04-b3b2-5eb71f86a475
# ╠═bff978dc-9e94-5d81-8d7c-ad8320c1742e
# ╟─fe80c112-bb99-5934-b3cd-7b2841cc0a4b
# ╠═fc1f6660-f2e8-5ffa-9fb6-1f5bd0b212f3
# ╠═bf85147f-48b6-56d8-9105-faf5ecfb60ab
# ╠═0c2aef1d-dd96-5e8a-926f-9423f62107df
# ╠═f62747f5-c58f-5a8c-a940-ee8ed0d8140b
# ╟─49e21171-e064-5370-bce4-df594b4656a8
# ╠═408fc802-0696-5ab4-b3e7-87f4cad29f59
# ╠═bf69c878-8466-53ca-a4a3-1337b00e2b3f
# ╟─4ad863b8-64e6-5256-858d-dd1dd6ac2279
# ╠═45f2f3e5-c54f-5cce-a366-14c6822e4d91
# ╠═94c0b0ea-8541-5bcd-bb88-7128403da0c4
# ╟─b24549db-ed30-555b-a79e-a8e79e712138
# ╠═9ae7eaeb-303d-57d5-97aa-d7cc90d3db3f
# ╟─65b77f8c-cd7c-5fe8-8380-202d69d36e26
# ╠═c945f0fd-bc00-5dfa-85b5-2a42d26bd86f
# ╠═ae41ce96-313f-5860-9d4f-cf3974b89840
# ╠═892e6151-282d-56fc-9edf-2d7129fe5bb3
# ╟─da54fdbc-85fc-5908-8aaa-26a7a5923c45
# ╠═f6975078-5be2-5cd4-ae0b-e7d7abfe171c
# ╟─a179ee9c-546c-550d-a53b-843d6e6b3181
# ╠═ce562c96-9838-5d64-b36c-b4f851274607
# ╠═c4dc4eca-cf0b-54b2-823d-337156dd61d4
# ╟─cecae9dd-b4be-549a-8070-39507f0260fd
# ╠═44f23217-ef9a-5709-81ec-219fed58d549
# ╟─ffd6b71c-111b-589c-a646-ed22c49e7f70
# ╠═452edcc8-423d-5e09-952c-68761badf122
# ╠═351b9f23-8c5f-5a5a-97c7-8b2a5eec4230
# ╟─6b2aac56-0b2b-5b59-9e3a-0cf45002c141
# ╠═9c6968ca-ae01-548b-acca-3e7bf4b7a9a8
# ╟─b1563f51-018f-5e35-89a9-7348c0aa59d5
# ╠═9a2f0218-ccea-5a0a-9980-3c67e5f6da46
# ╟─bafa03d7-b154-5bc4-99bf-e9257cea4f41
# ╠═44fcd3f6-3bdc-5d63-8774-ae5b8cfc7ecc
# ╠═74a682ff-67af-59a3-b970-bae095a10bbe
# ╟─d1ed2006-9318-5f68-a7b8-4cc9bcb7f2b8
