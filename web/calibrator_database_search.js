require([ "atnf/base", "dojo/dom", "dojo/dom-construct", "dojo/dom-attr",
	  "dojo/dom-class", "dojo/fx", "dojo/_base/fx", "./calibrator_database_api",
	  "dojo/number",
	  "dojo/domReady!" ],
	function(atnf, dom, domConstruct, domAttr, domClass, coreFx, fx, caldb,
		 number) {

	    var pageOptions = caldb.getOptions();

	    // Do some preliminary checks.
	    var checksFailed = false;
	    if (pageOptions.rarange || pageOptions.decrange) {
		if (!pageOptions.rarange || !pageOptions.decrange) {
		    checksFailed = true;
		} else if (!pageOptions.rarange.length ||
			   !pageOptions.decrange.length) {
		    checksFailed = true;
		} else if (pageOptions.rarange.length !== 2 ||
			   pageOptions.decrange.length !== 2) {
		    checksFailed = true;
		} else if (pageOptions.position || pageOptions.radius) {
		    checksFailed = true;
		} else {
		    for (var i = 0; i < 2; i++) {
			var ra = parseFloat(pageOptions.rarange[i]);
			var dec = parseFloat(pageOptions.decrange[i]);
			if (isNaN(ra) || isNaN(dec) ||
			    ra < 0 || ra > 24 ||
			    dec < -90 || dec > 90) {
			    checksFailed = true;
			}
		    }
		}
	    } else if (pageOptions.position || pageOptions.radius) {
		if (!pageOptions.position || !pageOptions.radius) {
		    checksFailed = true;
		} else if (!pageOptions.position.length) {
		    checksFailed = true;
		} else if (pageOptions.position.length !== 2) {
		    checksFailed = true;
		}
	    }
	    if (pageOptions.fluxlimit && !pageOptions.band) {
		checksFailed = true;
	    }

	    if (checksFailed) {
		domAttr.set('searchSummary', 'innerHTML',
			    'This page cannot search with the parameters it has been passed.');
		return;
	    } else {
		domClass.remove('searchResults', 'invisible');
	    }

	    // Generate a human-readable summary of what we will search for.
	    var searchMode = '';
	    var searchString = function() {
		var s = 'Searching for calibrators ';
		if (pageOptions.rarange &&
		    pageOptions.decrange) {
		    // Check that the Declination numbers are in the right
		    // order.
		    if (parseFloat(pageOptions.decrange[1]) < 
			parseFloat(pageOptions.decrange[0])) {
			var tp = pageOptions.decrange[0];
			pageOptions.decrange[0] = pageOptions.decrange[1];
			pageOptions.decrange[1] = tp;
		    }
		    s += 'with R.A. in the range ' +
			pageOptions.rarange[0] + ' to ' + pageOptions.rarange[1] +
			' hours, and Dec. in the range ' +
			pageOptions.decrange[0] + '&deg; to ' + 
			pageOptions.decrange[1] + '&deg;';
		    searchMode = 'slab';
		} else if (pageOptions.position &&
			   pageOptions.radius) {
		    s += 'within a radius of ' +
			pageOptions.radius + '&deg; of R.A. = ' +
			pageOptions.position[0] + ', Dec = ' +
			pageOptions.position[1];
		    searchMode = 'cone';
		}

		// Add restrictions now.
		if (pageOptions.fluxlimit &&
		    pageOptions.band) {
		    s += ' that have a flux density greater than ' +
			pageOptions.fluxlimit + ' Jy in the ' +
			pageOptions.band + ' band';
		} else if (pageOptions.measurements) {
		    s += ' that have at least one measurement';
		    if (pageOptions.band) {
			s += ' in the ' + pageOptions.band + ' band';
		    }
		}

		s += '.';
		domAttr.set('searchSummary', 'innerHTML', s);
	    };
	    searchString();

	    // The routine that constructs the summary table.
	    var summaryTable = function(data) {
		var tab = dom.byId('searchResultsTable');
		var tr = domConstruct.create('tr');
		tab.appendChild(tr);
		// The top row is mostly blank.
		var nb = (searchMode === 'cone') ? 4 : 3;
		for (var i = 0; i < nb; i++) {
		    var th = domConstruct.create('th');
		    tr.appendChild(th);
		}
		var fda = domConstruct.create('a', {
		    'href': 'calibrator_database_documentation.html#' +
			'interpreting-flux-densities',
		    'innerHTML': ' (?)',
		    'class': 'help-icon',
		    'target': 'documentation'
		});
		var th = domConstruct.create('th', {
		    'colspan': caldb.bands.length,
		    'innerHTML': 'Flux Density (Jy)'
		});
		tr.appendChild(th);
		th.appendChild(fda);
		// The second row is where all the action is.
		tr = domConstruct.create('tr');
		tab.appendChild(tr);
		th = domConstruct.create('th', {
		    'innerHTML': 'Name'
		});
		tr.appendChild(th);
		if (searchMode === 'cone') {
		    th = domConstruct.create('th', {
			'innerHTML': 'Distance'
		    });
		    tr.appendChild(th);
		}
		th = domConstruct.create('th', {
		    'innerHTML': 'R.A.'
		});
		tr.appendChild(th);
		th = domConstruct.create('th', {
		    'innerHTML': 'Dec.'
		});
		tr.appendChild(th);
		for (var i = 0; i < caldb.bands.length; i++) {
		    th = domConstruct.create('th', {
			'innerHTML': caldb.bands[i]
		    });
		    tr.appendChild(th);
		}
		if (typeof data !== 'undefined' &&
		    typeof data.matches !== 'undefined') {
		    var matches = data.matches;
		    if (searchMode === 'cone') {
			// Sort based on distance.
			matches.sort(function(a, b) {
			    return (a.angular_distance - b.angular_distance);
			});
		    } else {
			// Sort based on R.A.
			matches.sort(function(a, b) {
			    var c = a.skyRightAscension.toTurns() -
				b.skyRightAscension.toTurns();
			    if (c !== 0) {
				return c;
			    }
			    var d = a.skyDeclination.toTurns() -
				b.skyDeclination.toTurns();
			    return d;
			});
		    }
		    for (i = 0; i < matches.length; i++) {
			tr = domConstruct.create('tr');
			tab.appendChild(tr);
			var a = domConstruct.create('a', {
			    'href': 'calibrator_database_viewcal.html?source=' +
				matches[i].name,
			    'innerHTML': matches[i].name.toUpperCase()
			});
			var td = domConstruct.create('td');
			td.appendChild(a);
			tr.appendChild(td);
			if (searchMode === 'cone') {
			    td = domConstruct.create('td', {
				'innerHTML': number.round(
				    matches[i].angularDistance.toDegrees(), 2) +
				    '&deg;'
			    });
			    tr.appendChild(td);
			}
			td = domConstruct.create('td', {
			    'innerHTML': atnf.turns2hexa(
				matches[i].skyRightAscension.toTurns(), {
				    'units': 'hours',
				    'precision': 0
				})
			});
			tr.appendChild(td);
			td = domConstruct.create('td', {
			    'innerHTML': atnf.turns2hexa(
				matches[i].skyDeclination.toTurns(), {
				    'units': 'degrees',
				    'precision': 0,
				    'alwaysSigned': true
				})
			});
			tr.appendChild(td);
			for (var j = 0; j < caldb.bands.length; j++) {
			    td = domConstruct.create('td');
			    tr.appendChild(td);
			    for (var k = 0; k < matches[i].flux_densities.length; k++) {
				if (matches[i].flux_densities[k].bandname ===
				    caldb.bands[j]) {
				    domAttr.set(td, 'innerHTML',
						matches[i].flux_densities[k].flux_density);
				}
			    }
			}
		    }
		    coreFx.combine([
			fx.fadeOut({
			    'node': dom.byId('searchInProgress'),
			    'duration': 400
			}),
			fx.fadeIn({
			    'node': dom.byId('resultsTable'),
			    'duration': 400
			})
		    ]).play();
		}
	    };

	    // Call the server to do the search.
	    caldb.calibratorSearch(pageOptions).then(summaryTable);

	});