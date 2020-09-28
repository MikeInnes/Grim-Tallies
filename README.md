Grim Tallies
================
The Economist
September, 2020

This repository provides data and code for the briefing “Grim Tallies”.

Our scripts are written in R and available in the folder “scripts”. Our
data is contained in the folder “source-data”.

### Excess mortality

Our excess mortality data and code is available in [this
repo.](https://github.com/TheEconomist/covid-19-excess-deaths-tracker)

### SEIR models

For more information on such simulations and how they work, see:
<https://www.idmod.org/docs/emod/hiv/model-seir.html>

For the purposes of the simulations featured in the briefing, we based
our parameters for COVID-19 on [Ferretti et al
(2020)](https://www.medrxiv.org/content/10.1101/2020.09.04.20188516v2)
as well the [OpenABM-Covid19
parameters](https://github.com/BDI-pathogens/OpenABM-Covid19/blob/master/tests/data/baseline_parameters_transpose.csv).
To account for vaccination taking time to scale, we assumed only 1m
could be vaccinated in the first month of vaccinations.

### Licence

This software is published by *[The
Economist](https://www.economist.com)* under the [MIT
licence](https://opensource.org/licenses/MIT). The data generated by
*The Economist* are available under the [Creative Commons
Attribution 4.0 International
License](https://creativecommons.org/licenses/by/4.0/). The licences
include only the data and the software authored by *The Economist*, and
do not cover any *Economist* content or third-party data or content made
available using the software. More information about licensing,
syndication and the copyright of *Economist* content can be found
[here](https://www.economist.com/rights/).
