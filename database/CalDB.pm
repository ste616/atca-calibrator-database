#!/usr/bin/perl

package CalDB::uvPoint;
use base 'CalDB::DBI';
CalDB::uvPoint->table('atca_caldb_uvpoint');
CalDB::uvPoint->columns(All => qw/uv_id uvdistance_bin_centre uvdistance_residual_amplitude uvdistance_bin_npoints flux_id/);
CalDB::uvPoint->has_a(flux_id => 'CalDB::FluxDensity');

package CalDB::ClosurePhase;
use base 'CalDB::DBI';
CalDB::ClosurePhase->table('atca_caldb_closure');
CalDB::ClosurePhase->columns(All => qw/clos_id closure_phase_average closure_phase_measured_rms closure_phase_theoretical_rms freq_id/);
CalDB::ClosurePhase->has_a(freq_id => 'CalDB::Frequency');

package CalDB::Frequency;
use base 'CalDB::DBI';
CalDB::Frequency->table('atca_caldb_frequency');
CalDB::Frequency->columns(All => qw/freq_id frequency_first_channel frequency_channel_interval n_channels meas_id dataset_name/);
CalDB::Frequency->has_many(closurephases => 'CalDB::ClosurePhase');
CalDB::Frequency->has_a(meas_id => 'CalDB::Measurement');

package CalDB::FluxDensity;
use base 'CalDB::DBI';
CalDB::FluxDensity->table('atca_caldb_fluxdensity');
CalDB::FluxDensity->columns(All => qw/flux_id fluxdensity_vector_averaged fluxdensity_scalar_averaged fluxdensity_fit_order fluxdensity_fit_coeff fluxdensity_fit_scatter meas_id phase_vector_averaged kstest_d kstest_prob reduced_chisquare/);
CalDB::FluxDensity->has_many(uvpoints => 'CalDB::uvPoint');
CalDB::FluxDensity->has_a(meas_id => 'CalDB::Measurement');

package CalDB::Measurement;
use base 'CalDB::DBI';
CalDB::Measurement->table('atca_caldb_measurement');
CalDB::Measurement->columns(All => qw/meas_id source_name rightascension declination observation_mjd_start observation_mjd_end observation_mjd_integration frequency_band epoch_id band_fluxdensity band_fluxdensity_frequency public self_calibrated/);
CalDB::Measurement->columns(TEMP => qw/fluxdensity_fit_coeff fluxdensity_fit_scatter kstest_d kstest_prob reduced_chisquare closures epochs fluxdensity_vector_averaged flux_id/);
CalDB::Measurement->has_many(frequencies => 'CalDB::Frequency');
CalDB::Measurement->has_many(fluxdensities => 'CalDB::FluxDensity');
CalDB::Measurement->has_a(epoch_id => 'CalDB::Epoch');
CalDB::Measurement->set_sql(data => qq{
    SELECT atca_caldb_measurement.meas_id,source_name,rightascension,declination,observation_mjd_start,observation_mjd_integration,frequency_band,self_calibrated,fluxdensity_fit_coeff,fluxdensity_fit_scatter,kstest_d,kstest_prob,reduced_chisquare
    FROM atca_caldb_measurement INNER JOIN atca_caldb_fluxdensity
    ON (atca_caldb_measurement.meas_id = atca_caldb_fluxdensity.meas_id)
    WHERE epoch_id = ? AND public >= ? });
CalDB::Measurement->set_sql(closure => qq{
    SELECT source_name,GROUP_CONCAT(closure_phase_average) AS closures,GROUP_CONCAT(epoch_id) AS epochs
    FROM atca_caldb_measurement
    INNER JOIN atca_caldb_frequency ON (atca_caldb_frequency.meas_id = atca_caldb_measurement.meas_id)
    INNER JOIN atca_caldb_closure ON (atca_caldb_closure.freq_id = atca_caldb_frequency.freq_id)
    WHERE source_name = ?
    AND frequency_band = ?
    GROUP BY frequency_band});
CalDB::Measurement->set_sql(project_sources => qq{
    SELECT source_name
    FROM atca_caldb_measurement INNER JOIN atca_caldb_epoch
    ON (atca_caldb_measurement.epoch_id = atca_caldb_epoch.epoch_id)
    WHERE project_code = ?
    GROUP BY source_name
});
CalDB::Measurement->set_sql(notnumbers => qq{
    SELECT atca_caldb_measurement.meas_id,public,fluxdensity_fit_coeff,flux_id,fluxdensity_vector_averaged
    FROM atca_caldb_measurement INNER JOIN atca_caldb_fluxdensity
    ON (atca_caldb_measurement.meas_id = atca_caldb_fluxdensity.meas_id)
    WHERE fluxdensity_vector_averaged=0
    AND public=1
});
CalDB::Measurement->set_sql(smallflux => qq{
    SELECT meas_id,public,band_fluxdensity
    FROM atca_caldb_measurement
    WHERE band_fluxdensity < ?
    AND public=1
});
CalDB::Measurement->set_sql(allfluxdensities => qq{
    SELECT source_name,rightascension,declination,observation_mjd_start,observation_mjd_end,observation_mjd_integration,frequency_band,epoch_id,band_fluxdensity,band_fluxdensity_frequency,fluxdensity_fit_coeff
    FROM atca_caldb_measurement
    RIGHT JOIN atca_caldb_fluxdensity ON (atca_caldb_fluxdensity.meas_id=atca_caldb_measurement.meas_id)
    WHERE public=1 
    ORDER by source_name,band_fluxdensity_frequency,observation_mjd_start
});

package CalDB::Change;
use base 'CalDB::DBI';
CalDB::Change->table('atca_caldb_change');
CalDB::Change->columns(All => qw/change_id title description change_time epoch_id cal_id/);
CalDB::Change->has_a(epoch_id => 'CalDB::Epoch');
CalDB::Change->has_a(cal_id => 'CalDB::Calibrator');
CalDB::Change->set_sql(public => qq{
    SELECT change_id,title,description,change_time,atca_caldb_change.epoch_id,cal_id
    FROM atca_caldb_change INNER JOIN atca_caldb_epoch
    ON (atca_caldb_change.epoch_id = atca_caldb_epoch.epoch_id)
    WHERE public = 1
    ORDER BY change_time DESC});

package CalDB::EpochSummary;
use base 'CalDB::DBI';
CalDB::EpochSummary->table('atca_caldb_epochsummary');
CalDB::EpochSummary->columns(All => qw/summary_id epoch_id frequency_band n_sources integration_time/);
CalDB::EpochSummary->has_a(epoch_id => 'CalDB::Epoch');
CalDB::EpochSummary->set_sql(project => qq{
    SELECT array,mjd_start,mjd_end,GROUP_CONCAT(frequency_band) AS bands,GROUP_CONCAT(n_sources) AS n_sources,GROUP_CONCAT(integration_time) AS integration_times
    FROM atca_caldb_epoch INNER JOIN atca_caldb_epochsummary
    ON (atca_caldb_epoch.epoch_id = atca_caldb_epochsummary.epoch_id)
    WHERE project_code = ?
    GROUP BY atca_caldb_epoch.epoch_id});

package CalDB::Epoch;
use base 'CalDB::DBI';
CalDB::Epoch->table('atca_caldb_epoch');
CalDB::Epoch->columns(All => qw/epoch_id project_code array mjd_start mjd_end public/);
CalDB::Epoch->has_many(measurements => 'CalDB::Measurement');
CalDB::Epoch->has_many(summaries => 'CalDB::EpochSummary');

package CalDB::Calibrator;
use base 'CalDB::DBI';
CalDB::Calibrator->table('atca_caldb_calibratorinfo');
CalDB::Calibrator->columns(All => qw/cal_id name rightascension declination notes catalogue info vla_text latest_16cm latest_4cm latest_15mm latest_7mm latest_3mm ra_decimal dec_decimal/);
CalDB::Calibrator->columns(TEMP => qw/fluxdensities fluxdensities_bands measids fluxdensities_coeffs/);
CalDB::Calibrator->columns(Essential => qw/name rightascension declination ra_decimal dec_decimal/);
CalDB::Calibrator->set_sql(c007 => qq{
    SELECT name,catalogue,atca_caldb_calibratorinfo.rightascension,atca_caldb_calibratorinfo.declination,ra_decimal,dec_decimal,group_concat(band_fluxdensity) AS fluxdensities,group_concat(frequency_band) AS fluxdensities_bands,group_concat(atca_caldb_measurement.meas_id) AS measids,group_concat(atca_caldb_fluxdensity.fluxdensity_fit_coeff SEPARATOR '/') AS fluxdensities_coeffs
    FROM atca_caldb_calibratorinfo INNER JOIN atca_caldb_measurement
    ON (atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_16cm
    OR atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_4cm
    OR atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_15mm
    OR atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_7mm
    OR atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_3mm)
    INNER JOIN atca_caldb_fluxdensity ON (atca_caldb_fluxdensity.meas_id = atca_caldb_measurement.meas_id)
    WHERE (catalogue = 'vla' OR catalogue = 'atca' OR catalogue = 'lcs1')
    GROUP BY name});

CalDB::Calibrator->set_sql(position => qq{
    SELECT cal_id,name,atca_caldb_calibratorinfo.rightascension,atca_caldb_calibratorinfo.declination,group_concat(band_fluxdensity) AS fluxdensities,group_concat(frequency_band) AS fluxdensities_bands,group_concat(atca_caldb_measurement.meas_id) AS measids
    FROM atca_caldb_calibratorinfo INNER JOIN atca_caldb_measurement
    ON (atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_16cm
    OR atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_4cm
    OR atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_15mm
    OR atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_7mm
    OR atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_3mm)
    WHERE dec_decimal >= ?
    AND dec_decimal <= ?
    AND (ra_decimal >= ? AND ra_decimal <= ?)
    OR (ra_decimal >= ? AND ra_decimal <= ?)
    GROUP BY name});
CalDB::Calibrator->set_sql(scheduler_position_16cm => qq{
    SELECT cal_id,name,atca_caldb_calibratorinfo.rightascension,atca_caldb_calibratorinfo.declination,group_concat(band_fluxdensity) AS fluxdensities,group_concat(frequency_band) AS fluxdensities_bands,group_concat(atca_caldb_measurement.meas_id) AS measids,group_concat(atca_caldb_fluxdensity.fluxdensity_fit_coeff SEPARATOR '/') AS fluxdensities_coeffs
    FROM atca_caldb_calibratorinfo STRAIGHT_JOIN atca_caldb_measurement
    ON (atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_16cm)
    STRAIGHT_JOIN atca_caldb_fluxdensity ON (atca_caldb_fluxdensity.meas_id = atca_caldb_measurement.meas_id)
    WHERE dec_decimal >= ?
    AND dec_decimal <= ?
    AND (ra_decimal >= ? AND ra_decimal <= ?)
    OR (ra_decimal >= ? AND ra_decimal <= ?)
    GROUP BY name});
CalDB::Calibrator->set_sql(scheduler_position_4cm => qq{
    SELECT cal_id,name,atca_caldb_calibratorinfo.rightascension,atca_caldb_calibratorinfo.declination,group_concat(band_fluxdensity) AS fluxdensities,group_concat(frequency_band) AS fluxdensities_bands,group_concat(atca_caldb_measurement.meas_id) AS measids,group_concat(atca_caldb_fluxdensity.fluxdensity_fit_coeff SEPARATOR '/') AS fluxdensities_coeffs
    FROM atca_caldb_calibratorinfo STRAIGHT_JOIN atca_caldb_measurement
    ON (atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_4cm)
    STRAIGHT_JOIN atca_caldb_fluxdensity ON (atca_caldb_fluxdensity.meas_id = atca_caldb_measurement.meas_id)
    WHERE dec_decimal >= ?
    AND dec_decimal <= ?
    AND (ra_decimal >= ? AND ra_decimal <= ?)
    OR (ra_decimal >= ? AND ra_decimal <= ?)
    GROUP BY name});
CalDB::Calibrator->set_sql(scheduler_position_15mm => qq{
    SELECT cal_id,name,atca_caldb_calibratorinfo.rightascension,atca_caldb_calibratorinfo.declination,group_concat(band_fluxdensity) AS fluxdensities,group_concat(frequency_band) AS fluxdensities_bands,group_concat(atca_caldb_measurement.meas_id) AS measids,group_concat(atca_caldb_fluxdensity.fluxdensity_fit_coeff SEPARATOR '/') AS fluxdensities_coeffs
    FROM atca_caldb_calibratorinfo STRAIGHT_JOIN atca_caldb_measurement
    ON (atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_15mm)
    STRAIGHT_JOIN atca_caldb_fluxdensity ON (atca_caldb_fluxdensity.meas_id = atca_caldb_measurement.meas_id)
    WHERE dec_decimal >= ?
    AND dec_decimal <= ?
    AND (ra_decimal >= ? AND ra_decimal <= ?)
    OR (ra_decimal >= ? AND ra_decimal <= ?)
    GROUP BY name});
CalDB::Calibrator->set_sql(scheduler_position_7mm => qq{
    SELECT cal_id,name,atca_caldb_calibratorinfo.rightascension,atca_caldb_calibratorinfo.declination,group_concat(band_fluxdensity) AS fluxdensities,group_concat(frequency_band) AS fluxdensities_bands,group_concat(atca_caldb_measurement.meas_id) AS measids,group_concat(atca_caldb_fluxdensity.fluxdensity_fit_coeff SEPARATOR '/') AS fluxdensities_coeffs
    FROM atca_caldb_calibratorinfo STRAIGHT_JOIN atca_caldb_measurement
    ON (atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_7mm)
    STRAIGHT_JOIN atca_caldb_fluxdensity ON (atca_caldb_fluxdensity.meas_id = atca_caldb_measurement.meas_id)
    WHERE dec_decimal >= ?
    AND dec_decimal <= ?
    AND (ra_decimal >= ? AND ra_decimal <= ?)
    OR (ra_decimal >= ? AND ra_decimal <= ?)
    GROUP BY name});
CalDB::Calibrator->set_sql(scheduler_position_3mm => qq{
    SELECT cal_id,name,atca_caldb_calibratorinfo.rightascension,atca_caldb_calibratorinfo.declination,group_concat(band_fluxdensity) AS fluxdensities,group_concat(frequency_band) AS fluxdensities_bands,group_concat(atca_caldb_measurement.meas_id) AS measids,group_concat(atca_caldb_fluxdensity.fluxdensity_fit_coeff SEPARATOR '/') AS fluxdensities_coeffs
    FROM atca_caldb_calibratorinfo STRAIGHT_JOIN atca_caldb_measurement
    ON (atca_caldb_measurement.meas_id = atca_caldb_calibratorinfo.latest_3mm)
    STRAIGHT_JOIN atca_caldb_fluxdensity ON (atca_caldb_fluxdensity.meas_id = atca_caldb_measurement.meas_id)
    WHERE dec_decimal >= ?
    AND dec_decimal <= ?
    AND (ra_decimal >= ? AND ra_decimal <= ?)
    OR (ra_decimal >= ? AND ra_decimal <= ?)
    GROUP BY name});
