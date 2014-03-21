*! version 1.3.1 Matthew White 21mar2014
program bcstats, rclass
	vers 9

	#d ;
	syntax, Surveydata(str) Bcdata(str) id(passthru)
		/* comparison variables */
		[t1vars(passthru) t2vars(passthru) t3vars(passthru)]
		/* enumerator checks */
		[ENUMerator(passthru) BACKchecker(passthru)
		ENUMTeam(passthru) BCTeam(passthru) SHowid(str) showall]
		/* stability checks */
		[ttest(passthru) Level(real -1) signrank(passthru)]
		/* comparisons dataset */
		[KEEPSUrvey(passthru) keepbc(passthru) full NOLabel
		FILEname(str) replace dta]
		/* string comparison */
		[LOwer UPper NOSymbol TRim]
		/* other options */
		[okrate(real 0.1) okrange(str) nodiff(str asis) exclude(str asis)]
	;
	#d cr

	***check syntax***

	* Parse -okrange()-.
	parse_okrange `okrange'
	loc rangevars		"`s(varlist)'"
	loc okrange_perc	`s(perc)'
	loc okrange_min		`s(min)'
	loc okrange_max		`s(max)'

	preserve

	* Unabbreviate and expand varlists.
	#d ;
	parse_opt_varlists,
		surveydata(`"`surveydata'"') bcdata(`"`bcdata'"') rangevars(`rangevars')
		`id' `t1vars' `t2vars' `t3vars' `ttest' `signrank'
		`enumerator' `enumteam' `keepsurvey'
		`backchecker' `bcteam' `keepbc'
		varname(enumerator enumteam backchecker bcteam)
		numeric(enumerator enumteam backchecker bcteam ttest signrank)
	;
	#d cr

	* Check the comparison variables.
	loc tvars `t1vars' `t2vars' `t3vars'
	if !`:list sizeof tvars' {
		* Using -icd9- as a template.
		di as err "must specify one of options t1vars(), t2vars(), or t3vars()"
		ex 198
	}

	* Finish processing -okrange()-.

	foreach var of loc rangevars {
		if !`:list var in tvars' {
			di as err "option okrange(): " ///
				"`var' not type 1, type 2, or type 3 variable"
			ex 198
		}
	}

	forv i = 1/`:list sizeof rangevars' {
		loc var :			word `i' of `rangevars'
		loc `var'perc :		word `i' of `okrange_perc'
		loc `var'min :		word `i' of `okrange_min'
		loc `var'max :		word `i' of `okrange_max'
	}

	* enumerator checks
	foreach option in enumerator backchecker enumteam bcteam showid {
		if "``option''" != "" & "`t1vars'`t2vars'" == "" {
			di as err "option `option' must be specified with option t1vars or t2vars"
			ex 198
		}
	}

	* Parse -showid()-.
	if !`:length loc showid' ///
		loc showid 30%
	parse_showid `showid'
	loc showid_val  `s(val)'
	loc showid_perc `s(perc)'

	* stability checks
	foreach option in ttest signrank {
		if "``option''" != "" & "`t2vars'`t3vars'" == "" {
			di as err "option `option' must be specified with option t2vars or t3vars"
			ex 198
		}
	}

	* Parse -filename()-.
	loc ext = cond("`dta'" == "", ".csv", ".dta")
	if !`:length loc filename' ///
		loc filename bc_diffs`ext'
	else {
		* Add a file extension to `filename' if necessary.
		mata: if (pathsuffix(st_local("filename")) == "") ///
			st_local("filename", st_local("filename") + st_local("ext"));;
	}

	* Check -filename()- and -replace-.
	cap conf new f `"`filename'"'
	if ("`replace'" == "" & _rc) | ("`replace'" != "" & !inlist(_rc, 0, 602)) {
		conf new f `"`filename'"'
		ex `=_rc'
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

	* -lower- and -upper-
	if "`lower'" != "" & "`upper'" != "" {
		di as err "options lower and upper are mutually exclusive"
		ex 198
	}

	* duplicate variable specification
	* across options
	#d ;
	loc alloptions "
		"id t1vars t2vars t3vars enumerator enumteam backchecker bcteam"
		"id enumerator enumteam backchecker bcteam keepsurvey"
		"id backchecker bcteam keepbc"
	";
	#d cr
	foreach options of loc alloptions {
		loc nopts : word count `options'
		forv i = 1/`=`nopts' - 1' {
			loc option1 : word `i' of `options'
			forv j = `=`i' + 1'/`nopts' {
				loc option2 : word `j' of `options'
				loc shared : list `option1' & `option2'
				if `:list sizeof shared' {
					gettoken first : shared
					di as err "variable `first' specified in " ///
						"options `option1'() and `option2'()"
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

	loc surveyname survey
	loc bcname back check
	* "advars" suffix for "administrator variables"
	loc surveyadvars `enumerator' `enumteam'
	loc bcadvars `backchecker' `bcteam'
	foreach data in survey bc {
		use `"``data'data'"'

		* number of observations
		if !_N {
			di as err "no observations in ``data'name' data"
			ex 2000
		}

		* isid
		cap isid `id'
		if _rc {
			loc nvars : word count `id'
			di as err "`=plural(`nvars', "variable")' `id' `=plural(`nvars', "does", "do")' not uniquely identify observations in ``data'name' data"
			ex 459
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
		qui outsheet using `"`filename'"', c `replace'
		qui insheet  using `"`filename'"', c non clear
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
		qui save `"`filename'"', `replace'
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
			if `showid_perc' {
				loc if error_rate >= `showid_val' / 100
				loc message Displaying back checks with error rates of at least {res:`showid'}...
			}
			else {
				loc if differences >= `showid_val'
				loc message Displaying back checks with at least {res:`showid_val'} `=plural(`showid_val', "difference")'...
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
		gettoken varmin 0 : 0, p(",")
		gettoken comma1 0 : 0, p(",")
		gettoken max    0 : 0, p(",")
		gettoken comma2 0 : 0, p(",")

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
		loc min : list retok min
		loc max : list retok max

		* This check should come after the brackets are removed: "[ -x, y ]" is
		* four tokens, but it is a permitted syntax.
		if `:list sizeof min' > 1 | `:list sizeof max' > 1 {
			di as err "option okrange() invalid"
			ex 198
		}

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

pr parse_showid, sclass
	if `:list sizeof 0' != 1 {
		di as err "option showid() invalid"
		ex 198
	}

	mata: st_local("perc", strofreal(substr(st_local("0"), -1, 1) == "%"))
	if !`perc' ///
		loc val : copy loc 0
	else {
		mata: st_local("val", ///
			substr(st_local("0"), 1, strlen(st_local("0")) - 1))
	}

	cap conf n `val'
	if _rc {
		di as err "option showid() invalid"
		ex 198
	}

	if `perc' {
		if !inrange(`val', 0, 100) {
			di as err "showid rate must be between 0% and 100%"
			ex 198
		}
	}
	else if `val' < 0 {
		di as err "showid value must be nonnegative"
		ex 198
	}

	sret loc val  `val'
	sret loc perc `perc'
end

pr error_unab_diff
	syntax anything, opt(name)

	gettoken anything rest : anything
	if `:length loc rest' ///
		err 198

	di as err "option `opt'(): `anything' expands or unabbreviates to " ///
		"different variable lists in survey and back check data"
	ex 198
end

pr parse_opt_varlists
	loc optsboth	id t1vars t2vars t3vars ttest signrank
	loc optssurvey	enumerator enumteam keepsurvey
	loc optsbc		backchecker bcteam keepbc
	loc opts `optsboth' `optssurvey' `optsbc'

	foreach opt of loc opts {
		loc optssyntax `optssyntax' `opt'(str)
	}
	syntax, surveydata(str) bcdata(str) ///
		[rangevars(str asis) `optssyntax'] ///
		[varname(namelist) numeric(namelist)]

	foreach data in survey bc {
		loc dataname = cond("`data'" == "survey", "survey", "back check") + ///
			" data"

		loc fn : copy loc `data'data
		qui d using `"`fn'"'
		if r(N) ///
			qui u in 1 using `"`fn'"', clear
		else ///
			qui u `"`fn'"', clear

		foreach opt of loc optsboth {
			loc max = cond(`:list opt in varname', "max(1)", "")
			cap noi unab `opt'`data' : ``opt'', min(0) `max' name(`opt'())
			if _rc {
				di as err "in `dataname'"
				ex `=_rc'
			}

			* Sorting because even if ``opt'survey' and ``opt'bc' contain the
			* same variables, they may be in different orders after -unab-.
			foreach var in `:list sort `opt'`data'' {
				cap conf numeric var `var'
				loc `opt'`data'isnum ``opt'`data'isnum' `=!_rc'
			}
		}

		foreach var of loc rangevars {
			* Do not specify -name()-: we are parsing a single varlist, not the
			* entire option. Specifying -name()- would result in error messages
			* that are difficult to interpret.
			cap noi unab unab : `var', max(1)
			if _rc {
				di as err "in `dataname'"
				di as err "option okrange() invalid"
				ex `=_rc'
			}
			loc rangevars`data' `rangevars`data'' `unab'

			cap conf numeric var `var'
			if _rc {
				di as err "okrange():  `var':  string variable not allowed"
				ex 109
			}
		}

		foreach opt of loc opts`data' {
			loc max = cond(`:list opt in varname', "max(1)", "")
			unab `opt' : ``opt'', min(0) `max' name(`opt'())

			if `:list opt in numeric' {
				loc 0 , `opt'(``opt'')
				syntax, [`opt'(varlist num)]
			}
		}
	}

	* Check for differences across the datasets.

	foreach opt of loc optsboth {
		if !`:list `opt'survey === `opt'bc' {
			error_unab_diff "``opt''", opt(`opt')
			/*NOTREACHED*/
		}
		loc `opt' ``opt'survey'

		loc sort : list sort `opt'
		forv i = 1/`:list sizeof sort' {
			loc var :			word `i' of `sort'
			loc isnumsurvey :	word `i' of ``opt'surveyisnum'
			loc isnumbc :		word `i' of ``opt'bcisnum'

			if `isnumsurvey' != `isnumbc' {
				di as err "option `opt'(): " ///
					"`var' is numeric in one dataset and string in the other"
				ex 109
			}
		}
	}

	forv i = 1/`:list sizeof rangevars' {
		loc var	:			word `i' of `rangevars'
		loc varsurvey :		word `i' of `rangevarssurvey'
		loc varbc :			word `i' of `rangevarsbc'

		if "`varsurvey'" != "`varbc'" {
			error_unab_diff `var', opt(okrange)
			/*NOTREACHED*/
		}
	}
	loc rangevars `rangevarssurvey'

	* Check numeric varlists.
	* Placing this check here means that the error message does not have to
	* include the dataset name: we have already confirmed that the variable is
	* the same type in both datasets.
	foreach opt of loc optsboth {
		if `:list opt in numeric' {
			loc 0 , `opt'(``opt'')
			syntax, [`opt'(varlist num)]
		}
	}

	* Check for duplicates.

	foreach opt of loc opts {
		loc dups : list dups `opt'
		gettoken first : dups
		if "`first'" != "" {
			di as err "option `opt'(): " ///
				"variable `first' mentioned more than once"
			ex 198
		}
	}

	loc dups : list dups rangevars
	gettoken first : dups
	if "`first'" != "" {
		di as err "option okrange(): multiple ranges specified for `first'"
		ex 198
	}

	* Return parsed options.
	foreach opt in `opts' rangevars {
		c_local `opt' "``opt''"
	}
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
