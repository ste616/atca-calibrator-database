require([ "dojo/store/Memory", "dijit/form/FilteringSelect", "atnf/base", "dojo/number",
	  "dojo/dom", "dojo/dom-construct", "dojo/dom-attr", "./calibrator_database_api",
	  "dojo/fx", "dojo/_base/fx", "dojo/dom-class", "dojox/charting/Chart",
	  "dojox/charting/SimpleTheme", "atnf/time", "dojo/on", "dojo/query",
	  "dojo/dom-style", "dojo/_base/lang",
	  "dojo/NodeList-traverse",
	  "dojox/charting/plot2d/Scatter", "dojox/charting/plot2d/Markers",
	  "dojox/charting/plot2d/Lines", "dojox/charting/plot2d/Default",
	  "dojox/charting/axis2d/Default", "dojo/domReady!"],
	function(Memory, FilteringSelect, atnf, number, dom, domConstruct, domAttr, caldb,
		 coreFx, fx, domClass, Chart, SimpleTheme, atnfTime, on, query,
		 domStyle, lang) {

	    var arrayAverage = function(a) {
		var s = 0;
		for (var i = 0; i < a.length; i++) {
		    s += a[i];
		}
		if (a.length > 0) {
		    return (s / a.length);
		} else {
		    return 0;
		}
	    };

	    // What calibrator are we looking for.
	    var pageOptions = caldb.getOptions();
	    if (!pageOptions.source) {
		domAttr.set('calibratorName', 'innerHTML', 'No source specified!');
		return;
	    }

	    domAttr.set('calibratorName', 'innerHTML', 'Calibrator: ' +
			pageOptions.source.toUpperCase());

	    // Set the "detailed" link appropriately.
	    var cwl = window.location.href;
	    if (/detailed\=true/.test(cwl)) {
		// Already looking at the detailed page.
		domAttr.set('moreDetailLink', 'innerHTML', 'Hide observation details');
		domAttr.set('moreDetailLink', 'href', cwl.replace(/\&detailed\=true/, ''));
	    } else {
		domAttr.set('moreDetailLink', 'href', cwl + '&detailed=true');
	    }

	    // Alter the theme a bit.
	    var myTheme = new SimpleTheme({
		'markers': {
		    'CROSS': "m0,-3 l0,6 m-3,-3 l6,0",
		    'CIRCLE': "m-3,0 c0,-4 6,-4 6,0 m-6,0 c0,4 6,4 6,0",
		    'SQUARE': "m-3,-3 l0,6 6,0 0,-6 z", 
		    'DIAMOND': "m0,-3 l3,3 -3,3 -3,-3 z", 
		    'TRIANGLE': "m-3,3 l3,-6 3,6 z", 
		    'TRIANGLE_INVERTED': "m-3,-3 l3,6 3,-6 z"
		}
	    });

	    // A list of frequencies we show per band.
	    var bandFrequencies = {
		'16cm': [ 2100 ],
		'4cm': [ 5500, 9000 ],
		'15mm': [ 17000 ],
		'7mm': [ 33000 ],
		'3mm': [ 93000 ]
	    };
	    var bandRanges = {
		'16cm': { 'min': 700, 'max': 3300 },
		'4cm': { 'min': 4000, 'max': 12000 },
		'15mm': { 'min': 16000, 'max': 25000 },
		'7mm': { 'min': 30000, 'max': 50000 },
		'3mm': { 'min': 85000, 'max': 105000 }
	    };
	    var frequency2band = function(f) {
		// Return the band name for the specified frequency.
		for (var b in bandRanges) {
		    if (bandRanges.hasOwnProperty(b)) {
			if (f >= bandRanges[b].min &&
			    f <= bandRanges[b].max) {
			    return b;
			}
		    }
		}
		// Not known.
		return null;
	    };

	    var bandPlotProperties = {
		'16cm': [ { 'stroke': { 'color': '#e4002b' },
			    'fill': '#e4002b', 'marker': myTheme.markers.CIRCLE } ],
		'4cm': [ { 'stroke': { 'color': '#df1995' },
			   'fill': '#df1995', 'marker': myTheme.markers.SQUARE },
			 { 'stroke': { 'color': '#6d2077' },
			   'fill': '#6d2077', 'marker': myTheme.markers.CIRCLE } ],
		'15mm': [ { 'stroke': { 'color': '#ffb81c' },
			    'fill': '#ffb81c', 'marker': myTheme.markers.DIAMOND } ],
		'7mm': [ { 'stroke': { 'color': '#e87722' },
			   'fill': '#e87722', 'marker': myTheme.markers.TRIANGLE } ],
		'3mm': [ { 'stroke': { 'color': '#6d2077' },
			   'fill': '#6d2077', 'marker': myTheme.markers.TRIANGLE_INVERTED } ]
	    };
	    var plotsMade = {
		'timeSeries': null,
		'siTimeSeries': null,
		'fluxModel': null,
		'uvPoints': null
	    };


	    var seriesData = {
		'timeSeries': {},
		'siTimeSeries': {},
		'fluxModel': {},
		'uvPoints': {}
	    };
	    var bandsPlotted = {};
	    var showButtons = [ 'timeSeriesShow', 'spectralIndexShow',
				'fluxModelShow', 'uvResidualShow' ];


	    var bandPlotFrequencies = {};
	    for (var b in bandFrequencies) {
		if (bandFrequencies.hasOwnProperty(b)) {
		    bandPlotFrequencies[b] = bandFrequencies[b][0];
		}
	    }

	    // Add any custom frequencies we might have been given.
	    var customFrequencies = [];
	    if (pageOptions.frequencies) {
		customFrequencies = pageOptions.frequencies;
		if (!(pageOptions.frequencies instanceof Array)) {
		    customFrequencies = [ pageOptions.frequencies ];
		}
		for (var i = 0; i < customFrequencies.length; i++) {
		    var b = frequency2band(customFrequencies[i]);
		    var standard = false;
		    for (var j = 0; j < bandFrequencies[b].length; j++) {
			if (bandFrequencies[b][j] == customFrequencies[i]) {
			    standard = true;
			}
		    }
		    if (pageOptions.scheduler && i === 0) {
			bandPlotFrequencies[b] = customFrequencies[i];
		    }
		    if (standard === false) {
			if (typeof pageOptions.scheduler === 'undefined') {
			    bandPlotFrequencies[b] = customFrequencies[i];
			}
			bandFrequencies[b].push(customFrequencies[i]);
			// Add this value to the tables as well.
			domAttr.set('fluxMeasurements' + b, 'rowspan',
				    bandFrequencies[b].length);
			var quals = [ '6000', '1500', '750', '375' ];
			for (var j = 0; j < quals.length; j++) {
			    domAttr.set('calibratorQuality' + quals[j] + '-' +
					b, 'rowspan', bandFrequencies[b].length);
			}
			var crow = domConstruct.create('tr');
			var refNode = dom.byId('fluxMeasurements' + b).parentNode;
			if (bandFrequencies[b].length > 2) {
			    var sibs = query('#fluxMeasurements' + b).parent().
				nextAll('tr');
			    refNode = sibs[bandFrequencies[b].length - 3];
			}
			domConstruct.place(crow, refNode, 'after');
			var th = domConstruct.create('th', {
			    'class': 'customFrequency',
			    'innerHTML': customFrequencies[i]
			});
			crow.appendChild(th);
			var td = domConstruct.create('td', {
			    'id': 'calibratorTime' + customFrequencies[i],
			    'class': 'customFrequency',
			    'innerHTML': 'N/A'
			});
			crow.appendChild(td);
			td = domConstruct.create('td', {
			    'id': 'calibratorFlux' + customFrequencies[i],
			    'class': 'customFrequency',
			    'innerHTML': 'N/A'
			});
			crow.appendChild(td);
		    }
		}
	    }

	    // Check if we are being called by the scheduler.
	    var schedulerBandFrequencies = {};
	    if (pageOptions.scheduler) {
		// The scheduler doesn't know the band names, so we figure
		// them out from the frequencies it gives us.
		pageOptions.bands = [];
		for (var i = 0; i < customFrequencies.length; i++) {
		    var b = frequency2band(customFrequencies[i]);
		    var bf = false;
		    for (var j = 0; j < pageOptions.bands.length; j++) {
			if (pageOptions.bands[j] === b) {
			    bf = true;
			}
		    }
		    if (bf === false) {
			pageOptions.bands.push(b);
			schedulerBandFrequencies[b] = [ customFrequencies[i] ];
		    } else {
			schedulerBandFrequencies[b].push(customFrequencies[i]);
		    }
		}
	    }

	    // Check if we are limiting the bands that we show.
	    var bandsOnly = [];
	    if (pageOptions.bands) {
		bandsOnly = pageOptions.bands;
		if (!(pageOptions.bands instanceof Array)) {
		    bandsOnly = [ pageOptions.bands ];
		}

		for (var i = 0; i < caldb.bands.length; i++) {
		    var showBand = false;
		    for (var j = 0; j < bandsOnly.length; j++) {
			if (bandsOnly[j] === caldb.bands[i]) {
			    showBand = true;
			    break;
			}
		    }
		    if (!showBand) {
			// Hide this band.
			// First, don't show the flux densities.
			var hrows = [ dom.byId('fluxMeasurements' + caldb.bands[i]).
				      parentNode ];
			if (bandFrequencies[caldb.bands[i]].length > 1) {
			    var sibs = query('#fluxMeasurements' + caldb.bands[i]).
				parent().nextAll('tr');
			    for (var j = 0; j < bandFrequencies[caldb.bands[i]].length - 1;
				 j++) {
				hrows.push(sibs[j]);
			    }
			}
			for (var j = 0; j < hrows.length; j++) {
			    domClass.add(hrows[j], 'hidden');
			}
			// And get rid of the band buttons in the plots.
			for (var j = 0; j < showButtons.length; j++) {
			    var tdNode = dom.byId(showButtons[j] + caldb.bands[i]).
				parentNode;
			    domClass.add(tdNode, 'hidden');
			}
			// If we're at 16cm, hide the 16cm warning box.
			if (caldb.bands[i] === '16cm') {
			    domClass.add('warning16cm', 'hidden');
			}
		    } else if (pageOptions.scheduler) {
			// When displaying a page for the scheduler, we only want to
			// display the frequencies that will be observed.
			for (var j = 0; j < bandFrequencies[caldb.bands[i]].length; j++) {
			    var showFreq = false;
			    for (var k = 0; k < schedulerBandFrequencies[caldb.bands[i]].length; k++) {
				if (bandFrequencies[caldb.bands[i]][j] ==
				    schedulerBandFrequencies[caldb.bands[i]][k]) {
				    showFreq = true;
				}
			    }
			    if (showFreq === false) {
				domClass.add(dom.byId('calibratorFlux' +
						      bandFrequencies[caldb.bands[i]][j]).parentNode,
					     'hidden');
			    }
			}
		    }
		}
	    }
	    if (pageOptions.scheduler) {
		bandFrequencies = schedulerBandFrequencies;
	    }

	    // Check if we are showing more details on this page.
	    if (pageOptions.detailed === 'true') {
		domClass.remove('measurementDetails', 'hidden');
		
	    }

	    var alterTimeSeriesAxesRange = function() {
		// Check the axis range.
		var a = plotsMade.timeSeries.getPlot('default').getSeriesStats();
		a.vmax += 1;
		a.vmin -= 1;
		// Ensure the minimum value isn't less than zero.
		a.vmin = (a.vmin < 0) ? 0 : a.vmin;
		plotsMade.timeSeries.addAxis('y', {
		    'font': chartFont,
		    'titleFont': chartFont,
		    'title': "Flux Density (Jy)",
		    'titleOrientation': 'axis',
		    'natural': false,
		    'fixed': false,
		    'vertical': true,
		    'min': a.vmin,
		    'max': a.vmax,
		    'fixLower': 'major',
		    'fixUpper': 'major'
		});
	    };

	    // A routine to remove or add back series from the plots.
	    var changePlots = function(evtObj) {
		var tband = evtObj.target.id.replace(/^.*Show/, '');
		bandsPlotted[tband] = false;
		for (var p in plotsMade) {
		    if (plotsMade.hasOwnProperty(p) &&
			plotsMade[p] !== null) {
			if (!domClass.contains(evtObj.target, 'unshown')) {
			    // Remove the series from the plot.
			    plotsMade[p].removeSeries(tband);
			} else {
			    // Add the series back to the plot.
			    plotsMade[p].addSeries(tband, seriesData[p][tband],
						   bandPlotProperties[tband][0]);
			}
			plotsMade[p].render();
		    }
		}
		for (var i = 0; i < showButtons.length; i++) {
		    domClass.toggle(showButtons[i] + tband, 'unshown');
		}
		alterTimeSeriesAxesRange();
		plotsMade.timeSeries.render();
	    };

	    // Setup the buttons.
	    for (var b in bandFrequencies) {
		if (bandFrequencies.hasOwnProperty(b)) {
		    bandsPlotted[b] = true;
		    for (var j = 0; j < showButtons.length; j++) {
			on(dom.byId(showButtons[j] + b),
			   'click', changePlots);
		    }
		}
	    }

	    var quickLinksNtr = 3;
	    var quickLinksRow = null;
	    var getQuickLinksRow = function() {
		// Make or return the latest row in the quick links table.
		if (quickLinksNtr === 3) {
		    quickLinksNtr = 0;
		    // Make a new row.
		    quickLinksRow = domConstruct.create('tr');
		    dom.byId('pageQuickLinks').appendChild(quickLinksRow);
		}
		return quickLinksRow;
	    };

	    var addQuickLink = function(target, text) {
		// Add a new entry to the quick links table.
		var tr = getQuickLinksRow();
		var td = domConstruct.create('td');
		tr.appendChild(td);
		var a = domConstruct.create('a', {
		    'href': '#' + target,
		    'innerHTML': text
		});
		td.appendChild(a);
		quickLinksNtr++;
	    };

	    // A function to show calibrator summary.
	    var showCalibratorSummary = function(data) {
		if (typeof data !== 'undefined' &&
		    typeof data.name !== 'undefined') {
		    domAttr.set('calibratorPosition', 'innerHTML',
				data.rightascension + ', ' +
				data.declination);
		    if (data.catalogue !== '') {
			domAttr.set('calibratorCatalogue', 'innerHTML',
				    data.catalogue.toUpperCase());
		    } else {
			domAttr.set('calibratorCatalogue', 'innerHTML', 'N/A');
		    }
		    if (data.riseLst >= 0 && data.setLst < 1) {
			var nRT = atnf.turns2hexa(data.riseLst, {
			    'units': 'hours', 'precision': 0 });
			var nST = atnf.turns2hexa(data.setLst, {
			    'units': 'hours', 'precision': 0 });
			domAttr.set('calibratorRiseSet', 'innerHTML',
				    nRT + ' / ' + nST);
		    } else if (data.riseLst >= 1) {
			domAttr.set('calibratorRiseSet', 'innerHTML', 'never rises');
		    } else if (data.riseLst < 0) {
			domAttr.set('calibratorRiseSet', 'innerHTML', 'never sets');
		    }
		    if (typeof data.quality !== 'undefined') {
			var pos = /^(.*)\[(.*)\]$/.exec(data.quality);
			domAttr.set('calibratorPositionUncertainty', 'innerHTML', pos[1]);
			domAttr.set('calibratorReference', 'innerHTML', pos[2]);
		    } else {
			domAttr.set('calibratorPositionUncertainty', 'innerHTML', 'N/A');
			domAttr.set('calibratorReference', 'innerHTML', 'N/A');
		    }			
		    
		    // Make some links for external images.
		    var raEls = data.rightascension.split(/\:/g);
		    var decEls = data.declination.split(/\:/g);
		    var linkHREFprefix = 'http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?' +
			'Interface=bform&VCOORD=' + raEls[0] + '+' + raEls[1] +
			'+' + raEls[2] + '%2C+' + decEls[0] + '+' + decEls[1] +
			'+' + decEls[2];
		    var linkHREFsuffix = '&SCOORD=Equatorial&EQUINX=2000&' +
			'MAPROJ=Gnomic&SFACTR=0.3&' +
			'ISCALN=Linear&GRIDD=No';
		    
		    // Check for PMN image.
		    if (((decEls[0] > -88) && (decEls[0] <= -39)) ||
			((decEls[0] > -27) && (decEls[0] <= -9)) ||
			((decEls[0] >= 0) && (decEls[0] <= 77))) {
			var a = domConstruct.create('a', {
			    'target': 'skyview',
			    'href': linkHREFprefix + '&SURVEY=GB6+%284850Mhz%29' +
				linkHREFsuffix,
			    'innerHTML': 'PMN/GB6 image' 
			});
			var td = domConstruct.create('td');
			td.appendChild(a);
			dom.byId('imageRow').appendChild(td);
		    }

		    // Check for SUMSS image.
		    if (decEls[0] < -30) {
			var a = domConstruct.create('a', {
			    'target': 'skyview',
			    'href': linkHREFprefix + '&SURVEY=SUMSS+843+MHz' +
				linkHREFsuffix,
			    'innerHTML': 'SUMSS image' 
			});
			var td = domConstruct.create('td');
			td.appendChild(a);
			dom.byId('imageRow').appendChild(td);
		    }
		    
		    // Check for NVSS image.
		    if (decEls[0] > -39) {
			var a = domConstruct.create('a', {
			    'target': 'skyview',
			    'href': linkHREFprefix + '&SURVEY=NVSS' +
				linkHREFsuffix,
			    'innerHTML': 'NVSS image' 
			});
			var td = domConstruct.create('td');
			td.appendChild(a);
			dom.byId('imageRow').appendChild(td);
		    }

		    // NED link
		    var a = domConstruct.create('a', {
			'target': 'ned',
			'href': 'http://nedwww.ipac.caltech.edu/cgi-bin/' +
			    'nph-objsearch?search_type=Near+Position+Search&' +
			    'in_csys=Equatorial&in_equinox=J2000.0&lon=' +
			    raEls[0] + '+' + raEls[1] + '+' + raEls[2] +
			    '&lat=' + decEls[0] + '+' + decEls[1] + '+' +
			    decEls[2] + '&radius=5.0&out_csys=Equatorial&' +
			    'out_equinox=J2000.0&obj_sort=Distance+to+search+' +
			    'center&zv_breaker=30000.0&list_limit=5&' +
			    'img_stamp=YES&z_constraint=Unconstrained&' +
			    'z_value1=&z_value2=&z_unit=z&ot_include=ALL&' +
			    'in_objtypes2=Radio',
			'innerHTML': 'NED reference'
		    });
		    var td = domConstruct.create('td');
		    td.appendChild(a);
		    dom.byId('imageRow').appendChild(td);


		    // Show the box now.
		    fx.fadeIn({
			'node': dom.byId('sourceInformation'),
			'duration': 500,
		    }).play();

		    // Add the notes section.
		    if (data.notes !== '') {
			domAttr.set('sourceNotesArea', 'innerHTML', data.notes);
		    } else {
			domAttr.set('sourceNotesArea', 'innerHTML',
				    'There are no notes in the database for this source.');
		    }
		    // And show that box now.
		    fx.fadeIn({
			'node': dom.byId('sourceNotes'),
			'duration': 500,
		    }).play();

		    // Add the VLA information if it's present.
		    if (typeof data.vla_text !== 'undefined' &&
			data.vla_text !== '') {
			var p = domConstruct.create('pre', {
			    'innerHTML': data.vla_text
			});
			dom.byId('vla-calibrator-area').appendChild(p);
			// And show the box.
			domClass.remove('vlaInfo', 'hidden');
			fx.fadeIn({
			    'node': dom.byId('vlaInfo'),
			    'duration': 500
			}).play();
			// Add a link to the quick links.
			addQuickLink('vlaInfo', 'VLA Calibrator Information');
		    }
		    // Always show the flux density measurements box if we
		    // have a valid calibrator.
		    fx.fadeIn({
			'node': dom.byId('fluxMeasurements'),
			'duration': 500
		    }).play();
		    fx.fadeIn({
			'node': dom.byId('quickLinks'),
			'duration': 500
		    }).play();
		}
	    };

	    // A function to show the latest flux density for a source.
	    var displaySummaryFlux = function(data) {
		var showFlux = function(frequency) {
		    var fluxDensity = caldb.fluxModel2Density(data.fluxdensity_coefficients,
							      frequency);
		    domAttr.set('calibratorFlux' + frequency, 'innerHTML',
				number.round(fluxDensity, 3) + ' &plusmn; ' +
				number.round(data.fluxdensity_scatter, 3));
		    domAttr.set('calibratorTime' + frequency, 'innerHTML',
				data.observationTime.timeString('%y-%O-%d'));
		};
		
		if (typeof data !== 'undefined' &&
		    typeof data.fluxdensity_coefficients !== 'undefined') {
		    if (typeof bandFrequencies[data.frequency_band] !== 'undefined') {
			for (var i = 0; 
			     i < bandFrequencies[data.frequency_band].length; i++) {
			    showFlux(bandFrequencies[data.frequency_band][i]);
			}
		    }
		}

		return(data);
	    };

	    var displayQuality = function(data) {
		if (typeof data !== 'undefined' &&
		    typeof data.source_name !== 'undefined') {
		    var arrays = [ '6km', '1.5km', '750m', '375m' ];
		    var parrays = [ '6000', '1500', '750', '375' ];
		    for (var i = 0; i < arrays.length; i++) {
			if (typeof data[arrays[i]] !== 'undefined') {
			    // Display and colour the defect number.
			    var pid = 'calibratorDefect' + parrays[i] +
				'-' + data.frequency_band;
			    domAttr.set(pid, 'innerHTML',
					number.round(data[arrays[i]].defect, 1) + '%');
			    if (data[arrays[i]].defect < 3) {
				// Good defect.
				domClass.remove(pid, 'qualityBad');
				domClass.remove(pid, 'qualityWarn');
				domClass.add(pid, 'qualityGood');
			    } else if (data[arrays[i]].defect < 10) {
				// Might be OK.
				domClass.remove(pid, 'qualityBad');
				domClass.add(pid, 'qualityWarn');
				domClass.remove(pid, 'qualityGood');
			    } else {
				// Bad defect.
				domClass.add(pid, 'qualityBad');
				domClass.remove(pid, 'qualityWarn');
				domClass.remove(pid, 'qualityGood');
			    }
			    // Display and colour the closure phase.
			    var cphase = Math.abs(number.round(data[arrays[i]].closure_phase, 1));
			    pid = 'calibratorClosure' + parrays[i] +
				'-' + data.frequency_band;
			    domAttr.set(pid, 'innerHTML', cphase + '&deg;');
			    if (cphase < 2) {
				// Good closure phase.
				domClass.remove(pid, 'qualityBad');
				domClass.remove(pid, 'qualityWarn');
				domClass.add(pid, 'qualityGood');
			    } else if (cphase < 5) {
				// Might be OK.
				domClass.remove(pid, 'qualityBad');
				domClass.add(pid, 'qualityWarn');
				domClass.remove(pid, 'qualityGood');
			    } else {
				// Bad closure phase.
				domClass.add(pid, 'qualityBad');
				domClass.remove(pid, 'qualityWarn');
				domClass.remove(pid, 'qualityGood');
			    }
			    // Reveal the cell contents.
			    pid = 'calibratorQuality' + parrays[i] +
				'-' + data.frequency_band;
			    // And show that box now.
			    fx.fadeIn({
				'node': dom.byId(pid),
				'duration': 500,
			    }).play();
			}
		    }
		}
	    };

	    var timeSeriesBands = {};
	    var siTimeSeriesBands = {};
	    var fluxModelBands = {};
	    var uvPointsBands = {};
	    for (var i = 0; i < caldb.bands.length; i++) {
		timeSeriesBands[caldb.bands[i]] = false;
		siTimeSeriesBands[caldb.bands[i]] = false;
		fluxModelBands[caldb.bands[i]] = false;
		uvPointsBands[caldb.bands[i]] = false;
	    }
	    var chartFont = 'normal normal bold 12pt Varela Round';

	    var timeSeriesShown = false;
	    var siTimeSeriesShown = false;
	    var displayTimeSeries = function(data) {
		// Take a series of flux models and plot them.
		
		// Start by making our plot area if we haven't already.
		if (!plotsMade.timeSeries) {
		    var minTime = '1993-01-01T00:00:00';
		    var maxTime = '2016-01-01T00:00:00';
		    var minAtime = atnfTime.new({ 'utcString': minTime});
		    var maxAtime = atnfTime.new({ 'utcString': maxTime});

		    // Make our Chart.
		    plotsMade.timeSeries = new Chart('time-series-plot-area').setTheme(myTheme);
		    plotsMade.siTimeSeries = new Chart('spectral-index-plot-area').
			setTheme(myTheme);
		    plotsMade.timeSeries.addPlot('default', { 'type': 'Scatter' });
		    plotsMade.siTimeSeries.addPlot('default', { 'type': 'Scatter' });
		    // Add the axes.
		    plotsMade.timeSeries.addAxis('x', {
			'title': 'Date',
			'titleOrientation': 'away',
			'font': chartFont,
			'titleFont': chartFont,
			'minorLabels': false,
			'natural': false,
			'min': minAtime,
			'max': maxAtime,
			'majorTickStep': 3.15576e10, // 365.25 days.
			'minorTickStep': 7.8894e9, // 1 quarter.
			'labelFunc': function(text, value, precision) {
			    var d = new Date(value);
			    return d.getFullYear();
			}
		    });
		    plotsMade.siTimeSeries.addAxis('x', {
			'title': 'Date',
			'titleOrientation': 'away',
			'font': chartFont,
			'titleFont': chartFont,
			'minorLabels': false,
			'natural': false,
			'min': minAtime,
			'max': maxAtime,
			'majorTickStep': 3.15576e10, // 365.25 days.
			'minorTickStep': 7.8894e9, // 1 quarter.
			'labelFunc': function(text, value, precision) {
			    var d = new Date(value);
			    return d.getFullYear();
			}
		    });
		    plotsMade.timeSeries.addAxis('y', {
			'font': chartFont,
			'titleFont': chartFont,
			'title': 'Flux Density (Jy)',
			'titleOrientation': 'axis',
			'natural': false,
			'fixed': false,
			'vertical': true,
			'fixLower': 'major',
			'fixUpper': 'major'
		    });
		    plotsMade.siTimeSeries.addAxis('y', {
			'font': chartFont,
			'titleFont': chartFont,
			'title': 'Spectral Index',
			'titleOrientation': 'axis',
			'natural': false,
			'fixed': false,
			'vertical': true,
			'min': -2.0,
			'max': 2.0,
			'majorTickStep': 0.2,
			'minorTickStep': 0.1
		    });

		}
		
		// Take the flux models and turn them into flux densities
		// at our required frequencies.
		if (typeof data !== 'undefined' &&
		    typeof data.time_series !== 'undefined' &&
		    typeof bandFrequencies[data.frequency_band] !== 'undefined') {
		    // Enable the selection button.
		    var fluxes = [];
		    var spectralIndices = [];
		    for (var i = 0; i < data.time_series.length; i++) {
			fluxes.push({
			    'x': data.time_series[i].observationTime.valueOf(),
			    'y': caldb.fluxModel2Density(
				data.time_series[i].fluxdensity_coefficients,
				bandPlotFrequencies[data.frequency_band])
			});
			var si = caldb.fluxModel2Slope(
			    data.time_series[i].fluxdensity_coefficients,
			    bandPlotFrequencies[data.frequency_band]);
			// console.log(si);
			if (si !== null) {
			    spectralIndices.push({
				'x': data.time_series[i].observationTime.valueOf(),
				'y': si
			    });
			}
			// Change the button label appropriately.
			domAttr.set('timeSeriesShow' + data.frequency_band,
				    'innerHTML', bandPlotFrequencies[data.frequency_band]);
			domAttr.set('spectralIndexShow' + data.frequency_band,
				    'innerHTML', bandPlotFrequencies[data.frequency_band]);
		    }
		    if (fluxes.length > 0) {
			for (var i = 0; i < showButtons.length; i++) {
			    domAttr.remove(showButtons[i] + 
					   data.frequency_band, 'disabled');
			}
			// Add the flux densities.
			seriesData.timeSeries[data.frequency_band] =
			    fluxes;
			if (bandsPlotted[data.frequency_band]) {
			    plotsMade.timeSeries.addSeries(
				data.frequency_band, fluxes,
				bandPlotProperties[data.frequency_band][0]);
			}
		    }
		    if (spectralIndices.length > 0) {
			// Add the spectral indices.
			seriesData.siTimeSeries[data.frequency_band] =
			    spectralIndices;
			if (bandsPlotted[data.frequency_band]) {
			    plotsMade.siTimeSeries.addSeries(
				data.frequency_band, spectralIndices,
				bandPlotProperties[data.frequency_band][0]);
			}
		    }
		    timeSeriesBands[data.frequency_band] = true;
		    siTimeSeriesBands[data.frequency_band] = true;
		    plotsMade.timeSeries.render();
		    plotsMade.siTimeSeries.render();
		    var plotDone = true;
		    var uBands = caldb.bands;
		    if (bandsOnly.length > 0) {
			uBands = bandsOnly;
		    }
		    for (var j = 0; j < uBands.length; j++) {
			if (timeSeriesBands[uBands[j]] === false) {
			    plotDone = false;
			}
		    }
		    if (plotDone) {
			alterTimeSeriesAxesRange();
			plotsMade.timeSeries.render();
		    }
		    // Show the plot box if we haven't already.
		    if (!timeSeriesShown &&
			data.time_series.length > 0) {
			coreFx.combine([
			    fx.fadeIn({
				'node': dom.byId('fluxTimeSeries'),
				'duration': 500
			    }),
			    fx.fadeIn({
				'node': dom.byId('spectralIndexTimeSeries'),
				'duration': 500
			    })
			]).play();
			timeSeriesShown = true;
			siTimeSeriesShown = true;
			addQuickLink('fluxTimeSeries', 'Flux Density Time Series');
			addQuickLink('spectralIndexTimeSeries', 
				     'Spectral Index Time Series');
		    }
		}
	    };

	    var fluxModelsShown = false;
	    var displayFluxModels = function(data) {
		// We don't display if we are in the scheduler mode.
		if (pageOptions.scheduler) {
		    domClass.add('fluxModel', 'hidden');
		    return;
		}
		// Now we plot the flux model as a curve across the
		// frequency range of the band.
		if (typeof data !== 'undefined' &&
		    typeof data.fluxdensity_coefficients !== 'undefined') {
		    // Make the plot area if we haven't already.
		    if (!plotsMade.fluxModel) {
			plotsMade.fluxModel = new Chart('flux-model-plot-area').setTheme(myTheme);
			plotsMade.fluxModel.addPlot('default', { 'type': 'Lines' });
			// Add the axes.
			plotsMade.fluxModel.addAxis('x', {
			    'title': 'Frequency (GHz)',
			    'titleOrientation': 'away',
			    'font': chartFont,
			    'titleFont': chartFont,
			    'minorLabels': false,
			    'minorTicks': false,
			    'natural': false,
			    'min': Math.log(bandRanges['16cm'].min / 1000) / Math.log(10),
			    'max': Math.log(bandRanges['3mm'].max / 1000) / Math.log(10),
			    'majorTickStep': 0.2,
			    'labelFunc': function(text, value, precision) {
				return number.round(Math.pow(10, value), 1);
			    }
			    // 'labels': [
			    // 	{ 'value': -0.0969, 'text': '0.8' },
			    // 	{ 'value': -0.0456, 'text': '0.9' },
			    // 	{ 'value': 0, 'text': '1' },
			    // 	{ 'value': 0.3010, 'text': '2' },
			    // 	{ 'value': 0.4771, 'text': '3' },
			    // 	{ 'value': 0.6021, 'text': '4' },
			    // 	{ 'value': 0.6990, 'text': '5' },
			    // 	{ 'value': 0.7782, 'text': '6' },
			    // 	{ 'value': 0.8451, 'text': '7' },
			    // 	{ 'value': 0.9031, 'text': '8' },
			    // 	{ 'value': 0.9542, 'text': '9' },
			    // 	{ 'value': 1, 'text': '10' },
			    // 	{ 'value': 1.3010, 'text': '20' },
			    // 	{ 'value': 1.4771, 'text': '30' },
			    // 	{ 'value': 1.6021, 'text': '40' },
			    // 	{ 'value': 1.6990, 'text': '50' },
			    // 	{ 'value': 1.7782, 'text': '60' },
			    // 	{ 'value': 1.8451, 'text': '70' },
			    // 	{ 'value': 1.9031, 'text': '80' },
			    // 	{ 'value': 1.9542, 'text': '90' },
			    // 	{ 'value': 2, 'text': '100' } ]
			});
			plotsMade.fluxModel.addAxis('y', {
			    'font': chartFont,
			    'titleFont': chartFont,
			    'title': 'Flux Density (Jy)',
			    'titleOrientation': 'axis',
			    'natural': false,
			    'fixed': false,
			    'vertical': true,
			    'fixLower': 'major',
			    'fixUpper': 'major'
			});
		    }
		    var lf = bandRanges[data.frequency_band].min;
		    var hf = bandRanges[data.frequency_band].max;
		    var np = 20;
		    var fi = (hf - lf) / np;
		    var fds = [];
		    for (var i = 0; i < np; i++) {
			fds.push( { 'x': Math.log((lf + i * fi) / 1000) / Math.log(10),
				    'y': caldb.fluxModel2Density(
					data.fluxdensity_coefficients,
					(lf + i * fi)) } );
		    }
		    if (fds.length > 0) {
			seriesData.fluxModel[data.frequency_band] = fds;
			plotsMade.fluxModel.addSeries(data.frequency_band, fds,
						      bandPlotProperties[data.frequency_band][0]
						     );
			plotsMade.fluxModel.render();
		    }
		    // Show the plot box if we haven't already.
		    if (!fluxModelsShown) {
			fx.fadeIn({
			    'node': dom.byId('fluxModel'),
			    'duration': 500
			}).play();
			fluxModelsShown = true;
			addQuickLink('fluxModel', 'Flux Model');
		    }
		}
	    };

	    var uvPointsShown = false;
	    var displayUvPoints = function(data) {
		// Plot the residual amplitudes as a function of uv distance.
		if (typeof data !== 'undefined' &&
		    typeof data.uv_points !== 'undefined' &&
		    data.uv_points.length > 0) {
			// Make the plot area if we haven't already.
		    if (!plotsMade.uvPoints) {
			plotsMade.uvPoints = new Chart('uv-residual-plot-area').setTheme(myTheme);
			plotsMade.uvPoints.addPlot('default', { 'type': 'Scatter' });
			// Add the axes.
			plotsMade.uvPoints.addAxis('x', {
			    'title': 'uv distance (klambda)',
			    'titleOrientation': 'away',
			    'font': chartFont,
			    'titleFont': chartFont,
			    'minorLabels': false,
			    'natural': false
			});
			plotsMade.uvPoints.addAxis('y', {
			    'font': chartFont,
			    'titleFont': chartFont,
			    'title': 'Residual Amplitude (Jy)',
			    'titleOrientation': 'axis',
			    'natural': false,
			    'vertical': true,
			});
		    }
		    var res = [];
		    for (var i = 0; i < data.uv_points.length; i++) {
			res.push( { 'x': data.uv_points[i].uv,
				    'y': data.uv_points[i].amp } );
		    }
		    if (res.length > 0) {
			seriesData.uvPoints[data.frequency_band] = res;
			plotsMade.uvPoints.addSeries(data.frequency_band, res,
						     bandPlotProperties[data.frequency_band][0]);
			plotsMade.uvPoints.render();
		    }
		    // Show the plot box if we haven't already.
		    if (!uvPointsShown) {
			fx.fadeIn({
			    'node': dom.byId('uvResiduals'),
			    'duration': 500
			}).play();
			uvPointsShown = true;
			addQuickLink('uvResiduals', 'Structure Plot');
		    }
		}
	    };

	    var showThisBand = function(bandName) {
		if (bandsOnly.length === 0) {
		    return true;
		}
		for (var i = 0; i < bandsOnly.length; i++) {
		    if (bandName === bandsOnly[i]) {
			return true;
		    }
		}
		return false;
	    };

	    var displayDetailedInfo = function(data) {
		// Show some more detailed information.
		var measBandRows = {};
		for (var i = 0; i < caldb.bands.length; i++) {
		    measBandRows[caldb.bands[i]] = {
			'rowDom': null,
			'nRows': 0
		    };
		}
		if (typeof data !== 'undefined' &&
		    typeof data.measurements !== 'undefined') {
		    var meas = data.measurements;
		    // Sort these by date.
		    meas.sort(function(a, b) {
			return (parseFloat(a.epoch_start) -
				parseFloat(b.epoch_start));
		    });
		    // Keep track of flux densities and spectral indices
		    // per frequency.
		    var computedValues = {};
		    for (var b in bandFrequencies) {
			if (bandFrequencies.hasOwnProperty(b)) {
			    computedValues[b] = [];
			    for (var bi = 0; bi < bandFrequencies[b].length; bi++) {
				computedValues[b].push({
				    'fluxDensities': [],
				    'spectralIndices': []
				});
			    }
			}
		    }
		    // Add R.A. and Dec. information to a table.
		    for (var i = 0; i < meas.length; i++) {
			// Do we show this measurement.
			if (showThisBand(meas[i].frequency_band)) {
			    var tr = domConstruct.create('tr');
			    dom.byId('detailsSummaryTable').appendChild(tr);
			    var td = domConstruct.create('td', {
				'innerHTML': meas[i].epochTime.timeString('%y-%O-%d')
			    });
			    tr.appendChild(td);
			    td = domConstruct.create('td', {
				'innerHTML': meas[i].project_code
			    });
			    tr.appendChild(td);
			    td = domConstruct.create('td', {
				'innerHTML': caldb.arrayName(meas[i].array)
			    });
			    tr.appendChild(td);
			    td = domConstruct.create('td', {
				'innerHTML': meas[i].frequency_band
			    });
			    tr.appendChild(td);
			    var freqString = '';
			    for (var j = 0; j < meas[i].frequencies.length; j++) {
				var cf = caldb.centralFrequency(
				    meas[i].frequencies[j]
				);
				if (cf) {
				    if (freqString !== '') {
					freqString += ',';
				    }
				    freqString += number.round(cf, 0);
				}
			    }
			    td = domConstruct.create('td', {
				'innerHTML': freqString
			    });
			    tr.appendChild(td);
			    td = domConstruct.create('td', {
				'innerHTML': meas[i].rightascension
			    });
			    tr.appendChild(td);
			    td = domConstruct.create('td', {
				'innerHTML': meas[i].declination
			    });
			    tr.appendChild(td);
			    for (var j = 0; j < bandFrequencies[meas[i].frequency_band].length; j++) {
				computedValues[meas[i].frequency_band][j].fluxDensities.push(
				    number.round(caldb.fluxModel2Density(
					meas[i].fluxdensities[0].fluxdensity_fit_coeff,
					bandFrequencies[meas[i].frequency_band][j]), 3)				    
				);
				computedValues[meas[i].frequency_band][j].spectralIndices.push(
				    number.round(caldb.fluxModel2Slope(
					meas[i].fluxdensities[0].fluxdensity_fit_coeff,
					bandFrequencies[meas[i].frequency_band][j]), 3)				    
				);
			    }
			    // The measurements table.
			    for (var j = 0; j < meas[i].frequencies.length; j++) {
				if (typeof measBandRows[meas[i].frequency_band] !== 'undefined' &&
				    measBandRows[meas[i].frequency_band].rowDom == null) {
				    measBandRows[meas[i].frequency_band].rowDom =
					domConstruct.create('tbody', {
					    'class': 'measBody' + meas[i].frequency_band,
					    'id': 'measBodyStart' + meas[i].frequency_band
					});
				    tr = domConstruct.create('tr');
				    measBandRows[meas[i].frequency_band].rowDom.appendChild(tr);
				    th = domConstruct.create('th', {
					'innerHTML': 'Band: ' + meas[i].frequency_band,
					'colspan': 8
				    });
				    tr.appendChild(th);
				    var canadd = false;
				    var isadded = false;
				    for (var k = 0; k < caldb.bands.length; k++) {
					if (caldb.bands[k] === meas[i].frequency_band) {
					    canadd = true;
					} else if (canadd === true) {
					    if (dom.byId('measBodyStart' + caldb.bands[k])) {
						domConstruct.place(measBandRows[meas[i].frequency_band].rowDom,
								   dom.byId('measBodyStart' + caldb.bands[k]),
								   'before');
						canadd = false;
						isadded = true;
					    }
					}
				    }
				    if (isadded === false) {
					dom.byId('detailsMeasurements').
					    appendChild(measBandRows[meas[i].frequency_band].rowDom);
				    }
				}
				tr = domConstruct.create('tr');
				// dom.byId('detailsMeasurements').appendChild(tr);
				measBandRows[meas[i].frequency_band].rowDom.appendChild(tr);
				if (j === 0) {
				    td = domConstruct.create('td', {
					'innerHTML': meas[i].epochTime.timeString('%y-%O-%d'),
					'rowSpan': meas[i].frequencies.length
				    });
				    tr.appendChild(td);
				    var fc = lang.clone(
					meas[i].fluxdensities[0].fluxdensity_fit_coeff);
				    var fl = fc.splice(-1, 1);
				    td = domConstruct.create('td', {
					'innerHTML': fc.join(','),
					'rowSpan': meas[i].frequencies.length
				    });
				    tr.appendChild(td);
				    td = domConstruct.create('td', {
					'innerHTML': (fl[0] === 'log') ? 'Y' : 'N',
					'rowSpan': meas[i].frequencies.length
				    });
				    tr.appendChild(td);
				    var defect = 
					((parseFloat(meas[i].fluxdensities[0].fluxdensity_scalar_averaged) /
					  parseFloat(meas[i].fluxdensities[0].fluxdensity_vector_averaged)) - 1) * 100;
				    td = domConstruct.create('td', {
					'innerHTML': number.round(defect, 1) + '%',
					'rowSpan': meas[i].frequencies.length
				    });
				    tr.appendChild(td);
				}
				td = domConstruct.create('td', {
				    'innerHTML': caldb.centralFrequency(meas[i].frequencies[j])
				});
				tr.appendChild(td);
				
				td = domConstruct.create('td', {
				    'innerHTML': number.round(caldb.fluxModel2Density(
					meas[i].fluxdensities[0].fluxdensity_fit_coeff,
					caldb.centralFrequency(meas[i].frequencies[j])), 3) +
					' &pm; ' + number.round(
					    meas[i].fluxdensities[0].fluxdensity_fit_scatter, 3)
				});
				tr.appendChild(td);
				td = domConstruct.create('td', {
				    'innerHTML': number.round(caldb.fluxModel2Slope(
					meas[i].fluxdensities[0].fluxdensity_fit_coeff,
					caldb.centralFrequency(meas[i].frequencies[j])), 3)
				});
				tr.appendChild(td);
				td = domConstruct.create('td', {
				    'innerHTML': number.round(parseFloat(
					meas[i].frequencies[j].closure_phases[0].
					    closure_phase_average), 1) + '&deg; &pm; ' +
					number.round(parseFloat(
					    meas[i].frequencies[j].closure_phases[0].
						closure_phase_measured_rms), 1) + '&deg;'
				});
				tr.appendChild(td);
			    }
			}
		    }
		    // Make the statistics section.
		    for (var i = 0; i < caldb.bands.length; i++) {
			if (typeof bandFrequencies[caldb.bands[i]] === 'undefined') {
			    continue;
			}
			for (var j = 0; j < bandFrequencies[caldb.bands[i]].length; j++) {
			    if (computedValues[caldb.bands[i]][j].fluxDensities.length > 0) {
				var tr = domConstruct.create('tr');
				dom.byId('detailsStatistics').appendChild(tr);
				var td = domConstruct.create('td', {
				    'innerHTML': caldb.bands[i]
				});
				tr.appendChild(td);
				td = domConstruct.create('td', {
				    'innerHTML': bandFrequencies[caldb.bands[i]][j]
				});
				tr.appendChild(td);
				var av = number.round(
				    arrayAverage(computedValues[caldb.bands[i]][j].fluxDensities), 3);
				td = domConstruct.create('td', {
				    'innerHTML': av
				});
				tr.appendChild(td);
				computedValues[caldb.bands[i]][j].fluxDensities.sort(
				    function(a, b) { return (a - b); }
				);
				td = domConstruct.create('td', {
				    'innerHTML': number.round(
					computedValues[caldb.bands[i]][j].fluxDensities[0] * 100 / av, 1) +
					'% / ' + number.round(
					    computedValues[caldb.bands[i]][j].fluxDensities[
						computedValues[caldb.bands[i]][j].fluxDensities.length - 1]
						* 100 / av, 1) + '%'
				});
				tr.appendChild(td);
			    }
			}
		    }
		    // Show the section now.
		    fx.fadeIn({
			'node': dom.byId('measurementDetails'),
			'duration': 500
		    }).play();
		}
	    };

	    // Get the basic information straight away.
	    caldb.getBasicInfo(pageOptions.source).then(showCalibratorSummary);
	    if (pageOptions.detailed === 'true') {
		// Detailed information on the source.
		caldb.allSourceDetails(pageOptions.source).then(displayDetailedInfo);
	    }
	    // And the flux models and defects are discovered by band.
	    for (var i = 0; i < caldb.bands.length; i++) {
		var getBand = true;
		if (bandsOnly.length > 0) {
		    getBand = false;
		    for (var j = 0; j < bandsOnly.length; j++) {
			if (caldb.bands[i] == bandsOnly[j]) {
			    getBand = true;
			    break;
			}
		    }
		}
		if (getBand) {
		    // The latest flux model.
		    caldb.latestFluxModel(pageOptions.source, caldb.bands[i]).
			then(displaySummaryFlux).then(displayFluxModels);
		    // The latest quality information.
		    caldb.latestQuality(pageOptions.source, caldb.bands[i]).
			then(displayQuality);
		    // Time-series of all flux models.
		    caldb.fluxModelTimeSeries(pageOptions.source, caldb.bands[i]).
			then(displayTimeSeries);
		    // The uv distance distribution.
		    caldb.uvPoints(pageOptions.source, caldb.bands[i]).then(displayUvPoints);
		}
	    }


	});
