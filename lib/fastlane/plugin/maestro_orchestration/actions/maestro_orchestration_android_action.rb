require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane/helper/adb_helper'
require_relative '../helper/maestro_orchestration_helper'

module Fastlane
  module Actions
    class MaestroOrchestrationAndroidAction < Action
      def self.run(params)
        required_params = [:emulator_package, :emulator_device, :maestro_flow_file]
        missing_params = required_params.select { |param| params[param].nil? }

        if missing_params.any?
          missing_params.each do |param|
            UI.error("Missing parameter: #{param}")
          end
          raise "Missing required parameters: #{missing_params.join(', ')}"
        end

        UI.message("Emualtor_device: #{params[:emulator_device]}")
        UI.message("--------------\n\nSDK DIR: #{params[:sdk_dir]}\n\n--------------")
        adb = Helper::AdbHelper.new
        UI.message("ADB: #{adb.adb_path}")

        setup_emulator(params)
        sleep(5)
        demo_mode(params)
        install_android_app(params)

        UI.message("Running Maestro tests on Android...")
        devices = adb.load_all_devices
        if devices.empty?
          UI.message("No running emulators found.")
        else
          sleep(2)
          UI.message("Devices: #{devices}")
          devices.each do |device|
            sh("maestro --device #{device.serial} test #{params[:maestro_flow_file]}")
            UI.success("Finished Maestro tests on Android.")
          end
        end

        UI.message("Exit demo mode and kill Android emulator...")
        adb.trigger(command: "shell am broadcast -a com.android.systemui.demo -e command exit", serial: devices.first.serial)
        sleep(5)
        adb.trigger(command: "emu kill", serial: devices.first.serial)
        UI.success("Android emulator killed. Process finished.")
      end

      def self.setup_emulator(params)
        emulator = Helper::EmulatorHelper.new
        adb = Helper::AdbHelper.new
        avdmanager = Helper::AvdHelper.new

        UI.message("Stop all running emulators...")
        devices = adb.load_all_devices
        UI.success("Devices: #{devices}")

        if devices.empty?
          UI.message("No running emulators found.")
        else
          devices.each do |device|
            UI.message("Stopping emulator: #{device.serial}")
            adb.trigger(command: "emu kill", serial: device.serial)
            sleep(5)
            system("Stopped emulator: #{device.serial}")
          end
        end
        UI.message("Waiting for all emulators to stop...")
        sleep(5)

        UI.message("Setting up new Android emulator...")
        avdmanager.create_avd(name: params[:emulator_name], package: params[:emulator_package], device: params[:emulator_device])

        UI.message("Starting Android emulator...")
        emulator.start_emulator(name: params[:emulator_name], port: params[:emulator_port])
        adb.trigger(command: "wait-for-device", serial: "emulator-#{params[:emulator_port]}")

        loop do
          result = `#{adb.adb_path} -e shell getprop sys.boot_completed`.strip
          UI.message("ADB Response: #{result.inspect}")
          if result == "1"
            UI.success("Device booted!")
            break
          end
          sleep(5)
        end

        UI.success("Android emulator started.")
      end

      def self.demo_mode(params)
        adb = Helper::AdbHelper.new
        adb.load_all_devices
        serial = adb.devices.first.serial

        UI.message("Checking and allowing demo mode on Android emulator...")
        adb.trigger(command: "shell settings put global sysui_demo_allowed 1", serial: serial)
        adb.trigger(command: "shell settings get global sysui_demo_allowed", serial: serial)

        UI.message("Setting demo mode commands...")
        adb.trigger(command: "shell am broadcast -a com.android.systemui.demo -e command enter", serial: serial)
        adb.trigger(command: "shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200", serial: serial)
        adb.trigger(command: "shell am broadcast -a com.android.systemui.demo -e command battery -e level 100", serial: serial)
        adb.trigger(command: "shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4", serial: serial)
        adb.trigger(command: "shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4", serial: serial)
      end

      def self.install_android_app(params)
        UI.message("Installing Android app...")

        adb = Helper::AdbHelper.new
        adb.load_all_devices
        serial = adb.devices.first.serial

        apk_path = Dir["app/build/outputs/apk/release/*.apk"].first
        UI.success("APK path: #{apk_path}")

        if apk_path.nil?
          UI.user_error!("Error: APK file not found in build outputs.")
        end

        UI.message("Found APK file at: #{apk_path}")
        adb.trigger(command: "install -r '#{apk_path}'", serial: serial)
        UI.success("APK installed on Android emulator.")
      end

      def self.description
        "Boots an Android emulator, builds the app, installs it, and runs Maestro tests"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :sdk_dir,
            env_name: "MAESTRO_ANDROID_SDK_DIR",
            description: "Path to the Android SDK DIR",
            default_value: ENV["ANDROID_HOME"] || ENV["ANDROID_SDK_ROOT"] || "~/Library/Android/sdk",
            optional: true,
            verify_block: proc do |value|
              UI.user_error!("No ANDROID_SDK_DIR given, pass using `sdk_dir: 'sdk_dir'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :emulator_name,
            env_name: "MAESTRO_AVD_NAME",
            description: "Name of the AVD",
            default_value: "Maestro_Android_Emulator",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :emulator_package,
            env_name: "MAESTRO_AVD_PACKAGE",
            description: "The selected system image of the emulator",
            default_value: "system-images;android-35;google_apis_playstore;arm64-v8a",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :emulator_device,
            env_name: "MAESTRO_AVD_DEVICE",
            description: "Device",
            default_value: "pixel_7_pro",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :location,
            env_name: "MAESTRO_AVD_LOCATION",
            description: "Set location of the emulator '<longitude> <latitude>'",
            default_value: "28.0362979, -82.4930012",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :emulator_port,
            env_name: "MAESTRO_AVD_PORT",
            description: "Port of the emulator",
            default_value: "5554",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :maestro_flow_file,
            env_name: "MAESTRO_ANDROID_FLOW_FILE",
            description: "The path to the Maestro flow YAML file",
            optional: false,
            type: String
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
