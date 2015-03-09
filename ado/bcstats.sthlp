{smcl}
{* *! version 1.3.1 Matthew White 21mar2014}{...}
{title:Title}

{phang}
{cmd:bcstats} {hline 2} Compare survey and back check data,
producing a data set of comparisons


{marker syntax}{...}
{title:Syntax}

{p 8 10 2}
{cmd:bcstats,}
{opth s:urveydata(filename)} {opth b:cdata(filename)} {opth id(varlist)}
[{it:options}]


{* Using -help duplicates- as a template.}{...}
{synoptset 23 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{* Using -help ca postestimation- as a template.}{...}
{p2coldent:* {opth s:urveydata(filename)}}the survey data{p_end}
{p2coldent:* {opth b:cdata(filename)}}the back check data{p_end}
{p2coldent:* {opth id(varlist)}}the unique ID{p_end}

{syntab:Comparison variables}
{p2coldent:+ {opth t1vars(varlist)}}the list of
{help bcstats##type1:type 1 variables}{p_end}
{p2coldent:+ {opth t2vars(varlist)}}the list of
{help bcstats##type2:type 2 variables}{p_end}
{p2coldent:+ {opth t3vars(varlist)}}the list of
{help bcstats##type3:type 3 variables}{p_end}

{syntab:Enumerator checks}
{synopt:{opth enum:erator(varname)}}display enumerators with
high error rates and variables with high error rates for those enumerators;
{varname} in survey data is used{p_end}
{synopt:{opth back:checker(varname)}}display the error rates of
all back checkers; {varname} in back check data is used{p_end}
{synopt:{opth enumt:eam(varname)}}display the overall error rates of
all enumerator teams; {varname} in survey data is used{p_end}
{synopt:{opth bct:eam(varname)}}display the overall error rates of
all back check teams; {varname} in back check data is used{p_end}
{synopt:{cmdab:sh:owid(}{it:integer}[%]{cmd:)}}display unique IDs with
at least {it:integer} differences or at least an {it:integer}% error rate;
default is {cmd:showid(30%)}{p_end}
{synopt:{opt showall}}display the error rates of all enumerators, all variables,
and all variables for all enumerators{p_end}

{syntab:Stability checks}
{synopt:{opth ttest(varlist)}}run paired two-sample mean-comparison tests for
{varlist} in the back check and survey data using {helpb ttest}{p_end}
{synopt:{opt l:evel(#)}}set confidence level for {helpb ttest};
default is {cmd:level(95)}{p_end}
{synopt:{opth signrank(varlist)}}run
Wilcoxon matched-pairs signed-ranks tests for {varlist} in
the back check and survey data using {helpb signrank}{p_end}

{syntab:Comparisons data set}
{synopt:{opth keepsu:rvey(varlist)}}include {varlist} in the survey data in
the comparisons data set{p_end}
{synopt:{opth keepbc(varlist)}}include {varlist} in the back check data in
the comparisons data set{p_end}
{synopt:{opt full}}include all comparisons, not just differences{p_end}
{synopt:{opt nol:abel}}do not use value labels{p_end}
{synopt:{opth file:name(filename)}}save as {it:filename};
default is {cmd:filename(bc_diffs.csv)} or
{cmd:filename(bc_diffs.dta)} if {opt dta} is specified {p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt dta}}save data set as .dta file; default is .csv{p_end}

{syntab:Options}
{synopt:{opt okrate(#)}}the acceptable error rate;
default is {cmd:okrate(0.1)}{p_end}
{synopt:{cmd:okrange(}{varname} {it:range} [, {varname} {it:range} ...]{cmd:)}}do
not count a value of {varname} in the back check data as a difference if
it falls within {it:range} of the survey data{p_end}
{synopt:{cmd:nodiff(}{it:# string} [, {it:# string} ...]{cmd:)}}do not count
back check responses that equal {it:#} (for numeric variables) or
{it:string} (for string variables) as differences{p_end}
{synopt:{opt exclude(# string)}}do not compare back check responses that
equal {it:#} (for numeric variables) or
{it:string} (for string variables){p_end}
{synopt:{opt lo:wer}}convert all string variables to lower case before
comparing{p_end}
{synopt:{opt up:per}}convert all string variables to upper case before
comparing{p_end}
{synopt:{opt nos:ymbol}}replace symbols with spaces in string variables before
comparing{p_end}
{synopt:{opt tr:im}}remove leading or trailing blanks and
multiple, consecutive internal blanks in string variables before
comparing{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}* {opt surveydata()}, {opt bcdata()}, and {opt id()} are
required.{p_end}
{p 4 6 2}* {opt t1vars()}, {opt t2vars()}, or {opt t3vars()} is required.


{marker description}{...}
{title:Description}

{pstd}
{cmd:bcstats} compares back check data and survey data,
producing a data set of comparisons.
It completes enumerator checks for type 1 and type 2 variables and
stability checks for type 2 and type 3 variables.


{marker remarks}{...}
{title:Remarks}

{pstd}
The GitHub repository for {cmd:bcstats} is
{browse "https://github.com/PovertyAction/bcstats":here}.
Previous versions may be found there: see the tags.


{marker options}{...}
{title:Options}

{dlgtab:Comparison variables}

{phang}
{marker type1}
{opth t1vars(varlist)} specifies the list of type 1 variables.
Type 1 variables are expected to stay constant between
the survey and back check, and differences may result in action against
the enumerator. Display variables with high error rates and
complete enumerator checks.
See the Innovations for Poverty Action
{help bcstats##back_check_manual:back check manual} for
more on the three types.

{phang}
{marker type2}
{opth t2vars(varlist)} specifies the list of type 2 variables.
Type 2 variables may be difficult for enumerators to administer.
For instance, they may involve complicated skip patterns or many examples.
Differences may indicate the need for further training,
but will not result in action against the enumerator.
Display the error rates of all variables and
complete enumerator and stability checks.
See the Innovations for Poverty Action
{help bcstats##back_check_manual:back check manual} for
more on the three types.

{phang}
{marker type3}
{opth t3vars(varlist)} specifies the list of type 3 variables.
Type 3 variables are variables whose stability between
the survey and back check is of interest.
Differences will not result in action against the enumerator.
Display the error rates of all variables and complete stability checks.
See the Innovations for Poverty Action
{help bcstats##back_check_manual:back check manual} for
more on the three types.

{dlgtab:Stability checks}

{phang}
{opt level(#)} specifies the confidence level, as a percentage, for
confidence intervals calculated by {helpb ttest}.
The default is {cmd:level(95)} or as set by {helpb set level}.

{dlgtab:Comparisons data set}

{phang}
{opth keepbc(varlist)} specifies that variables in {varlist} in
the back check data are to be included in the comparisons data set.
Variables in {varlist} are renamed with the prefix {cmd:bc_} in
the comparisons data set.

{phang}
{opt nolabel} specifies that survey and back check responses are
not to be value-labeled in the comparisons data set.
Variables specified through {opt keepsurvey} or {opt keepbc} are
also not value-labeled.

{dlgtab:Options}

{phang}
{cmd:okrange(}{varname} {it:range} [, {varname} {it:range} ...]{cmd:)}
specifies that a value of {varname} in the back check data will not
be counted as a difference if it falls within {it:range} of the survey data.
{it:range} may be of the form {cmd:[}{it:-x}, {it:y}{cmd:]} (absolute) or
{cmd:[}{it:-x%}, {it:y%}{cmd:]} (relative).

{phang}
{cmd:nodiff(}{it:# string} [, {it:# string} ...]{cmd:)} specifies that
back check responses that equal {it:#} (for numeric variables) or
{it:string} (for string variables) will not be counted as differences,
regardless of what the survey response is.

{phang}
{opt exclude(# string)} specifies that
back check responses that equal {it:#} (for numeric variables) or
{it:string} (for string variables) will not be compared.
These responses will not affect error rates and
will not appear in the comparisons data set.
Used when the back check data set contains data for
multiple back check survey versions.

{phang}
{opt nosymbol} replaces the following characters in string variables with
a space before comparing:
{cmd:. , ! ? ' / ; : ( ) ` ~ @ # $ % ^ & * - _ + = [ ] { } | \ " < >}

{phang}
{opt trim} removes leading or trailing blanks and
multiple, consecutive internal blanks before comparing.
If {opt nosymbol} is specified,
this occurs after symbols are replaced with a space.


{marker examples}{...}
{title:Examples}

{pstd}Assume that missing values were not asked in
the back check survey version.{p_end}
{phang2}{cmd:bcstats, surveydata(bcstats_survey) bcdata(bcstats_bc) id(id) ///}{p_end}
{phang3}{cmd:okrate(0.09) okrange(gameresult [-1, 1], itemssold [-5%, 5%]) exclude(. "") ///}{p_end}
{phang3}{cmd:t1vars(gender) enumerator(enum) enumteam(enumteam) backchecker(bcer) ///}{p_end}
{phang3}{cmd:t2vars(gameresult) signrank(gameresult) ///}{p_end}
{phang3}{cmd:t3vars(itemssold) ttest(itemssold) ///}{p_end}
{phang3}{cmd:keepbc(date) keepsurvey(date) full replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:bcstats} saves the following in {cmd:r()}:

{* Using -help describe- as a template.}{...}
{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(showid1)}}1 if {opt showid()} displayed
unique IDs for type 1 variables and 0 otherwise{p_end}
{synopt:{cmd:r(showid2)}}1 if {opt showid()} displayed
unique IDs for type 2 variables and 0 otherwise{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(enum1)}}the type 1 variable error rates of all enumerators{p_end}
{synopt:{cmd:r(enum2)}}the type 2 variable error rates of all enumerators{p_end}
{synopt:{cmd:r(backchecker1)}}the type 1 variable error rates of
the back checkers{p_end}
{synopt:{cmd:r(backchecker2)}}the type 2 variable error rates of
the back checkers{p_end}
{synopt:{cmd:r(enumteam1)}}the type 1 variable error rates of
the enumerator teams{p_end}
{synopt:{cmd:r(enumteam2)}}the type 2 variable error rates of
the enumerator teams{p_end}
{synopt:{cmd:r(bcteam1)}}the type 1 variable error rates of
the back checker teams{p_end}
{synopt:{cmd:r(bcteam2)}}the type 2 variable error rates of
the back checker teams{p_end}
{synopt:{cmd:r(var1)}}the error rates of all type 1 variables{p_end}
{synopt:{cmd:r(var2)}}the error rates of all type 2 variables{p_end}
{synopt:{cmd:r(var3)}}the error rates of all type 3 variables{p_end}
{synopt:{cmd:r(ttest2)}}the results of {cmd:ttest} for type 2 variables{p_end}
{synopt:{cmd:r(ttest3)}}the results of {cmd:ttest} for type 3 variables{p_end}
{synopt:{cmd:r(signrank2)}}the results of {cmd:signrank} for
type 2 variables{p_end}
{synopt:{cmd:r(signrank3)}}the results of {cmd:signrank} for
type 3 variables{p_end}
{p2colreset}{...}


{marker references}{...}
{title:References}

{marker back_check_manual}{...}
{phang}
{browse "https://ipastorage.box.com/s/wvbz9wgpyhorw30sjyqo":Innovations for Poverty Action Back Check Manual}


{marker acknowledgements}{...}
{title:Acknowledgements}

{pstd}
Hana Scheetz Freymiller of Innovations for Poverty Action conceived of
the three variable types and
collaborated on the structure of the program.


{marker author}{...}
{title:Author}

{pstd}Matthew White{p_end}

{pstd}For questions or suggestions, submit a
{browse "https://github.com/PovertyAction/bcstats/issues":GitHub issue}
or e-mail researchsupport@poverty-action.org.{p_end}


{title:Also see}

{psee}
Help:  {manhelp ttest R}, {manhelp signrank R}

{psee}
User-written:  {helpb cfout}
