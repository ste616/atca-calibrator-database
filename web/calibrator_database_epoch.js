require([ "dojo/dom", "dojo/dom-construct", "dojo/dom-attr", "./calibrator_database_api",
	  "dojo/fx", "dojo/_base/fx", "dojo/dom-class", "dojo/number",
	  "dojo/domReady!" ],
	function(dom, domConstruct, domAttr, caldb, coreFx, fx, domClass, number) {

	    // What epoch are we looking for.
	    var pageOptions = caldb.getOptions();
	    if (!pageOptions.epoch) {
		domAttr.set('statusMessage', 'innerHTML', 'No epoch specified!');
		domClass.add('statusMessage', 'statusIsError');
		domClass.add('listEpochs', 'invisible');
		return;
	    }

	    // Some standard frequencies.
	    var freqs = {
		'16cm': 2100,
		'4cm': 5500,
		'15mm': 17000,
		'7mm': 33000,
		'3mm': 93000
	    };
	    
	    // A function to show the epochs and then get a summary for each.
	    caldb.getEpochList().then(function(data) {
		var epochFound = -1;
		if (typeof data !== 'undefined' &&
		    typeof data.epochs !== 'undefined') {
		    for (var i = 0; i < data.epochs.length; i++) {
			if (data.epochs[i].epoch_id !== pageOptions.epoch) {
			    continue;
			}
			domClass.add('statusMessage', 'hidden');
			epochFound = i;
			var m = dom.byId('summaryItems');
			var d = [ [ 'Project Code', 'project_code' ],
				  [ 'Array Name', 'array' ],
				  [ 'Start Time', 'startTime' ],
				  [ 'End Time', 'endTime' ] ];
			for (var j = 0; j < d.length; j++) {
			    var tr = domConstruct.create('tr');
			    m.appendChild(tr);
			    var th = domConstruct.create('th', {
				'innerHTML': d[j][0] + ':'
			    });
			    tr.appendChild(th);
			    var e = data.epochs[i][d[j][1]];
			    if (d[j][1] === 'array') {
				e = caldb.arrayName(e);
			    } else if (d[j][1] === 'startTime' ||
				       d[j][1] === 'endTime') {
				e = e.timeString('%y-%O-%d %H:%M');
			    }
			    var td = domConstruct.create('td', {
				'innerHTML': e
			    });
			    tr.appendChild(td);
			}
		    }
		    if (epochFound < 0) {
			domAttr.set('statusMessage', 'innerHTML', 
				    'Invalid epoch specified!');
			domClass.add('statusMessage', 'statusIsError');
			domClass.add('listEpochs', 'invisible');
			return;
		    } else {
			// We have a valid epoch, let's get all the observations.
			caldb.getEpochDetail(pageOptions.epoch, {
			    'epochStartTime': data.epochs[epochFound].startTime
			}).then(function(data) {
			    var nSources = {};
			    var integration = {};
			    if (typeof data !== 'undefined' &&
				typeof data.sources !== 'undefined') {
				// Construct the tables first.
				var t = dom.byId('epochList');
				var tr = domConstruct.create('tr');
				t.appendChild(tr);
				var th = domConstruct.create('th');
				tr.appendChild(th);
				for (var i = 0; i < data.orderedBands.length; i++) {
				    th = domConstruct.create('th', {
					'colspan': 2,
					'innerHTML': data.orderedBands[i]
				    });
				    tr.appendChild(th);
				    // Make similar columns for the summary table too.
				    th = domConstruct.create('th', {
					'innerHTML': data.orderedBands[i]
				    });
				    dom.byId('timeSummaryHeaders').appendChild(th);
				    td = domConstruct.create('td', {
					'id': 'timeSummaryNsources' + 
					    data.orderedBands[i]
				    });
				    dom.byId('timeSummaryNsources').appendChild(td);
				    td = domConstruct.create('td', {
					'id': 'timeSummaryIntegration' + 
					    data.orderedBands[i]
				    });
				    dom.byId('timeSummaryIntegration').appendChild(td);
				    integration[data.orderedBands[i]] = 0;
				    nSources[data.orderedBands[i]] = 0;
				}
				tr = domConstruct.create('tr');
				t.appendChild(tr);
				th = domConstruct.create('th', {
				    'innerHTML': 'Source'
				});
				tr.appendChild(th);
				for (var i = 0; i < data.orderedBands.length; i++) {
				    th = domConstruct.create('th', {
					'innerHTML': 'Since Start (Int. Time)'
				    });
				    tr.appendChild(th);
				    var fda = domConstruct.create('a', {
					'href': 'calibrator_database_documentation.html#' +
					    'interpreting-flux-densities',
					'innerHTML': ' (?)',
					'class': 'help-icon',
					'target': 'documentation'
				    });
				    th = domConstruct.create('th', {
					'innerHTML': 'Flux Density (Jy)'
				    });
				    tr.appendChild(th);
				    th.appendChild(fda);
				}
				// Sort the sources by observation time in the first
				// band.
				var sources = [];
				for (var s in data.sources) {
				    if (data.sources.hasOwnProperty(s)) {
					sources.push(s);
				    }
				}
				domAttr.set('timeSummaryNsourcesTotal', 'innerHTML',
					    sources.length);
				sources.sort(function(a, b) {
				    var lta = 1e9;
				    var ltb = 1e9;
				    for (var sa in data.sources[a]) {
					if (data.sources[a].hasOwnProperty(sa)) {
					    if (data.sources[a][sa].sinceStart < lta) {
						lta = data.sources[a][sa].sinceStart;
					    }
					}
				    }
				    for (var sb in data.sources[b]) {
					if (data.sources[b].hasOwnProperty(sb)) {
					    if (data.sources[b][sb].sinceStart < ltb) {
						ltb = data.sources[b][sb].sinceStart;
					    }
					}
				    }
				    return (lta - ltb);
				});
				for (var i = 0; i < sources.length; i++) {
				    tr = domConstruct.create('tr');
				    t.appendChild(tr);
				    var a = domConstruct.create('a', {
					'href': 'calibrator_database_viewcal.html?source=' +
					    sources[i],
					'innerHTML': sources[i]
				    });
				    var td = domConstruct.create('td');
				    td.appendChild(a);
				    tr.appendChild(td);
				    
				    for (var j = 0; j < data.orderedBands.length; j++) {
					td = domConstruct.create('td');
					tr.appendChild(td);
					var v = data.sources[sources[i]][data.orderedBands[j]];
					if (typeof v !== 'undefined') {
					    domAttr.set(td, 'innerHTML',
							number.round((v.sinceStart / 60), 1) + 
							'm (' +
							// v.startTime.
							// timeString('%y-%O-%d %H:%M') + ' (' +
							number.round(v.integrationMinutes, 1) +
							'm)');
					    nSources[data.orderedBands[j]]++;
					    integration[data.orderedBands[j]] +=
					    v.integrationMinutes;
					}
					td = domConstruct.create('td');
					tr.appendChild(td);
					if (typeof v !== 'undefined') {
					    domAttr.set(td, 'innerHTML',
							number.round(
							    caldb.fluxModel2Density(
								v.fluxdensity_coefficients,
								freqs[data.orderedBands[j]]),
							    3) + ' &plusmn; ' +
							number.round(
							    v.fluxdensity_scatter, 3));
					}
				    }
				}
				var totalIntegration = 0;
				for (var i = 0; i < data.orderedBands.length; i++) {
				    domAttr.set('timeSummaryNsources' + 
						data.orderedBands[i], 'innerHTML',
						nSources[data.orderedBands[i]]);
				    domAttr.set('timeSummaryIntegration' +
						data.orderedBands[i], 'innerHTML',
						number.round(integration[data.orderedBands[i]],
							     1) + 'm' );
				    totalIntegration += integration[data.orderedBands[i]];
				}
				domAttr.set('timeSummaryIntegrationTotal', 'innerHTML',
					    number.round(totalIntegration, 1) + 'm');
				coreFx.combine([
				    fx.fadeIn({
					'node': dom.byId('epochList'),
					'duration': 400
				    }),
				    fx.fadeOut({
					'node': dom.byId('loadingMessage'),
					'duration': 400
				    }),
				    fx.fadeIn({
					'node': dom.byId('timeSummaryItems'),
					'duration': 400
				    })
				]).play();
			    }
			});
		    }
		}
		    
	    });

	});
	  