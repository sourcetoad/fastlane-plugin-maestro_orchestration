require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane/plugin/android_emulator'
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

        setup_emulator(params)
        sleep(5)
        demo_mode(params)
        build_and_install_android_app(params)

        UI.message("Running Maestro tests on Android...")
        sh("maestro test #{params[:maestro_flow_file]}")
        UI.success("Finished Maestro tests on Android.")

        UI.message("Exit demo mode and kill Android emulator...")
        adb = "#{params[:sdk_dir]}/platform-tools/adb"
        system("#{adb} shell am broadcast -a com.android.systemui.demo -e command exit")
        sleep(3)
        system("#{adb} emu kill")
        UI.success("Android emulator killed. Process finished.")
      end

      def self.setup_emulator(params)
        sdk_dir = params[:sdk_dir]
        adb = "#{sdk_dir}/platform-tools/adb"

        UI.message("Stop all running emulators...")
        devices = `adb devices`.split("\n").drop(1)
        UI.message("Devices: #{devices}")

        if devices.empty?
          UI.message("No running emulators found.")
        else
          sleep(5)
          devices.each do |device|
            serial = device.split("\t").first  # Extract the serial number
            if serial.include?("emulator")     # Check if it's an emulator
              system("adb -s #{serial} emu kill") # Stop the emulator
              system("Stopped emulator: #{serial}")
            end
          end
        end

        UI.message("Setting up new Android emulator...")
        system("#{sdk_dir}/cmdline-tools/latest/bin/avdmanager create avd -n '#{params[:emulator_name]}' -f -k '#{params[:emulator_package]}' -d '#{params[:emulator_device]}'")
        sleep(5)

        UI.message("Starting Android emulator...")
        system("#{sdk_dir}/emulator/emulator -avd #{params[:emulator_name]} -port #{params[:emulator_port]} > /dev/null 2>&1 &")
        sh("#{adb} -e wait-for-device")

        sleep(5) while sh("#{adb} -e shell getprop sys.boot_completed").strip != "1"

        UI.success("Android emulator started.")
      end

      def self.demo_mode(params)
        UI.message("Checking and allowing demo mode on Android emulator...")
        sh("#{params[:sdk_dir]}/platform-tools/adb shell settings put global sysui_demo_allowed 1")
        sh("#{params[:sdk_dir]}/platform-tools/adb shell settings get global sysui_demo_allowed")

        UI.message("Setting demo mode commands...")
        sh("#{params[:sdk_dir]}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command enter")
        sh("#{params[:sdk_dir]}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200")
        sh("#{params[:sdk_dir]}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100")
        sh("#{params[:sdk_dir]}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4")
        sh("#{params[:sdk_dir]}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4")
      end

      def self.build_and_install_android_app(params)
        UI.message("Building Android app...")
        other_action.gradle(task: "assembleDebug")

        apk_path = Dir["app/build/outputs/apk/debug/app-debug.apk"].first

        if apk_path.nil?
          UI.user_error!("Error: APK file not found in build outputs.")
        end

        UI.message("Found APK file at: #{apk_path}")
        sh("adb install -r '#{apk_path}'")
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
            default_value: "~/Library/Android/sdk",
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
            default_value: "pixel_8_pro",
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
