require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane/helper/adb_helper'
require_relative '../helper/maestro_orchestration_helper'

module Fastlane
  module Actions
    class MaestroOrchestrationAndroidAction < Action
      def self.run(params)
        required_params = [:maestro_flow_file]
        missing_params = required_params.select { |param| params[param].nil? }

        if missing_params.any?
          missing_params.each do |param|
            UI.error("Missing parameter: #{param}")
          end
          raise "Missing required parameters: #{missing_params.join(', ')}"
        end

        Helper::MaestroOrchestrationHelper.clear_maestro_logs if params[:clear_maestro_logs]

        adb = Helper::AdbHelper.new

        sleep(5) # Give time emulator to boot
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
        # adb.trigger(command: "emu kill", serial: devices.first.serial)
        # UI.success("Android emulator killed. Process finished.")
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
      end

      def self.install_android_app(params)
        UI.message("Installing Android app...")

        adb = Helper::AdbHelper.new
        adb.load_all_devices
        serial = adb.devices.first.serial

        UI.message("Generating 'assembleRelease' build...")
        # Trigger the 'assembleRelease' build
        system("./gradlew assembleRelease")
        # After building, try to find the APK file in the release output directory
        apk_path = Dir["app/build/outputs/apk/release/*.apk"].first
        # If still not found after building, raise an error
        if apk_path.nil?
          UI.user_error!("Error: APK file not found in build outputs even after running assembleRelease.")
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
            key: :maestro_flow_file,
            env_name: "MAESTRO_ANDROID_FLOW_FILE",
            description: "The path to the Maestro flow YAML file",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :clear_maestro_logs,
            env_name: "MAESTRO_CLEAR_LOGS",
            description: "If true, clears all previous Maestro logs before running tests",
            type: Boolean,
            default_value: true,
            optional: true
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
