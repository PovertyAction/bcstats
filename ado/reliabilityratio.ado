pr reliabilityratio, rclass
	syntax, survey(varname) backcheck(varname)
	* Relability ratio

	* calculate the Simple Response Variance (SRV).
	tempvar diff
	qui generate `diff' = `survey' - `backcheck'
	qui summarize `diff'
	local srv = r(sd)^2 / 2
	drop `diff'

	* Calculate the variance of the back check variable.
	* We're using the back check variable instead of the survey variable,
	* thinking that the back check data is probably more reliable.
	qui summarize `backcheck'
	local variance = r(sd)^2

	return scalar rr = 1 - `srv' / `variance'
	return scalar srv = `srv'
	return scalar variance = `variance'
end
