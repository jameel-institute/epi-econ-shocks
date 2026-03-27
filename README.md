
[![Project Status: Concept – Minimal or no implementation has been done yet, or the repository is only intended to be a limited example, demo, or proof-of-concept.](https://www.repostatus.org/badges/latest/concept.svg)](https://www.repostatus.org/#concept)

# Translate epidemic shocks into economic and trade outcomes

This is the source code for a project to translate epidemic morbidity and mortality outcomes into shocks that can be passed to two widely used macroeconomic models, NiGEM and GTAP.

## Contact and attribution

This section holds contact data for this project.

## Workflow

This is a project written in Julia.
Please install a current version of Julia, and from the terminal, run the selected script.

```sh
# specify project dir if not already in this dir
# substitute the correct script name as required
julia --project ./scripts/SCRIPT_NAME.jl
```

This is should generate outputs in `data/outputs/`.

## Data

Data informing case study 1, and data acquired under license from GTAP, cannot be shared in this repository.

Publicly available data used to inform this project is stored under `data/raw/`.

## Report, manuscript, or other documentation

This section will list any related long-form documentation.

## Further reading

This project uses the following packages developed at the Jameel Institute:

- [_Daedalus.jl_](https://github.com/jameel-institute/Daedalus.jl), a Julia version of the integrated epidemiological-economic model provided in the R package _daedalus_.
- [_EpiEconShocks.jl_](https://jameel-institute.github.io/EpiEconShocks.jl/dev/), a helper package developed to pass shocks to the GTAP model.

This project also uses [_GlobalTradeAnalysisProjectv7.jl_](https://mivanic.github.io/GlobalTradeAnalysisProjectModelV7.jl/dev/), part of the GTAP project.
