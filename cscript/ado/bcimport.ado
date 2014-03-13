pr bcimport
	vers 9

	syntax using/

	* Add the .csv extension to `using' if necessary.
	mata: if (pathsuffix(st_local("using")) == "") ///
		st_local("using", st_local("using") + ".csv");;

	qui insheet using `"`using'"', c n clear
	tempfile temp
	qui sa `temp'

	mata: st_local("dir", parentdir(st_local("using")))
	insheet_metadata using `"`dir'/metadata.csv"'
	mata: attach_metadata(st_local("temp"))

	cap conf f `"`dir'/value_labels.do"'
	if !_rc ///
		run `"`dir'/value_labels.do"'

	mata: st_local("dta", pathrmsuffix(st_local("using")) + ".dta")
	qui sa `"`dta'"', replace
end

pr insheet_metadata
	syntax using

	qui insheet `using', c n clear

	foreach var of var v* {
		cap conf n `=substr("`var'", 2, .)'
		if !_rc ///
			drop `var'
	}

	unab all : _all
	loc expected name format vallab varlab
	assert `:list all == expected'

	qui ds, has(t numeric)
	loc numvars `r(varlist)'
	if `:list sizeof numvars' {
		qui tostring `numvars', replace
		foreach var of loc numvars {
			qui replace `var' = "" if `var' == "."
		}
	}
end

vers 9

loc RS	real scalar
loc SS	string scalar
loc SR	string rowvector
loc SM	string matrix

mata:

`SS' parentdir(`SS' _fn)
{
	`SS' dir

	pragma unset dir
	pathsplit(_fn, dir, "")
	if (dir == "")
		dir = "."

	return(dir)
}

void attach_metadata(`SS' _fn)
{
	`RS' n, i
	`SR' all
	`SM' meta

	meta = st_sdata(., .)

	stata(sprintf(`"use `"%s"', clear"', _fn))

	all = st_varname(1..st_nvar())
	n = rows(meta)
	for (i = 1; i <= n; i++) {
		name = meta[i, 1]
		if (anyof(all, name)) {
			meta[i,]

			st_varformat(name, meta[i, 2])
			if (st_isnumvar(name))
				st_varvaluelabel(name, meta[i, 3])
			st_varlabel(name, meta[i, 4])
		}
	}
}

end
