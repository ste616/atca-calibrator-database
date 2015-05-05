require([ "./calibrator_database_api", "dojo/dom", "dojo/dom-attr",
	  "dojo/domReady!" ],
	function(caldb, dom, domAttr) {
	    
	    // What project are we looking for?
	    var pageOptions = caldb.getOptions();
	    if (!pageOptions.project) {
		domAttr.set('projectCode', 'innerHTML', 'No project specified!');
		return;
	    }

	    domAttr.set('projectCode', 'innerHTML', 'Project: ' + 
			pageOptions.project);

	    
	});