* version 1.0.0.
program bcstats
	vers 9
	syntax using/, ///
		id(varlist) ///
		[okrate(real 0.1) EXclval(str asis) okrange(str)] ///
		[t1vars(varlist) ENUMerator(str) BACKchecker(varname num) ENUMTeam(str) BCTeam(varname num)] ///
		[t2vars(varlist)] ///
		[t3vars(varlist) ttest(varlist) signrank(varlist)] ///
		[KEEPSUrvey(str) keepbc(varlist) full FILEname(str) replace dta NOLabel] ///
		[NOSymbol Lower Upper]
	
	***Check syntax***
	foreach option in enumerator enumteam okrange keepsurvey filename {
		loc temp : subinstr loc `option' `"""' "", count(loc dq)
		if `dq' {
			di as err `"option `option' cannot contain ""'
			ex 198			
		}
	}
	loc temp : subinstr loc exclval "'" "", count(loc csq)
	if `csq' {
		di as err "option exclval cannot contain '"
		ex 198
	}
	loc temp : subinstr loc exclval "`" "", count(loc osq)
	if `osq' {
		di as err "option exclval cannot contain `"
		ex 198
	}
	
	isid `id'
	
	loc tvars `t1vars' `t2vars' `t3vars'
	if "`tvars'" == "" {
		di as err "must specify one of t1vars, t2vars, and t3vars options"
		ex 198
	}
	forv i = 1/2 {
		forv j = `=`i' + 1'/3 {
			loc shared : list t`i'vars & t`j'vars
			if "`shared'" != "" {
				di as err "variable `:word 1 of `shared'' is specified in t`i'vars and t`j'vars"
				ex 198
			}
		}
	}
	foreach option in enumerator backchecker enumteam bcteam okrate {
		loc len : length loc `option'
		if `len' & "`t1vars'`t2vars'" == "" {
			di as err "option `option' must be specified with option t1vars or t2vars"
			ex 198
		}
	}
	foreach var of loc tvars {
		cap confirm new v bc_`var'
		if _rc {
			di as err "variable name '`var'' exceeds 29 characters"
			ex 198
		}
	}
	
	loc exclwc : word count `exclval'
	if `exclwc' {
		if `exclwc' > 18 {
			di as err "option exclval: too many values"
			ex 130
		}
		tempvar test
		while `"`exclval'"' != "" {
			gettoken val   exclval : exclval, parse(",")
			gettoken comma exclval : exclval, parse(",")
			
			if `:word count `val'' != 2 {
				di as err "invalid option exclval"
				ex 198
			}
			
			loc num : word 1 of `val'
			cap gen `test' = `num'
			cap confirm numeric v `test'
			if _rc {
				di as err "option exclval: invalid numeric missing value"
				ex 198
			}
			drop `test'
			loc exclnum `exclnum'`=cond("`exclnum'" == "", "", ", ")'`num'
			
			loc str : word 2 of `val'
			cap gen `test' = "`str'"
			cap confirm str v `test'
			if _rc {
				di as err "option exclval: invalid string missing value"
				ex 198
			}
			drop `test'
			loc exclstr `exclstr'`=cond("`exclstr'" == "", "", ", ")'`str'
		}
	}
	
	if !inrange(`okrate', 0, 1) {
		di as err "okrate must be between 0 and 1"
		ex 198
	}
	
	loc t12vars : list t1vars | t2vars
	while "`okrange'" != "" {
		gettoken range okrange : okrange, parse(",")
		gettoken comma okrange : okrange, parse(",")
		gettoken rest  okrange : okrange, parse(",")
		gettoken comma okrange : okrange, parse(",")
		loc range `range',`rest'
		
		gettoken var range : range
		if `:list var in rangevars' {
			di as err "multiple ranges attached to `var'"
			ex 198
		}
		else loc rangevars : list rangevars | var
		cap confirm numeric v `var'
		if _rc {
			di as err "option okrange: `var' not numeric in back check data"
			ex 198
		}
		
		gettoken min   range : range, parse(",")
		gettoken comma max : range, parse(",")
		if substr(ltrim("`min'"), 1, 1) != "[" | substr(rtrim("`max'"), -1, 1) != "]" {
			di as err "range must be enclosed by brackets"
			ex 198
		}
		loc min = substr(trim("`min'"), 2, .)
		loc max = substr(trim("`max'"), 1, length(rtrim("`max'")) - 1)
		if wordcount("`min'") > 1 | wordcount("`max'") > 1 {
			di as err "invalid range"
			ex 198
		}
		loc minperc = strpos("`min'", "%")
		if `minperc' + strpos("`max'", "%") == 1 {
			di as err "range endpoints must be both absolute or both relative"
			ex 198
		}
		else {
			loc `var'perc `minperc'
			if ``var'perc' {
				loc min = substr("`min'", 1, length("`min'") - 1)
				loc max = substr("`max'", 1, length("`max'") - 1)
			}
		}
		if `min' > `max' {
			di as err "range min greater than max"
			ex 198
		}
		if `min' > 0 | `max' < 0 {
			di as err "range does not include 0"
			ex 198
		}
		loc `var'min `min'
		loc `var'max `max'
	}
	
	foreach option in ttest signrank {
		if "``option''" != "" & "`t3vars'`t2vars'" == "" {
			di as err "option `option' must be specified with option t3vars or t2vars"
			ex 198
		}
	}
	loc shared : list ttest & signrank
	if "`shared'" != "" {
		di as err "variable `:word 1 of `shared'' is specified in both options ttest and signrank"
		ex 198
	}			
	
	loc type = cond("`dta'" == "", "csv", "dta")
	if "`filename'" == "" loc filename bc_diffs.`type'
	else {
		if substr("`filename'", -4, 4) != ".`type'" {
			di as err "filename must be of type .`type'"
			ex 10
		}
	}
	cap confirm new file "`filename'"
	if ("`replace'" == "" & _rc) | ("`replace'" != "" & !inlist(_rc, 0, 602)) confirm new file "`filename'"
	
	if "`lower'" != "" & "`upper'" == "" {
		di as err "options lower and upper are mutually exclusive"
		ex 198
	}
	
	loc allvars `id' `enumerator' `backchecker' `enumteam' `bcteam' `tvars' `keepsurvey' `keepbc'
	foreach reserved in variable survey back_check differences total error_rate {
		if `:list reserved in allvars' {
			di as err "`reserved' is a reserved variable name"
			ex 198
		}
	}
	cap ds bc_*
	if !_rc {
		loc varl `r(varlist)'
		di as err "variable `:word 1 of `varl'' has illegal prefix bc_"
		ex 198
	}
	preserve
	keep `id' `backchecker' `bcteam' `tvars' `keepbc'
	modifystrs `tvars', `nosymbol' `lower' `upper'
	foreach var of loc tvars {
		ren `var' bc_`var'
	}
	foreach var of loc keepbc {
		loc keepbcf `keepbcf' `:format `var''
		ren `var' bc_`var'
		loc bckeepbc `bckeepbc' bc_`var'
	}
	loc varls id enumerator enumteam backchecker bcteam keepsurvey bckeepbc
	loc nvars : word count `varls'
	forv i = 1/`=`nvars' - 1' {
		loc varl1 : word `i' of `varls'
		forv j = `=`i' + 1'/`nvars' {
			loc varl2 : word `j' of `varls'
			if "`varl1'" == "`varl2'" {
				loc dups : list dups `varl1'
				if "`dups'" != "" {
					di as err "variable `:word 1 of `dups'' specified twice in option `varl1'"
					ex 198
				}
			}
			else {
				loc shared : list `varl1' & `varl2'
				if "`shared'" != "" {
					di as err "variable `:word 1 of `shared'' is specified in options `varl1' and `varl2'"
					ex 198
				}
			}
		}
	}
	
	tempfile bc
	sort `id'
	qui save `bc'
	
	use "`using'", clear
	loc allvars `id' `enumerator' `enumteam' `tvars' `keepsurvey'
	cap confirm v `allvars'
	if _rc {
		qui ds
		loc varl `r(varlist)'
		di as err "variable `:word 1 of `:list allvars - varl'' not found in survey data"
		restore
		ex 111
	}
	if "`enumerator'" != "" {
		cap confirm numeric v `enumerator'
		if _rc {
			di as err "enumerator variable must be numeric"
			restore
			ex 198
		}
	}
	if "`enumteam'" != "" {
		cap confirm numeric v `enumteam'
		if _rc {
			di as err "enumerator team variable must be numeric"
			restore
			ex 198
		}
	}
	foreach var of loc rangevars {
		cap confirm numeric v `var'
		if _rc {
			di as err "option okrange: `var' not numeric in survey data"
			restore
			ex 198
		}
	}
	
	cap isid `id'
	if _rc {
		loc idvars : word count `id'
		di as err "`=plural(`idvars', "variable")' `id' `=plural(`idvars', "does", "do")' not uniquely identify observations in survey data"
		restore
		ex 459
	}
	
	cap ds bc_*
	if !_rc {
		loc varl `r(varlist)'
		di as err "variable `:word 1 of `varl'' has illegal prefix bc_ in survey data"
		restore
		ex 198
	}
	***End***
	
	***Produce data set***
	keep `id' `enumerator' `enumteam' `tvars' `keepsurvey'
	modifystrs `tvars', `nosymbol' `lower' `upper'
	foreach var of loc keepsurvey {
		loc keepsurveyf `keepsurveyf' `:format `var''
	}
	sort `id'
	tempfile survey
	qui save `survey'
	qui merge `id' using `bc'
	qui count if _merge == 2
	if r(N) {
		di as err "note: the following ids appear in the back check data but not the survey data and will be dropped."
		sort `id'
		l `id' if _merge == 2, noo
		qui drop if _merge == 2
	}
	qui drop if _merge == 1
	foreach var of loc tvars {
		qui ds `var' bc_`var', has(type numeric)
		if `:word count `r(varlist)'' == 1 {
			di as err "variable `var' is numeric in the `=cond("`r(varlist)'" == "`var'", "survey", "back check")' data and string in the `=cond("`r(varlist)'" == "`var'", "back check", "survey")' data"
			restore
			ex 198
		}
	}
	foreach var of loc tvars {
		if "`:val la bc_`var''" == "" & "`:val la `var''" != "" la val bc_`var' `:val la `var''
	}
	
	foreach var of loc id {
		loc idpost `idpost' `:type `var'' `var'
	}
	foreach var in `keepsurvey' `bckeepbc' {
		loc keeppost `keeppost' `:type `var'' `var'
	}
	tempname pf
	tempfile byobs
	postfile `pf' `idpost' `enumerator' `enumteam' `backchecker' `bcteam' str32 variable str244 survey str244 back_check diff `keeppost' using `byobs'
	sort `enumerator' `id'
	
	tempvar decvar bcdecvar
	foreach var of loc tvars {
		if "`:val la `var''" != "" & "`nolabel'" == "" {
			qui dec `var', gen(`decvar')
			qui dec bc_`var', gen(`bcdecvar')
		}
		cap confirm numeric v bc_`var'
		loc type = cond(_rc, "str", "num")
		forv i = 1/`=_N' {
			if `:list var in rangevars' {
				if ``var'perc' loc inrange = bc_`var'[`i'] >= (1 + ``var'min' / 100) * `var'[`i'] & ///
					bc_`var'[`i'] <= (1 + ``var'max' / 100) * `var'[`i']
				else loc inrange = bc_`var'[`i'] >= `var'[`i'] + ``var'min' & bc_`var'[`i'] <= `var'[`i'] + ``var'max'
			}
			else loc inrange 0
			
			loc idpost
			foreach idvar of loc id {
				loc idval = `idvar'[`i']
				cap confirm str v `idvar'
				loc isstr = !_rc
				if `isstr' loc idval = `"""' + "`idval'" + `"""'
				loc idpost `idpost' (`idval')
			}
			
			loc keeppost
			foreach keepvar in `keepsurvey' `bckeepbc' {
				loc keepval = `keepvar'[`i']
				cap confirm str v `keepvar'
				loc isstr = !_rc
				if `isstr' loc keepval = `"""' + "`keepval'" + `"""'				
				loc keeppost `keeppost' (`keepval')
			}
			
			if "`:val la `var''" != "" & "`nolabel'" == "" {
				if mi(`decvar'[`i']) loc val = `var'[`i']
				else loc val = `decvar'[`i']
			}
			else loc val = `var'[`i']
			
			if "`:val la bc_`var''" != "" & "`nolabel'" == "" {
				loc isstr 1
				if mi(`bcdecvar'[`i']) loc bcval = bc_`var'[`i']
				else loc bcval = `bcdecvar'[`i']
			}
			else {
				cap confirm str v bc_`var'
				loc isstr = !_rc
				loc bcval = bc_`var'[`i']
			}
			
			if "`enumerator'" != ""  loc enumpost  (`enumerator'[`i'])
			if "`backchecker'" != "" loc bcerpost  (`backchecker'[`i'])
			if "`enumteam'" != ""    loc enumtpost (`enumteam'[`i'])
			if "`bcteam'" != ""      loc bcertpost (`bcertpost'[`i'])
			
			if "`exclnum'" == "" | !inlist(bc_`var'[`i'], `excl`type'') post `pf' `idpost' `enumpost' `enumtpost' `bcerpost' `bcertpost' ///
				("`var'") ("`val'") ("`bcval'") (`var'[`i'] != bc_`var'[`i'] & !`inrange') `keeppost'
		}
		if "`:val la `var''" != "" & "`nolabel'" == "" drop `decvar' `bcdecvar'
	}
	
	postclose `pf'
	
	use `byobs', clear
	la var variable "Variable"
	la var survey "Value in survey data"
	la var back_check "Value in back check data"
	la var diff "Difference between survey and back check"
	if "`enumerator'`enumteam'`nolabel'" != "" {
		tempvar n
		gen `n' = _n
	}
	if "`enumerator'`enumteam'" != "" {
		sort `id'
		qui merge `id' using `survey', keep(`enumerator' `enumteam') nok update
		drop _merge
	}
	if "`backchecker'`bcteam'" != "" {
		sort `id'
		qui merge `id' using `bc', keep(`backchecker' `bcteam') nok update
		drop _merge		
	}
	if "`nolabel'" == "" {
		if "`keepsurvey'" != "" {
			sort `id'
			qui merge `id' using `survey', keep(`keepsurvey') nok update
			drop _merge
			forv i = 1/`:word count `keepsurvey'' {
				format `:word `i' of `keepsurvey'' `:word `i' of `keepsurveyf''
			}
		}
		if "`keepbc'" != "" {
			sort `id'
			qui merge `id' using `bc', keep(`bckeepbc') nok update
			drop _merge
			forv i = 1/`:word count `bckeepbc'' {
				format `:word `i' of `bckeepbc'' `:word `i' of `keepbcf''
			}
		}		
	}
	if "`enumerator'`enumteam'`nolabel'" != "" {
		sort `n'
		drop `n'
	}
	qui save `byobs', replace
	if "`full'" == "" {
		qui keep if diff
		drop diff
	}
	
	loc csvwarn 0
	if "`dta'" == "" {
		qui outsheet `id' `enumerator' variable survey back_check `=cond("`full'" == "", "", "diff")' `keepsurvey' `bckeepbc' using ///
			"`filename'", c `replace' `nolabel'
		qui insheet using "`filename'", c clear non
		qui ds `varlist'
		loc varl `r(varlist)'
		forv i = 1/`c(k)' {
			if mi(`:word `i' of `varl''[1]) {
				loc csvwarn 1
				continue, break
			}
		}
	}
	else {
		qui compress
		qui save "`filename'", `replace'
	}
	***End***
	
	***Display stats***
	use `byobs', clear
	
	foreach varl in t1vars t2vars t3vars {
		tempvar is`varl'
		gen is`varl' = 0
		
		foreach var of loc `varl' {
			qui replace is`varl' = 1 if variable == "`var'"
		}
	}
	
	loc t1varstitle "type 1 variables"
	loc t2varstitle "type 2 variables"
	loc t3varstitle "type 3 variables"
	
	foreach varl in t1vars t2vars {
		if "``varl''" != "" {
			di _n "{txt}Completing {res:enumerator} checks for {res:``varl'title'}..."
			
			tempvar highvar
			checkrate, by(`enumerator') message("Displaying enumerators with high error rates...") highvar(`highvar') varl(is`varl') okrate(`okrate')
			loc varbyenum = r(high)
			
			if "`enumteam'" != "" checkrate, by(`enumteam') message("Displaying enumerator team error rates...") listall varl(is`varl')
						
			checkrate, by(variable) message("Displaying variables with high error rates...") varl(is`varl') okrate(`okrate')
			
			if `varbyenum' checkrate, by(`enumerator' variable) ///
				message("Displaying variables with high error rates for enumerators with high error rates...") listif(`highvar') varl(is`varl') ///
				okrate(`okrate')
			
			if "`backchecker'" != "" checkrate, by(`backchecker') message("Displaying back checker error rates...") listall varl(is`varl')
			
			if "`bcteam'" != "" checkrate, by(`bcteam') message("Displaying back checker team error rates...") listall varl(is`varl')
		}
	}
	
	foreach varl in t3vars t2vars {
		if "``varl''" != "" {
			di _n "{txt}Completing {res:stability} checks for {res:``varl'title'}..."
			
			checkrate, by(variable) message("Displaying variable error rates...") listall varl(is`varl') okrate(`okrate')
			
			tempvar val bcval
			loc ttestvars    : list `varl' & ttest
			loc signrankvars : list `varl' & signrank
			foreach var in `ttestvars' `signrankvars' {
				di _n "{txt}{cmd:`=cond(`:list var in ttestvars', "ttest", "signrank")'} for {res:`var'}:"
				qui gen `val'    = cond(variable == "`var'", survey, "")
				qui en `val', g(`var')
				qui gen `bcval' = cond(variable == "`var'", back_check, "")
				qui en `bcval', g(bc_`var')
				
				`=cond(`:list var in ttestvars', "ttest", "signrank")' `var' =`=cond(`:list var in ttestvars', "=", "")' bc_`var'
				drop `val' `bcval' `var' bc_`var'
			}
		}
	}
	***End***
	
	if `csvwarn' di _n "{txt}note: the data produced by {cmd:outsheet} contains commas and is misaligned."

	restore
end

pr modifystrs
	syntax varlist, [NOSYMBOL lower upper]
	
	if "`nosymbol'`lower'`upper'" != "" {
		ds `varlist', has(type string)
		foreach var in `r(varlist)' {
			if "`nosymbol'" != "" {
				qui replace `var' == trim(itrim(`var'))
				foreach symbol in . , ! ? ' / ; : ( ) ` ~ @ # $ % ^ & * - _ + = [ ] { } | \ `"""' < > {
					qui replace `var' = subinstr(`var', `"`symbol'"', " ", .)
				}
			}
			if "`lower'`upper'" != "" qui replace `var' = `lower'`upper'(`var')
		}
	}
end

pr checkrate, rclass
	syntax, by(varlist) message(str) [listif(str asis) highvar(str)] varl(varname num) [okrate(real -1) listall]
	if `okrate' == -1 & "`listall'" == "" err 198
	
	qui bys `by': egen differences = total(diff & `varl')
	qui by `by': egen total = total(`varl')
	qui by `by': gen error_rate = differences / total
	if `okrate' != -1 {
		tempvar higherr
		qui gen `higherr' = error_rate > `okrate' & !mi(error_rate)
		qui count if `higherr'
		return scalar high = r(N) != 0
	}
	else return scalar high = .
	if return(high) {
		di _n "{txt}`message'"
		tempvar tag
		egen `tag' = tag(`by')
		format error_rate %9.4f
		sort `by' error_rate differences total
		l `by' error_rate differences total if `=cond(`okrate' != -1, "`higherr'", "!mi(error_rate)")' & ///
			`tag' `=cond(`:length loc listif', "&", "")' `listif', ab(32) noo
	}
	drop differences total error_rate
	
	if "`highvar'" != "" gen `highvar' = `higherr'
end

* Changes history
* 1.0.0. Oct 25, 2011.
