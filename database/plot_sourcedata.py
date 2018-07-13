import matplotlib
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import argparse
import sys
import math
from astropy.time import Time

def fluxModel2Density(model, frequency):
    # Evaluate the flux density model "model" at the frequency
    # specified as "frequency" in MHz, to give a flux density
    # in Jy.
    f = frequency / 1000.0
    isLog = False
    if (model[-1] == 'log'):
        isLog = True
        f = math.log10(f)
    s = float(model[0])
    for i in xrange(1, len(model) - 1):
        s += float(model[i]) * f ** float(i)
    if (isLog):
        s = 10.0 ** s
    return s

def fluxModel2Slope(model, frequency):
    # Evaluate the flux density model "model" at the frequency
    # specified as "frequency" in MHz, to give a spectral index.
    f = frequency / 1000.0
    isLog = False
    if (model[-1] == 'log'):
        isLog = True
        f = math.log10(f)
    # How we get the slope depends on whether we have a log model.
    if (not isLog):
        # We can only have order 2 or below.
        if ((len(model) - 1) > 3):
            return None
        a = 0
        b = 0
        c = 0
        if (len(model) >= 2):
            a = float(model[0])
        if (len(model) >= 3):
            b = float(model[1])
        if (len(model) == 4):
            c = float(model[2])
        s = ((10.0 ** f) * (b + 2.0 ** (f + 1.0)) * (5.0 ** f) * c) / (a + (10.0 ** f) * (b + c * (10.0 ** f)))
        return s
    else:
        s = 0.0
        for i in xrange(1, len(model) - 1):
            s += float(model[i]) * float(i) * (f ** float(i - 1))
        return s

def bandName(freq):
    # Return the band name for the specified frequency, in MHz.
    ranges = { '16cm': [ 800.0, 3500.0 ],
               '4cm': [ 3500.0, 15000.0 ],
               '15mm': [ 15000.0, 27000.0 ],
               '7mm': [ 27000.0, 80000.0 ],
               '3mm': [ 80000.0, 120000.0 ] }
    for c in ranges:
        if ((freq >= ranges[c][0]) and
            (freq < ranges[c][1])):
            return c
    return None

def main(args):
    # Read in the data file.
    dataTable = pd.read_csv(args.file, delim_whitespace=True)

    if 'source' not in args:
        print "No source specified."
        sys.exit(-1)

    minMjd = args.min_mjd
    if (minMjd is None):
        minMjd = 0
    maxMjd = args.max_mjd
    if (maxMjd is None):
        maxMjd = 1e6

    badEpochs = args.exclude_epoch
    if (badEpochs is None):
        badEpochs = []
        
    # Extract the source.
    sourceTable = dataTable[(dataTable["source_name"] == args.source) &
                            (dataTable["observation_mjd_start"] >= minMjd) &
                            (dataTable["observation_mjd_start"] <= maxMjd)]

    matplotlib.rcParams.update({ 'font.size': 22 })
    
    fig, ax = plt.subplots()
    if (args.top_mjd):
        ax2 = ax.twiny()

    symbols = [ "o", "^", "s", "D", "*", "h" ]
    colours = [ "blue", "green", "red", "orange", "magenta", "black" ]
    
    for e in xrange(0, len(args.freq)):
        ef = float(args.freq[e])
        bn = bandName(ef)
        if (bn is not None):
            bandTable = sourceTable[sourceTable['frequency_band'] == bn]
            times = bandTable['observation_mjd_start'].tolist()
            epochs = bandTable['epoch_id'].tolist()
            jdtimes = np.array(times) + 2400000.5
            dtimes = Time(jdtimes, format='jd', scale='utc')
            #models = bandTable['band_fluxdensity_model'].tolist()
            models = bandTable['fluxdensity_fit_coeff'].tolist()
            if (args.plot_uncertainties):
                #uncertainties = bandTable['band_fluxdensity_scatter'].tolist()
                uncertainties = bandTable['fluxdensity_scatter'].tolist()
            y = []
            pt = ""
            pu = ""
            remeps = []
            for i in xrange(0, len(models)):
                if (epochs[i] in badEpochs):
                    # Don't look at this epoch.
                    remeps.append(i)
    
                m = models[i].split(",")
                if (("spectralindex" in args) and (args.spectralindex)):
                    y.append(fluxModel2Slope(m, ef))
                    pt = "spectral index"
                else:
                    y.append(fluxModel2Density(m, ef))
                    pt = "flux density"
                    pu = "Jy"

            # Get rid of the bad epochs.
            adtimes = dtimes.datetime
            ajtimes = dtimes.jd - 2400000.5
            adtimes = np.delete(adtimes, remeps, 0)
            ajtimes = np.delete(ajtimes, remeps, 0)
            y = np.delete(y, remeps, 0)
            if (args.top_mjd):
                # Make a top x-axis with MJD showing.
                ax2.plot(ajtimes, y, symbols[e], color=colours[e], markersize=8)
                #ax2.cla()
            if (args.plot_uncertainties):
                yu = np.delete(uncertainties, remeps, 0)

            if (args.plot_uncertainties):
                ax.errorbar(adtimes, y, yerr=yu, color=colours[e], fmt=symbols[e], label="%.1f MHz" % ef,
                            markersize=8)
            else:
                ax.plot(adtimes, y, symbols[e], color=colours[e], label="%.1f MHz" % ef, markersize=8)
            
            # Calculate the average.
            mn = np.mean(y);
            print "Mean %s at %.1f MHz = %.3f %s (%d points)" % (pt, ef, mn, pu, len(y))
            if (pt == "flux density"):
                ny = np.array(y)
                nv = ny - mn
                nrms = np.sqrt(np.mean(np.square(nv)))
                print "RMS from mean at %.1f MHz = %.3f %s" % (ef, nrms, pu)
                print "M (%.1f MHz) = %.3f" % (ef, (nrms / mn))

    ax.set_xlabel("Date")
    if (("spectralindex" in args) and (args.spectralindex)):
        ax.set_ylabel("Spectral Index")
    else:
        ax.set_ylabel("Flux Density [Jy]")

    if (args.top_mjd):
        xmg, ymg = ax2.margins()
        ax2.margins(x=xmg + 0.05)
        dms = Time(ax2.get_xlim(), format='mjd', scale='utc')
        ax.set_xlim(dms.datetime)
    else:
        xmg, ymg = ax.margins()
        ax.margins(x=xmg + 0.05)
        
    fig.set_size_inches(11.69, 8.27)
    if (not args.top_mjd):
        plt.legend(bbox_to_anchor=(0., 1.01, 1., .102), loc=3, fontsize=15,
                   ncol=len(args.freq), mode="expand", borderaxespad=0.)
    else:
        ax.legend(bbox_to_anchor=(0., 1.06, 1., .102), loc=3, fontsize=15,
                  ncol=len(args.freq), mode="expand", borderaxespad=0.)
        
#    fig.autofmt_xdate()
    # plt.show()
    ftype = "eps"
    if (args.save_png):
        ftype = "png"
    fname = "%s_plot.%s" % (args.source, ftype)
    fig.savefig(fname, dpi=100, bbox_inches='tight')

# Get the command line arguments if we're called as a script.
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--file",
                        help="the name of the file to read")
    parser.add_argument("-F", "--freq", type=float, action="append",
                        help="add an evaluation frequency")
    parser.add_argument("-S", "--fluxdensity", action="store_true", default=True,
                        help="plot the flux densities")
    parser.add_argument("-a", "--spectralindex", action="store_true", default=False,
                        help="plot the spectral indices")
    parser.add_argument("-s", "--source",
                        help="the source of interest")
    parser.add_argument("-m", "--min-mjd", type=float,
                        help="the minimum MJD to plot")
    parser.add_argument("-x", "--max-mjd", type=float,
                        help="the maximum MJD to plot")
    parser.add_argument("-X", "--exclude-epoch", type=int, action="append",
                        help="an epoch number to exclude from the plot")
    parser.add_argument("-u", "--plot-uncertainties", action="store_true", default=False,
                        help="plot error bars for the scatter")
    parser.add_argument("-t", "--top-mjd", action="store_true", default=False,
                        help="display MJD on top x-axis")
    parser.add_argument("-p", "--save-png", action="store_true", default=False,
                        help="output a PNG rather than an EPS")
    args = parser.parse_args()
    
    main(args)
