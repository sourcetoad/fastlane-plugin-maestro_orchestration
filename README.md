# maestro_orchestration plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-maestro_orchestration)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-maestro_orchestration`, add it to your project by running:

```bash
fastlane add_plugin maestro_orchestration
```

## About maestro_orchestration

The `maestro_orchestration` plugin enhances your Fastlane workflows by integrating with the Maestro testing framework. It provides the following actions:

### 1. `maestro_orchestration` - separate actions for iOS and Android platform.
Executes Maestro test suites within your Fastlane lanes, facilitating automated UI testing for mobile applications.

**Parameters `iOS`:**

  -  `workspace`: Path to the project's Xcode workspace directory.
  -  `scheme`: The iOS app scheme to build.
  -  `maestro_flow_file`: The path to the Maestro flows YAML file.
  -  `simulator_name` (Optional): The iOS simulator device to boot. Defaults to "iPhone 15".
  -  `device_type` (Optional): The iOS simulator device type for new simulator (iPhone #, iPad, etc...). Defaults to iPhone 15 - com.apple.CoreSimulator.SimDeviceType.iPhone-15.

**Parameters `Android`:**

  - `sdk_dir` (Optional): Path to the Android SDK DIR. Set as optional but it searches env variables `ENV["ANDROID_HOME"]` or `ENV["ANDROID_SDK_ROOT"]` or defaults to `"~/Library/Android/sdk"`.
  -  `maestro_flow_file`: The path to the Maestro flows YAML file.
  - `emulator_name` (Optional): Name of the AVD. Defaults to "Maestro_Android_Emulator"
  - `emulator_package (Optional)`: The selected system image of the emulator.
  - `emulator_device` (Optional): Type of android device.
  - `emulator_port` (Optional): Port of the emulator.

### 2. `maestro_orchestartion_s3_upload`
Uploads a folder of files (such as screenshots) to an S3 bucket, organizing them based on the app version, theme, and device type.

**Parameters:**

  - `folder_path`: Path to the local folder containing the files to upload.
  - `bucket`: The name of the S3 bucket where files will be uploaded.
  - `s3_path`: The base S3 path (excluding the bucket name).
  - `version`: The app version associated with the uploaded files.
  - `device`: The target device type (android or ios).
  - `theme` (Optional): The application theme (e.g., dark or light).

### 3. `maestro_orchestration_api_request`
Sends an API request with a signed payload, typically used to notify external systems of events such as the completion of test runs or the availability of new screenshots.

**Parameters:**

  - `s3_path`: The base S3 path (excluding the bucket name) where files are uploaded.
  - `version`: The version of the app associated with the screenshots or test results.
  - `device`: The device type (android or ios).
  - `theme` (Optional): The application theme (e.g., dark or light).
  - `hmac_secret`: The HMAC secret used to sign the payload for security purposes.
  - `url`: The endpoint URL to which the API request is sent.

## Example

**iOS**
```ruby
lane :maestro do |options|
  maestro_orchestration_ios(
    scheme: your_app,
    workspace: your_app.xcworskapce,
    maestro_flow_file: "../.maestro/flow_ios.yaml"
  )

  maestro_orchestration_s3_upload(
    folder_path: "../.maestro/android/screenshots,
    bucket: "your-s3-bucket-name",
    s3_path: "path/to/s3/folder",
    version: "1.0.0",
    device: "android",
    theme: "dark" # optional
  )

  maestro_orchestration_api_request(
    s3_path: "path/to/s3/folder",
    version: "1.0.0",
    device: "android",
    hmac_secret: "your-hmac-secret",
    url: "https://your-webhook-url.com"
  )
end
```
**Android**
```ruby
lane :maestro do |options|
  maestro_orchestration_android(
    maestro_flow_file: "../.maestro/flow_android.yaml
  )

  maestro_orchestration_s3_upload(
    folder_path: "../.maestro/android/screenshots,
    bucket: "your-s3-bucket-name",
    s3_path: "path/to/s3/folder",
    version: "1.0.0",
    device: "android",
    theme: "dark" # optional
  )

  maestro_orchestration_api_request(
    s3_path: "path/to/s3/folder",
    version: "1.0.0",
    device: "android",
    hmac_secret: "your-hmac-secret",
    url: "https://your-webhook-url.com"
  )
end
```
**Note:** For Android platform, the plugin relies on the already previously generated build by Fastlane instead of generating a new one like for the iOS. The plugin was intended to run on simulators, and iOS has differents build types for simulators and real devices.

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
