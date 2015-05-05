define([ "dojo/request/xhr", "dojo/_base/lang", "atnf/base", "atnf/angle",
	 "atnf/skyCoordinate", "atnf/source", "atnf/time", "dojox/timing" ],
       function(xhr, lang, atnf, atnfAngle, atnfSkyCoord, atnfSource, atnfTime, timing) {
	   // The name of the script to call on the server to
	   // interact with the v3 calibrator database.
	   var serverScript = '/cgi-bin/Calibrators/new/caldb_v3.pl';

	   // A check for an empty object.
	   var isEmpty = function(obj) {
	       for (var prop in obj) {
		   if (obj.hasOwnProperty(prop)) {
		       return false;
		   }
	       }
	       return true;
	   };

	   // The private communication method.
	   var _comms = function(data) {
	       return xhr(serverScript, {
		   'data': data,
		   'handleAs': 'json',
		   'method': 'POST'
	       }).then(function(rdata) {
		   if (isEmpty(rdata)) {
		       console.log("Received an empty data set.")
		       return _comms(data);
		   }
		   return rdata;
	       }, function(err) {
		   console.log("Received a data transfer error.")
		   console.log(err);
		   return _comms(data);
	       });
	   };
	   
	   var rObj = {};

	   // A list of all the bands we use.
	   rObj.bands = [ '16cm', '4cm', '15mm', '7mm', '3mm' ];

	   // The list of all the calibrators.
	   var calibratorNames = [];
	   
	   // Call the database to get just the names of the calibrators.
	   rObj.getCalibratorNames = function() {
	       return _comms({
		   'action': 'names'
	       }).then(function(data) {
		   if (typeof data !== 'undefined' &&
		       typeof data.names !== 'undefined') {
		       for (var i = 0; i < data.names.length; i++) {
			   calibratorNames.push({ 'name': data.names[i] });
		       }
		   }
	       });
	   };
	   
	   // Return the list of calibrators to the caller.
	   rObj.calibratorNames = function() {
	       return lang.clone(calibratorNames);
	   };
	   
	   // Get a list of the most recent changes.
	   rObj.getRecentChanges = function(nChanges) {
	       return _comms({
		   'action': 'changes',
		   'nchanges': nChanges
	       });
	   };

	   // Get a bit of information about a specified epoch.
	   rObj.getEpochSummary = function(epoch_id) {
	       if (typeof epoch_id === 'undefined') {
		   return null;
	       }
	       return _comms({
		   'action': 'epoch_summary',
		   'epoch_id': epoch_id
	       });
	   };

	   // Get a lot of information about a specified epoch.
	   rObj.getEpochDetail = function(epoch_id, options) {
	       if (typeof epoch_id === 'undefined') {
		   return null;
	       }
	       var commspkg = { 'action': 'epoch_details',
				'epoch_id': epoch_id };
	       if (typeof options !== 'undefined' &&
		   typeof options.showAll !== 'undefined' &&
		   options.showAll === true) {
		   commspkg.showall = 1;
	       }
	       return _comms(commspkg).then(function(data) {
		   if (typeof data !== 'undefined') {
		       // Change the MJDs into ATNF times, and compile a list
		       // of the bands present in the epoch.
		       data.bands = {};
		       for (var s in data.sources) {
			   if (data.sources.hasOwnProperty(s)) {
			       for (var b in data.sources[s]) {
				   if (data.sources[s].hasOwnProperty(b)) {
				       data.sources[s][b].startTime = atnfTime.new({
					   'mjd': parseFloat(data.sources[s][b].mjd_start)
				       });
				       if (typeof options !== 'undefined' &&
					   typeof options.epochStartTime !== 'undefined' &&
					   atnf.isTime(options.epochStartTime)) {
					   // Subtract some starting time from the
					   // start time of the observation.
					   data.sources[s][b].sinceStart =
					       (data.sources[s][b].startTime.time().valueOf() -
						options.epochStartTime.time().valueOf()) / 1000;
					   // This value is in seconds.
				       }
				       data.sources[s][b].integrationMinutes =
					   parseFloat(data.sources[s][b].integration) * 1440;
				       if (!data.bands[b]) {
					   data.bands[b] = true;
				       }
				   }
			       }
			   }
		       }
		       data.orderedBands = [];
		       for (var i = 0; i < rObj.bands.length; i++) {
			   if (data.bands.hasOwnProperty(rObj.bands[i])) {
			       data.orderedBands.push(rObj.bands[i]);
			   }
		       }
		   }
		   return data;
	       });
	   };

	   // Get the list of epochs.
	   rObj.getEpochList = function(options) {
	       var commspkg = { 'action': 'epochs' };
	       if (typeof(options) !== 'undefined') {
		   if (typeof(options.projectCode) !== 'undefined') {
		       commspkg['projectcode'] = options.projectCode;
		   }
		   if (typeof(options.showAll) !== 'undefined' &&
		       options.showAll) {
		       commspkg['showall'] = 1;
		   }
	       }
	       return _comms(commspkg).then(function(data) {
		   if (typeof data !== 'undefined' &&
		       typeof data.epochs !== 'undefined') {
		       // Change the MJDs into ATNF times.
		       for (var i = 0; i < data.epochs.length; i++) {
			   data.epochs[i].startTime = atnfTime.new({
			       'mjd': parseFloat(data.epochs[i].mjd_start)
			   });
			   data.epochs[i].endTime = atnfTime.new({
			       'mjd': parseFloat(data.epochs[i].mjd_end)
			   });
		       }
		   }

		   return data;
	       });
	   };

	   // Get basic information about a calibrator.
	   rObj.getBasicInfo = function(calibratorName) {
	       return _comms({
		   'action': 'info',
		   'source': calibratorName
	       }).then(function(data) {
		   if (typeof data !== 'undefined' &&
		       typeof data.rightascension !== 'undefined') {
		       data.skyRightAscension = atnfAngle.new({
			   'value': atnf.hexa2turns(data.rightascension, { 'units': 'hours' }),
			   'units': 'turns' });
		       data.skyDeclination = atnfAngle.new({
			   'value': atnf.hexa2turns(data.declination, { 'units': 'degrees' }),
			   'units': 'turns' });
		       data.skyCoordinate = atnfSkyCoord.new(
			   [ data.skyRightAscension, data.skyDeclination ]);
		       data.skySource = atnfSource.new({
			   'coordinate': data.skyCoordinate, 'name': data.name });
		       data.skySource.setLocation('ATCA');
		       data.riseLst = data.skySource.lstRise().toTurns();
		       data.setLst = data.skySource.lstSet().toTurns();
		   }		   
		   return data;
	       });
	   };
	   
	   // Get the latest flux model for a particular source and band.
	   rObj.latestFluxModel = function(calibratorName, bandName) {
	       return _comms({
		   'action': 'band_fluxdensity',
		   'source': calibratorName,
		   'band': bandName
	       }).then(function(data) {
		   // Change the returning MJD into an ATNF Time.
		   if (typeof data !== 'undefined' &&
		       typeof data.observation_mjd !== 'undefined') {
		       data.observationTime = atnfTime.new({
			   'mjd': parseFloat(data.observation_mjd)
		       });
		   }
		   return(data);
	       });
	   };

	   // Get a time-series for a particular source and band.
	   rObj.fluxModelTimeSeries = function(calibratorName, bandName) {
	       return _comms({
		   'action': 'band_timeseries',
		   'source': calibratorName,
		   'band': bandName
	       }).then(function(data) {
		   // Change each of the returning MJD into ATNF Times.
		   if (typeof data !== 'undefined' &&
		       typeof data.time_series !== 'undefined') {
		       for (var i = 0; i < data.time_series.length; i++) {
			   if (typeof data.time_series[i].observation_mjd 
			       !== 'undefined') {
			       data.time_series[i].observationTime =
				   atnfTime.new({
				       'mjd': parseFloat(data.time_series[i].observation_mjd)
				   });
			   }
		       }
		   }
		   return(data);
	       });
	   };

	   // Get the latest available defects and closure phases.
	   rObj.latestQuality = function(calibratorName, bandName) {
	       return _comms({
		   'action': 'band_quality',
		   'source': calibratorName,
		   'band': bandName
	       });
	   };

	   // Get the latest available uv points.
	   rObj.uvPoints = function(calibratorName, bandName) {
	       return _comms({
		   'action': 'band_uvpoints',
		   'source': calibratorName,
		   'band': bandName
	       });
	   };

	   // Search for a calibrator.
	   rObj.calibratorSearch = function(params) {
	       var pack = { 'action': 'search' };
	       if (params.rarange && params.decrange) {
		   pack.rarange = params.rarange[0] + ',' +
		       params.rarange[1];
		   pack.decrange = params.decrange[0] + ',' +
		       params.decrange[1];
	       } else if (params.position && params.radius) {
		   pack.position = params.position[0] + ',' +
		       params.position[1];
		   pack.radius = params.radius;
	       }
	       if (params.fluxlimit) {
		   pack['flux_limit'] = params.fluxlimit;
	       }
	       if (params.band) {
		   pack['flux_limit_band'] = params.band;
	       }
	       if (params.measurements) {
		   pack['allow_no_measurements'] = 0;
	       }
	       return _comms(pack).then(function(data) {
		   if (typeof data !== 'undefined' &&
		       typeof data.matches !== 'undefined') {
		       for (var i = 0; i < data.matches.length; i++) {
			   if (typeof data.matches[i].rightascension !== 'undefined' &&
			       typeof data.matches[i].declination !== 'undefined') {
			       data.matches[i].skyRightAscension =
				   atnfAngle.new({
				       'value': atnf.hexa2turns(
					   data.matches[i].rightascension, {
					       'units': 'hours' }),
				       'units': 'turns' });
			       data.matches[i].skyDeclination =
				   atnfAngle.new({
				       'value': atnf.hexa2turns(
					   data.matches[i].declination, {
					       'units': 'degrees' }),
				       'units': 'turns' });
			       data.matches[i].skyCoordinate = atnfSkyCoord.new(
				   [ data.matches[i].skyRightAscension,
				     data.matches[i].skyDeclination ]);
			       data.matches[i].skySource = atnfSource.new({
				   'coordinate': data.matches[i].skyCoordinate,
				   'name': data.matches[i].name });
			       data.matches[i].skySource.setLocation('ATCA');
			   }
			   if (typeof data.matches[i].angular_distance !== 'undefined') {
			       data.matches[i].angularDistance =
				   atnfAngle.new({
				       'value': data.matches[i].angular_distance,
				       'units': 'turns' });
			   }
		       }
		   }

		   return data;
	       });
	   };

	   // Get an almost complete list of details about a particular
	   // calibrator and all the observations the database has on it.
	   rObj.allSourceDetails = function(calibratorName) {
	       return _comms({
		   'action': 'source_all_details',
		   'source': calibratorName
	       }).then(function(data) {
		   // Do some data massaging.
		   if (typeof data !== 'undefined' &&
		       typeof data.measurements !== 'undefined') {
		       for (var i = 0; i < data.measurements.length; i++) {
			   if (typeof data.measurements[i].epoch_start !== 'undefined') {
			       data.measurements[i].epochTime =
				   atnfTime.new({
				       'mjd': parseFloat(data.measurements[i].epoch_start)
				   });
			   }
			   if (typeof data.rightascension !== 'undefined' &&
			       typeof data.declination !== 'undefined') {
			       data.measurements[i].skyRightAscension =
				   atnfAngle.new({
				       'value': atnf.hexa2turns(
					   data.measurements[i].rightascension, {
					       'units': 'hours'
					   }),
				       'units': 'turns'
				   });
			       data.measurements[i].skyDeclination =
				   atnfAngle.new({
				       'value': atnf.hexa2turns(
					   data.measurements[i].declination, {
					       'units': 'degrees'
					   }),
				       'units': 'turns'
				   });
			       data.measurements[i].skyCoordinate =
				   atnfSkyCoord.new(
				       [ data.measurements[i].skyRightAscension,
					 data.measurements[i].skyDeclination ] );
			       data.measurements[i].skySource =
				   atnfSource.new({
				       'coordinate': data.measurements[i].skyCoordinate,
				       'name': data.source_name
				   });
			       data.measurements[i].skySource.setLocation('ATCA');
			   }
		       }
		   }
		   return data;
	       });
	   };

	   // Get the computed statistics for each epoch.
	   rObj.projectStatistics = function(projectCode) {
	       
	   };
	   

	   // Take a flux model and return the flux density at the
	   // specified frequency.
	   rObj.fluxModel2Density = function(model, frequency) {
	       // The frequency should be in MHz, but the model will require
	       // it in GHz.
	       var f = frequency / 1000;
	       var isLog = (model[model.length - 1] === 'log');
	       if (isLog) {
		   f = Math.log(f) / Math.log(10);
	       }
	       var s = parseFloat(model[0]);
	       for (var i = 1; i < model.length; i++) {
		   // if ((i === model.length - 1) && isLog) {
		   if (i === model.length - 1) {
		       break;
		   }
		   s += parseFloat(model[i]) * Math.pow(f, i);
	       }
	       if (isLog) {
		   s = Math.pow(10, s);
	       }
	       return s;
	   };

	   // Take a flux model and return the log S - log v slope
	   // (the spectral index) at a specified frequency, by
	   // taking the derivative and evaluating.
	   rObj.fluxModel2Slope = function(model, frequency) {
	       // The frequency should be in MHz, but the model will require
	       // it in GHz.
	       var isLog = (model[model.length - 1] === 'log');
	       var f = Math.log(frequency / 1000) / Math.log(10);
	       // This only works if we have a log/log model.
	       if (!isLog) {
		   // We get the derivative of the general function
		   // S = a + bv + cv^2
		   // after being transformed to log S
		   // log S = log(a + bv + cv^2)
		   // by substituting x = log v, thus v = 10^x
		   // Then dlog S/dx is solved by Wolfram Alpha to be
		   // 10^x (b + 2^(x+1) * 5^x * c) / (a + 10^x * (b + c * 10^x))

		   // Check that we only have order 2 or below.
		   if ((model.length - 1) > 3) {
		       return null;
		   }
		   var a = (model.length >= 2) ? parseFloat(model[0]) : 0;
		   var b = (model.length >= 3) ? parseFloat(model[1]) : 0;
		   var c = (model.length == 4) ? parseFloat(model[2]) : 0;
		   var s = Math.pow(10, f) * (b + Math.pow(2, (f + 1)) *
					      Math.pow(5, f) * c) /
		       (a + Math.pow(10, f) * (b + c * Math.pow(10, f)));
		   return s;
	       }
	       var s = 0;
	       for (var i = 1; i < model.length; i++) {
		   if (i === model.length - 1) {
		       break;
		   }
		   s += parseFloat(model[i]) * i * Math.pow(f, (i - 1));
	       }
	       return s;
	   };

	   // Take the flux model and a reference frequency, and return the
	   // "alphas": the spectral index, spectral curvature, and third
	   // order spectral term. The alphas can be made in base e or base 10.
	   rObj.fluxModel2Alphas = function(model, referenceFreq, basee) {
	       // As long as the reference frequency and frequency are in
	       // the same units, we're OK. So it needs to be passed as MHz.
	       var isLog = (model[model.length - 1] === 'log');
	       // We can't do what we're about to do without a log model.
	       if (!isLog) {
		   return undefined;
	       }
	       var f = referenceFreq / 1000;
	       var a = (model.length >= 3) ? parseFloat(model[1]) : 0;
	       var b = (model.length >= 4) ? parseFloat(model[2]) : 0;
	       var c = (model.length == 5) ? parseFloat(model[3]) : 0;
	       var alphas = [];
	       if (model.length >= 3) {
		   alphas.push(a);
		   if (model.length >= 4) {
		       var a2 = b;
		       if (basee) {
			   a2 *= Math.log(Math.exp(1)) / Math.log(10);
		       }
		       alphas[0] += ((basee) ? Math.log(f) : 
				     Math.log(f) / Math.log(10)) * 2 * a2;
		       alphas.push(a2);
		       if (model.length == 5) {
			   var a3 = c;
			   if (basee) {
			       a3 *= Math.pow((Math.log(Math.exp(1)) / Math.log(10)), 2);
			   }
			   alphas[0] += ((basee) ? Math.pow(Math.log(f),2) :
					 Math.pow((Math.log(f) / Math.log(10)), 2)) *
			       3 * a3;
			   alphas[1] += ((basee) ? Math.log(f) :
					 Math.log(f) / Math.log(10)) * 3 * a3;
			   alphas.push(a3);
		       }
		   }
	       }
	       return alphas;
	   };

	   // Take a database array string and modify it to only return
	   // the array name.
	   rObj.arrayName = function(arrayString) {
	       if (typeof arrayString !== 'undefined') {
		   var a = arrayString.split(/\s/g);
		   return a[0];
	       }
	   };

	   // Take a frequency specification and get the central
	   // frequency.
	   rObj.centralFrequency = function(freqSpec) {
	       if (typeof freqSpec !== 'undefined' &&
		   typeof freqSpec.frequency_first !== 'undefined' &&
		   typeof freqSpec.frequency_interval !== 'undefined' &&
		   typeof freqSpec.nchans !== 'undefined') {
		   var mchan = (parseInt(freqSpec.nchans) - 1) / 2;
		   var cfreq = parseFloat(freqSpec.frequency_first) +
		       parseFloat(freqSpec.frequency_interval) * mchan;
		   return cfreq;
	       }
	       return null;
	   };

	   rObj.getOptions = function() {
	       
	       var options = {};
	       
	       var tagValue = function(args) {
		   if ((!args) || (!args.tag) || (!args.string)) {
		       return (null);
		   }
		   
		   var elementsExp;
		   if (args.string.search(/\&/) != -1) {
		       elementsExp = new
		       RegExp('^(.*?)' + args.tag + '\\=(\\S+?)\\&(.*)$', '');
		   } else {
		       elementsExp = new
		       RegExp('^(.*?)' + args.tag + '\\=(\\S+?)$','');
		   }
		   var elements = elementsExp.exec(args.string);
		   var value = elements[2];
		   var remainder = elements[1] + elements[3];
		   
		   return ({ value: value, remainder: remainder });
	       };
	       
	       var nextToken = function(string) {
		   // Find the string directly after the next question mark (?).
		   var elements = /^\?*(\S+?)\=.*$/.exec(string);
		   if (!elements) {
		       return (null);
		   }
		   return (elements[1]);
	       };
	       
	       var instructions = location.search + '&';
	       
	       var tokenNext = nextToken(instructions);
	       while (tokenNext != null) {
		   var response = tagValue({tag: tokenNext,
					    string: instructions});
		   instructions = response.remainder;
		   
		   if (/\,/.test(response.value) == false){
		       // just a single value
		       options[tokenNext] = response.value;
		   } else {
		       // a list of values, turn it into an array
		       options[tokenNext] =
			   response.value.split(/\,/g);
		   }
		   tokenNext = nextToken(instructions);
	       }
	       
	       return options;
	   };

	   return rObj;
       });
