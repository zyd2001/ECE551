#!usr/bin/python

import os,sys

# Opening channel dump file for specified channel
if (len(sys.argv) == 1):
    print("plot.py X Y\nplot testX_CHYdmp.txt")
    print("plot.py 2 1\nplot test2_CH1dmp.txt")
    exit()
test = sys.argv[1]
ch = sys.argv[2]
dump_file = 'test' + test + '_CH' + ch + 'dmp.txt'
try:
    f = open(dump_file,"r")
except:
    print "\nError: Unable to read dump file %s. Aborting ...\n" % dump_file 
    exit()
# parse the channel dump file in a list #
lines = [line.strip() for line in f]

# Open output .dat file to plot #
outfile = open("lvl.dat","w")

# Iterate over each byte and decode signal level #
i = 0         # Line number for X axis of plot
for byte in lines:
    a = bin(int(byte,16))[2:].zfill(8)
    
    for t in range(3,-1,-1):
        low  = a[2*t]
        high = a[2*t+1]
        smpl =''
        if(low =='0'and high == '0'):
            smpl =str(i) + ' 0'
        elif(low == '1' and high == '1'):
            smpl =str(i) + ' 1'
        else:
            smpl =str(i) + ' 0.5'
        outfile.write(smpl+'\n')
        i = i +1

outfile.close()

# Generate GNU plot script #
plot_string = ''
plot_string+="""plot "lvl.dat" with lines\n"""


plot_scr=""

plot_scr +="""
set title "Channel Dump Output from LA"
set xlabel "Timestamp (samples)"
set ylabel "Logic Level"
set xrange [%d:%d]
set yrange [-1:2]\n""" %(0,1536)


plot_scr += plot_string

plot_scr+="""pause -1 "Hit any key to continue" """
plot_script = open("plot_dmp.scr","w+")
plot_script.write(plot_scr);
plot_script.close()

# launch GNUplot 
os.system("gnuplot plot_dmp.scr")


