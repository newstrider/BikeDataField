# Garmin FTMS Bike Data Field 🚴

A robust Garmin Connect IQ Data Field written in Monkey C. It connects seamlessly via **Bluetooth Low Energy (BLE)** to standard fitness equipment supporting the **Bluetooth FTMS (Fitness Machine Service)** protocol—such as the **MERACH S26** indoor bike!

It monitors the *Indoor Bike Data* characteristic (UUID: `0x2AD2`), parses the bit-flags according to standard FTMS specifications, draws the metrics in a highly optimized full-screen layout, and automatically records the data natively into your activity `.fit` file for post-workout review on Garmin Connect.

## Features

- **Bluetooth Low Energy (BLE)**: Automatically scans for and pairs with standard FTMS bikes (Service UUID `0x1826`). Safely manages BLE lifecycle internally through the `compute()` function to prevent lifecycle crashes.
- **4-Quadrant Data Display**: An upgraded, fully custom `WatchUi.DataField` layout displaying multiple live metrics simultaneously in an easy-to-read layout:
  - **Power** (W)
  - **Speed** (kph)
  - **Distance** (km)
  - **Calories** (cal)
  - **Elapsed Time** (MM:SS)
- **Automatic FIT File Recording**: Leverages the Garmin SDK's `FitContributor` module to write the custom incoming data points directly into your activity `.fit` file. They are mapped natively to Garmin's standard definitions (Power, Enhanced Speed, Distance, Calories), showing up perfectly on the web platform.
- **On-Device Settings**: Allows configurations via `Menu2` toggles stored in the device's application storage.

## Project Structure & Architecture

- **`manifest.xml`**: Specifies standard requirements, necessary permissions (`BluetoothLowEnergy`, `FitContributor`, `DataFieldAlert`), and enforces a `minSdkVersion` of `3.1.0`.
- **`monkey.jungle`**: Configurations for compiling the Monkey C code. Explicitly locks `base.sourcePath = source` to ensure rogue experimental or `sample` folders do not break the compiler!
- **`source/`**:
  - `BikeDataFieldApp.mc`: The core application launcher. Dynamically returns an untyped initial view to pass strict Garmin runtime validation arrays seamlessly.
  - `BleManager.mc`: The core BLE engine. Implements `BleDelegate` to scan, mount the device, enable notifications, and rigorously parse FTMS 16-bit flags. Uses strict 36-character hyphenated UUID designations (`00001826-0000-1000-8000-00805f9b34fb`) to satisfy Garmin's UUID parser.
  - `BikeDataFieldView.mc`: The logic engine. Evaluates the background grid layout, concatenates formatting safely, and feeds `FitContributor` its persistent data buffers.
- **`scripts/`**: Automation scripts directly tailored for environments like VS Code and specifically targeting Forerunner 165 (`fr165`). These scripts dynamically detect your Connect IQ SDK locally through `APPDATA`, so you're not forced to mess with system `PATH` variables!
  - `build.ps1`: Safely executes `monkeyc` to package your app securely into `bin\BikeDataField.prg`.
  - `simulate.ps1`: Mounts your freshly compiled app seamlessly into your local Garmin Connect IQ Simulator.
  - `sideload.ps1`: Using deep Shell COM mappings, it detects your Garmin MTP Drive automatically and transfers the Data Field perfectly over a normal USB connection.
  - `get_logs.ps1`: Automatically searches your watch's internal MTP storage for Garmin crash logs and debug traces, downloading them to a local `\logs` folder for analysis.

## How to Build & Run

Ensure your device is connected, or fire up exactly the script you need directly via PowerShell in VS Code:

1. **Compile the App**:
   ```pwsh
   .\scripts\build.ps1
   ```
2. **Test in the Simulator**:
   ```pwsh
   .\scripts\simulate.ps1
   ```
3. **Mount to your Garmin MTP Watch**:
   ```pwsh
   .\scripts\sideload.ps1
   ```

## Debugging

If the application crashes on your physical watch:
1. Re-connect the watch to your PC via USB.
2. Run the log retrieval script:
   ```pwsh
   .\scripts\get_logs.ps1
   ```
3. Check the `\logs` directory in this project. Look for `CIQ_LOG.txt` or similar files. These files contain stack traces and the line numbers where the failure occurred.
4. The `BleManager.mc` is configured with verbose `System.println` statements which will also appear in these logs.
