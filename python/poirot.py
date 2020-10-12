# A simple PPL, supporting VI

import torch, collections, statistics
from torch import logsumexp
from torch.distributions import Normal

dev = torch.device('cuda') if torch.cuda.is_available() else torch.device('cpu')

def tensor(x, dtype = torch.float32, requires_grad = False):
    if isinstance(x, torch.Tensor):
        return x.clone().detach().to(dev).requires_grad_(requires_grad)
    else:
        return torch.tensor(x, dtype = dtype, requires_grad = requires_grad, device = dev)

# Functor/pytree

def functor(x):
    if isinstance(x, list):
        return x, lambda xs: list(xs)
    elif isinstance(x, dict):
        ks, vs = zip(*sorted(x.items()))
        return vs, lambda vs: dict(zip(ks, vs))
    else:
        return [], lambda _: x

def isleaf(x):
    return len(functor(x)[0]) == 0

def fmap1(f, x, *xs):
    items, re = functor(x)
    rest = map(lambda x: functor(x)[0], xs)
    return re(map(f, items, *rest))

def fmap(f, *xs):
    if any(map(isleaf, xs)):
        return f(*xs)
    else:
        return fmap1(lambda *xs: fmap(f, *xs), *xs)

def ffold(f, x):
    if isleaf(x):
        return x
    else:
        items, re = functor(x)
        items = map(lambda x: ffold(f, x), items)
        return f(*items)

def fsum(x):
    return ffold(lambda *x: sum(x), x)

# Log likelihood DSL

lls = []

def dist(x, d):
    lls[-1] += d.log_prob(x).sum()

def loglikelihood(f, *args):
    lls.append(tensor(0))
    f(*args)
    return lls.pop()

def each(d, f):
    cases = d.enumerate_support()
    lpdf = torch.zeros(len(cases))
    for i in range(len(cases)):
        lls.append(0)
        dist(cases[i], d)
        f(cases[i])
        lpdf[i] = lls.pop()
    lls[-1] += logsumexp(lpdf, 0)

# Reparameterised Distributions

class RDistribution:
    pass

class RNormal(RDistribution):
    def __init__(self, mu, lsigma):
        self.mu = tensor(mu, requires_grad = True)
        self.lsigma = tensor(lsigma, requires_grad = True)
    def parameters(self):
        return [self.mu, self.lsigma]
    def restore(self):
        return Normal(self.mu, self.lsigma.exp())
    def rsample(self, shape = []):
        return self.restore().rsample(shape)
    def log_prob(self, x):
        return self.restore().log_prob(x).sum()

def fsample(q, batch = None):
    def f(x):
        if isinstance(x, RDistribution):
            return x.rsample([] if batch == None else [batch])
        else:
            return x
    return fmap(f, q)

def flog_prob(q, x):
    def f(x, y):
        if isinstance(x, RDistribution):
            return x.log_prob(y)
        else:
            return 0
    return fsum(fmap(f, q, x))

def fparams(q):
    params = []
    def f(x):
        if isinstance(x, RDistribution):
            params.extend(x.parameters())
        elif isinstance(x, torch.Tensor):
            params.append(x)
    fmap(f, q)
    return params

def instantiate(q):
    def f(x):
        if isinstance(x, (float, int, torch.Tensor)):
            return RNormal(x, x*0-5)
        else:
            return x
    return fmap(f, q)

def unstantiate(q):
    def f(x):
        if isinstance(x, RDistribution):
            return x.restore()
        else:
            return x
    return fmap(f, q)

def instantiate_map(q):
    def f(x):
        if isinstance(x, (float, int, torch.Tensor)):
            return tensor(x, requires_grad = True)
        else:
            return x
    return fmap(f, q)

def fbatch(q):
    def f(x):
        if isinstance(x, torch.Tensor):
            return x.reshape([-1] + list(x.size()))
        else:
            return x
    return fmap(f, q)

# Inference routines

def windowlen(n, b):
    return n if b == None else max(n // b, 1)

def infer(f, q, batch = None, window = 5000):
    q = instantiate(q)
    opt = torch.optim.Adam(fparams(q))
    # opt = torch.optim.SGD(fparams(q), lr = 1e-7)
    window = collections.deque(maxlen=windowlen(window, batch))
    N = 0
    try:
        while True:
            N += 1
            opt.zero_grad()
            sample = fsample(q, batch = batch)
            l = loglikelihood(f, sample) - flog_prob(q, sample)
            if torch.isinf(l):
                raise Exception("Loss is inf")
            if torch.isnan(l):
                raise Exception("Loss is nan")
            if batch != None:
                l /= batch
            (-l).backward()
            opt.step()
            window.append(l.item())
            print("\r[ %.1f, %.2e iterations  " % (statistics.mean(window), N), end = "")
    except KeyboardInterrupt:
        pass
    print()
    return unstantiate(q)

def infermap(f, x, batch = None):
    x = instantiate_map(x)
    # opt = torch.optim.LBFGS(fparams(x))
    opt = torch.optim.Adam(fparams(x))
    N = 0
    try:
        while True:
            N += 1
            l = 0
            def closure():
                opt.zero_grad()
                sample = x
                if batch != None:
                    sample = fbatch(x)
                nonlocal l
                l = -loglikelihood(f, sample)
                l.backward()
                return l
            opt.step(closure)
            print("\r[ %.1f, %.2e iterations  " % (-l.item(), N), end = "")
    except KeyboardInterrupt:
        pass
    print()
    return x
