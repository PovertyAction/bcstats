* Author: Matt White
* Purpose: Test -bcstats-.

* -version- intentionally omitted for -cscript-.

* 1 to execute profile.do after completion; 0 not to.
* (Matt's computer only.)
local profile 1


/* -------------------------------------------------------------------------- */
					/* initialize			*/

* Check the parameters.
assert inlist(`profile', 0, 1)

* Set the working directory to the bcstats folder.
c bcstats
cd cscript

cap log close bcstats
log using bcstats, name(bcstats) s replace
di "`c(username)'"
di "`:environment computername'"

clear
clear matrix
clear mata
set varabbrev off
set type float
set more off
pause off

di _caller()
loc vers = cond(_caller() < 11.2, _caller(), 11.2)
vers `vers': set seed 112709820

timer clear 1
timer on 1

cd ../ado
adopath ++ `"`c(pwd)'"'
cd ../cscript
adopath ++ `"`c(pwd)'/ado"'

cscript_bcstats bcstats


/* -------------------------------------------------------------------------- */
					/* convert .csv to .dta			*/

#d ;
loc csv
	1	bcstats_survey	bcstats_bc
	2	bcstats_survey	bcstats_bc
;
#d cr
while `:list sizeof csv' {
	gettoken dir    csv : csv
	gettoken survey csv : csv
	gettoken bc     csv : csv

	cd `"`dir'"'

	bcimport using `"`survey'"'
	bcimport using `"`bc'"'

	cd ..
}


/* -------------------------------------------------------------------------- */
					/* basic				*/

cd 1

* varlist abbreviation
forv i = 1/3 {
	bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
		t`i'vars(gender) replace
	loc cmd bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
		t`i'vars(ge) replace
	rcof "noi `cmd'" == 111
	varabbrev `cmd'
}

cd ..


/* -------------------------------------------------------------------------- */
					/* string comparison options	*/

cd 2

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	t1vars(gender) replace

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	t1vars(gender) replace ///
	lower

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	t1vars(gender) replace ///
	upper

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	t1vars(gender) replace ///
	lower nosymbol trim

cd ..


/* -------------------------------------------------------------------------- */
					/* comparisons data set		*/

cd 1

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	t1vars(gender) replace

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	t1vars(gender) replace ///
	nolabel

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	t1vars(gender) replace ///
	keepsurvey(date) keepbc(date)

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	t1vars(gender) replace ///
	keepsurvey(date) keepbc(date) nolabel

cd ..


/* -------------------------------------------------------------------------- */
					/* help file examples	*/

cd 1

bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///
	okrate(0.09) okrange(gameresult [-1, 1], itemssold [-5%, 5%]) exclude(. "") ///
	t1vars(gender) enumerator(enum) enumteam(enumteam) backchecker(bcer) ///
	t2vars(gameresult) signrank(gameresult) ///
	t3vars(itemssold) ttest(itemssold) ///
	keepbc(date) keepsurvey(date) full replace

cd ..


/* -------------------------------------------------------------------------- */
					/* finish up			*/

timer off 1

if `profile' {
	cap which profile
	if !_rc ///
		profile
}

timer list 1

log close bcstats
