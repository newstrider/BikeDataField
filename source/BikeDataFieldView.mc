//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.FitContributor;
import Toybox.UserProfile;

class BikeDataField extends WatchUi.DataField {

    private var _bleManager as BleManager;

    // FitContributor fields (per-record)
    private var _powerField as FitContributor.Field or Null;
    private var _speedField as FitContributor.Field or Null;
    private var _distanceField as FitContributor.Field or Null;
    private var _resistanceField as FitContributor.Field or Null;

    // FitContributor fields (session & lap summaries)
    private var _distanceSessionField as FitContributor.Field or Null;
    private var _distanceLapField as FitContributor.Field or Null;
    private var _speedSessionField as FitContributor.Field or Null;
    private var _speedLapField as FitContributor.Field or Null;

    private var _currentHeartRate as Number = 0;

    //! Constructor
    public function initialize() {
        DataField.initialize();
        _bleManager = new $.BleManager();
        Toybox.BluetoothLowEnergy.setDelegate(_bleManager);

        // Initialize FitContributor fields
        var dictPower = {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "W", :nativeNum => 7};
        var dictSpeed = {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "m/s", :nativeNum => 73}; // 73 is enhanced_speed
        var dictDistance = {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "m", :nativeNum => 9}; // 9 is distance
        var dictResistance = {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "level"}; 

        // Session-level fields (written once when activity is saved)
        var dictDistanceSession = {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "m", :nativeNum => 9};
        var dictDistanceLap = {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "m", :nativeNum => 9};
        var dictSpeedSession = {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "m/s", :nativeNum => 73};
        var dictSpeedLap = {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "m/s", :nativeNum => 73};

        _powerField = createField("power", 0, FitContributor.DATA_TYPE_SINT16, dictPower);
        _speedField = createField("speed", 1, FitContributor.DATA_TYPE_FLOAT, dictSpeed);
        _distanceField = createField("distance", 2, FitContributor.DATA_TYPE_FLOAT, dictDistance);
        _resistanceField = createField("resistance", 3, FitContributor.DATA_TYPE_SINT16, dictResistance);

        // Session & lap summary fields
        _distanceSessionField = createField("total_distance", 4, FitContributor.DATA_TYPE_FLOAT, dictDistanceSession);
        _distanceLapField = createField("lap_distance", 5, FitContributor.DATA_TYPE_FLOAT, dictDistanceLap);
        _speedSessionField = createField("avg_speed", 6, FitContributor.DATA_TYPE_FLOAT, dictSpeedSession);
        _speedLapField = createField("lap_speed", 7, FitContributor.DATA_TYPE_FLOAT, dictSpeedLap);
    }

    //! Get the information to show in the data field
    //! @param info The updated Activity.Info object
    //! @return The data to show
    public function compute(info as Activity.Info) as Void {
        _bleManager.startScan();

        // We write developer data if fields are created
        if (_powerField != null) {
            _powerField.setData(_bleManager.power);
        }
        if (_speedField != null) {
            // Speed from bike is mph, FIT expects m/s (mph * 0.44704 = m/s)
            _speedField.setData(_bleManager.speed * 0.44704f);
        }
        if (_distanceField != null) {
            // Distance from bike is in imperial units; convert to meters
            // (raw / 1000 = miles, so raw * 1.60934 = meters)
            _distanceField.setData(_bleManager.distance.toFloat() * 1.60934f);
        }
        if (_resistanceField != null) {
            _resistanceField.setData(_bleManager.resistance);
        }

        // Update session & lap summary fields with latest values
        var distMeters = _bleManager.distance.toFloat() * 1.60934f;
        var speedMs = _bleManager.speed * 0.44704f;
        if (_distanceSessionField != null) {
            _distanceSessionField.setData(distMeters);
        }
        if (_distanceLapField != null) {
            _distanceLapField.setData(distMeters);
        }
        if (_speedSessionField != null) {
            _speedSessionField.setData(speedMs);
        }
        if (_speedLapField != null) {
            _speedLapField.setData(speedMs);
        }

        if (info.currentHeartRate != null) {
            _currentHeartRate = info.currentHeartRate;
        } else {
            _currentHeartRate = 0;
        }
    }

    public function onUpdate(dc as Dc) as Void {
        var bgColor = getBackgroundColor();
        var fgColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

        dc.setColor(bgColor, bgColor);
        dc.clear();
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        var w = dc.getWidth();
        var h = dc.getHeight();

        var font = Graphics.FONT_SMALL;
        var smFont = Graphics.FONT_XTINY;

        var cx = w / 2;
        var r1y = h * 0.05; // Heart Rate
        var r2y = h * 0.26; // Row 1 (Power/Speed)
        var r3y = h * 0.52; // Row 2 (Distance/Calories)
        var r4y = h * 0.78; // Row 3 (Time)
        var gap = 20;

        // Draw layout lines
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        
        // Horizontal lines separating Heart Rate, 4 Quadrants, and Time
        dc.drawLine(0, h * 0.22, w, h * 0.22); // Top boundary of quadrants
        dc.drawLine(0, h * 0.48, w, h * 0.48); // Divider between quadrant rows
        dc.drawLine(0, h * 0.74, w, h * 0.74); // Bottom boundary of quadrants
        
        // Vertical divider ONLY in the middle 4 blocks
        dc.drawLine(w / 2, h * 0.22, w / 2, h * 0.74);

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        // HR Zone decimal (below HR value)
        var hrZone = 0.0f;
        if (_currentHeartRate > 0) {
            hrZone = computeHrZoneDecimal(_currentHeartRate);
        }

        // Heart Rate (Top Center)
        var hrStr = (_currentHeartRate == 0) ? "--" : _currentHeartRate.format("%d");
        dc.drawText(cx, r1y, smFont, "HEART RATE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, r1y + gap, font, hrStr + " Z" + hrZone.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        // Quadrant 1: Power (Row 1 Left)
        dc.drawText(w * 0.25, r2y, smFont, "Power", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.25, r2y + gap, font, _bleManager.power.format("%d") + " W", Graphics.TEXT_JUSTIFY_CENTER);

        // Quadrant 2: Speed (Row 1 Right) - convert mph to kph
        var speedKph = _bleManager.speed * 1.60934f;
        dc.drawText(w * 0.75, r2y, smFont, "Speed", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.75, r2y + gap, font, speedKph.format("%.1f") + " kph", Graphics.TEXT_JUSTIFY_CENTER);

        // Quadrant 3: Distance (Row 2 Left) - convert miles to km
        var distKm = (_bleManager.distance / 1000.0f) * 1.60934f;
        dc.drawText(w * 0.25, r3y, smFont, "Distance", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.25, r3y + gap, font, distKm.format("%.2f") + " km", Graphics.TEXT_JUSTIFY_CENTER);

        // Quadrant 4: Resistance (Row 2 Right)
        dc.drawText(w * 0.75, r3y, smFont, "Resistance", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.75, r3y + gap, font, _bleManager.resistance.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        // Bottom space: Time
        var timeStr = "0:00";
        var s = _bleManager.elapsedTime;
        var min = (s / 60) % 60;
        var hrs = s / 3600;
        var sec = s % 60;
        if (hrs > 0) {
            timeStr = hrs + ":" + min.format("%02d") + ":" + sec.format("%02d");
        } else {
            timeStr = min + ":" + sec.format("%02d");
        }

        dc.drawText(cx, r4y, smFont, "ELAPSED TIME", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, r4y + gap, font, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Compute the decimal HR zone (e.g. 2.4 = 40% into Zone 2)
    private function computeHrZoneDecimal(hr as Number) as Float {
        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if (zones == null || zones.size() < 2) {
            return 0.0f;
        }

        // HR below the first zone boundary
        if (hr < (zones[0] as Number)) {
            return 0.0f;
        }

        // Find which zone HR falls into
        for (var i = 0; i < zones.size() - 1; i++) {
            var lower = zones[i] as Number;
            var upper = zones[i + 1] as Number;
            if (hr >= lower && hr < upper) {
                var fraction = (hr - lower).toFloat() / (upper - lower).toFloat();
                return (i + 1) + fraction;
            }
        }

        // HR at or above the last zone upper bound -> cap at max zone
        return (zones.size() - 1).toFloat();
    }
}