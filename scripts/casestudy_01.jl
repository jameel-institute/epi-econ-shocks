#TO DO:
#parametrisation
#sectoral disaggregation
#avoidant behaviour

#PACKAGES USED
using CSV
using DataFrames
using Dates
using EpiEconShocks
using StatsBase
using Trapz

# READ IN DATA
datadir = "data/raw/casestudy_01"
df_tsdp = CSV.read(joinpath(datadir, "tsdp.csv"), DataFrame);
df_tsdw = CSV.read(joinpath(datadir, "tsdw.csv"), DataFrame);
df_tsdc = CSV.read(joinpath(datadir, "tsdc.csv"), DataFrame);

SIM_END = Date(2025, 11, 25); #end of exercise
SIM_BEG = SIM_END - Day(90);

filter!(:date => x -> SIM_BEG < x <= SIM_END, df_tsdp);
filter!(:date => x -> SIM_BEG < x <= SIM_END, df_tsdw);
filter!(:date => x -> SIM_BEG < x <= SIM_END, df_tsdc);

# PARAMETERS
N_TOT = 67e6; #total population
N_WORK = 30e6; #total workforce
N_NESS = 20e6; #non-essential workforce
N_SCHC = 0.172 * 67e6; #total school-children
EMP_POP = 0.75; #ratio of workforce to adult-population
A_MILD = 0.50; #relative productivity of mildly symptomatic
A_CAR = 0.50; #relative productivity of caregiving adults
PHI_ECO = 0.01 * 19216182.0 / N_TOT; #fitted value from Pangollo but rescaled from NY Metro to UK population

# CLOSURE change or application dates
closure_date_01 = Date(2025, 10, 10)
closure_date_02 = Date(2025, 10, 31)
closure_date_03 = Date(2025, 11, 25)

# DEFINE DAILY SHOCKS
l_notill = (N_WORK .- ((1 .- A_MILD) .* df_tsdw.prev_mldi .+ df_tsdw.prev_sevi .+
             df_tsdw.occupancy_hosp .+ df_tsdw.deaths)) ./ N_WORK;

l_notcar = (N_WORK .-
            (1 .- A_CAR) .* EMP_POP .*
            (df_tsdc.prev_mldi .+ df_tsdc.prev_sevi .+ df_tsdc.occupancy_hosp)) ./ N_WORK;

l_notecl = (N_WORK .-
            N_NESS .*
            (closure_date_02 .<= df_tsdw.date .< closure_date_03)
) ./ N_WORK;

l_notscl = (N_WORK .-
            (1 .- A_CAR) .* EMP_POP .* N_SCHC .*
            ((df_tsdc.date .≥ closure_date_01) .-
             (df_tsdc.date .≥ closure_date_03))) ./ N_WORK;

l_avl = l_notill .* l_notcar .* l_notecl .* l_notscl;

l_shock = 1 .- l_avl;

c_shock = 1 .- exp.(-PHI_ECO .* [0; diff(df_tsdp.deaths)]);

# NOTE: L.66 and L.69 not really necessary as we need available labour
# and realised consumption
df_shocks = DataFrame(
    date = Dates.value.(df_tsdp.date), l_shock = l_shock, c_shock = c_shock);

# CALCULATE OUTPUT
vec_shocks = [
    trapz(df_shocks.date, df_shocks.l_shock),
    trapz(df_shocks.date, df_shocks.c_shock)] ./
             (df_shocks.date[end] - (df_shocks.date[1] - 1.0));

# TRANSLATE TO SCALING FACTORS
vec_scaling = 1.0 .- vec_shocks;
labour_scaling = vec_scaling[1];
consumption_scaling = vec_scaling[end];

hosp_leisure_scaling = 0.75 # assumption of reduced travel and leisure

# DEFINE PARAM SHOCKS FOR EPIECONSHOCKS
# NOTE: ASSUMPTION: labour shock affects all regions and labour sectors equally
labour_shock = ParameterShock(
    "qe", ["skilled labour", "unskilled labour"], labour_scaling
);
consumption_shock = ParameterShock(
    "qpa", ["svces", "tpt_hosp_leis"], [consumption_scaling, hosp_leisure_scaling]
);

# assume decreased imports
comm_import_scaling = [0.8, 0.75, 0.9] # scale separately for each sector
comm_supply_shock = ParameterShock(
    "qms", ["extract", "manuf", "processed food"], comm_import_scaling
)

# GENERATE INITIAL MODEL FROM GTAP 11 data in `data/raw/gtap11`
datadir_gtap = "data/raw/gtap11/"
model = EpiEconShocks.ModelInit.initial_gtap_model(datadir_gtap);

# RUN MODEL AFTER PASSING SHOCKS
output = shock_gtap(model, [labour_shock, consumption_shock]);

# GET CHANGE IN GDP BETWEEN EQUILIBRIA
output.delta_gdp
