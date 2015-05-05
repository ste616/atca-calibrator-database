require([ "dojo/dom", "dojo/dom-construct", "dojo/dom-attr", "./calibrator_database_api",
	  "dojo/fx", "dojo/_base/fx",
	  "dojo/domReady!" ],
	function(dom, domConstruct, domAttr, caldb, coreFx, fx) {
	    
	    // A function to show all the database changes.
	    caldb.getRecentChanges().then(function(data) {
		if (typeof data !== 'undefined' &&
		    typeof data.changes !== 'undefined') {
		    for (var i = 0; i < data.changes.length; i++) {
			var tr = domConstruct.create('tr');
			dom.byId('listChanges').appendChild(tr);
			var td = domConstruct.create('td', {
			    'innerHTML': data.changes[i].time.
				substring(0, data.changes[i].time.length - 3),
			    'class': 'dbChangeTime'
			});
			tr.appendChild(td);
			td = domConstruct.create('td');
			tr.appendChild(td);
			if (data.changes[i].epoch_id !== 'null') {
			    var a = domConstruct.create('a', {
				'href': 'calibrator_database_epoch.html?epoch=' +
				    data.changes[i].epoch_id,
				'innerHTML': data.changes[i].description
			    });
			    td.appendChild(a);
			} else if (data.changes[i].cal_id !== 'null') {
			    var a = domConstruct.create('a', {
				'href': 'calibrator_database_viewcal.html?source=' +
				    data.changes[i].cal_id,
				'innerHTML': data.changes[i].description
			    });
			    td.appendChild(a);
			}
		    }
		}
	    });

	    // A function to show the epochs and then get a summary for each.
	    caldb.getEpochList().then(function(data) {
		if (typeof data !== 'undefined' &&
		    typeof data.epochs !== 'undefined') {
		    var epochs = data.epochs;
		    // Sort the epochs by their start MJD, ascending order.
		    epochs.sort(function(a, b) {
			return (a.mjd_start - b.mjd_start);
		    });
		    for (var i = 0; i < epochs.length; i++) {
			var tr = domConstruct.create('tr');
			dom.byId('epochList').appendChild(tr);
			var td = domConstruct.create('td', {
			    'innerHTML': epochs[i].project_code
			});
			tr.appendChild(td);
			td = domConstruct.create('td', {
			    'innerHTML': epochs[i].startTime.
				timeString('%y-%O-%d %H:%M') + ' - ' +
				epochs[i].endTime.timeString('%y-%O-%d %H:%M')
			});
			tr.appendChild(td);
			td = domConstruct.create('td', {
			    'innerHTML': caldb.arrayName(epochs[i].array)
			});
			tr.appendChild(td);
			td = domConstruct.create('td');
			tr.appendChild(td);
			var a = domConstruct.create('a', {
			    'id': 'esource' + epochs[i].epoch_id,
			    'href': 'calibrator_database_epoch.html?epoch=' +
				epochs[i].epoch_id,
			    'class': 'invisible'
			});
			td.appendChild(a);
			td = domConstruct.create('td');
			tr.appendChild(td);
			var s = domConstruct.create('span', {
			    'id': 'ebands' + epochs[i].epoch_id,
			    'class': 'invisible'
			});
			td.appendChild(s);
			// Now get the details for this epoch.
			caldb.getEpochSummary(epochs[i].epoch_id).then(function(data) {
			    if (typeof data !== 'undefined') {
				domAttr.set('esource' + data.epoch_id, 'innerHTML',
					    data.nsources);
				fx.fadeIn({
				    'node': dom.byId('esource' + data.epoch_id),
				    'duration': 400
				}).play();
				var bandString = '';
				for (var b in data.bands) {
				    if (data.bands.hasOwnProperty(b)) {
					if (bandString === '') {
					    bandString = b;
					} else {
					    bandString += ',' + b;
					}
				    }
				}
				domAttr.set('ebands' + data.epoch_id, 'innerHTML',
					    bandString);
				fx.fadeIn({
				    'node': dom.byId('ebands' + data.epoch_id),
				    'duration': 400
				}).play();
			    }
			});
		    }
		}
	    });

	});
	  