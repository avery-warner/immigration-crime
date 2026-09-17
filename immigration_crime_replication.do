
* ============================================================
* Crime and Immigration Enforcement
* ============================================================
* Authors: Avery Warner and Michael Light
* Date last updated: September 17, 2026
* ============================================================

* ============================================================
* Cleans individual datasets from raw data sources, combines data into relevant data files for analysis, and produces figures. 
* Data sources: ICE arrests, CBP border apprehensions, ICE arrest conviction rates, Crime Index (July 2026)
* ============================================================

* Uncomment and set global directories to read in and save data 
*global data     ""
*global clean    ""
*global figures  ""


* ============================================================
* 1. Border Encounters 
* Source: Customs and Border Protections: 
* https://www.cbp.gov/sites/default/files/2026-08/nationwide-encounters-fy23-fy26-jul-aor.csv
* ============================================================

import delimited "$data/cpb_encounters_fy23_fy26_jul.csv", clear

* Keep Only Southern Border Encounters
keep if landborderregion=="Southwest Land Border"

* Keep only Expulsions and Apprehensions
drop if encountertype=="Inadmissibles"

* Recode Fiscal Year to Calendar Year
gen fy=0
replace fy=2023 if fiscalyear=="2023"
replace fy=2024 if fiscalyear=="2024"

replace fy=2025 if fiscalyear=="2025"
replace fy=2026 if fiscalyear=="2026 (FYTD)"

gen fy_month=0

replace fy_month=1 if monthabbv=="OCT"
replace fy_month=2 if monthabbv=="NOV"
replace fy_month=3 if monthabbv=="DEC"
replace fy_month=4 if monthabbv=="JAN"
replace fy_month=5 if monthabbv=="FEB"
replace fy_month=6 if monthabbv=="MAR"
replace fy_month=7 if monthabbv=="APR"
replace fy_month=8 if monthabbv=="MAY"
replace fy_month=9 if monthabbv=="JUN"
replace fy_month=10 if monthabbv=="JUL"
replace fy_month=11 if monthabbv=="AUG"
replace fy_month=12 if monthabbv=="SEP"

gen cal_month = mod(fy_month + 8, 12) + 1
gen cal_year = fy
replace cal_year = fy - 1 if fy_month <= 3

* Create Encounter Count
bysort cal_year cal_month: egen encounters = sum(encountercount)

* Collapse Dataset
collapse encounters, by(cal_year cal_month)

* Create month-year variable 
gen month_year = ym(cal_year, cal_month)
format %tmMon_CCYY month_year
drop cal_year cal_month

* Save border encounter dataset
save "$clean/border_encounters.dta", replace


* ============================================================
* 2. ICE Arrests  - national-month level 
* Source: Deportation Data Project
* https://deportationdata.org/index.html
* ICE arrests, summarized by time: by month, location: nationwide 
* ============================================================

* Upload national and state ICE arrests separately, as some arrests have missing measures on state 

import excel "$data/ice_arrests_national_09_17_2026.xlsx", sheet("data") firstrow clear

rename n ice_arrests 

* Correct time measure 
gen month_year = mofd(bucket)
format %tmMon_CCYY month_year
drop bucket

* Drop incomplete final month
tsset month_year
drop if month_year == tm(2026m8)

* Save national ice arrest dataset 
save "$clean/ice_arrests_national.dta", replace

* ============================================================
* 3. ICE Arrests - state-month level 
* Source: Deportation Data Project
* https://deportationdata.org/index.html
* ICE arrests, summarized by time: by month, location: by state 
* ============================================================

import excel "$data/ice_arrests_state_09_17_2026.xlsx", sheet("data") firstrow clear

rename n ice_arrests 
rename apprehension_state_filled_in state_name

* Correct time measure 
gen month_year = mofd(bucket)
format %tmMon_CCYY month_year
drop bucket

* Drop missing state measures 
drop if state_fips == ""

* Drop U.S. territories 
drop if inlist(state_fips, "66", "69", "72", "78")

* Crosswalk apprehension state name with abbreviations 
preserve
clear
input str30 state_name str2 state
"ALABAMA" "AL"
"ALASKA" "AK"
"ARIZONA" "AZ"
"ARKANSAS" "AR"
"CALIFORNIA" "CA"
"COLORADO" "CO"
"CONNECTICUT" "CT"
"DELAWARE" "DE"
"DISTRICT OF COLUMBIA" "DC"
"FLORIDA" "FL"
"GEORGIA" "GA"
"HAWAII" "HI"
"IDAHO" "ID"
"ILLINOIS" "IL"
"INDIANA" "IN"
"IOWA" "IA"
"KANSAS" "KS"
"KENTUCKY" "KY"
"LOUISIANA" "LA"
"MAINE" "ME"
"MARYLAND" "MD"
"MASSACHUSETTS" "MA"
"MICHIGAN" "MI"
"MINNESOTA" "MN"
"MISSISSIPPI" "MS"
"MISSOURI" "MO"
"MONTANA" "MT"
"NEBRASKA" "NE"
"NEVADA" "NV"
"NEW HAMPSHIRE" "NH"
"NEW JERSEY" "NJ"
"NEW MEXICO" "NM"
"NEW YORK" "NY"
"NORTH CAROLINA" "NC"
"NORTH DAKOTA" "ND"
"OHIO" "OH"
"OKLAHOMA" "OK"
"OREGON" "OR"
"PENNSYLVANIA" "PA"
"RHODE ISLAND" "RI"
"SOUTH CAROLINA" "SC"
"SOUTH DAKOTA" "SD"
"TENNESSEE" "TN"
"TEXAS" "TX"
"UTAH" "UT"
"VERMONT" "VT"
"VIRGINIA" "VA"
"WASHINGTON" "WA"
"WEST VIRGINIA" "WV"
"WISCONSIN" "WI"
"WYOMING" "WY"
end
tempfile crosswalk
save `crosswalk'
restore

merge m:1 state_name using `crosswalk'
tab _merge
drop _merge

* Drop incomplete final month
drop if month_year == tm(2026m8)

* Save state-month ICE arrest dataset 
save "$clean/ice_arrests_state.dta", replace


* ============================================================
* 4. ICE Arrests - apprehension criminality 
* Source: Deportation Data Project
* https://deportationdata.org/index.html
* ICE arrests, summarized by time: by month, location: nationwide, category: by apprehension criminality
* ============================================================

import excel "$data/ice_arrests_convicted_09_17_2026.xlsx", sheet("data") firstrow clear

* Keep percent of arrests that are convicted criminals 
keep if apprehension_criminality == "1 Convicted Criminal"
drop apprehension_criminality

* Correct time measure 
gen month_year = mofd(bucket)
format %tmMon_CCYY month_year
drop bucket

rename n pct_convicted

* Drop incomplete final month
tsset month_year
drop if month_year == tm(2026m8)

* Save ICE arrest percent convicted dataset 
save "$clean/ice_arrests_pct_convicted.dta", replace


* ============================================================
* 5. CRIME INDEX DATA (national aggregates and state-month panels, July 2026 file)
* Source: https://crimeindex.org/download
* ============================================================

import delimited "$data/crime_index_202607.csv", clear

* Retain only aggregated agencies within a given state-month 
keep if size == "all"
gen state_raw = substr(id,1,2)
drop if state_raw != lower(state_raw)
gen state = upper(state_raw)
drop state_raw

* Correct month_year variable for consistency across datasets 
gen month_year = ym(year, month)
format %tmMon_CCYY month_year

* Keep only measures of total crime counts by category
drop *_ytd *_change *_change_raw *_roll sample size

* Drop regions and the aggregated US indicator 
drop if inlist(id, "mdw", "noe", "sth", "wst", "us")

* Keep only month_year after October 2022 
drop if month_year < tm(2022m10)

* Save state-month crime data 
save "$clean/crime_index_state_monthly.dta", replace

* Collapse to create national-month aggregates ----
use "$clean/crime_index_state_monthly.dta", clear
collapse (sum) violent_count_month_year=violent_total ///
               murder_count=murder_total ///
               robbery_count=robbery_total ///
               assault_count_month_year=assault_total ///
               property_count=property_total ///
               theft_count_month_year=theft_total ///
               burglary_count_month_year=burglary_total ///
               motor_count_month_year=motor_total, ///
         by(month_year)

save "$clean/crime_index_national_monthly.dta", replace


* ============================================================
* MERGE DATA TO PREPARE FOR ANALYSES
* ============================================================

* ============================================================
* 6. National dataset of Border Encounters, ICE arrests, and crime 
* This will be used to create figures 1a, 1b, and 4
* ============================================================

use "$clean/crime_index_national_monthly.dta", clear 
merge 1:1 month_year using "$clean/ice_arrests_pct_convicted.dta", nogen
merge 1:1 month_year using "$clean/border_encounters.dta", nogen
merge 1:1 month_year using "$clean/ice_arrests_national.dta", nogen

save "$clean/national_analyses.dta", replace

* ============================================================
* 7. ICE arrests, crime, and sanctuary vs. non-sanctuary states
* This will be used to create figure 2  
* ============================================================

use "$clean/crime_index_state_monthly.dta", clear 

* Drop DC 
drop if state == "DC"

gen sanctuary = inlist(state,"CA","CO","CT","IL","MN","NV","NY") | inlist(state,"OR","RI","VT","WA")

* Create event-month relative to January 2025 
gen event_month = (year-2025)*12 + (month-1)
keep if event_month >= -18 & event_month <= 18

* Aggregate to totals by sanctuary and non-sanctuary states 
collapse (sum) total_homicides=murder_total total_robberies=robbery_total total_property=property_total, by(sanctuary event_month)

* Baseline = each group's own January 2025 total, for each outcome
bysort sanctuary: egen baseline_homicides = mean(cond(event_month==0, total_homicides, .))
gen pct_change_homicides = (total_homicides - baseline_homicides) / baseline_homicides * 100

bysort sanctuary: egen baseline_robberies = mean(cond(event_month==0, total_robberies, .))
gen pct_change_robberies = (total_robberies - baseline_robberies) / baseline_robberies * 100

bysort sanctuary: egen baseline_property = mean(cond(event_month==0, total_property, .))
gen pct_change_property = (total_property - baseline_property) / baseline_property * 100

drop baseline_homicides baseline_robberies baseline_property total_homicides total_robberies total_property

reshape wide pct_change_homicides pct_change_robberies pct_change_property, i(event_month) j(sanctuary)

save "$clean/sanctuary_nonsanctuary.dta", replace

* ============================================================
* 8. ICE arrests and crime 
* This will be used to create figure 3  
* ============================================================

use "$clean/crime_index_state_monthly.dta", clear 
merge 1:1 state month_year using "$clean/ice_arrests_state.dta"

* Drop DC 
drop if state == "DC"

* Drop states that do not have crime data 
drop if _merge == 2 

* If ICE arrests are missing, assume zero arrests 
replace ice_arrests = 0 if ice_arrests == .
drop _merge

* Indicator for sanctuary states - will separately color these states, but no separate analyses 
gen sanctuary = inlist(state,"CA","CO","CT","IL","MN","NV","NY") | inlist(state,"OR","RI","VT","WA")

* Create event-month relative to January 2025
gen event_month = (year-2025)*12 + (month-1)
keep if event_month >= -18 & event_month <= 18

* Create measure indicating 18 months before January 2025 and 18 months beginning in January 2025 
gen period = .
replace period = 0 if event_month>=-18 & event_month<=-1
replace period = 1 if event_month>=0  & event_month<=18
keep if period==0 | period==1

* Fix state indicator and create numerical state measure 
bysort state (state_fips): replace state_fips = state_fips[_N] if missing(state_fips)
bysort state (state_name): replace state_name = state_name[_N] if missing(state_name)
destring state_fips, replace

sort state month_year

* On the log scale, fit each state's own pre-existing trend for ICE arrests and crime (by type), net of month fixed effects in the 18 months before January 2025. Then, extrapolate forward in the 18 months beginning in January 2025. Next, create measures of deviations in the post-period from the 
gen ln_ice = ln(ice_arrests + 1)
regress ln_ice i.state_fips##c.event_month i.month if event_month < 0
predict ice_pretrend_fitted
gen ice_pretrend_dev = ln_ice - ice_pretrend_fitted if event_month >= 0 

gen ln_murder = ln(murder_total + 1)
regress ln_murder i.state_fips##c.event_month i.month if event_month < 0
predict murder_pretrend_fitted
gen murder_pretrend_dev = ln_murder - murder_pretrend_fitted if event_month >= 0 

gen ln_property = ln(property_total + 1)
regress ln_property i.state_fips##c.event_month i.month if event_month < 0
predict property_pretrend_fitted
gen property_pretrend_dev = ln_property - property_pretrend_fitted if event_month >= 0 

gen ln_robbery = ln(robbery_total + 1)
regress ln_robbery i.state_fips##c.event_month i.month if event_month < 0
predict robbery_pretrend_fitted
gen robbery_pretrend_dev = ln_robbery - robbery_pretrend_fitted if event_month >= 0 

* Drop the pre-period - not needed for actual plotting 
drop if period == 0 

* Fit bivariate models in the post-period, clustering standard errors at the state level 
regress murder_pretrend_dev   ice_pretrend_dev, vce(cluster state_fips)
regress property_pretrend_dev ice_pretrend_dev, vce(cluster state_fips)
regress robbery_pretrend_dev  ice_pretrend_dev, vce(cluster state_fips)

save "$clean/ice_arrests_crime_state_deviations.dta", replace


* ============================================================
* CREATE FIGURES
* ============================================================

* ============================================================
* FIGURES 1a and 1b
* Figure 1a: Border encounters and homicide 
* Figure 1b: ICE arrests and homicide
* ============================================================

* FIGURE 1a - border encounters and homicide 
use "$clean/national_analyses.dta", clear 

twoway ///
(line encounters month_year , yaxis(1) lcolor(navy) lwidth(medthick) lpattern(dash)) ///
(line murder_count month_year, yaxis(2) lcolor(cranberry) lwidth(medthick)), ///
ytitle("Border Encounters", axis(1) color(navy) size(small)) ///
ylabel(0(50000)250000, axis(1) labcolor(navy) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(navy) axis(1) range(0 .)) ///
ytitle("Homicides", axis(2) color(cranberry) size(small)) ///
ylabel(0(200)1000, axis(2) labcolor(cranberry) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(cranberry) axis(2) range(0 .)) ///
xline(`=ym(2025,1)', lcolor(gs10) lpattern(shortdash)) ///
xtitle("") ///
xlabel(753(4)798, format(%tmMon_CCYY) angle(45) labsize(small)) ///
title("Border Encounters and Homicides", size(medium)) ///
subtitle("Monthly Totals, October 2022 - July 2026", size(small)) ///
legend(order(1 "Border Encounters" 2 "Homicides") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$Figures/figure1a.png", width(2400) replace


* FIGURE 1b - ICE arrests and homicide 
twoway ///
(line ice_arrests month_year, yaxis(1) lcolor(navy) lwidth(medthick) lpattern(dash)) ///
(line murder_count month_year, yaxis(2) lcolor(cranberry) lwidth(medthick)), ///
ytitle("ICE Arrests", axis(1) color(navy) size(small)) ///
ylabel(0(10000)50000, axis(1) labcolor(navy) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(navy) axis(1) range(0 .)) ///
ytitle("Homicides", axis(2) color(cranberry) size(small)) ///
ylabel(0(200)1000, axis(2) labcolor(cranberry) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(cranberry) axis(2) range(0 .)) ///
xline(`=ym(2025,1)', lcolor(gs10) lpattern(shortdash)) ///
xtitle("") ///
xlabel(753(4)798, format(%tmMon_CCYY) angle(45) labsize(small)) ///
title("ICE Arrests and Homicides", size(medium)) ///
subtitle("Monthly Totals, October 2022 - July 2026", size(small)) ///
legend(order(1 "ICE Arrests" 2 "Homicides") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure1b.png", width(2400) replace


* ============================================================
* FIGURE 2: Homicide trends in sanctuary vs. non-sanctuary states 
* ============================================================
use "$clean/sanctuary_nonsanctuary.dta", clear 

twoway ///
(line pct_change_homicides0 event_month, lcolor("56 72 96") lwidth(medthick)) ///
(line pct_change_homicides1 event_month, lcolor("151 166 196") lwidth(medthick)), ///
xline(0, lcolor(black) lpattern(shortdash) lwidth(thin)) ///
yline(0, lcolor(gs10) lwidth(thin)) ///
ytitle("% Change in Homicides", size(small)) ///
ylabel(, angle(horizontal) labsize(small)) ///
xtitle("Months Relative to January 2025", size(small)) ///
xlabel(-18(6)18, labsize(small)) ///
title("Homicide Trends in Sanctuary vs. Non-Sanctuary States", size(medium)) ///
subtitle("% Change in Homicides Relative to January 2025", size(small)) ///
legend(order(1 "Non-Sanctuary States" 2 "Sanctuary States") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure2.png", width(2400) replace


* ============================================================
* FIGURE 3: ICE Arrests and Homicides by State 
* ============================================================
use "$clean/ice_arrests_crime_state_deviations.dta", clear 

twoway ///
(lfit murder_pretrend_dev ice_pretrend_dev if period==1, lcolor(gs8) lwidth(medium) lpattern(dash)) ///
(scatter murder_pretrend_dev ice_pretrend_dev if sanctuary==0 & period==1, mcolor("56 72 96") msize(small)) ///
(scatter murder_pretrend_dev ice_pretrend_dev if sanctuary==1 & period==1, mcolor("151 166 196") msize(small) msymbol(D)), ///
ytitle("Deviations in ln(homicides) from Predicted Trend", size(small)) ///
ylabel(, angle(horizontal) labsize(small)) ///
xtitle("Deviations in ln(ICE arrests) from Predicted Trend", size(small)) ///
xlabel(, labsize(small)) ///
title("ICE Arrests and Homicides by State", size(medium)) ///
subtitle("State-Month Observations, January 2025 - July 2026, Adjusting for Each State's Pre-Existing Trend", size(small)) ///
legend(order(2 "Non-Sanctuary States" 3 "Sanctuary States") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)


graph export "figures/figure3.png", width(2400) replace

* ============================================================
* FIGURE 4: ICE Arrests and Percent of Arrests with Prior Criminal Conviction
* ============================================================
use "$clean/national_analyses.dta", clear 

twoway ///
(line ice_arrests month_year, yaxis(1) lcolor(navy) lwidth(medthick) lpattern(dash)) ///
(line pct_convicted month_year, yaxis(2) lcolor( "0 100 0") lwidth(medthick)), ///
ytitle("Total ICE Arrests", axis(1) color(navy) size(small)) ///
ylabel(0(10000)50000, axis(1) labcolor(navy) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(navy) axis(1) range(0 .)) ///
ytitle("Percent with Prior Convictions", axis(2) color( "0 100 0") size(small)) ///
ylabel(0(10)100, axis(2) labcolor( "0 100 0") labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor( "0 100 0") axis(2) range(0 .)) ///
xtitle("") ///
xline(`=ym(2025,1)', lcolor(black) lpattern(shortdash) lwidth(thin)) ///
xlabel(753(6)798, format(%tmMon_CCYY) angle(45) labsize(small)) ///
title("ICE Arrests and Percent of Noncitizens Arrested with Prior Convictions", size(medium)) ///
subtitle("Monthly Totals, October 2022 - July 2026", size(small)) ///
legend(order(1 "ICE Arrests" 2 "Percent with Prior Convictions") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure4.png", width(2400) replace


* ============================================================
* Replication of figures using property crime and robbery 
* ============================================================

* FIGURE 1a - border encounters and property crime
use "$clean/national_analyses.dta", clear 

twoway ///
(line encounters month_year , yaxis(1) lcolor(navy) lwidth(medthick) lpattern(dash)) ///
(line property_count month_year, yaxis(2) lcolor(cranberry) lwidth(medthick)), ///
ytitle("Border Encounters", axis(1) color(navy) size(small)) ///
ylabel(0(50000)250000, axis(1) labcolor(navy) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(navy) axis(1) range(0 .)) ///
ytitle("Property Crimes", axis(2) color(cranberry) size(small)) ///
ylabel(0(50000)300000, axis(2) labcolor(cranberry) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(cranberry) axis(2) range(0 .)) ///
xline(`=ym(2025,1)', lcolor(gs10) lpattern(shortdash)) ///
xtitle("") ///
xlabel(753(4)798, format(%tmMon_CCYY) angle(45) labsize(small)) ///
title("Border Encounters and Property Crimes", size(medium)) ///
subtitle("Monthly Totals, October 2022 - July 2026", size(small)) ///
legend(order(1 "Border Encounters" 2 "Property Crimes") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure1a_property.png", width(2400) replace


* FIGURE 1a - border encounters and robbery
use "$clean/national_analyses.dta", clear 

twoway ///
(line encounters month_year , yaxis(1) lcolor(navy) lwidth(medthick) lpattern(dash)) ///
(line robbery_count month_year, yaxis(2) lcolor(cranberry) lwidth(medthick)), ///
ytitle("Border Encounters", axis(1) color(navy) size(small)) ///
ylabel(0(50000)250000, axis(1) labcolor(navy) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(navy) axis(1) range(0 .)) ///
ytitle("Robberies", axis(2) color(cranberry) size(small)) ///
ylabel(0(3000)15000, axis(2) labcolor(cranberry) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(cranberry) axis(2) range(0 .)) ///
xline(`=ym(2025,1)', lcolor(gs10) lpattern(shortdash)) ///
xtitle("") ///
xlabel(753(4)798, format(%tmMon_CCYY) angle(45) labsize(small)) ///
title("Border Encounters and Robberies", size(medium)) ///
subtitle("Monthly Totals, October 2022 - July 2026", size(small)) ///
legend(order(1 "Border Encounters" 2 "Robberies") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure1a_robbery.png", width(2400) replace


* FIGURE 1b - ICE arrests and property crime
twoway ///
(line ice_arrests month_year, yaxis(1) lcolor(navy) lwidth(medthick) lpattern(dash)) ///
(line property_count month_year, yaxis(2) lcolor(cranberry) lwidth(medthick)), ///
ytitle("ICE Arrests", axis(1) color(navy) size(small)) ///
ylabel(0(10000)50000, axis(1) labcolor(navy) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(navy) axis(1) range(0 .)) ///
ytitle("Property Crimes", axis(2) color(cranberry) size(small)) ///
ylabel(0(50000)300000, axis(2) labcolor(cranberry) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(cranberry) axis(2) range(0 .)) /// 
xline(`=ym(2025,1)', lcolor(gs10) lpattern(shortdash)) ///
xtitle("") ///
xlabel(753(4)798, format(%tmMon_CCYY) angle(45) labsize(small)) ///
title("ICE Arrests and Property Crimes", size(medium)) ///
subtitle("Monthly Totals, October 2022 - July 2026", size(small)) ///
legend(order(1 "ICE Arrests" 2 "Property Crimes") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure1b_property.png", width(2400) replace

* FIGURE 1b - ICE arrests and robbery
twoway ///
(line ice_arrests month_year, yaxis(1) lcolor(navy) lwidth(medthick) lpattern(dash)) ///
(line robbery_count month_year, yaxis(2) lcolor(cranberry) lwidth(medthick)), ///
ytitle("ICE Arrests", axis(1) color(navy) size(small)) ///
ylabel(0(10000)50000, axis(1) labcolor(navy) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(navy) axis(1) range(0 .)) ///
ytitle("Robberies", axis(2) color(cranberry) size(small)) ///
ylabel(0(3000)15000, axis(2) labcolor(cranberry) labsize(small) angle(horizontal) format(%9.0fc)) ///
yscale(lcolor(cranberry) axis(2) range(0 .)) ///
xline(`=ym(2025,1)', lcolor(gs10) lpattern(shortdash)) ///
xtitle("") ///
xlabel(753(4)798, format(%tmMon_CCYY) angle(45) labsize(small)) ///
title("Ice Arrests and Robberies", size(medium)) ///
subtitle("Monthly Totals, October 2022 - July 2026", size(small)) ///
legend(order(1 "ICE Arrests" 2 "Robberies") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure1b_robbery.png", width(2400) replace


* FIGURE 2 - property crime trends in sanctuary vs. non-sanctuary states 
use "$clean/sanctuary_nonsanctuary.dta", clear 

twoway ///
(line pct_change_property0 event_month, lcolor("56 72 96") lwidth(medthick)) ///
(line pct_change_property1 event_month, lcolor("151 166 196") lwidth(medthick)), ///
xline(0, lcolor(black) lpattern(shortdash) lwidth(thin)) ///
yline(0, lcolor(gs10) lwidth(thin)) ///
ytitle("% Change in Property Crime", size(small)) ///
ylabel(, angle(horizontal) labsize(small)) ///
xtitle("Months Relative to January 2025", size(small)) ///
xlabel(-18(6)18, labsize(small)) ///
title("Property Crime Trends in Sanctuary vs. Non-Sanctuary States", size(medium)) ///
subtitle("% Change in Property Crime Relative to January 2025", size(small)) ///
legend(order(1 "Non-Sanctuary States" 2 "Sanctuary States") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)
graph export "$figures/figure2_property.png", width(2400) replace

* FIGURE 2 - robbery trends in sanctuary vs. non-sanctuary states 
twoway ///
(line pct_change_robberies0 event_month, lcolor("56 72 96") lwidth(medthick)) ///
(line pct_change_robberies1 event_month, lcolor("151 166 196") lwidth(medthick)), ///
xline(0, lcolor(black) lpattern(shortdash) lwidth(thin)) ///
yline(0, lcolor(gs10) lwidth(thin)) ///
ytitle("% Change in Robberies", size(small)) ///
ylabel(, angle(horizontal) labsize(small)) ///
xtitle("Months Relative to January 2025", size(small)) ///
xlabel(-18(6)18, labsize(small)) ///
title("Robbery Trends in Sanctuary vs. Non-Sanctuary States", size(medium)) ///
subtitle("% Change in Robberies Relative to January 2025", size(small)) ///
legend(order(1 "Non-Sanctuary States" 2 "Sanctuary States") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure2_robbery.png", width(2400) replace

* FIGURE 3 - ICE Arrests and property crime by state 
use "$clean/ice_arrests_crime_state_deviations.dta", clear 

twoway ///
(lfit property_pretrend_dev ice_pretrend_dev if period==1, lcolor(gs8) lwidth(medium) lpattern(dash)) ///
(scatter property_pretrend_dev ice_pretrend_dev if sanctuary==0 & period==1, mcolor("56 72 96") msize(small)) ///
(scatter property_pretrend_dev ice_pretrend_dev if sanctuary==1 & period==1, mcolor("151 166 196") msize(small) msymbol(D)), ///
ytitle("Deviations in ln(property crime) from Predicted Trend", size(small)) ///
ylabel(, angle(horizontal) labsize(small)) ///
xtitle("Deviations in ln(ICE arrests) from Predicted Trend", size(small)) ///
xlabel(, labsize(small)) ///
title("ICE Arrests and Property Crimes by State", size(medium)) ///
subtitle("State-Month Observations, January 2025 - July 2026, Adjusting for Each State's Pre-Existing Trend", size(small)) ///
legend(order(2 "Non-Sanctuary States" 3 "Sanctuary States") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure3_property.png", width(2400) replace

* FIGURE 3 - ICE Arrests and robbery by state 
twoway ///
(lfit robbery_pretrend_dev ice_pretrend_dev if period==1, lcolor(gs8) lwidth(medium) lpattern(dash)) ///
(scatter robbery_pretrend_dev ice_pretrend_dev if sanctuary==0 & period==1, mcolor("56 72 96") msize(small)) ///
(scatter robbery_pretrend_dev ice_pretrend_dev if sanctuary==1 & period==1, mcolor("151 166 196") msize(small) msymbol(D)), ///
ytitle("Deviations in ln(robbery) from Predicted Trend", size(small)) ///
ylabel(, angle(horizontal) labsize(small)) ///
xtitle("Deviations in ln(ICE arrests) from Predicted Trend", size(small)) ///
xlabel(, labsize(small)) ///
title("ICE Arrests and Robberies by State", size(medium)) ///
subtitle("State-Month Observations, January 2025 - July 2026, Adjusting for Each State's Pre-Existing Trend", size(small)) ///
legend(order(2 "Non-Sanctuary States" 3 "Sanctuary States") position(6) rows(1)) ///
graphregion(color(white)) plotregion(color(white)) ///
scheme(s1color)

graph export "$figures/figure3_robbery.png", width(2400) replace


