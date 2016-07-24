require([ "dojo/store/Memory", "dijit/form/FilteringSelect", "atnf/base", "dojo/number",
	  "dojo/dom", "dojo/dom-construct", "dojo/dom-attr", "./calibrator_database_api",
	  "dojo/fx", "dojo/_base/fx", "dojo/on", "dojo/query", "atnf/sourceResolver",
	  "dojo/dom-class",
	  "dojo/NodeList-manipulate", "dojo/NodeList-dom", "dojo/domReady!"],
	function(Memory, FilteringSelect, atnf, number, dom, domConstruct, domAttr, caldb,
		 coreFx, fx, on, query, atnfResolver, domClass) {

	    // A list of frequencies we show per band.
	    var bandFrequencies = {
		'16cm': [ 2100 ],
		'4cm': [ 5500, 9000 ],
		'15mm': [ 17000 ],
		'7mm': [ 33000 ],
		'3mm': [ 93000 ]
	    };

	    // A function to show calibrator summary.
	    var showCalibratorSummary = function(data) {
		if (typeof data !== 'undefined' &&
		    typeof data.name !== 'undefined') {
		    domAttr.set('calibratorName', 'innerHTML', data.name);
		    domAttr.set('calibratorPosition', 'innerHTML',
				data.rightascension + ', ' +
				data.declination);
		    domAttr.set('calibratorCatalogue', 'innerHTML', data.catalogue);
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
		    // Redirect the "more information" link.
		    domAttr.set('calibratorMoreInfo', 'href',
				'calibrator_database_viewcal?source=' +
				data.name);
		    // Show the box now.
		    fx.fadeIn({
			'node': dom.byId('quickSummary'),
			'duration': 500,
		    }).play();
		}
	    };

	    // A function to make the "resolving" overlay start or stop animating.
	    var currentAnimation = 'stop';
	    var endShowNode = null;
	    var animateResolving = function() {
		var displayAnim;
		if (currentAnimation === 'stop' || currentAnimation === 'middle') {
		    // Start the animation.
		    var anims = [];
		    var animNode = dom.byId('positionResolving');
		    var middleOpacity = 0.3;
		    if (currentAnimation === 'stop') {
			anims.push(
			    fx.fadeIn({
				'node': animNode,
				'duration': 400
			    })
			);
		    } else {
			anims.push(
			    fx.animateProperty({
				'node': animNode,
				'duration': 1000,
				'properties': {
				    'opacity': { 
					'start': middleOpacity, 
					'end': 1 
				    }
				}
			    })
			);
		    }
		    anims.push(
			fx.animateProperty({
			    'node': animNode,
			    'duration': 1000,
			    'properties': {
				'opacity': {
				    'start': 1,
				    'end': middleOpacity
				}
			    }
			})
		    );
		    if (currentAnimation === 'stop') {
			endShowNode = null;
		    }
		    currentAnimation = 'start';
		    displayAnim = coreFx.chain(anims);
		    on(displayAnim, "End", function() {
			if (currentAnimation === 'start') {
			    currentAnimation = 'middle';
			    animateResolving();
			} else if (currentAnimation === 'stop') {
			    var endAnims = [];
			    endAnims.push(
				fx.fadeOut({
				    'node': animNode,
				    'duration': 100
				})
			    );
			    if (endShowNode) {
				endAnims.push(
				    fx.fadeIn({
					'node': endShowNode,
					'duration': 200
				    })
				);
			    }
			    coreFx.chain(endAnims).play();
			}
		    });
		    displayAnim.play();
		} else if (currentAnimation === 'start') {
		    currentAnimation = 'stop';
		}
	    };

	    var fadeOuts = function() {
		// Fade out previous success/fails.
		fx.fadeOut({
		    'node': dom.byId('resolveSuccess'),
		    'duration': 1
		}).play();
		fx.fadeOut({
		    'node': dom.byId('resolveFail'),
		    'duration': 1
		}).play();
	    };

	    var positionResolved = false;
	    var resolveSourcePosition = function() {
		fadeOuts();
		
		// Check if this looks like something we need to resolve.
		var spEntry = domAttr.get('searchPosition', 'value');
		if ((spEntry.replace(/\s/g, '')) === '') {
		    // Blank box.
		    positionResolved = false;
		    return;
		}
		var checkPos = spEntry.match(/\:/g);
		if (checkPos && checkPos.length >= 2) {
		    // This looks like coordinates, since there are
		    // colon delimiters.
		    positionResolved = true;
		    return null;
		}

		animateResolving();
		var r = atnfResolver.new({
		    'sourceName': spEntry
		})
		return r.resolveName().then(function(rSource) {
		    var sourceDetails = rSource.source.details();
		    var rCoords = sourceDetails.coordinate.toJ2000();
		    if (rCoords.rightAscension.toTurns() !== 0 &&
			rCoords.declination.toTurns() !== 0) {
			positionResolved = true;
			var ra = atnf.turns2hexa(rCoords.rightAscension.toTurns(), {
			    'units': 'hours',
			    'precision': 0
			});
			var dec = atnf.turns2hexa(rCoords.declination.toTurns(), {
			    'units': 'degrees',
			    'precision': 0
			});
			domAttr.set('searchPosition', 'value', ra + ' ' + dec);
			domAttr.set('resolveSuccess', 'innerHTML', sourceDetails.name);
			endShowNode = dom.byId('resolveSuccess');
		    } else {
			positionResolved = false;
			endShowNode = dom.byId('resolveFail');
		    }
		    animateResolving();
		});
		
	    };

	    on(dom.byId('searchPosition'), 'change', resolveSourcePosition);


	    // A function to show the latest flux density for a source.
	    var displaySummaryFlux = function(data) {
		var showFlux = function(frequency) {
		    var fluxDensity = caldb.fluxModel2Density(data.fluxdensity_coefficients,
							      frequency);
		    domAttr.set('calibratorFlux' + frequency, 'innerHTML',
				number.round(fluxDensity, 3) + ' &plusmn; ' +
				number.round(data.fluxdensity_scatter, 3));
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
	    };

	    // Get a list of all the calibrators to begin with.
	    caldb.getCalibratorNames().then(function() {
		var calibratorNames = caldb.calibratorNames();
		for (var i = 0; i < calibratorNames.length; i++) {
		    calibratorNames[i].id = calibratorNames[i].name;
		    calibratorNames[i].oname = calibratorNames[i].name.replace('j', '');
		    calibratorNames[i].name = calibratorNames[i].name.replace('j', 'J');
		}
		calibratorNames.sort(function(a, b) {
		    var va = a.oname;
		    var vb = b.oname;
		    return va.localeCompare(vb);
		});

		var calibratorStore = new Memory({ 'data': calibratorNames });
		var filteringSelect = new FilteringSelect({
		    'id': 'calibratorQuickFind', 
		    'name': 'calibrator',
		    'value': '',
		    'store': calibratorStore,
		    'searchAttr': 'name',
		    'queryExpr': "*${0}*",
		    'autoComplete': false,
		    'onChange': function(calName) {
			caldb.getBasicInfo(calName).then(showCalibratorSummary);
			for (var i = 0; i < caldb.bands.length; i++) {
			    caldb.latestFluxModel(calName, caldb.bands[i]).then(displaySummaryFlux);
			}
		    }
		}, 'calibratorQuickFind');
	    });

	    caldb.getRecentChanges().then(function(data) {
		if (typeof data !== 'undefined' &&
		    typeof data.changes !== 'undefined') {
		    var tr = domConstruct.create('tr');
		    dom.byId('changeSummary').appendChild(tr);
		    for (var i = 0; i < data.changes.length; i++) {
			if (i > 2) {
			    break;
			}
			var td = domConstruct.create('td');
			tr.appendChild(td);
			var ts = domConstruct.create('div', {
			    'class': 'changeTitle',
			    'innerHTML': data.changes[i].title
			});
			td.appendChild(ts);
			ts = domConstruct.create('div', {
			    'class': 'changeDescription',
			    'innerHTML': data.changes[i].description
			});
			td.appendChild(ts);
			if (data.changes[i].epoch_id !== 'null') {
			    ts = domConstruct.create('div', {
				'class': 'changeShowEpoch'
			    });
			    td.appendChild(ts);
			    var a = domConstruct.create('a', {
				'href': 'calibrator_database_epoch.html?epoch=' +
				    data.changes[i].epoch_id,
				'innerHTML': 'show epoch'
			    });
			    ts.appendChild(a);
			} else if (data.changes[i].cal_id !== 'null') {
			    ts = domConstruct.create('div', {
				'class': 'changeShowEpoch'
			    });
			    td.appendChild(ts);
			    var a = domConstruct.create('a', {
				'href': 'calibrator_database_viewcal.html?source=' +
				    data.changes[i].cal_id,
				'innerHTML': 'show source'
			    });
			    ts.appendChild(a);
			}
			ts = domConstruct.create('div', {
			    'class': 'changeTime',
			    'innerHTML': data.changes[i].time
			});
			td.appendChild(ts);
		    }
		}
	    });

	    var unrestrictedSearchAllowed = false;

	    // Setup some button events.
	    on(dom.byId('resetButton'), 'click', function(evtObj) {
		// Reset the search form.
		fadeOuts();
		domAttr.set('searchPosition', 'value', '');
		domAttr.set('searchRadius', 'value', '10');
		domAttr.set('searchRaRange', 'value', '');
		domAttr.set('searchDecRange', 'value', '');
		domAttr.set('searchFluxLimit', 'value', '');
		dom.byId('measurementsRequired').checked = false;
		query('[name="searchBand"]').forEach(function(node) {
		    node.checked = false;
		});
		unrestrictedSearchAllowed = false;
		positionResolved = false;
	    });

	    var performSearch = function() {
		// Construct the search query page address.
		var pageAddress = 'calibrator_database_search.html?';
		var pos = domAttr.get('searchPosition', 'value');
		if (pos.length > 0 && positionResolved === false) {
		    // Have to resolve the position first.
		    resolveSourcePosition().then(performSearch);
		    return;
		}
		// Check which way to search.
		if (positionResolved === true &&
		    parseFloat(domAttr.get('searchRadius', 'value')) > 0) {
		    // Search by position.
		    var pos = domAttr.get('searchPosition', 'value');
		    pos = pos.replace(/^\s+/g, '');
		    pos = pos.replace(/\s+$/g, '');
		    pos = pos.replace(/\s+/g, ',');
		    pageAddress += 'position=' + pos;
		    var radius = domAttr.get('searchRadius', 'value');
		    radius = radius.replace(/\s+/g, '');
		    pageAddress += '&radius=' + radius;
		} else {
		    // Search by slab.
		    var slabSearch = true;
		    var raRange = domAttr.get('searchRaRange', 'value').
			replace(/\s/g, '');
		    var decRange = domAttr.get('searchDecRange', 'value').
			replace(/\s/g, '');

		    // We will enable slab search if either range is filled in,
		    // and let the other range default to its full range.
		    if (raRange.length === 0 &&
			decRange.length === 0) {
			slabSearch = false;
		    } else {
			if (raRange.length === 0) {
			    raRange = '0,24';
			}
			var raEls = raRange.split(/\,/g);
			if (decRange.length === 0) {
			    decRange = '-90,90';
			}
			var decEls = decRange.split(/\,/g);


			if (raEls.length !== 2 &&
			    decEls.length !== 2) {
			    slabSearch = false;
			} else {
			    for (var i = 0; i < 2; i++) {
				var raFloat = parseFloat(raEls[i]);
				var decFloat = parseFloat(decEls[i]);
				if (isNaN(raFloat) || isNaN(decFloat) ||
				    raFloat < 0 || raFloat > 24 ||
				    decFloat < -90 || decFloat > 90) {
				    slabSearch = false;
				}
			    }
			}
		    }

		    if (!slabSearch && unrestrictedSearchAllowed) {
			raRange = '0,24';
			decRange = '-90,90';
			slabSearch = true;
		    }
		    if (slabSearch) {
			pageAddress += 'rarange=' + raRange +
			    '&decrange=' + decRange;
		    } else {
			domClass.add('modal-error-search', 'md-show');
			return;
		    }
		}

		// Add any restrictions.
		var fluxLimit = domAttr.get('searchFluxLimit', 'value');
		var limitBand = query('[name="searchBand"]:checked').val();
		var restricted = false;
		if (fluxLimit.length > 0 &&
		    parseFloat(fluxLimit) > 0 &&
		    limitBand) {
		    restricted = true;
		    pageAddress += '&fluxlimit=' + fluxLimit;
		}
		if (dom.byId('measurementsRequired').checked) {
		    restricted = true;
		    pageAddress += '&measurements=true';
		}
		if (restricted && limitBand) {
		    pageAddress += '&band=' + limitBand;
		}

		// console.log(pageAddress);
		// Change to the search page.
		window.location.href = pageAddress;
	    };

	    on(dom.byId('searchButton'), 'click', performSearch);

	    on(dom.byId('position-unrestricted'), 'click', function() {
		domClass.remove('modal-error-search', 'md-show');
		unrestrictedSearchAllowed = true;
		performSearch();
	    });

	    on(dom.byId('position-restricted'), 'click', function() {
		domClass.remove('modal-error-search', 'md-show');
		unrestrictedSearchAllowed = false;
	    });
	       

	});