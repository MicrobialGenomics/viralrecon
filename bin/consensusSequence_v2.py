#!/usr/bin/env python
import pysam
import numpy
from scipy import stats
from collections import Counter
import math
from decimal import *
getcontext().prec = 100
import sys

def reject_outliers(data, data2 , m=2):
    if len(data) != len(data2):
        print('ERROR')
    I=[]
    J=[]
    data=numpy.array(data)
    data2=numpy.array(data2)
    I.append(data2[abs(data - numpy.mean(data)) < m * numpy.std(data)])
    J.append(data[abs(data - numpy.mean(data)) < m * numpy.std(data)])
    if len(data) != len(data2):
        print('ERROR')
    return I

def repeat_to_length(string_to_expand, length):
   return (string_to_expand * ((length/len(string_to_expand))+1))[:length]

file=sys.argv[1]

samfile = pysam.AlignmentFile(file,"rb")
threshold=Decimal(float(sys.argv[2]))
Sequence=''
X=Decimal(0)
for pileupcolumn in samfile.pileup(start=1,end=30000,truncate=True):
    T=0
    R=[]
    Q=[]
    if pileupcolumn.n < 10:
        Sequence+='N'
        X=X+1
        continue
    while X <= pileupcolumn.reference_pos:
        Sequence+='N'
        X=X+1

    for pileupread in pileupcolumn.pileups:
        # Note that we are not including INDELS by nows
        if not pileupread.is_del and not pileupread.is_refskip:
            T=T+1
            if pileupread.alignment.query_qualities[pileupread.query_position] <= 25:
                continue
            R.append(pileupread.alignment.query_sequence[pileupread.query_position])
            Q.append(pileupread.alignment.query_qualities[pileupread.query_position])
    #R=reject_outliers(Q,R,m=4)
    R=numpy.ravel(R)
    if len(R) < 10: ### Number of effective(>Q25) bases covering poistion, otherwise base="N"
        Sequence+='N'
        X=X+1
        continue
    C=Counter(R)
    S=Decimal(sum(C.values()))
    C['A']=(C['A']/S)*100
    C['T']=(C['T']/S)*100
    C['C']=(C['C']/S)*100
    C['G']=(C['G']/S)*100
    string=''
    if Decimal(C['A']) >= threshold:
        string+='A'
    if Decimal(C['T']) >= threshold:
        string+='T'
    if Decimal(C['C']) >= threshold:
        string+='C'
    if Decimal(C['G']) >= threshold:
        string+='G'
    if string == 'A':
        Sequence+='A'
    if string == 'T':
        Sequence+='T'
    if string == 'C':
        Sequence+='C'
    if string == 'G':
        Sequence+='G'
    if string == 'AT':
        Sequence+='W'
    if string == 'AC':
        Sequence+='M'
    if string == 'AG':
        Sequence+='R'
    if string == 'TC':
        Sequence+='Y'
    if string == 'TG':
        Sequence+='K'
    if string == 'CG':
        Sequence+='S'
    X=X+1
print('>'+sys.argv[1]+'_Threshold_'+str(threshold))
print(Sequence)
samfile.close()

