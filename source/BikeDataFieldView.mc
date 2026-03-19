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

class BikeDataField extends WatchUi.DataField {

    private var _bleManager as BleManager;

    // FitContributor fields
    private var _powerField as FitContributor.Field or Null;
    private var _speedField as FitContributor.Field or Null;
    private var _distanceField as FitContributor.Field or Null;
    private var _caloriesField as FitContributor.Field or Null;
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
        var dictCalories = {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "kcal", :nativeNum => 11}; // 11 is calories

        _powerField = createField("power", 0, FitContributor.DATA_TYPE_SINT16, dictPower);
        _speedField = createField("speed", 1, FitContributor.DATA_TYPE_FLOAT, dictSpeed);
        _distanceField = createField("distance", 2, FitContributor.DATA_TYPE_FLOAT, dictDistance);
        _caloriesField = createField("calories", 3, FitContributor.DATA_TYPE_UINT16, dictCalories);
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
            // Speed from bike is km/h, FIT expects m/s
            _speedField.setData(_bleManager.speed / 3.6f);
        }
        if (_distanceField != null) {
            _distanceField.setData(_bleManager.distance.toFloat());
        }
        if (_caloriesField != null) {
            _caloriesField.setData(_bleManager.calories);
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

        // Heart Rate (Top Center)
        var hrStr = (_currentHeartRate == 0) ? "--" : _currentHeartRate.format("%d");
        dc.drawText(cx, r1y, smFont, "HEART RATE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, r1y + gap, font, hrStr + " bpm", Graphics.TEXT_JUSTIFY_CENTER);

        // Quadrant 1: Power (Row 1 Left)
        dc.drawText(w * 0.25, r2y, smFont, "Power", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.25, r2y + gap, font, _bleManager.power.format("%d") + " W", Graphics.TEXT_JUSTIFY_CENTER);

        // Quadrant 2: Speed (Row 1 Right)
        dc.drawText(w * 0.75, r2y, smFont, "Speed", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.75, r2y + gap, font, _bleManager.speed.format("%.1f") + " kph", Graphics.TEXT_JUSTIFY_CENTER);

        // Quadrant 3: Distance (Row 2 Left)
        var distKm = _bleManager.distance / 1000.0f;
        dc.drawText(w * 0.25, r3y, smFont, "Distance", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.25, r3y + gap, font, distKm.format("%.2f") + " km", Graphics.TEXT_JUSTIFY_CENTER);

        // Quadrant 4: Calories (Row 2 Right)
        dc.drawText(w * 0.75, r3y, smFont, "Calories", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 0.75, r3y + gap, font, _bleManager.calories.format("%d") + " cal", Graphics.TEXT_JUSTIFY_CENTER);

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
}