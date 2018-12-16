title 'Oral Surgery - Survival Analysis';
options nodate pageno=1 formdlim='_';
options nodate nocenter pageno = 1; title; footnote;

ods graphics off;

data msckevin;
   set TMP1.msckevin;
run;

proc print data=msckevin (obs=100);
run;

data workingdata1 (DROP = ProcedureEvent EtCO2 InCo2 RespRate Pulse);
	set msckevin;
	format DateofTreatment date9.; 			* change the date to a readable format, (Shows month of treatment);
	m = month(DateofTreatment);				* Introduces a vaiable to take account of what month treatment takes place;
	RelTime1 = 5*(round((RelTime1/5),1));	* this step changes the time to units of 5;
	Age = round((Age - 0.5),1);				* this changes Age to just years;
	if Patient = 'M029' then Sys = 99;		* sets the values of Sys and Dias for Patient 29;
	if Patient = 'M029' then Dias = 60;
	Infusions = 0;							* adding a variable to count number of infusions;
	if InfTime1 > 0 then Infusions = 1;
	if InfTime2 > 0 then Infusions = 2;
	if InfTime3 > 0 then Infusions = 3;
	if InfTime4 > 0 then Infusions = 4;
	if InfTime5 > 0 then Infusions = 5;
	if InfTime6 > 0 then Infusions = 6;
	if InfTime7 > 0 then Infusions = 7;
	if InfTime8 > 0 then Infusions = 8;
	if InfTime9 > 0 then Infusions = 9;
run;

proc print data=workingdata1 (obs=100);
run;

/* This set introduces a new variable to keep account of the quarter of the year that treatment takes place in */
data workingdata2;					
	set workingdata1;
	if m = 1 or m = 2 or m = 3 then Quarter = 1;
		else if m = 4 or m = 5 or m = 6 then Quarter = 2;
			else if m = 7 or m = 8 or m = 9 then Quarter = 3;
				else if m = 10 or m = 11 or m = 12 then Quarter = 4;
run;

proc print data=workingdata2 (obs=100);
run;


*this data step removes all of the negative time values as these are the points before first infusion was made;
data workingdata3 (Drop = m DateofTreatment);
	set workingdata2;
	if index(RelTime1,'-') then delete;
run;

proc print data=workingdata3 (obs=100);
run;

/* produce Graphs og SpO2 per patient */
symbol1 colour=red interpol = join;
proc gplot data=workingdata3;
	title 'SpO2 for M001';
	where Patient = 'M001';
  	plot SpO2*Reltime1 = Patient / vref=94 ;
run;

proc gplot data=workingdata3;
	title 'SpO2 for M002';
	where Patient = 'M002';
  	plot SpO2*Reltime1 = Patient;
run;

proc gplot data=workingdata3;
	title 'SpO2 for M003';
	where Patient = 'M003';
  	plot SpO2*Reltime1 = Patient / vref=94 href=455;
run;

proc gplot data=workingdata3;
	title 'SpO2 for M007';
	where Patient = 'M007';
  	plot SpO2*Reltime1 = Patient / vref=93;
run;


/* Want to check max number of observtions per patient */
proc freq data=workingdata3 ;
	tables  Patient SpO2 Age ASA BMI Infusions Sys Dias Quarter;
run;

title;
/* Introducing an Event variable to record the points when SpO2 drops below 94*/
data Event1;
	set workingdata3;
	Event = 0;
	if SpO2 >= 94 then Event=0;
		else if SpO2=. then Event=0;
			else Event = 1;
	keep Patient Age ASA BMI Infusions Sys Dias RelTime1 SpO2 Event Quarter ;
run;

proc print data=Event1 (obs=100);
run;

/* Check frequencies with previous dataset to ensure that correct number of event times has been recorded*/
proc freq data=Event1;
tables Patient SpO2 Event;
run;

proc sgplot data=Event1;
	yaxis grid type=discrete;
	scatter y=Patient x=RelTime1;
run;

/* Setting up a dataset with only time points with SpO2 below 94%. This will help isolate the time to first event*/
data Event2;
	set Event1;
	if Event = 0 then delete;
run;

proc print data=Event2;
run;

/* Identifying the First Record for each patient which will correspond to the first time that SpO2 dropped below 94%*/
data Event3;
	set Event2;
	by Patient;
		if first.Patient then FirstRec = 1;
			else FirstRec = 0;
run;

/* Remove other observations to have a time just cases with time to first event for Cox PH */
data EventFirst;
	set Event3;
	if FirstRec = 0 then delete;
run;

proc print data=EventFirst;
run;

/* This identifies the first and last event experienced by each patient. These are then isolated so that each patient only has two observations */
data FirstLast;
	set Event1;
	by Patient;
		if first.Patient then FirstRec = 1;
			else FirstRec = 0;
		if last.Patient then LastRec = 1;
			else LastRec = 0;
run;

proc print data=Event3 (obs = 200);
run;


data FirstLast1;
	set FirstLast;
	if FirstRec = 0 and LastRec = 0 then delete;
run;

proc print data=FirstLast1;
run;

/* Combing the first/last dataset with the first event dataset to get a dataset with a Patients Start observation, 
	Last Observation and time of First Event. These are then ordered by Patient and Time to get observations per 
	in chronilogical order patient */
data TimeToFirEvt;
	set FirstLast1 EventFirst;
	by Patient RelTime1;
run;

proc print data=TimeToFirEvt;
run;

/* There is a counter introdouced to assign a count to each observation correpsonding to a patient. Patients with an
	event will have a max count of three and those without will have a max count of two */
data TimeToFirEvt1 (Drop = FirstRec LastRec);
	set TimeToFirEvt;
	by Patient;
		if First.Patient then Counter = 0;
		Counter + 1;
run;

proc print data=TimeToFirEvt1;
run;

/* The second count for each patient is isolated as this will correspond to the time of first event for patients with an
	event and to the censoring time of patients who do not experience an event */
data CoxPH;
	set TimeToFirEvt1;
	if Counter = 3 or Counter = 1 then delete;
run;

data CoxPH (Drop = Counter);
	set CoxPH;
run;

proc print data=CoxPH;
	title 'Table of Observations for Cox PH Model';
run;

/* Run the Cox PH model on this dataset */
proc phreg data=CoxPH;
	title 'Cox PH model results';
	class ASA(ref='1') Quarter(ref='1');
	model RelTime1*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
run;

title;

proc phreg data=CoxPH;
	class ASA(ref='1') Quarter(ref='1') Infusions(ref='5');
	model RelTime1*Event(0) = BMI ASA Sys Dias Age Infusions Quarter;
run;

proc phreg data=CoxPH;
	model RelTime1*Event(0) = BMI ASA Age infusions;
run;

proc phreg data=CoxPH;
	model RelTime1*Event(0) = BMI ASA;
run;



data CoxPH1;
	set CoxPH;
	if Age >= 60 then OldAge = 1;
		else OldAge = 0;
run;

proc print data = CoxPH1;
run;

proc phreg data=CoxPH1;
	class ASA(ref='1') Quarter(ref='1') OldAge(ref = '0') ;
	model RelTime1*Event(0) = BMI ASA Sys Dias Infusions Quarter OldAge;
run;

/* *************************************************************************************************** */
/* Checks of the assumptions for the Cox PH Model */

/* This checks that the that the PH assumption is not violated. It does so by interaction each covariate of interest with the 
	log(RelTime1) variable. A non-significant coeffiecent for these interactions means that the PH assumption is satisfied */
proc phreg data=CoxPH;
	title 'Cehcking the interaction between each paramter an time';
	class ASA(ref='1') Quarter(ref='1');
	model RelTime1*Event(0) = BMI ASA Sys Dias Age Infusions Quarter BMIt ASAt Syst Diast Aget Infusionst Quartert;
	BMIt = BMI*log(RelTime1);
	ASAt = ASA*log(RelTime1);
	Syst = Sys*log(RelTime1);
	Diast = Dias*log(RelTime1);
	Aget = Age*log(RelTime1);
	Infusionst = Infusions*log(RelTime1);
	Quartert = Quarter*log(RelTime1);
run;

title;

/* Assess function comes from Paul Alison pdf */
ods graphics on;
proc phreg data=CoxPH;
	title 'Using the ASSESS function to check the PH assumption';
	class ASA(ref='1') Quarter(ref='1');
	model RelTime1*Event(0) = BMI ASA Sys Dias Age Infusions Quarter;
	output out=Outs ressch=schBMI schASA schSys schDias schAge schInfusions schQuarter resdev=dev resmart=mart xbeta=xb;
	Assess PH / Resample;
run;
ods graphics off;

title;

/* This provides us with the Schoenfeld residuals for each of the covariates. These residuals are useful in investigating the nature 
	of non-proportionality if the proportional hazard assumption does not hold.
	NOTE : the Schoenfeld residuals are not defined for censored observations */
proc phreg data=CoxPH;
	class ASA(ref='1') Quarter(ref='1');
	model RelTime1*Event(0) = BMI ASA Sys Dias Age Infusions Quarter ;
	output out=Outs ressch=schBMI schASA2  schASA3 schSys schDias schAge schInfusions schQuarter2 schQuarter3 schQuarter4 resdev=dev resmart=mart xbeta=xb;
run;

proc phreg data=CoxPH;
	class ASA(ref='1') Quarter(ref='1');
	model RelTime1*Event(0) = BMI ASA Sys Dias Age Infusions Quarter ;
	output out=Outs ressch=sch resdev=dev resmart=mart xbeta=xb;
run;

proc print data=outs;
run;


data c;
	set Outs;
	logtime = log(RelTime1);
proc corr;
	Var RelTime1 logtime schBMI schASA schSys schDias schAge schInfusions schQuarter;
run;

title “Schoenfeld residuals”;
axis1 label=(angle=90);
proc gplot data=Outs;
	plot (schBMI schASA2  schASA3 schSys schDias schAge schInfusions schQuarter2 schQuarter3 schQuarter4) * RelTime1 / vaxis=axis1 ;
	symbol1 value=dot h=1 i=sm60S;
run;

proc gplot data=Outs;
	plot schQuarter * RelTime1 / vaxis=axis1 ;
	symbol1 value=dot h=1 i=sm60S;
run;

proc gplot data=Outs;
	plot schAge * RelTime1 / vaxis=axis1 ;
	symbol1 value=dot h=1 i=sm60S;
run;

/* The following are plots of the martingale and deviance residuals to assess the lack of fit of the model */
title “Residual analysis”;
proc gplot data=Outs;
	plot (mart dev)*xb / vref=0;
	symbol1 value=circle;
run;

title;

proc lifetest data=CoxPH plot=(Surival LogSurv LogLogs) noprint;
	time RelTime1*Event(0);
	strata Quarter;
run;





/* *************************************************************************************************** */

/* Looking at Event times only. Calculate the difference in time between rows to find the times greater than 5 intervals.
	This means that the SpO2 rose to 94% or above during these gaps. Therefore a new event was formed */
data MultipleEvents;
	set Event2;
		by Patient;
		Time_1 = lag(RelTime1);
		Diff_Time = RelTime1 - Time_1;
run;

proc print data=MultipleEvents;
run;

/* First observation per patient will have a distored time difference due to changing between patients
	We still want to keep this point so will assign a value of 11 to these ensure they are not removed */
data MultipleEvents1;
	set MultipleEvents;
	by Patient;
	if First.Patient then Diff_Time = 11;
run;

proc print data=MultipleEvents1;
run;

/* Reducing the dataset to just the first observation of each event */
data MultipleEvents2;
	set MultipleEvents1;
	if Diff_Time <= 5 then delete;
run;

proc print data=MultipleEvents2;
run;

/* Counting the number of events per patient */
data NumEvents;
	set MultipleEvents2;
	by Patient;
		if First.Patient then EventNum = 0;
		EventNum + 1;
run;

proc print data=NumEvents;
run;


/* Isolating the last point of Patient M036 in order to get the stop time for the final event of this patient
	This is done over the next few steps and the single observation is contained in LastPatient2. The single 
	observation is the last point when SpO2 is below 94% for patient M036 */
data LastPatient;
	set MultipleEvents;
	where Patient = 'M036';
run;

proc print data=LastPatient;
run;

/* Isolating last obs for M036 */
data LastPatient1;
	set LastPatient;
	by Patient;
		if Last.Patient then LastP = 1;
			else LastP = 0;
run;

proc print data=LastPatient1;
run;

data LastPatient2;
	set LastPatient1;
	if LastP = 0 then delete;
	Time_1 = RelTime1;
run;

proc print data=LastPatient2;
run;

/* now combine the first observations of each event with the last observation of Patient M036 to get the start times of each event */
data NumEvents1;
	set NumEvents LastPatient2;
	EventStart = RelTime1;
run;

proc print data=NumEvents1;
run;

/* Sort the data upside down to reverse the lag function, in essence it will then work as a lead function (taking the value from 
	the next row). The lead function takes the previous time, Time_1, from the next row which will correspond to the stop time of the 
	previous event. The finsh time of each event is contained within the next row and the lead (opposite of lag) function will help to
	find this time */
proc sort data=NumEvents1;
	by descending Patient descending RelTime1;
run;

data NumEvents2;
	set NumEvents1;
	EventStop = lag(Time_1);
run;

proc sort data=NumEvents2;
	by Patient RelTime1;
run;

/* removing the last observation for M036 cause ot was only wanted for the T_Stop of preceding observation */
data NumEvents3;
	set NumEvents2;
	if EventStop = '.' then delete;
run;

/* This dataset now contains the start and stop time of each event */
proc print data=NumEvents3;
run;

/* If we want the time that the patient is at risk for then it will be represented by the time that the patient is 
	not experiencing an event */

/* The start of each observation period will be 5 seconds (1 time point) after the end of the event */
data NumEvents4;
	set NumEvents3;
	T_Start= lag(EventStop) + 5;
run;

proc print data=NumEvents4;
run;

/* the stop time for each observation will be the time that each next event starts */
data NumEvents5;
	set NumEvents4;
	by Patient;
	if First.Patient then T_Start = 0;
	T_Stop = EventStart;
run;

proc print data=NumEvents5;
run;

/* The time from the end of the final event to the end of the surgery is missing. The censorship time for each of the patients who 
	experienced an event will be isolated to accomadate this */ 
data LastObsEvent;
	set Event2;
	by Patient;
		if Last.Patient then LastEventObs = 1;
		else LastEventObs = 0;
run;

data LastObsEvent1;
	set LastObsEvent;
	if LastEventObs = 0 then delete;
run;

proc print data=LastObsEvent1;
run;

/* This is now combined with the censorship time for each event */
data LastObs;
	set FirstLast;
	if LastRec = 0 then delete;
run;

/* There will be two observations for those patients who experienced an event (those we are interested in) and one for all others */
data FinalStrata;
	set LastObs LastObsEvent1;
	by Patient RelTime1 descending Event;
run;

proc print data=FinalStrata;
run;


proc sort data=FinalStrata;
	by descending Patient descending RelTime1 Event;
run;

/* the start time of the final observation will be 5 seconds after the last event ends
	the stop time will be the time of censorship (end of surgery) */
data FinalStrata1;
	set FinalStrata;
	T_Start = (RelTime1 + 5);
	T_Stop = lag(RelTime1);
run;

proc sort data=FinalStrata1;
	by Patient RelTime1 descending Event;
run;

proc print data=FinalStrata1;
run;

/* only want the observations for patient with who experienced an event. However, having isolated these the event will be set to zero 
	as these observations correspond to the time between final event per patient and the end of the surgery */
data FinalStrata2;
	set FinalStrata1;
	if Event=0 then delete;
	if T_Start >= T_Stop then delete;
	Event = 0;
run;

proc print data=FinalStrata2;
run;

/* Combines the eventless observation of the patients with their event dataset */
data ObsOfEvents;
	set FinalStrata2 NumEvents5;
	by Patient T_Start;
run;

proc print data=ObsOfEvents;
run;

proc print data=TimeToFirEvt2;
run;

/* Setting the T_Start to be zero for all these cases as they only have one observation from start to finsh of the surgery */
data NoEvents (Drop = Counter);
	set CoxPH;
	where Event=0;
	T_Start = 0;
	T_Stop = RelTime1;
run;

proc print data=NoEvents;
run;


/* Merges the two datasets; the Patients with no events in one and the patients with events in the other */
data AG (Drop = FirstRec LastRec LastEventObs Time_1 Diff_Time EventNum LastP EventStart EventStop);
	set NoEvents ObsOfEvents;
	by Patient T_Start;
run;

proc print data=AG;
run;

/* ******************************** */

data AllEvents (Drop = FirstRec LastRec LastEventObs Time_1 Diff_Time EventNum LastP);
	set NoEvents ObsofEvents;
	if Event=1;
	LengthofEvent = EventStop - EventStart;
	StartNewPeriod = lag(EventStop + 5);
	by Patient;
		if First.Patient then StartNewPeriod = 0;
run;

proc print data=AllEvents;
run;

/* removing short events */

data AllEvents;
	set AllEvents;
	if LengthofEvent <= 10 then Delete;
run;

proc print data=AllEvents;
run;

proc sort data=AllEvents;
	by descending Patient descending T_Start;
run;

/* ******************************** */

/* Introduces a stratification variable */
data AG1;
	set AG;
	by Patient;
		if First.Patient then Strata = 0;
		Strata + 1;
run;

proc print data=AG1;
	title 'Table of observations for Andersen-Gill model';
run;


*****
*****
*****
*****
*****
*****;
/*
data tony1;
	set AG1;
	time=RelTime1;
run;

data tony2;
	set tony1;
	if Strata>1 then time=.;
run;

data tony3;
	set tony2;
	retain _time;
	if not missing(time) then _time=time;
	else  time=_time;
run;

proc print data=tony3;
run;

data tony2;
	set tony1;
	by Patient;
	if Strata=2 then start1=lag(RelTime1);
run;

proc print data=tony2;
run;

data test;
	set AG;
	Lag = lag(RelTime1);
run;

proc print data=AG;
run;

title;

*/

/* Running the Andersen-Gill model */
proc phreg data=AG;
	title 'Results of the Andersen-Gill model';
	class ASA(ref='1') Quarter(ref='1');
	model (T_Start T_Stop)*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
run;

title;

/* Andersen-Gill model with robust sandwich estimate for covariance */
proc phreg data=AG covs covm;
	title 'Results of the Andersen-Gill model with robust sandwich estimate for covariance';
	class ASA(ref='1') Quarter(ref='1');
	model (T_Start T_Stop)*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
run;

title;


proc phreg data=AG;
	class ASA(ref='1');
	model (T_Start, T_Stop)*Event(0) = BMI ASA;
run;

/* Fitting the marginal means model */

proc phreg data=AG covs(aggregate);
	title1 ‘Marginal means model for recurrent time-to-event data’;
	class ASA(ref='1') Quarter(ref='1');
  	model (T_Start, T_Stop) * Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits; 
  	id Patient;
run;


/* Fitting the PWP models */

data PWP;
	set AG;
	GapTime = T_Stop - T_Start;
run;

proc print data=PWP;
run;

proc sgplot data=PWP;
	yaxis grid type=discrete;
	scatter y=Patient x=RelTime1 / markerattrs = (color=black size=13);
run;

data PWPPlot;
	set PWP;
	by Patient;
		if Last.Patient then Event=0;
run;

/* This produces a plot of the events experienced by each patient */
ods graphics on;

proc reliability data=PWPPlot;
	unitid Patient;
	mcfplot RelTime1 * Event(0) / nocenprint EVENTPLOT;
run;

ods graphics off;


proc phreg data=PWP;
	title 'Fitting the PWP total time model';
	class ASA(ref='1') Quarter(ref='1');
	model (T_Start, T_Stop) * Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	strata Strata;
run;

proc phreg data=PWP;
	title 'Fitting the PWP gaptime model';
	class ASA(ref='1') Quarter(ref='1');
	model GapTime * Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	strata Strata;
run;

title;

/* Reducing the number of events possible so as not to have certain patients having too much influence */
proc phreg data=PWP;
	where Strata < 6;
	title 'Fitting the PWP total time model';
	class ASA(ref='1') Quarter(ref='1');
	model (T_Start, T_Stop) * Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	strata Strata;
run;


proc phreg data=PWP;
	title 'Fitting the PWP gaptime model';
	where Strata < 6;
	class ASA(ref='1') Quarter(ref='1');
	model GapTime * Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	strata Strata;
run;

title;


/* fitting the LWA model. It uses the same datsaset as the AG model */
proc phreg data=AG covs(aggregate);
	title 'Results of the Lee, Wei and Amato model';
	class ASA(ref='1') Quarter(ref='1');
	model (T_Start, T_Stop)*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
run;

title;


proc phreg data=PWP;
	title 'Results of the Frailty model with Gaussian random effects using Counting Process';
	class ASA(ref='1') Quarter(ref='1') Patient;
	model (T_Start, T_Stop)*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=lognormal;
run;

title;

proc phreg data=PWP;
	title 'Results of the Frailty model with gamma random effects using Counting Process';
	class ASA(ref='1') Quarter(ref='1') Patient;
	model (T_Start, T_Stop)*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=gamma;
run;

title;


proc phreg data=PWP;
	title 'Results of the Condtional Frailty model with Gaussian random effects using Counting Process';
	class ASA(ref='1') Quarter(ref='1') Patient; 
	model (T_Start, T_Stop)*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=lognormal;
	strata Strata;
run;

title;

proc phreg data=PWP;
	title 'Results of the Condtional Frailty model with gamma random effects using Counting Process';
	class ASA(ref='1') Quarter(ref='1') Patient;
	model (T_Start, T_Stop)*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=gamma;							*can see the frailty associated with each patient by including the term "solution";
	strata Strata;
run;

title;

/* Using the GapTime interval */
/* First two use the lognormal/Gaussian distribution */
proc phreg data=PWP;
	title 'Results of the Frailty model with Gaussian random effects using Gaptime';
	class ASA(ref='1') Quarter(ref='1') Patient;
	model Gaptime*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=lognormal;
run;

title;

proc phreg data=PWP;
	title 'Results of the Condtional Frailty model with Gaussian random effects using Gaptime';
	class ASA(ref='1') Quarter(ref='1') Patient;
	model Gaptime*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits ties=Efron;
	random Patient / dist=lognormal;
	strata Strata;
run;

title;

proc phreg data=PWP;
	title 'Results of the Condtional Frailty model with Lognormal random effects using Gaptime and event limit';
	where strata < 6;
	class ASA(ref='1') Quarter(ref='1') Patient;
	model Gaptime*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=lognormal;
	strata Strata;
run;

title;

/* Next two will use the gamma distribution */
proc phreg data=PWP;
	title 'Results of the Frailty model with gamma random effects using Gaptime';
	class ASA(ref='1') Quarter(ref='1') Patient;
	model Gaptime*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=gamma;
run;

title;

proc phreg data=PWP;
	title 'Results of the Condtional Frailty model with gamma random effects using Gaptime';
	class ASA(ref='1') Quarter(ref='1') Patient;
	model Gaptime*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=gamma;
	strata Strata;
run;

title;


/* uses the Conditional frailty mode with gammma, gap time and restricts the number of strata */
proc phreg data=PWP;
	title 'Results of the Condtional Frailty model with gamma random effects using Gaptime';
	where Strata < 6;
	class ASA(ref='1') Quarter(ref='1') Patient;
	model Gaptime*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=gamma;
	strata Strata;
run;

title;


****************************************************;

* Macro for the transition probabilities ;

%ptransit(data = PWP, time1 = T_Start,
	time2 = T_Stop, event = Event,
	xvars = BMI ASA Sys Dias Age Infusions Quarter,
	id = Patient, new = TransProb);




****************************************************;

proc phreg data=PWP;
	class ASA(ref='1') Quarter(ref='1') Patient;
	model Gaptime*Event(0) = BMI ASA Sys Dias Age Infusions Quarter / risklimits;
	random Patient / dist=gamma solution (2 4);
	bayes seed=1 dispersionprior=igamma (shape=3, scale=3);
	title 'Bayesian Analysis for Gamma Frailty Model';
run;




/****************************************************************************************************/

/* Kaplan Meier Test */

proc lifetest data= CoxPH;
	time RelTime1 * Event(0); 
	survival out=outdata confband=all;
	title 'outputs all confidence limits';
run;

goptions reset=all;
axis1 label=(angle=90); 
proc gplot data= outdata ;
	title ‘Kaplan-Meier plot with confidence bands’;
	label survival='Survival Probability';
	label RelTime1='Time to First Event (Seconds)';
	plot survival * RelTime1 hw_UCL * RelTime1 hw_LCL * RelTime1 /overlay vaxis=axis1;
	symbol1 v=none i=stepj c=black line=1;
	symbol2 v=none i=stepj c=black line=2;
	symbol3 v=none i=stepj c=black line=2;
run; quit;


* uses the Hall Wellner Estimate;
ods graphics on;

proc lifetest data=CoxPH atrisk plots=survival;
	title ‘Kaplan-Meier plot for time to first event’;
	time RelTime1 * Event (0);
run;

ods graphics off;


/* time to second event Kaplan-Meier */
data SecondEvent;
	set PWP;
	if Strata = 2;
run;

proc print data=SecondEvent;
run;

proc lifetest data=SecondEvent atrisk plots=survival;
	title ‘Kaplan-Meier plot for time to second event’;
	time GapTime * Event (0);
run;

proc lifetest data=SecondEvent atrisk plots=survival;
	title ‘Kaplan-Meier plot for time to second event’;
	time T_Stop * Event (0);
run;

/* time to third event Kaplan-Meier */
data ThirdEvent;
	set PWP;
	if Strata = 3;
run;

proc print data=ThirdEvent;
run;

proc lifetest data=ThirdEvent atrisk plots=survival;
	title ‘Kaplan-Meier plot for time to third event’;
	time GapTime * Event (0);
run;

/* time to fourth event Kaplan-Meier */
data FourthEvent;
	set PWP;
	if Strata = 4;
run;

proc print data=FourthEvent;
run;

proc lifetest data=FourthEvent atrisk plots=survival;
	title ‘Kaplan-Meier plot for time to Fourth event’;
	time GapTime * Event (0);
run;

/* time to fifth event Kaplan-Meier */
data FifthEvent;
	set PWP;
	if Strata = 5;
run;

proc print data=FifthEvent;
run;

proc lifetest data=FifthEvent atrisk plots=survival;
	title ‘Kaplan-Meier plot for time to Fourth event’;
	time GapTime * Event (0);
run;


proc lifetest data=PWP atrisk plots=survival;
	title ‘Kaplan-Meier plot for all events’;
	time T_Stop * Event (0);
run;

* uses the Equal Precision Estimate;
ods graphics on;

proc lifetest data=CoxPH atrisk plots=survival(cb = ep test);
	time RelTime1 * Event (0);
run;

ods graphics off;

title;

* uses both the Hall Wellner and Equal Precision Estimates;
ods graphics on;

proc lifetest data=CoxPH atrisk plots=survival(cb = all test atrisk);
	time RelTime1 * Event (0);
run;

ods graphics off;

* Failure Plot;
/* Must add in extra end point for patient M007 */
data Last7;
	set PWP;
	if Patient="M007";
run;

data Last7;
set Last7;
	by Patient;
		if Last.Patient then LastPat = 1;
			else LastPat = 0;
run;

data Last7;
	set Last7;
	if LastPat = 0 then delete;
run;

proc print data=Last7;
run;

data Last7;
	set Last7;
	T_Start = 2080;
	T_Stop = 2090;
	Event = 0;
run;

data FakePWP;
	set PWP Last7;
	by Patient T_Start;
run;


ods graphics on;

proc reliability data=FakePWP;
   unitid Patient;
   mcfplot T_Stop * Event(0) / nocenprint eventplot nohlabel;
run;
ods graphics off;


* Failure Plot;
ods graphics on;

proc lifetest data=CoxPH atrisk plots=survival(cb = all failure test);
	time RelTime1 * Event (0);
run;

ods graphics off;

/* Nelson Aalen Test */

proc lifetest data=CoxPH atrisk plots=survival(cb = hw) nelson;
	time RelTime1 * Event (0);
run;


/* Getting the mean and median times to first event */


proc print data=CoxPH;
run;

data NoEvents;
	set PWP;
	if Event = 1;
run;

proc print data=NoEvents;
run;

data ShortEvents;
	set PWP;
	if Event = 1;
	if GapTime <= 10;
run;

proc print data=ShortEvents;
run;

proc freq data=NoEvents;
	tables Patient Strata;
run;

data FirstEvents;
	set CoxPH;
	if Event = 1;
run;

proc print data=FirstEvents;
run;

data NoEvents;
	set CoxPH;
	if Event = 0;
run;

proc print data=NoEvents;
run;


data SecondEvent;
	set PWP;
	if Event=1;
	if Strata = 2;
run;

proc print data=SecondEvent;
run;


data ThirdEvent;
	set PWP;
	if Event=1;
	if Strata = 3;
run;

proc print data=ThirdEvent;
run;


data FourthEvent;
	set PWP;
	if Event=1;
	if Strata = 4;
run;

proc print data=FourthEvent;
run;

data OtherEvent;
	set PWP;
	if Event=1;
	if Strata > 1;
run;

proc print data=OtherEvent;
run;

