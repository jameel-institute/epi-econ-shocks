#PACKAGES USED
using CSV
using XLSX
using DataFrames
using Dates
using StatsBase
using Random
using Trapz
using EpiEconShocks
using Distributions


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
#unemployment rate in 2025 Q4 (https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/employmentandemployeetypes/datasets/summaryoflabourmarketstatistics)
P_UNEM = 0.052;

#furloughed workforce by sector at any time 2020-2021 (https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/employmentandemployeetypes/datasets/characteristicsofpeoplewhohavebeenfurloughedintheuk) 
P_FURL = [0.134, 0.209, 0.357, 0.209, 0.209, 0.397, 0.382, 0.216, 0.692, 0.216,
    0.232, 0.232, 0.232, 0.232, 0.069, 0.174, 0.117, 0.556, 0.345, 0.345]';

#population of school-children
N_SCHC = sum(N_AGE[1:3]);
#ratio of population of workforce to adults
EMP_POP = sum(N_WORK) / sum(N_AGE[5:end]);

#home-working workforce by sector in 2023 (https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/employmentandemployeetypes/articles/whoarethehybridworkers/2024-11-11)
A_WFH = [0.154, 0.154, 0.154, 0.154, 0.154, 0.14, 0.198, 0.112, 0.061, 0.769,
    0.769, 0.4, 0.604, 0.273, 0.273, 0.472, 0.2, 0.193, 0.098, 0.098]';

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
datadir = "data/raw/casestudy_01";
df_tsdp = CSV.read(joinpath(datadir, "tsdp.csv"), DataFrame);
df_tsdw = CSV.read(joinpath(datadir, "tsdw.csv"), DataFrame);
df_tsdc = CSV.read(joinpath(datadir, "tsdc.csv"), DataFrame);

filter!(:date => x -> SIM_BEG <= x <= SIM_END, df_tsdp);
filter!(:date => x -> SIM_BEG <= x <= SIM_END, df_tsdw);
filter!(:date => x -> SIM_BEG <= x <= SIM_END, df_tsdc);


# DEFINE ECON SHOCKS
t = Dates.value.(df_tsdp.date);

function compute_avl(P_FURL, A_WFH, PHI_ECO)

    #relative productivity of workers who are mildly symptomatic
    A_MILD = 0.50 .* A_WFH;
    #relative productivity of workers who are caregiving to mildly symptomatic
    A_CARE = 0.50 .* A_WFH;

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

    l_avlcum = trapz(t, l_avl')' ./ (t[end] - t[1]);
    c_avlcum = trapz(t, c_avl')' ./ (t[end] - t[1]);

    return l_avlcum, c_avlcum
end

#distribution 
nsamples  = 1000;
l_avldist = zeros(nsamples, length(N_WORK));
c_avldist = zeros(nsamples, length(N_WORK));

for i = 1:nsamples;
    rv_furl = rand(Uniform(0.5, 1.0));
    rv_wfh  = rand(Gamma(30, 1/30));
    rv_phi  = rand(Gamma(30, 0.0075/30));

    l_avlcum, c_avlcum = compute_avl(rv_furl .* P_FURL, min.(rv_wfh .* A_WFH, 1.0), rv_phi .* PHI_ECO ./ 0.01);

    l_avldist[i, :] = l_avlcum;
    c_avldist[i, :] = c_avlcum;
end


# NIGEM: AGGREGATE AND SAVE SHOCKS 
l_avlagg = sum(l_avldist .* (N_WORK ./ sum(N_WORK)), dims = 2);
c_avlagg = sum(c_avldist .* (E_HHC ./ sum(E_HHC)), dims = 2);

l_avlagg = l_avlagg .* (1 - P_UNEM);

l_shock  = 100 .* (l_avlagg .- 1);
c_shock  = 100 .* (c_avlagg .- 1);

#write dataframe of outputs
outdir    = "data/outputs/casestudy_01/"
df_shocks = DataFrame(quarter     = collect(1:size(l_shock,2)), 
                      UKLFWA_pess = quantile(l_shock, [0.025]), 
                      UKLFWA_cent = quantile(l_shock, [0.500]), 
                      UKLFWA_opti = quantile(l_shock, [0.975]), 
                      UKC_pess    = quantile(c_shock, [0.025]), 
                      UKC_cent    = quantile(c_shock, [0.500]), 
                      UKC_opti    = quantile(c_shock, [0.975]));
CSV.write(joinpath(outdir, "NIGEM.csv"), df_shocks);


# PLOTTING: SAVE SHOCKS
#write dataframe of schocks over time
A_MILD = 0.50 .* A_WFH;
A_CARE = 0.50 .* A_WFH;
l_notill = 1 .- (((1 .- A_MILD) .* df_tsdw.prev_mldi .+ df_tsdw.prev_sevi .+
            df_tsdw.occupancy_hosp .+ df_tsdw.deaths) ./ sum(N_WORK));
l_notcar = 1 .-
        EMP_POP .* (((1 .- A_CARE) .* df_tsdc.prev_mldi .+ df_tsdc.prev_sevi .+
            df_tsdc.occupancy_hosp) ./ sum(N_WORK));
l_notecl = 1 .- 0.75.*P_FURL .* (closure_date_02 .<= df_tsdw.date .<= SIM_END);
l_notscl = 1 .-
        EMP_POP .* (1 .- A_WFH) .* (N_SCHC ./ sum(N_WORK)) .*
        (closure_date_01 .<= df_tsdc.date .<= SIM_END);

l_avl = l_notill .* l_notcar .* l_notecl .* l_notscl;
c_avl = exp.((-0.0075 .* PHI_ECO ./ 0.01) .* [0; diff(df_tsdp.deaths)]);

l_avlaggt = sum(l_avl .* (N_WORK ./ sum(N_WORK)), dims = 2);
c_avlaggt = c_avl[:,7];

df_times = DataFrame(times     = Date.(Dates.UTD.(t)),
                     wf_pcred  = vec(100 .* (l_avlaggt .- 1)),
                     ccf_pcred = 100 .* (c_avlaggt .- 1));
CSV.write(joinpath(outdir, "shock_times.csv"), df_times);

#write dataframe of shock samples
df_samples = DataFrame(samples    = 1:nsamples,
                       wf_pcred   = vec(100 .* (sum(l_avldist .* (N_WORK ./ sum(N_WORK)), dims = 2) .- 1)),
                       ccf_pcred  = 100 .* (c_avldist[:,7] .- 1),
                       lf_pcred   = vec(l_shock),
                       cagg_pcred = vec(c_shock)); 
CSV.write(joinpath(outdir, "shock_samples.csv"), df_samples);


# GTAP: RUN BASELINE AND IMPOSE SHOCKS
#generate initial model from GTAP 11 data in `data/raw/gtap11`
datadir_gtap = "data/raw/gtap11/";
model        = EpiEconShocks.ModelInit.initial_gtap_model(datadir_gtap);

#note: this needs to be explained better and generalised if possible
W = zeros(20, 10);
G = ([1,2],[3],[4,5],[6],[7],[8],[9],[10,11,12,13,14],[15,16,17],[18,19,20]);

for (i,g) in enumerate(G);
    W[g,i] = E_HHC[g] ./ sum(E_HHC[g]);
end

l_avlagg = sum(l_avldist .* (N_WORK ./ sum(N_WORK)), dims = 2);
c_avlagg = c_avldist * W;

#define wrapper function for shocks
function run_gtap(l_shock, c_shock)

    #labour shock affects all regions and sectors equally
    labour_shock      = ParameterShock("qe",  ["skilled labour", "unskilled labour"], l_shock);
    consumption_shock = ParameterShock("qpa", ["allprimary", "manufac", "utilities", "constr", "retail", 
                                               "transport", "hosp", "ict_prof_serv", "pubadm", "arts_rec_other"], c_shock);

    #run model after passing shocks
    output = shock_gtap(model, [labour_shock, consumption_shock]);

    return output
end

#run GTAP model with shocks for same scenarios as NIGEM
output_pess = run_gtap(quantile(l_avlagg, [0.025]),
                       quantile.(eachcol(c_avlagg), 0.025));
output_cent = run_gtap(quantile(l_avlagg, [0.500]),
                       quantile.(eachcol(c_avlagg), 0.500));
output_opti = run_gtap(quantile(l_avlagg, [0.975]),
                       quantile.(eachcol(c_avlagg), 0.975));

#distribution of outcomes
n_iter = 100;
gdpl   = zeros(n_iter,1);

for i in 1:n_iter;
    l_shock = rand(l_avlagg);
    c_shock = rand.(eachcol(c_avlagg));

    output  = run_gtap(l_shock, c_shock);
    gdpl[i] = - output.delta_gdp[9] * 100;
end

df_gpdl = DataFrame(gdpl = gdpl);
CSV.write(joinpath(outdir, "GTAP.csv"), df_gpdl);