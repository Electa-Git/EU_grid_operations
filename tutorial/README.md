# EUGO student tutorial: from a first OPF to a CBA of HVDC links

Two Pluto notebooks for someone who is new to Julia and to `EU_grid_operations.jl` (EUGO).

| File | What it covers | Run time |
|:--|:--|:--|
| `01_julia_basics_and_first_opf.jl` | Julia basics (vectors, functions, dictionaries, DataFrames); one OPF on the 5-bus AC/DC test case and how to read the result; DC versus AC formulation; one OPF on the full European grid | about 2 minutes |
| `02_hvdc_cba_with_eugo.jl` | CBA of HVDC links in the German grid: zonal TYNDP model, nodal model of Germany, adding the three links EUGO knows and your own link, hourly OPFs with and without the links, benefit indicators, annualisation and NPV, interconnectors in the zonal model | about 3 minutes for 24 hours |
| `setup_environment.jl` | one-time installation of all packages into `tutorial_env` | 10 to 30 minutes, once |

The notebooks build on `tutorials/opf.jl` and `tutorials/cba_german_hvdc.jl` in PowerModelsACDC.jl.

## Setup, step by step

1. **Install Julia** with `juliaup` (https://julialang.org/install). See "Julia version" below.
2. **Clone EUGO**:
   ```
   git clone https://github.com/Electa-Git/EU_grid_operations.git
   ```
   This folder (`tutorial`) belongs inside the clone. If you keep it somewhere else, set the environment variable `EUGO_PATH` as described at the top of `setup_environment.jl`.
3. **Download the weather data** (needed for Part 2 only, about 350 MB). The three PECD files are not in the git repository. Download them and put them, with unchanged names, in `EU_grid_operations/data_sources`:
   - https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-PV.feather?download=1
   - https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-WindOnshore.feather?download=1
   - https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-WindOffshore.feather?download=1
4. **Install the packages.** Open a terminal in this folder and run
   ```
   julia setup_environment.jl
   ```
5. **Start Pluto**:
   ```
   julia --project=tutorial_env -e "import Pluto; Pluto.run()"
   ```
   A browser tab opens. Under "Open a notebook", paste the full path of `01_julia_basics_and_first_opf.jl` and press Enter. The notebook runs all cells when it opens; the first time this takes a few minutes because the packages compile.

Work through Part 1 first, including the exercises, then open Part 2.

## Julia version

| Julia | EUGO `main` (July 2026) |
|:--|:--|
| 1.12 | installs and loads as is |
| 1.13 | fails to precompile: `Project.toml` restricts Memento to 1.4 or older, which does not precompile on 1.13. Changing the `[compat]` entry to `Memento = "1"` fixes it |
| 1.10 (LTS) | does not install: `Project.toml` requires `Statistics` 1.11 |

`setup_environment.jl` prints the Memento fix if it runs into that error.

## Things that go wrong

- **"Missing file data_sources/PECD-..."** in Part 2: step 3 was skipped, or the files were renamed by the browser.
- **A cell shows "Multiple definitions for x"**: in Pluto a variable can be defined in one cell only. Rename the variable in your new cell.
- **`PMACDC.parse_file` is not defined**: that function exists from PowerModelsACDC 0.10.1 on. EUGO currently pins the environment to 0.10.0, so the notebooks use `PM.parse_file` followed by `PMACDC.process_additional_data!`, which is the same thing.
- **Hours with status `INFEASIBLE` in Part 2**: they are excluded from all sums. See the notes in sections 6, 7.1 and 11 of the notebook.
- **Everything is slow the first time**: Julia compiles code on first use. The second run of the same cell is fast.

## Working without Pluto

A Pluto notebook is a plain Julia file. Once you are comfortable you can run it as a script,

```
julia --project=tutorial_env 02_hvdc_cba_with_eugo.jl
```

or copy the cells you need into your own script and run them line by line in VS Code with the Julia extension. For runs of a full year this is the better way of working.
