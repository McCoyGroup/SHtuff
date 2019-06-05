'''eigs.py is a command-line wrapper to the scipy sparse eigenvalue routine

'''

import numpy, scipy.io, sys, os, scipy.sparse.linalg, argparse

### ARGUMENT PARSING

# literally just added all the parameters for scipy...eigs

parser = argparse.ArgumentParser(description='Diagonalize a matrix')
parser.add_argument(
    'mat',
    metavar='mat',
    help='matrix to be diagonalized'
    )
parser.add_argument(
    '-k',
    metavar='k', type=int, nargs='?',
    help='number of eigenvectors returned',
    default=5
    )
parser.add_argument(
    '-M',
    metavar='M', nargs='?',
    help='matrix for generalized eigenvalue problem'
    )
parser.add_argument(
    '--sigma',
    metavar='sigma', type=float, nargs='?',
    help='eigenvalue neighborhood target',
    default=None
    )
parser.add_argument(
    '--ncv',
    metavar='ncv', type=int, nargs='?',
    help='number of basis vectors used in the diagonalization',
    default=None
    )
parser.add_argument(
    '--v0',
    metavar='v0', nargs='?',
    help='starting vector for iteration'
    )
parser.add_argument(
    '--which',
    metavar='which', nargs='?',
    choices=['LM', 'SM', 'LR', 'SR', 'LI', 'SI'],
    help='mode for diagonalization',
    default='SR'
    )
parser.add_argument(
    '--maxiter',
    metavar='maxiter', nargs='?', type=int,
    help='max number of iterations',
    default=None
    )
parser.add_argument(
    '--tol',
    metavar='tol', type=float,
    help='tolerance for convergence',
    default=0, nargs='?'
    )
parser.add_argument(
    'out',
    metavar='out',
    nargs='?',
    help='file for output',
    default='out.mtx'
    )
args = parser.parse_args()

### Debug junk
# print(args)
#
# raise Exception("exit")

### ARGUMENT VALIDATION
open(args.mat, 'r').close(); # ensure that mat may be read from
open(args.out, 'w').close(); # ensure that out may be written to
if not args.M is None:
    args.M=scipy.io.mmread(args.M)

# raise Exception("exit")

### DIAGONALIZE

# if looking for smallest real bits we'll just flip
# implicitly this assumes a matrix with all real eigenvalues

mat = scipy.io.mmread(args.mat)
mode = args.which
if args.which == 'SR':
    mat *= -1
    mode = 'LR'

eigset = list(
    scipy.sparse.linalg.eigs(
        mat,
        k=args.k,
        sigma=args.sigma,
        M=args.M,
        ncv=args.ncv,
        maxiter=args.maxiter,
        tol=args.tol,
        which=mode,
        v0=args.v0
        )
    )

if args.which == 'SR':
    eigset[0] *= -1

eigset = numpy.real(eigset)

### DUMP
scipy.io.mmwrite(args.out, numpy.insert(eigset[1], 0, eigset[0], axis=0));
print(args.out)
