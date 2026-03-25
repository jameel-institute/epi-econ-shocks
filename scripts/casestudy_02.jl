
# Case study using a generic SEIR model (Daedalus)

# This case study shows how to translate epi outcomes from an arbitrary SEIR
# compartmental model of an UNMITIGATED PANDEMIC into economic shocks
# for Nigem and GTAP

# The goal of this cases study is to show 

using CSV
using Daedalus
using DataFrames
using EpiEconShocks

#### Helper function ####
# Note: part of this is internal in Daedalus.Outputs.get_values, but this
# bit is needed here
"""
    sum_over_range(x, range)
Sum `x` elements over bins given in `range`. Assumes zero indexing of `x` which
    is suitable for many epidemiological modelling outputs.
"""
function sum_over_range(x, range)
    x_ = cumsum(x)
    binends = collect(range) .+ 1
    x_ends = x_[binends]

    return [first(x_ends); diff(x_ends)]
end

# get SEIR output

ct = Daedalus.DataLoader.get_country("United Kingdom");
infect = Daedalus.DataLoader.get_pathogen("sars-cov-2 pre-alpha");
QDAYS = 90;
NQS = 8;
time_end = Float64(QDAYS * NQS);
output = daedalus(ct, infect, time_end = time_end);

# get cumulative working-age indivs in compartments
WORKING_STRATA = 5:49;

tsw_asymp = Daedalus.Outputs.get_values(output, "Ia", 90, WORKING_STRATA);
tsw_symp = Daedalus.Outputs.get_values(output, "Is", 90, WORKING_STRATA);
tsw_hosp = Daedalus.Outputs.get_values(output, "H", 90, WORKING_STRATA);
tsw_dead = Daedalus.Outputs.get_values(output, "D", 90, WORKING_STRATA);
tsp_dead = Daedalus.Outputs.get_values(output, "D", 1);

# PARAMETERS SHARED WITH CS 01
N_WORK = sum(ct.workers);
#relative productivity of workers who are mildly symptomatic
A_WFH = 0.28; # mean value of vector in CS 01
A_MILD = 0.50 .* A_WFH;
#relative productivity of workers who are caregiving to mildly symptomatic
A_CARE = 0.50 .* A_WFH;

# school age population
N_SCHC = sum(ct.demography[[1, 2]]);
# employed ratio
EMP_POP = N_WORK / ct.demography[3];
# infection avoidance, mean
PHI_ECO = 0.001;

# CALCULATE AVAILABLE LABOUR and CONSUMPTION
# this case study omits labour lost due to mitigation measures which are
# specific to CS 01
l_aggcum = 1.0 .-
           (((1 .- A_MILD) .* tsw_asymp .+ tsw_symp .+ tsw_hosp .+ tsw_dead) ./
            (N_WORK * QDAYS));

c_aggcum = exp.(-PHI_ECO .* [0.0; diff(tsp_dead)])
c_aggcum = sum_over_range(c_aggcum, QDAYS:QDAYS:Int(time_end)) ./ QDAYS

#### PREPARE SHOCK TIMESERIES FOR NIGEM ####
l_shock = 100.0 .* (l_aggcum .- 1.0)
c_shock = 100.0 .* (c_aggcum .- 1.0)

outdir = "data/outputs/casestudy_02/"
if !isdir(outdir)
    mkdir(outdir)
end

df_shocks = DataFrame(
    quarter = 1:NQS,
    UKE = l_shock, UKC = c_shock);
CSV.write(joinpath(outdir, "cs_02_NIGEM_central.csv"), df_shocks);

#### PREPARE SHOCK VALUES FOR GTAP RUNS ####
# GTAP has no representation of time and should be run with shocks
# representing some new equilibrium
# we choose to run GTAP at the end of the 720 day (8 quarter) period

# WIP
