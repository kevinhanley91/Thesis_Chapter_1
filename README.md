# Thesis_Chapter_1

__Purpose:__ Analysis of the association between the risk of arterial oxygen desaturation and conscious sedation was performed in an oral surgery setting. Recurrent event survival techniques were applied to investigate if several patient characteristics if any showed an association.

__Context:__ The first chapter of my research MSc in statistics thesis

__Language:__ SAS

__Note:__ I did this project before I knew of the wonders of version control and git. Also the commenting and coding practices leave something to be desired. 

## Introduction
Intravenous conscious sedation allows surgery to be performed with reduced pain and trauma to the patient; however, hypoxemia resulting from oxygen desaturation for a sustained period of time is an ever present risk. The identification of a risk group provides the opportunity for additional observance and extra precautions to be provided for those most at risk.  Previous papers have identified risk factors during varying procedures and under the sedation of different medications. There has been little analysis performed in an oral surgery context, with even less by the use of recurrent event survival analysis methods. Recurrent events allow for the possibility of multiple contributions from each patient to the dataset. 

## Methods
By implementing the Cox model, results were observed for the time to first occurrence of oxygen desaturation or censorship for each patient, while multiple events per patient were observed. The recurrent event models fitted can be seen as adaptations of the Cox model to allow for the possibility of multiple events per patient, each with varying approaches to intra-subject event correlation. The model by Andersen and Gill (1982) made adaptions to the standard Cox formula for use with multivariate counting processes, by assuming that intra-subject events were independent. Varying risk intervals were allowed for in the Prentice, Williams, and Peterson (1981) models with the risk sets stratified by number of events experienced to date. The conditional frailty model introduced by Box-Steffensmeier and De Boef (2006) allowed for the prospect of heterogeneity between patients to exist. The event of interest for each of these models was when the subject’s peripheral arterial oxygen saturation dropped below 94%. 
