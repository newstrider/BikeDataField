import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;

class BleManager extends BluetoothLowEnergy.BleDelegate {

    private var _profileDef as Dictionary;
    
    // BLE state
    public var scanning as Boolean = false;
    public var device as BluetoothLowEnergy.Device or Null = null;

    // Parsed metrics
    public var power as Number = 0;
    public var speed as Float = 0.0f;
    public var distance as Number = 0;
    public var calories as Number = 0;
    public var elapsedTime as Number = 0;

    public function initialize() {
        BleDelegate.initialize();
        System.println("BLE: Initializing BleManager");
        
        // Setup FTMS Profile
        _profileDef = {
            :uuid => BluetoothLowEnergy.stringToUuid("00001826-0000-1000-8000-00805f9b34fb"),
            :characteristics => [{
                :uuid => BluetoothLowEnergy.stringToUuid("00002ad2-0000-1000-8000-00805f9b34fb"),
                :descriptors => [BluetoothLowEnergy.cccdUuid()]
            }]
        };

        try {
            BluetoothLowEnergy.registerProfile(_profileDef as Dictionary);
            System.println("BLE: Profile registered");
        } catch (e) {
            System.println("BLE Error during init: " + (e has :getErrorMessage ? e.getErrorMessage() : "unknown"));
        }
    }

    public function startScan() as Void {
        if (!scanning && device == null) {
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
            scanning = true;
        }
    }

    public function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        System.println("BLE: Scanning...");
        for (var result = scanResults.next(); result != null; result = scanResults.next()) {
            var sr = result as BluetoothLowEnergy.ScanResult;
            var iter = sr.getServiceUuids();
            for (var uuid = iter.next(); uuid != null; uuid = iter.next()) {
                var u = uuid as BluetoothLowEnergy.Uuid;
                if (u.equals(_profileDef.get(:uuid))) {
                    System.println("BLE: Found Bike, stopping scan and pairing...");
                    BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
                    scanning = false;
                    device = BluetoothLowEnergy.pairDevice(sr);
                    return;
                }
            }
        }
    }

    public function onConnectedStateChanged(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        System.println("BLE: Connection state changed to " + state);
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            setupNotifications(device);
        } else {
            self.device = null;
            // Don't restart scanning immediately in the callback, 
            // the compute() loop will pick it up securely
            scanning = false;
        }
    }

    private function setupNotifications(device as BluetoothLowEnergy.Device) as Void {
        System.println("BLE: Setting up notifications...");
        try {
            var profileUuid = _profileDef.get(:uuid) as BluetoothLowEnergy.Uuid;
            var service = device.getService(profileUuid);
            if (service != null) {
                var characteristic = service.getCharacteristic(BluetoothLowEnergy.stringToUuid("00002ad2-0000-1000-8000-00805f9b34fb"));
                if (characteristic != null) {
                    var cccd = characteristic.getDescriptor(BluetoothLowEnergy.cccdUuid());
                    if (cccd != null) {
                        System.println("BLE: Enabling notifications for 0x2AD2");
                        cccd.requestWrite([0x01, 0x00]b); 
                    } else {
                        System.println("BLE Error: CCCD not found");
                    }
                } else {
                    System.println("BLE Error: Characteristic 0x2AD2 not found");
                }
            } else {
                System.println("BLE Error: FTMS service 0x1826 not found on device");
            }
        } catch (e) {
            System.println("BLE Error in setupNotifications: " + e.getErrorMessage());
        }
    }

    public function onCharacteristicChanged(characteristic as BluetoothLowEnergy.Characteristic, value as Lang.ByteArray) as Void {
        parseIndoorBikeData(value);
    }

    private function parseIndoorBikeData(value as Lang.ByteArray) as Void {
        if (value.size() < 2) { return; }

        var offset = 0;
        
        // Parse flags (16-bit little-endian)
        var flags = (value[1] << 8) | (value[0] & 0xFF);
        offset += 2;

        var moreData = (flags & 0x0001) != 0;
        var avgSpeedPresent = (flags & 0x0002) != 0;
        var instCadencePresent = (flags & 0x0004) != 0;
        var avgCadencePresent = (flags & 0x0008) != 0;
        var totalDistancePresent = (flags & 0x0010) != 0;
        var resistancePresent = (flags & 0x0020) != 0;
        var instPowerPresent = (flags & 0x0040) != 0;
        var avgPowerPresent = (flags & 0x0080) != 0;
        var expendedEnergyPresent = (flags & 0x0100) != 0;
        var heartRatePresent = (flags & 0x0200) != 0;
        var metabolicPresent = (flags & 0x0400) != 0;
        var elapsedTimePresent = (flags & 0x0800) != 0;
        var remainingTimePresent = (flags & 0x1000) != 0;

        // Instantaneous Speed (uint16, 0.01 km/h resolution) -> convert to m/s for FIT but let's keep km/h for display or mph
        if (!moreData) {
            if (offset + 2 <= value.size()) {
                var speedRaw = (value[offset + 1] << 8) | (value[offset] & 0xFF);
                speed = speedRaw * 0.01f; // km/h
                offset += 2;
            }
        }

        if (avgSpeedPresent) { offset += 2; }
        if (instCadencePresent) { offset += 2; }
        if (avgCadencePresent) { offset += 2; }

        // Total Distance (uint24, 1 m resolution)
        if (totalDistancePresent) {
            if (offset + 3 <= value.size()) {
                distance = ((value[offset + 2] & 0xFF) << 16) | ((value[offset + 1] & 0xFF) << 8) | (value[offset] & 0xFF);
                offset += 3;
            }
        }

        if (resistancePresent) { offset += 2; }

        // Instantaneous Power (sint16, 1 W resolution)
        if (instPowerPresent) {
            if (offset + 2 <= value.size()) {
                power = (value[offset + 1] << 8) | (value[offset] & 0xFF);
                offset += 2;
            }
        }

        if (avgPowerPresent) { offset += 2; }

        // Expended Energy (Total Energy: uint16, Energy Per Hour: uint16, Energy Per Minute: uint8) -> Total Energy in kcal
        if (expendedEnergyPresent) {
            if (offset + 5 <= value.size()) {
                calories = (value[offset + 1] << 8) | (value[offset] & 0xFF);
                offset += 5;
            }
        }

        if (heartRatePresent) { offset += 1; }
        if (metabolicPresent) { offset += 1; }

        // Elapsed Time (uint16, 1 second resolution)
        if (elapsedTimePresent) {
            if (offset + 2 <= value.size()) {
                elapsedTime = (value[offset + 1] << 8) | (value[offset] & 0xFF);
                offset += 2;
            }
        }
    }
}
