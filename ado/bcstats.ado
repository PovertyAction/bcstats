*! version 1.2.1  20dec2011
program bcstats, rclass
	vers 9
	syntax, ///
		Surveydata(str) Bcdata(str) id(str) ///
		[t1vars(str) ENUMerator(str) BACKchecker(str) ENUMTeam(str) BCTeam(str) SHowid(str) showall] ///
		[t2vars(str)] ///
		[t3vars(str) ttest(str) Level(real -1) signrank(str)] ///
		[KEEPSUrvey(str) keepbc(str) full NOLabel FILEname(str) replace dta] ///
		[okrate(real 0.1) okrange(str) nodiff(str asis) exclude(str asis)] ///
		[LOwer UPper NOSymbol TRim]

	***check syntax***

	* Parse -okrange()-.
	parse_okrange `okrange'
	loc rangevars		"`s(varlist)'"
	loc okrange_perc	`s(perc)'
	loc okrange_min		`s(min)'
	loc okrange_max		`s(max)'
	* strings
	foreach option in surveydata bcdata id t1vars t2vars t3vars enumerator backchecker enumteam bcteam showid ttest signrank keepsurvey keepbc ///
		filename okrange {
		loc temp : subinstr loc `option' `"""' "", count(loc dq)
		if `dq' {
			di as err `"option `option' cannot contain ""'
			ex 198
		}
	}
	foreach option in id t1vars t2vars t3vars enumerator backchecker enumteam bcteam showid ttest signrank keepsurvey keepbc okrange {
		loc temp : subinstr loc `option' "'" "", count(loc csq)
		if `csq' {
			di as err "option `option' cannot contain '"
			ex 198
		}
	}

	preserve

	* Unabbreviate and expand varlists.
	loc optssurvey id t1vars t2vars t3vars enumerator enumteam ///
		ttest signrank keepsurvey
	loc optsbc backchecker bcteam keepbc
	foreach data in survey bc {
		loc fn : copy loc `data'data
		qui d using `"`fn'"'
		if r(N) ///
			qui u in 1 using `"`fn'"', clear
		else ///
			qui u `"`fn'"', clear

		foreach opt of loc opts`data' {
			unab `opt' : ``opt'', min(0)
		}
	}

	* t1vars, t2vars, t3vars
	loc tvars `t1vars' `t2vars' `t3vars'
	if "`tvars'" == "" {
		di as err "must specify one of t1vars, t2vars, and t3vars options"
		ex 198
	}

	* enumerator checks
	foreach option in enumerator backchecker enumteam bcteam showid {
		if "``option''" != "" & "`t1vars'`t2vars'" == "" {
			di as err "option `option' must be specified with option t1vars or t2vars"
			ex 198
		}
	}

	* showid
	loc showid = trim("`showid'")
	if "`showid'" == "" loc showid 30%
	else {
		if `:word count `showid'' > 1 {
			di as err "invalid option showid"
			ex 198
		}
		loc perc = substr("`showid'", -1, 1) == "%"
		if `perc' loc num = substr("`showid'", 1, length("`showid'") - 1)
		else loc num `showid'
		cap confirm n `num'
		if _rc {
			di as err "invalid option showid"
			ex 198
		}
		if `perc' {
			if !inrange(`num', 0, 100) {
				di as err "showid rate must be between 0% and 100%"
				ex 198
			}
		}
		else if `num' < 0 {
			di as err "showid value must be nonnegative"
			ex 198
		}
	}

	* stability checks
	foreach option in ttest signrank {
		if "``option''" != "" & "`t2vars'`t3vars'" == "" {
			di as err "option `option' must be specified with option t2vars or t3vars"
			ex 198
		}
	}

	* filename, dta, replace
	loc type = cond("`dta'" == "", "csv", "dta")
	if "`filename'" == "" loc filename bc_diffs.`type'
	else if substr("`filename'", -4, 4) != ".`type'" loc filename `filename'.`type'
	cap confirm new f "`filename'"
	if "`replace'" == "" & _rc confirm new f "`filename'"
	else if "`replace'" != "" {
		if !inlist(_rc, 0, 602) confirm new f "`filename'"
		else if _rc == 602 {
			tempfile temp
			copy "`filename'" `temp'
			copy `temp' "`filename'", replace
		}
	}

	* okrate, showall
	loc showall = "`showall'" != ""
	if !`showall' {
		if !inrange(`okrate', 0, 1) {
			di as err "okrate must be between 0 and 1"
			ex 198
		}
	}
	* -2, NOT -1: see subprogram errorrate
	else loc okrate -2

	* nodiff
	loc ndwc : word count `nodiff'
	if `ndwc' {
		loc nocommas : subinstr loc nodiff "," "", all
		loc ncwc : word count `nocommas'
		if `ncwc' > 18 {
			di as err "option nodiff: too many values"
			ex 130
		}
		tempvar test
		loc first 1
		while `ndwc' {
			gettoken vals  nodiff : nodiff, parse(",")
			gettoken comma nodiff : nodiff, parse(",")

			loc nvals : word count `vals'
			if `nvals' != 2 {
				di as err "invalid option nodiff"
				ex 198
			}

			gettoken num str : vals, quotes
			cap gen `test' = `num'
			cap confirm numeric v `test'
			if _rc {
				di as err "option nodiff: invalid numeric value"
				ex 198
			}
			drop `test'
			loc nodiffnum `nodiffnum'`=cond("`nodiffnum'" == "", "", ", ")'`num'

			cap gen `test' = `str'
			cap confirm str v `test'
			if _rc {
				di as err "option nodiff: invalid string value"
				ex 198
			}
			drop `test'
			loc str `str'
			cap loc str = `"`"`str'"'"'
			if _rc {
				di as err "option nodiff: string value not enclosable by compound double quotes"
				ex 198
			}
			loc nodiffstr `"`nodiffstr'`=cond(`"`nodiffstr'"' == "", "", ", ")'`str'"'
			loc ndwc : word count `nodiff'
		}
	}

	* exclude
	loc exclwc : word count `exclude'
	if `exclwc' {
		if `exclwc' > 2 {
			di as err "option exclude: too many values"
			ex 130
		}

		gettoken exclnum exclstr : exclude
		tempvar test
		cap gen `test' = `exclnum'
		cap confirm numeric v `test'
		if _rc {
			di as err "option exclude: invalid numeric value"
			ex 198
		}
		drop `test'

		cap gen `test' = `exclstr'
		cap confirm str v `test'
		if _rc {
			di as err "option exclude: invalid string value"
			ex 198
		}
		drop `test'
		loc exclstr `exclstr'
		cap loc exclstr = `"`"`exclstr'"'"'
		if _rc {
			di as err "option exclude: string value not enclosable by compound double quotes"
			ex 198
		}
	}

	* ttest, level
	if `level' == -1 loc level = c(level)
	else if "`ttest'" == "" {
		di as err "option level must be specified with option ttest"
		ex 198
	}
	if !inrange(`level', 10, 99.99) {
		di as err "level() must be between 10 and 99.99 inclusive"
		ex 198
	}

	* lower, upper
	if "`lower'" != "" & "`upper'" != "" {
		di as err "options lower and upper are mutually exclusive"
		ex 198
	}

	loc surveyname survey
	loc bcname back check
	* adopts: "administrator options"
	loc surveyadopts enumerator enumteam
	loc bcadopts backchecker bcteam
	foreach data in survey bc {
		* file
		cap use "``data'data'", clear
		if _rc {
			di as err "invalid option `data'data"
			ex 198
		}

		* confirm variables
		foreach option in id t1vars t2vars t3vars ttest signrank {
			if "``option''" != "" {
				foreach v of loc `option' {
					cap unab temp : `v'
					if _rc {
						di as err "option `option': variable `v' not found in ``data'name' data"
						ex 111
					}
				}
				unab `data'`option' : ``option''
			}
		}
		if "`keep`data''" != "" {
			foreach v of loc keep`data' {
				cap unab temp : `v'
				if _rc {
					di as err "option keep`data': variable `v' not found"
					ex 111
				}
			}
			unab keep`data' : `keep`data''
		}
		foreach option of loc `data'adopts {
			loc nvars : word count ``option''
			if `nvars' > 1 {
				di as err "option `option': too many variables specified"
				ex 103
			}
			else if `nvars' == 1 {
				foreach v of loc `option' {
					cap unab temp : `v'
					if _rc {
						di as err "option `option': variable `v' not found"
						ex 111
					}
				}
				unab `option' : ``option''
				if `:word count ``option''' > 1 {
					di as err "option `option': too many variables specified"
					ex 103
				}
			}
			loc `data'advars : list `data'advars | `option'
		}
	}
	foreach option in id t1vars t2vars t3vars ttest signrank {
		if !`:list survey`option' === bc`option'' {
			di as err "option `option': ``option'' expands or unabbreviates to different variable lists in survey and back check data"
			ex 198
		}
		loc `option' : copy loc survey`option'
	}

	* duplicate variable specification
	* within options
	foreach option in id t1vars t2vars t3vars enumerator enumteam backchecker bcteam ttest signrank keepsurvey keepbc {
		loc dups : list dups `option'
		if "`dups'" != "" {
			di as err "option `option': variable `:word 1 of `dups'' specified twice"
			ex 198
		}
	}
	* across options
	loc alloptions `""id t1vars t2vars t3vars enumerator enumteam backchecker bcteam" "id enumerator enumteam backchecker bcteam keepsurvey" "id backchecker bcteam keepbc""'
	foreach options of loc alloptions {
		loc nopts : word count `options'
		forv i = 1/`=`nopts' - 1' {
			loc option1 : word `i' of `options'
			forv j = `=`i' + 1'/`nopts' {
				loc option2 : word `j' of `options'
				loc shared : list `option1' & `option2'
				if "`shared'" != "" {
					di as err "variable `:word 1 of `shared'' specified in options `option1' and `option2'"
					ex 198
				}
			}
		}
	}

	* reserved variable names
	loc allvars `id' `tvars' `enumerator' `backchecker' `enumteam' `bcteam' `keepsurvey' `keepbc'
	foreach reserved in type variable survey back_check differences total error_rate {
		if `:list reserved in allvars' {
			di as err "`reserved' is a reserved variable name"
			ex 198
		}
	}

	* ttest, signrank
	foreach option in ttest signrank {
		loc not23 : list `option' - t2vars
		loc not23 : list not23 - t3vars
		if "`not23'" != "" {
			di as err "option `option': `:word 1 of `not23'' not type 2 or type 3 variable"
			ex 198
		}
	}

	* okrange
	while "`okrange'" != "" {
		gettoken varmin okrange : okrange, parse(",")
		gettoken comma  okrange : okrange, parse(",")
		gettoken max    okrange : okrange, parse(",")
		gettoken comma  okrange : okrange, parse(",")

		gettoken v min : varmin
		cap unab var : `v'
		if _rc {
			di as err "option okrange: variable `v' not found"
			ex 111
		}
		if `:word count `var'' > 1 {
			di as err "option okrange: `v' specifies too many variables"
			ex 103
		}
		if !`:list var in tvars' {
			di as err "option okrange: `var' not type 1, type 2, or type 3 variable"
			ex 198
		}
		if `:list var in rangevars' {
			di as err "option okrange: multiple ranges attached to `var'"
			ex 198
		}
		loc rangevars : list rangevars | var

		loc min = trim("`min'")
		loc max = trim("`max'")
		if substr("`min'", 1, 1) != "[" | substr("`max'", -1, 1) != "]" {
			di as err "invalid option okrange"
			ex 198
		}
		loc min = substr("`min'", 2, .)
		loc max = substr("`max'", 1, length("`max'") - 1)
		if wordcount("`min'") > 1 | wordcount("`max'") > 1 {
			di as err "option okrange: invalid range"
			ex 198
		}
		loc `var'perc = strpos("`min'", "%")
		if ``var'perc' + strpos("`max'", "%") == 1 {
			di as err "option okrange: range endpoints must be both absolute or both relative"
			ex 198
		}
		if ``var'perc' {
			loc min = substr("`min'", 1, length("`min'") - 1)
			loc max = substr("`max'", 1, length("`max'") - 1)
		}
		if `min' > `max' {
			di as err "option okrange: range min greater than max"
			ex 198
		}
		if `min' > 0 | `max' < 0 {
			di as err "option okrange: range does not include 0"
			ex 198
		}
		loc `var'min `min'
		loc `var'max `max'
	}

	foreach data in survey bc {
		use "``data'data'"

		* number of observations
		if !_N {
			di as err "no observations in ``data'name' data"
			ex 2000
		}

		* confirm numeric variables
		foreach var in ``data'advars' `ttest' `signrank' `rangevars' {
			cap confirm numeric v `var'
			if _rc {
				di as err "'`var'' found where numeric variable expected in ``data'name' data"
				ex 198
			}
		}

		* isid
		cap isid `id'
		if _rc {
			loc nvars : word count `id'
			di as err "`=plural(`nvars', "variable")' `id' `=plural(`nvars', "does", "do")' not uniquely identify observations in ``data'name' data"
			ex 459
		}

		* id types
		foreach var of loc id {
			cap confirm numeric v `id'
			loc isnumid`data' `isnumid`data'' `=!_rc'
		}

		* bc_ prefix
		cap ds bc_*
		if !_rc {
			di as err "variable `:word 1 of `r(varlist)'' has illegal prefix bc_ in ``data'name' data"
			ex 198
		}

		* enclosable by compound quotes
		tempvar noenclose
		qui ds `id' `tvars', has(type string)
		foreach var in `r(varlist)' {
			egen `noenclose' = total(strpos(`var', "`") | strpos(`var', `"""' + "'"))
			if `noenclose'[1] {
				di as err "`var' contains `" `" or ""' "' in ``data'name' data"
				ex 198
			}
			drop `noenclose'
		}

		keep `id' `tvars' ``data'advars' `keep`data''

		* save formats
		foreach var of loc keep`data' {
			loc keep`data'f `keep`data'f' `:format `var''
		}

		* modify strings
		if "`lower'`upper'`nosymbol'`trim'" != "" {
			qui ds `tvars', has(type string)
			foreach var in `r(varlist)' {
				if "`lower'`upper'" != "" qui replace `var' = `lower'`upper'(`var')
				if "`nosymbol'" != "" {
					foreach symbol in . , ! ? ' / ; : ( ) ` ~ @ # $ % ^ & * - _ = + [ ] { } \ | < > {
						qui replace `var' = subinstr(`var', "`symbol'", " ", .)
					}
					qui replace `var' = subinstr(`var', `"""', " ", .)
				}
				if "`trim'" != "" qui replace `var' = trim(itrim(`var'))
			}
		}

		* rename variables in back check data
		if "`data'" == "bc" {
			* variable name length
			foreach var of loc tvars {
				cap confirm new v bc_`var'
				if _rc {
					di as err "variable name '`var'' exceeds 29 characters"
					ex 198
				}
			}

			* rename
			foreach var of loc tvars {
				ren `var' bc_`var'
			}
			foreach var of loc keepbc {
				cap confirm v bc_`var'
				if _rc ren `var' bc_`var'
				loc bckeepbc `bckeepbc' bc_`var'
			}
		}

		* save modified data set
		sort `id'
		tempfile `data'
		qui save ``data''
	}

	* id types
	if !`:list isnumidsurvey == isnumidbc' {
		di as err "id types differ in survey and back check data"
		ex 198
	}
	***end***

	***produce data set***
	* merge
	qui merge `id' using `survey'

	* ids in back check but not survey data
	qui count if _merge == 3
	if !r(N) {
		di as err "there are no shared IDs between survey and back check data"
		ex 2000
	}
	qui count if _merge == 1
	if r(N) {
		di "{txt}note: the following ids appear in the back check data but not the survey data and will be dropped."
		sort `id'
		l `id' if _merge == 1, noo
	}
	qui drop if _merge != 3

	* tvars types
	foreach var of loc tvars {
		qui ds `var' bc_`var', has(type numeric)
		if `:word count `r(varlist)'' == 1 {
			if "`r(varlist)'" == "`var'" di as err "variable `var' is numeric in the survey data and string in the back check data"
			else di as err "variable `var' is string in the survey data and numeric in the back check data"
			ex 198
		}
	}

	* attach survey value labels to back check tvars if not labeled and vice versa
	foreach var of loc tvars {
		loc surveylab : val la `var'
		loc bclab : val la bc_`var'
		if "`bclab'" == "" & "`surveylab'" != "" la val bc_`var' `surveylab'
		else if "`surveylab'" == "" & "`bclab'" != "" la val `var' `bclab'
	}

	* create postfile
	foreach var of loc id {
		loc idpost `idpost' `:type `var'' `var'
	}
	tempname pf
	tempfile byobs
	postfile `pf' `idpost' type str32 variable str244 survey str244 back_check diff using `byobs'

	* post
	sort `enumerator' `id'
	tempvar decvar bcdecvar
	foreach var of loc tvars {
		* use value label instead of number for variables survey and back_check
		loc uselab = "`:val la `var''" != "" & "`nolabel'" == ""
		if `uselab' {
			qui dec `var', gen(`decvar')
			qui dec bc_`var', gen(`bcdecvar')
		}

		* determine type/format of `var'
		cap confirm numeric v `var'
		loc type = cond(_rc, "str", "num")
		loc format : format `var'

		* determine whether `var' is type 1, 2, or 3
		loc ttype : list var in t1vars
		if !`ttype' {
			loc ttype : list var in t2vars
			if `ttype' loc ttype 2
			else loc ttype 3
		}

		* loop through observations
		forv i = 1/`=_N' {
			* option exclude
			if "`exclnum'" == "" loc post 1
			else loc post = bc_`var'[`i'] != `excl`type''
			if `post' {
				* prepare id values for post
				loc idpost
				foreach idvar of loc id {
					loc idval = `idvar'[`i']
					cap confirm str v `idvar'
					if !_rc loc idval `"`"`idval'"'"'
					loc idpost `idpost' (`idval')
				}

				* prepare survey and back check values for post
				if `uselab' {
					if mi(`decvar'[`i']) loc val = string(`var'[`i'], "`format'")
					else loc val = `decvar'[`i']

					if mi(`bcdecvar'[`i']) loc bcval = string(bc_`var'[`i'], "`format'")
					else loc bcval = `bcdecvar'[`i']
				}
				else {
					if "`type'" == "num" {
						loc val = string(`var'[`i'], "`format'")
						loc bcval = string(bc_`var'[`i'], "`format'")
					}
					else {
						loc val = `var'[`i']
						loc bcval = bc_`var'[`i']
					}
				}

				* prepare diff for post
				loc diff = `var'[`i'] != bc_`var'[`i']
				if `diff' {
					* option okrange
					if `:list var in rangevars' {
						if ``var'perc' loc diff = bc_`var'[`i'] <= (1 + ``var'min' / 100) * `var'[`i'] | ///
							bc_`var'[`i'] >= (1 + ``var'max' / 100) * `var'[`i']
						else loc diff = bc_`var'[`i'] <= `var'[`i'] + ``var'min' | bc_`var'[`i'] >= `var'[`i'] + ``var'max'
					}
					else loc diff 1

					* option nodiff
					if `diff' & "`nodiffnum'" != "" loc diff = !inlist(bc_`var'[`i'], `nodiff`type'')
				}

				* post
				post `pf' `idpost' (`ttype') ("`var'") (`"`val'"') (`"`bcval'"') (`diff')
			}
		}
		if `uselab' drop `decvar' `bcdecvar'
	}

	* close post file
	postclose `pf'

	* add value labels/formats to id; add administrator and "keep" variables; add variable labels
	use `byobs', clear
	tempvar n
	gen `n' = _n
	sort `id'
	qui save `byobs', replace
	use `survey', clear
	sort `id'
	qui merge `id' using `byobs'
	qui drop if _merge != 3
	drop _merge
	sort `id'
	qui merge `id' using `bc'
	qui drop if _merge != 3
	drop _merge
	sort `n'
	drop `n'
	order `id' `enumerator' `enumteam' `backchecker' `bcteam' type variable survey back_check diff `keepsurvey' `bckeepbc'
	if "`nolabel'" != "" {
		if `:list sizeof keepsurvey' | `:list sizeof bckeepbc' {
			qui ds `keepsurvey' `bckeepbc', has(t numeric)
			if "`r(varlist)'" != "" ///
				la val `r(varlist)'
		}
	}
	la var type "Variable type"
	cap la l vartype
	if _rc loc label vartype
	else {
		tempname label
		cap la l `label'
		while !_rc {
			tempname label
			cap la l `label'
		}
	}
	la def `label' 1 "type 1" 2 "type 2" 3 "type 3"
	la val type `label'
	la var variable "Variable"
	la var survey "Value in survey data"
	la var back_check "Value in back check data"
	la var diff "Difference between survey and back check"

	qui save `byobs', replace

	drop `:list tvars - keepsurvey'
	foreach var in `:list tvars - keepbc' {
		drop bc_`var'
	}

	* option full
	if "`full'" == "" {
		qui keep if diff
		drop diff
	}

	* save as .csv/.dta
	loc csvwarn 0
	if "`dta'" == "" {
		qui outsheet using "`filename'", c `replace'
		qui insheet using "`filename'", c clear non
		qui ds
		foreach var in `r(varlist)' {
			if mi(`var'[1]) {
				loc csvwarn 1
				continue, break
			}
		}
	}
	else {
		qui compress
		qui save "`filename'", `replace'
	}
	***end***

	***display stats***
	use `byobs', clear

	* enumerator checks
	forv type = 1/2 {
		if "`t`type'vars'" != "" {
			di _n "{txt}Completing {res:enumerator} checks for type {res:`type'} variables..."

			* enumerators with high error rates
			if "`enumerator'" != "" {
				if !`showall' loc message Displaying enumerators with error rates above {res:`=100 * `okrate''%}...
				else loc message Displaying enumerator error rates...
				errorrate, type(`type') by1(`enumerator') by1name(enumerator) message("`message'") okrate(`okrate') keep
				loc varbyenum = r(high)
				tempname enum`type'
				mat `enum`type'' = r(rates)
				loc retenum `"`retenum' "ret mat enum`type' = `enum`type''""'

				tempvar highenum
				qui gen `highenum' = error_rate > `okrate' & !mi(error_rate)
				drop differences total error_rate
			}
			else loc varbyenum 0

			* enumerator team error rates
			if "`enumteam'" != "" {
				errorrate, type(`type') by1(`enumteam') by1name(enum team) message("Displaying enumerator team error rates...")
				tempname enumteam`type'
				mat `enumteam`type'' = r(rates)
				loc retenumteam `"`retenumteam' "ret mat enumteam`type' = `enumteam`type''""'
			}

			* variable error rates
			if `type' == 1 & !`showall' loc message Displaying variables with error rates above {res:`=100 * `okrate''%}...
			else loc message Displaying variable error rates...
			errorrate, type(`type') by1(variable) message("`message'") okrate(`=cond(`type' == 1, `okrate', -1)') strictreturn
			if `type' == 1 {
				qui errorrate, type(1) by1(variable) strictreturn
				tempname var1
				mat `var1' = r(rates)
				loc retvar `""ret mat var1 = `var1'""'
			}
			else {
				tempname var2
				mat `var2' = r(rates)
				loc retvar `"`retvar' "ret mat var2 = `var2'""'
			}

			* variables with high error rates for enumerators with high error rates
			if `varbyenum' {
				if !`showall' loc message Displaying variables with high error rates for enumerators with high error rates...
				else loc message Displaying variable error rates by enumerator...
				errorrate if `highenum', type(`type') by1(`enumerator') by2(variable) message("`message'") okrate(`okrate')
			}

			* back checker error rates
			if "`backchecker'" != "" {
				errorrate, type(`type') by1(`backchecker') by1name("back checker") message("Displaying back checker error rates...")
				tempname backchecker`type'
				mat `backchecker`type'' = r(rates)
				loc retbackchecker `"`retbackchecker' "ret mat backchecker`type' = `backchecker`type''""'
			}

			* back checker team error rates
			if "`bcteam'" != "" {
				errorrate, type(`type') by1(`bcteam') by1name("bc team") message("Displaying back checker team error rates...")
				tempname bcteam`type'
				mat `bcteam`type'' = r(rates)
				loc retbcteam `"`retbcteam' "ret mat bcteam`type' = `bcteam`type''""'
			}

			* back checks with high error rates (option showid)
			if substr("`showid'", -1, 1) == "%" {
				loc if error_rate >= `=`=substr("`showid'", 1, length("`showid'") - 1)' / 100'
				loc message Displaying back checks with error rates of at least {res:`showid'}...
			}
			else {
				loc if differences >= `showid'
				loc message Displaying back checks with at least {res:`showid'} `=plural(`showid', "difference")'...
			}
			errorrate if `if', type(`type') by1(`id') message("`message'") keep
			qui count if `if' & type == `type'
			loc retshowid `"`retshowid' "return scalar showid`type' = `=r(N) != 0'""'
			drop differences total error_rate
		}
	}

	* stability checks
	foreach type in 2 3 {
		loc ttestvars    : list t`type'vars & ttest
		loc signrankvars : list t`type'vars & signrank
		if (`type' == 2 & "`ttestvars'`signrankvars'" != "") | (`type' == 3 & "`t`type'vars'" != "") {
			di _n "{txt}Completing {res:stability} checks for type {res:`type'} variables..."

			* type 3 variables: variable error rates
			if `type' == 3 {
				errorrate, type(`type') by1(variable) message("Displaying variable error rates...") strictreturn
				tempname var3
				mat `var3' = r(rates)
				loc retvar `"`retvar' "ret mat var3 = `var3'""'
			}

			* ttest and signrank
			loc tteststats N_1 N_2 p_l p_u p se t sd_1 sd_2 mu_1 mu_2 df_t
			loc signrankstats N_neg N_pos N_tie sum_pos sum_neg z Var_a
			foreach test in ttest signrank {
				loc statsrow
				foreach stat of loc `test'stats {
					loc statsrow `statsrow'`=cond("`statsrow'" == "", "", ", ")'r(`stat')
				}

				tempname statsmat
				foreach var of loc `test'vars {
					qui count if variable == "`var'" & !mi(`var', bc_`var')
					if r(N) {
						di _n "{txt}{cmd:`test'} for {res:`var'}:"
						if "`test'" == "ttest" ttest `var' == bc_`var' if variable == "`var'", level(`level')
						else signrank `var' = bc_`var' if variable == "`var'"
						loc row `statsrow'
					}
					else {
						di _n "{txt}no observations for {res:`var'}; skipping {cmd:`test'}"
						loc row
						forv i = 1/`:word count `statsrow'' {
							loc row `row'`=cond("`row'" == "", "", ", ")'.
						}
					}
					cap confirm mat `statsmat'
					mat `statsmat' = `=cond(_rc, "", "`statsmat' \ ")'(`row')
				}

				if "``test'vars'" != "" {
					mat rown `statsmat' = ``test'vars'
					mat coln `statsmat' = ``test'stats'
					loc ret`test' `"`ret`test'' "ret mat `test'`type' = `statsmat'""'
				}
			}
		}
	}
	***end***

	if `csvwarn' di _n "{txt}note: the comparisons .csv contains commas and is misaligned."

	`:word 2 of `retshowid''
	`:word 1 of `retshowid''
	foreach ret in signrank ttest var bcteam enumteam backchecker enum {
		forv i = `:word count `ret`ret'''(-1)1 {
			`:word `i' of `ret`ret'''
		}
	}
end


/* -------------------------------------------------------------------------- */
					/* parsing programs		*/

pr parse_okrange, sclass
	while `:length loc 0' {
		gettoken varmin 0 : 0, parse(",")
		gettoken comma1 0 : 0, parse(",")
		gettoken max    0 : 0, parse(",")
		gettoken comma2 0 : 0, parse(",")

		if "`comma1'" != "," | !inlist("`comma2'", ",", "") {
			di as err "option okrange() invalid"
			ex 198
		}

		* Parse the varname.
		gettoken var min : varmin
		if `:list sizeof var' > 1 {
			di as err "option okrange(): `var': too many variables specified"
			ex 103
		}
		loc vars "`vars' `"`var'"'"

		* Parse the min and the max.

		if `:list sizeof min' > 1 | `:list sizeof max' > 1 {
			di as err "option okrange() invalid"
			ex 198
		}

		* Remove the brackets.
		* Remove leading and trailing white space.
		loc min : list retok min
		loc max : list retok max
		mata: st_local("maxlast", substr(st_local("max"), -1, 1))
		if substr("`min'", 1, 1) != "[" | "`maxlast'" != "]" {
			di as err "option okrange() invalid"
			ex 198
		}
		loc min : subinstr loc min "[" ""
		mata: st_local("max", ///
			substr(st_local("max"), 1, strlen(st_local("max")) - 1))

		* Parse percentages.
		foreach local in min max {
			mata: st_local("`local'perc", ///
				strofreal(substr(st_local("`local'"), -1, 1) == "%"))
			if ``local'perc' {
				mata: st_local("`local'", substr(st_local("`local'"), 1, ///
					strlen(st_local("`local'")) - 1))
			}
		}
		if `minperc' + `maxperc' == 1 {
			di as err "option okrange(): range endpoints must be " ///
				"both absolute or both relative"
			ex 198
		}
		loc allperc `allperc' `minperc'

		cap conf n `min'
		if _rc {
			di as err "option okrange(): invalid minimum"
			ex 198
		}

		cap conf n `max'
		if _rc {
			di as err "option okrange(): invalid maximum"
			ex 198
		}

		if `min' > `max' {
			di as err "option okrange(): range minimum greater than maximum"
			ex 198
		}

		if `min' > 0 | `max' < 0 {
			di as err "option okrange(): range does not include 0"
			ex 198
		}

		loc allmin `allmin' `min'
		loc allmax `allmax' `max'
	}

	sret loc varlist	"`vars'"
	sret loc perc		`allperc'
	sret loc min		`allmin'
	sret loc max		`allmax'
end

					/* parsing programs		*/
/* -------------------------------------------------------------------------- */


/* -------------------------------------------------------------------------- */
					/* -errorrate-			*/

* show table of error rates and save error rates matrix in r(rates)
pr errorrate, rclass
	qui gen differences = .
	qui gen total = .
	qui gen error_rate = .
	syntax [if/], type(integer) by1(varname) [by1name(str) by2(varname) message(str) okrate(real -1) keep strictreturn]
	drop differences total error_rate

	qui bys `by1' `by2': egen differences = total(diff & type == `type')
	qui by `by1' `by2': egen total = total(type == `type')
	qui by `by1' `by2': gen error_rate = differences / total

	if `okrate' == -1 {
		return scalar high = .

		qui count `=cond(`:length loc if', "if", "")' `if'
		loc table = r(N) != 0
	}
	else {
		tempvar higherr
		qui gen `higherr' = error_rate > `okrate' & !mi(error_rate)
		qui count if `higherr' `=cond(`:length loc if', "&", "")' `if'
		return scalar high = r(N) != 0

		loc table = return(high)
	}

	if `table' {
		if "`message'" != "" di _n "{txt}`message'"
		format error_rate %9.4f
		gsort -error_rate -total `by1' `by2'

		tempvar display tag
		if "`by2'" == "" {
			if `okrate' == -1 gen `display' = type == `type'
			else gen `display' = `higherr'
			if `:length loc if' qui replace `display' = `display' & `if'
			egen `tag' = tag(`by1') if `display'
			l `by1' error_rate differences total if `display' & `tag', ab(32) noo
		}
		else {
			cap confirm str v `by1'
			loc isstr = !_rc
			if `okrate' == -1 gen `display' = type == `type'
			else gen `display' = `higherr'
			if `:length loc if' qui replace `display' = `display' & `if'
			egen `tag' = tag(`by1' `by2') if `display'
			qui levelsof `by1' if `display', miss
			foreach level in `r(levels)' {
				if `isstr' loc level `"`"`level'"'"'
				l `by1' `by2' error_rate differences total if `display' & `tag' & `by1' == `level', ab(32) noo
			}
		}
	}

	if "`by2'" == "" {
		tempname ratesmat
		cap confirm str v `by1'
		loc isstr = !_rc
		qui levelsof `by1' `=cond("`strictreturn'" == "", "", "if type == `type'")', loc(levels) miss
		foreach level of loc levels {
			if `isstr' loc level `"`"`level'"'"'
			qui su error_rate if `by1' == `level'
			if r(N) loc rate = r(max)
			else loc rate .
			if `isstr' loc row `rate'
			else loc row `level', `rate'
			cap confirm mat `ratesmat'
			mat `ratesmat' = `=cond(_rc, "", "`ratesmat' \ ")'(`row')
		}

		if `isstr' {
			mat coln `ratesmat' = "error rate"
			mat rown `ratesmat' = `levels'
		}
		else mat coln `ratesmat' = "`=cond("`by1name'" == "", "`by1'", "`by1name'")'" "error rate"

		ret mat rates = `ratesmat'
	}

	if "`keep'" == "" drop differences total error_rate
end

					/* -errorrate-			*/
/* -------------------------------------------------------------------------- */
