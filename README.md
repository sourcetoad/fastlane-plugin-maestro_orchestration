# maestro_orchestration plugin

[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-maestro_orchestration.svg)](https://badge.fury.io/rb/fastlane-plugin-maestro_orchestration)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-maestro_orchestration`, add it to your project by running:

```bash
fastlane add_plugin maestro_orchestration
```

## About maestro_orchestration

The `maestro_orchestration` plugin enhances your Fastlane workflows by integrating with the Maestro testing framework. It provides the following actions:

### 1. `maestro_orchestration` - separate actions for iOS and Android platform.
Executes Maestro test suites within your Fastlane lanes, facilitating automated UI testing for mobile applications.

## Parameters `iOS`

| Parameter           | Env Name | Notes                                                                                                                                                                        |
| ------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `workspace`         | `MAESTRO_IOS_WORKSPACE`      | Path to the project's Xcode workspace directory.  <br>  **Required**                                                                                     |
| `scheme`            | `MAESTRO_IOS_SCHEME`         | The iOS app scheme to build.  <br>  **Required**                                                                                                         |
| `maestro_flow_file` | `MAESTRO_IOS_FLOW_FILE`      | The path to the Maestro flows YAML file. <br> **Required**                                                                                               |
| `simulator_name`    | `MAESTRO_IOS_DEVICE_NAME`    | The iOS simulator device to boot. <br> **Default value:** 'iPhone 15'                                                                                    |
| `device_type`       | `MAESTRO_IOS_DEVICE`         | The iOS simulator device type for new simulator (e.g., iPhone #, iPad, etc...). <br> **Default value:** 'com.apple.CoreSimulator.SimDeviceType.iPhone-15'|

## Parameters `Android`
For Android OS we are relying `android-emulator-runner` github action to spin up emulator instance, therefore no additional parameters are required. `For more info:` https://github.com/ReactiveCircus/android-emulator-runner

| Parameter           | Env Name                           | Notes                                                                                                                                  |
| ------------------- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `sdk_dir`           | `MAESTRO_ANDROID_SDK_DIR`          | Path to the Android SDK DIR. <br> **Required**              `ENV["ANDROID_HOME"]`, `ENV["ANDROID_SDK_ROOT"]`, `~/Library/Android/sdk`  |
| `maestro_flow_file` | `MAESTRO_IOS_FLOW_FILE`            | The path to the Maestro flows YAML file.  <br> **Required**                                                                            |

### 2. `maestro_orchestartion_s3_upload`
Uploads a folder of files (such as screenshots) to an S3 bucket, organizing them based on the app version, theme, and device type.

| Parameter     | Env Name | Notes                                                                                                           |
| ------------- | -------- | --------------------------------------------------------------------------------------------------------------- |
| `folder_path` | `MAESTRO_SCREENSHOTS_FOLDER_PATH`            | Path to the local folder containing the files to upload. <br> **Required**  |
| `bucket`      | `MAESTRO_SCREENSHOTS_S3_BUCKET`              | The name of the S3 bucket where files will be uploaded.  <br> **Required**  |
| `s3_path`     | `MAESTRO_SCREENSHOTS_S3_PATH`                | The base S3 path (excluding the bucket name).            <br> **Required**  |
| `version`     | `MAESTRO_SCREENSHOTS_APP_VERSION`            | The app version associated with the uploaded files.      <br> **Required**  |
| `device`      | `MAESTRO_SCREENSHOTS_DEVICE`                 | The target device type (android or ios).                 <br> **Required**  |
| `theme`       | `MAESTRO_SCREENSHOTS_APPLICATION_THEME`      | The application theme (e.g., dark or light).             <br> Optional      |

### 3. `maestro_orchestration_api_request`
Sends an API request with a signed payload, typically used to notify external systems of events such as the completion of test runs or the availability of new screenshots.

| Parameter     | Env Name | Notes                                                                                                                         |
| ------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `s3_path`     | `MAESTRO_SCREENSHOTS_S3_PATH`                | The base S3 path (excluding the bucket name) where files are uploaded.  <br> **Required** |
| `version`     | `MAESTRO_SCREENSHOTS_APP_VERSION`            | The version of the app associated with the screenshots or test results. <br> **Required** |
| `device`      | `MAESTRO_SCREENSHOTS_APP_VERSION`            | The device type (android or ios).                                       <br> **Required** |
| `theme`       | `MAESTRO_SCREENSHOTS_APPLICATION_THEME`      | The application theme (e.g., dark or light).                            <br> Optional     |
| `hmac_secret` | `MAESTRO_SCREENSHOTS_HMAC_SECRET`            | The HMAC secret used to sign the payload for security purposes.         <br> **Required** |
| `url`         | `MAESTRO_SCREENSHOTS_WEBHOOK_URL`            | The endpoint URL to which the API request is sent.                      <br> **Required** |

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
