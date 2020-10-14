import torch, pandas, poirot
from torch import sigmoid
from torch.distributions import Normal, Binomial
from poirot import tensor, dist, infer, infermap
from datetime import datetime

def date(s):
    return datetime.strptime(s, '%Y-%m-%d').date()

def logit(p):
    return (p / (1-p)).log()

data = pandas.read_csv("../source-data/sero-surveys.csv")

data.date = [date(d) for d in data.date]

population = tensor(data.population)
case_ir = tensor(data.case_ir)
death_r = tensor(data.death_r)
death_r += 1e-5
gdp = tensor(data.log_gdp_ppp)

N = tensor(data["sample.size"])
sero = tensor(data.sero_ir)

startDate = min(data.date)
date = tensor([(d - startDate).days for d in data.date])

def model(beta):
    dist(beta, Normal(0, 1))

    intercept = torch.ones(len(sero), device = poirot.dev)
    X = torch.stack([intercept,
                     logit(case_ir), logit(death_r),
                     gdp, logit(case_ir) * gdp, logit(death_r) * gdp,
                     date/30])
    Y = beta @ X

    dist(sero*N, Binomial(N, sigmoid(Y)))

beta = torch.zeros(1, 7)

beta = infermap(model, beta, batch = 1)
beta = infer(model, beta, batch = 10)

print(beta.loc)
