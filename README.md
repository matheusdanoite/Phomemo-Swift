# Phomemo T02 Swift

[Português Brasileiro](README.pt-br.md)

An iOS application built with SwiftUI and CoreBluetooth for printing images on the Phomemo T02 thermal printer. This project demonstrates advanced image processing techniques and Bluetooth Low Energy (BLE) communication to deliver high-quality 1-bit prints. It also features an experimental printer sharing system via Bluetooth.

## Features
- **Direct Bluetooth Printing**: Seamlessly connect to and print on Phomemo T02 devices.
- **Advanced Image Dithering**: Choose from multiple algorithms to convert grayscale images to 1-bit bitmaps:
  - **Floyd-Steinberg**: Provides high-quality error diffusion for detailed photos.
  - **Halftone**: Simulates traditional newspaper printing with dot patterns.
  - **Threshold**: simple high-contrast binarization for text and line art.
- **Camera & Gallery Support**: Capture new photos or select existing ones from your library.
- **Smart Image Preparation**: automatically handles rotation, scaling, and contrast adjustments for the 58mm thermal paper.
- **Custom Themes**: Switch between standard and "Pink Mode" themes.
- **Printer Sharing (Experimental)**: Share a connected printer with another device via Bluetooth.

## Printer Sharing 
When you connect your device to a Phomemo T02 printer, you can share the printer with another device via Bluetooth. This allows you to print from multiple devices without having to connect each device to the printer individually. The host device will display a "Host" badge on the Settings menu and how many Clients are connected, the clients will display a "Client" badge on the Settings menu.

## Build Instructions
1. Clone the repository.
2. Open `Phomemo T02 Swift.xcodeproj` in Xcode 13 or later.
3. Ensure your target device is running iOS 15.6+.
4. Build and run on a physical device (Bluetooth capabilities are required and do not work on the Simulator).

## Installation Instructions
1. Download the .ipa file on the [releases page](https://github.com/matheusdanoite/Phomemo-Swift/releases)
2. Sideload it with AltStore or your sideloader of choice on your physical device.

## Usage
1. **Connect**: Launch the app and it will automatically connect to the printer.
2. **Capture/Select**: Use the camera view to take a photo or tap the gallery icon to pick an image.
3. **Edit**: The app automatically processes the image. You can adjust the dithering algorithm swiping from left to right on the preview, and set intensity by swiping up and down.
4. **Print**: Tap the print button to send the data to the printer.
5. **Settings**: Swipe up from que capture button or the printer button to access Settings.

## Architecture
- **PhomemoDriver**: Manages CoreBluetooth interactions, scanning, connecting, and sending raw byte commands to the printer.
- **PhomemoImageProcessor**: Uses Apple's `Accelerate` framework (vImage) and `CoreImage` for high-performance image manipulation and dithering.
- **SwiftUI**: Provides a modern, reactive user interface with MVVM pattern (`ContentViewModel`).

## Requirements
- iOS 15.6+
- Xcode 13.0+
- Phomemo T02 Printer

## License
This project is licensed under the MIT License.

*Another software brought to you by matheusdanoite*
