#TO DO:
#harmonise GTAP sectoral disaggregation and check . in function call
#avoidant behaviour
#data and parameter uncertainty
#what scaling for N_ess
#what is it? income via consumption in pangollo

#PACKAGES USED
using CSV
using XLSX
using DataFrames
using Dates
using StatsBase
using Trapz
using EpiEconShocks

# PARAMETERS
#population by age in 2024 scaled to total population (https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/populationestimatesforukenglandandwalesscotlandandnorthernireland)
N_TOT = 66930425; #total population (via email)
N_AGE = [3574156, 3978857, 4204852, 4126585, 4166255,
    4548970, 4796627, 4775770, 4529122, 4093384,
    4420093, 4616723, 4288377, 3572657, 3096754, 2901851, 1840390, 1124778, 625236] .*
        (N_TOT ./ 69281437);

#workforce by sector in 2024 scaled to total population (https://data-explorer.oecd.org/vis?df[ds]=DisseminateFinalDMZ&df[id]=DSD_NAMAIN10%40DF_TABLE7&df[ag]=OECD.SDD.NAD&dq=A.AUT...EMP....PS...&lom=LASTNPERIODS&lo=5&to[TIME_PERIOD]=false)
N_WORK = [
    358891, 53525, 2445007, 131789, 201530, 2141882, 4532352, 1644253, 2412496, 1492821,
    1110370, 629758, 2975812, 2734434, 1567856, 2723349, 4545941, 963524, 889977, 57176]' .*
         (N_TOT ./ 69281437);

#furloughed workforce by sector (https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/employmentandemployeetypes/datasets/characteristicsofpeoplewhohavebeenfurloughedintheuk) 
P_FURL = [0.134, 0.209, 0.357, 0.209, 0.209, 0.397, 0.382, 0.216, 0.692, 0.216,
    0.232, 0.232, 0.232, 0.232, 0.069, 0.174, 0.117, 0.556, 0.345, 0.345]';

#population of school-children
N_SCHC = sum(N_AGE[1:3]);
#ratio of population of workforce to adults
EMP_POP = sum(N_WORK) / sum(N_AGE[5:end]);

#home-working workforce by sector in 2023 (https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/employmentandemployeetypes/articles/whoarethehybridworkers/2024-11-11)
A_WFH = [0.154, 0.154, 0.154, 0.154, 0.154, 0.14, 0.198, 0.112, 0.061, 0.769,
    0.769, 0.4, 0.604, 0.273, 0.273, 0.472, 0.2, 0.193, 0.098, 0.098]';

#relative productivity of workers who are mildly symptomatic
A_MILD = 0.50 .* A_WFH;
#relative productivity of workers who are caregiving to mildly symptomatic
A_CARE = 0.50 .* A_WFH;

#household consumption expenditure by sector in 2022 (https://www.oecd.org/en/data/datasets/input-output-tables.html)
E_HHC = [28978.715, 4717.879, 360055.722, 55604.819, 17992.213,
    7976.728, 231374.941, 43813.051, 82393.223, 70985.688,
    113279.043, 373852.584, 16552.634, 41389.457, 10245.339,
    56213.19, 48317.408, 40611.289, 44670.928, 2893.169]';

#infection avoidance by sector from Pangollo scaled from population of NY Metro to UK           
PHI_ECO = 0.01 * (19216182.0 / N_TOT) .*
          [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0]';

# SIMULATION AND CLOSURE DATES
SIM_END = Date(2025, 11, 25); #end of exercise
SIM_BEG = SIM_END - Day(90);

closure_date_01 = Date(2025, 10, 10);
closure_date_02 = Date(2025, 10, 31);

# READ IN EPI DATA
datadir = "data/raw/casestudy_01"
df_tsdp = CSV.read(joinpath(datadir, "tsdp.csv"), DataFrame);
df_tsdw = CSV.read(joinpath(datadir, "tsdw.csv"), DataFrame);
df_tsdc = CSV.read(joinpath(datadir, "tsdc.csv"), DataFrame);

filter!(:date => x -> SIM_BEG <= x <= SIM_END, df_tsdp);
filter!(:date => x -> SIM_BEG <= x <= SIM_END, df_tsdw);
filter!(:date => x -> SIM_BEG <= x <= SIM_END, df_tsdc);

# DEFINE DISAGGREGATED ECON SHOCKS
t = Dates.value.(df_tsdp.date);

l_notill = 1 .- (((1 .- A_MILD) .* df_tsdw.prev_mldi .+ df_tsdw.prev_sevi .+
             df_tsdw.occupancy_hosp .+ df_tsdw.deaths) ./ sum(N_WORK));
l_notcar = 1 .-
           EMP_POP .* (((1 .- A_CARE) .* df_tsdc.prev_mldi .+ df_tsdc.prev_sevi .+
             df_tsdc.occupancy_hosp) ./ sum(N_WORK));
l_notecl = 1 .- P_FURL .* (closure_date_02 .<= df_tsdw.date .<= SIM_END);
l_notscl = 1 .-
           EMP_POP .* (1 .- A_WFH) .* (N_SCHC ./ sum(N_WORK)) .*
           (closure_date_01 .<= df_tsdc.date .<= SIM_END);

l_avl = l_notill .* l_notcar .* l_notecl .* l_notscl;
c_avl = exp.(-PHI_ECO .* [0; diff(df_tsdp.deaths)]);

# AGGREGATE SHOCKS FOR NIGEM
l_agg = sum(l_avl .* (N_WORK ./ sum(N_WORK)), dims = 2);
c_agg = sum(c_avl .* (E_HHC ./ sum(E_HHC)), dims = 2);

l_aggcum = trapz(t, l_agg') / (t[end] - (t[1] - 1.0));
c_aggcum = trapz(t, c_agg') / (t[end] - (t[1] - 1.0));

l_shock = 100 .* (l_aggcum .- 1);
c_shock = 100 .* (c_aggcum .- 1);

# WRITE DATAFRAME OF OUTPUTS
outdir = "data/outputs/casestudy_01/"
df_shocks = DataFrame(quarter = collect(1:length(l_shock)), UKE = l_shock, UKC = c_shock);
CSV.write(joinpath(outdir, "NIGEM_central.csv"), df_shocks);

# AGGREGATE SHOCKS FOR GTAP
# NOTE: this needs to be explained better and generalised if possible
W = zeros(20, 7);
W[CartesianIndex.([1, 1, 2, 3, 3], [1, 2, 3, 4, 5])] .= 1;
W[[4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17], 6] = E_HHC[[
    4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17]] ./ sum(E_HHC[[
    4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17]]);
W[[8, 9, 18, 19, 20], 7] = E_HHC[[8, 9, 18, 19, 20]] ./ sum(E_HHC[[8, 9, 18, 19, 20]]);

l_agg = sum(l_avl .* (N_WORK ./ sum(N_WORK)), dims = 2);
c_agg = c_avl * W;

l_aggcum = first(trapz(t, l_agg') / (t[end] - (t[1] - 1.0))); # get float from vec
c_aggcum = trapz(t, c_agg') / (t[end] - (t[1] - 1.0));

# DEFINE PARAMETER SHOCKS FOR EPIECONSHOCKS.JL
#labour shock affects all regions and sectors equally
labour_shock = ParameterShock(
    "qe", ["skilled labour", "unskilled labour"], l_aggcum);
consumption_shock = ParameterShock("qpa",
    ["crops", "animals", "extract", "processed food",
        "manuf", "svces", "tpt_hosp_leis"],
    c_aggcum);

# GENERATE INITIAL MODEL FROM GTAP 11 data in `data/raw/gtap11`
datadir_gtap = "data/raw/gtap11/";
model = EpiEconShocks.ModelInit.initial_gtap_model(datadir_gtap);

# RUN MODEL AFTER PASSING SHOCKS
output = shock_gtap(model, [labour_shock, consumption_shock]);

# GET CHANGE IN GDP BETWEEN EQUILIBRIA
output.delta_gdp
