*! version 3.6.0  04mar2013
program define cscript , rclass
	version 9
	set linesize 79
	while !("`1'" == "adofile" | "`1'"=="adofiles" | "`1'"=="") {
		local stuff `stuff' `1'
		mac shift
	}
	local dup = 79-6-length("`stuff'")
	di in smcl in gr "{hline `dup'}" `"BEGIN `stuff'"'

	mac shift			/* adofile[s] */
	while "`1'" != "" { 
		di
		di "-> which `1'"
		which `1'
		mac shift
	}

	drop _all 
	label drop _all
	macro drop _all
	macro drop S_*
	program drop _all
	scalar drop _all
	matrix drop _all
	constraint drop _all
	discard
	mata: mata clear
	set type float 
	set maxiter 100
	set scheme s2color8
	set emptycells keep
	set showbaselevels
	set showemptycells
	set showomitted
	set lstretch
	set cformat
	set pformat
	set sformat
	set fvwrap 1
	set fvwrapon word
	set fvlabel on

	if "$S_FLAVOR"!="Small" {
		qui set matsize 400
	}

end
