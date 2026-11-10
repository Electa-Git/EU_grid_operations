# ------------------------------------------------------------------------------------------
# One-time setup for the EUGO student tutorial.
#
# Run from a terminal, inside the folder that contains this file:
#
#     julia setup_environment.jl
#
# What it does:
#   1. creates a Julia environment in the folder `tutorial_env` (next to this file);
#   2. adds your local copy of EU_grid_operations (EUGO) to it in "develop" mode, so that the
#      notebooks use the code and data of your local clone;
#   3. installs the other packages used in the notebooks (PowerModels, PowerModelsACDC, the
#      solvers HiGHS and Ipopt, DataFrames, Plots, Pluto, ...);
#   4. checks that EUGO loads and that the weather-data files needed for Part 2 are present.
#
# The first run downloads and compiles a lot of code: expect 10 to 30 minutes.
#
# By default the script assumes this folder sits inside the EUGO repository
# (EU_grid_operations/tutorial). If your clone is somewhere else, point to it with
#
#     EUGO_PATH="/path/to/EU_grid_operations" julia setup_environment.jl        (macOS / Linux)
#     $env:EUGO_PATH="C:\path\to\EU_grid_operations"; julia setup_environment.jl  (Windows PowerShell)
# ------------------------------------------------------------------------------------------

import Pkg

const TUTORIAL_DIR = @__DIR__
const EUGO_PATH = abspath(get(ENV, "EUGO_PATH", joinpath(TUTORIAL_DIR, "..")))
const ENV_DIR = joinpath(TUTORIAL_DIR, "tutorial_env")

println("Julia version:      ", VERSION)
println("Tutorial folder:    ", TUTORIAL_DIR)
println("EUGO repository:    ", EUGO_PATH)

if !isfile(joinpath(EUGO_PATH, "src", "EU_grid_operations.jl"))
    error("""
    No EU_grid_operations repository found at $EUGO_PATH.
    Clone it first (git clone https://github.com/Electa-Git/EU_grid_operations.git) and either
    put this tutorial folder inside it, or set the environment variable EUGO_PATH (see the top of this file).""")
end

# --- 1-3. environment and packages ---------------------------------------------------------
Pkg.activate(ENV_DIR)
Pkg.develop(path = EUGO_PATH)
Pkg.add([
    "PowerModels", "PowerModelsACDC",   # OPF formulations for AC and AC/DC grids
    "JuMP", "HiGHS", "Ipopt",           # optimisation layer and two open-source solvers
    "DataFrames", "CSV", "JSON",        # tables and file formats
    "Plots",                            # figures
    "Memento",                          # only used to silence the PowerModels log messages
    "Pluto",                            # the notebook environment
])

# --- 4. checks -----------------------------------------------------------------------------
println("\nLoading EU_grid_operations (compiles on first use, this can take several minutes) ...")
try
    @eval import EU_grid_operations
catch err
    println("""

    ------------------------------------------------------------------------------------------
    EU_grid_operations could not be loaded on Julia $VERSION.

    If the messages above mention "Memento" and "Method overwriting is not permitted during
    Module precompilation", your copy of EUGO still restricts Memento to versions <= 1.4, which
    do not precompile on recent Julia versions. Two ways out:
      * update your clone (git pull) once the fix is merged, or
      * open EU_grid_operations/Project.toml and, under [compat], replace the Memento line by
            Memento = "1"
        then run this script again.
    ------------------------------------------------------------------------------------------
    """)
    rethrow(err)
end
println("EU_grid_operations loaded from ", pkgdir(EU_grid_operations))

feather_files = ["PECD-MAF2019-wide-PV.feather", "PECD-MAF2019-wide-WindOnshore.feather", "PECD-MAF2019-wide-WindOffshore.feather"]
missing_files = [f for f in feather_files if !isfile(joinpath(EUGO_PATH, "data_sources", f))]

if isempty(missing_files)
    println("Weather-data files (PECD) found in data_sources: OK")
else
    println("""

    ------------------------------------------------------------------------------------------
    Part 1 is ready to run. For Part 2 you still need the wind and solar time series (PECD,
    about 350 MB in total). They are not stored in the git repository. Missing:
    """)
    for f in missing_files
        println("      ", f)
    end
    println("""
    Download them from Zenodo (links also listed in data_sources/download_links.txt):
      https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-PV.feather?download=1
      https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-WindOnshore.feather?download=1
      https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-WindOffshore.feather?download=1
    and save them, with exactly these file names, in
      $(joinpath(EUGO_PATH, "data_sources"))
    ------------------------------------------------------------------------------------------""")
end

println("""

Setup finished. To open the notebooks, run in this folder:

    julia --project=tutorial_env -e "import Pluto; Pluto.run()"

Your browser opens the Pluto start page. Under "Open a notebook", paste the path of
    $(joinpath(TUTORIAL_DIR, "01_julia_basics_and_first_opf.jl"))
and press Enter.
""")
