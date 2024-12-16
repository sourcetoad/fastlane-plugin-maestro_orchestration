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

        sdk_dir = "~/Library/Android/sdk"
        adb = "#{sdk_dir}/platform-tools/adb"

        Fastlane::Actions::AndroidEmulatorAction.run(
          name: "Test_Emulator",
          sdk_dir: sdk_dir,
          package: params[:emulator_package],
          device: params[:emulator_device],
          port: "5554",
          demo_mode: false,
          cold_boot: true,
          additional_options: []
        )
        sleep(5)
        demo_mode(params)
        build_and_install_android_app(params)

        UI.message("Running Maestro tests on Android...")
        sh("maestro test #{params[:maestro_flow_file]}")
        UI.success("Finished Maestro tests on Android.")

        UI.message("Exit demo mode and kill Android emulator...")
        system("#{adb} shell am broadcast -a com.android.systemui.demo -e command exit")
        sleep(3)
        system("#{adb} emu kill")
        UI.success("Android emulator killed. Process finished.")
      end

      def self.demo_mode(params)
        sdk_dir = "~/Library/Android/sdk"

        UI.message("Checking and allowing demo mode on Android emulator...")
        sh("#{sdk_dir}/platform-tools/adb shell settings put global sysui_demo_allowed 1")
        sh("#{sdk_dir}/platform-tools/adb shell settings get global sysui_demo_allowed")

        UI.message("Setting demo mode commands...")
        sh("#{sdk_dir}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command enter")
        sh("#{sdk_dir}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200")
        sh("#{sdk_dir}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100")
        sh("#{sdk_dir}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4")
        sh("#{sdk_dir}/platform-tools/adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4")
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
            key: :emulator_package,
            env_name: "MAESTRO_AVD_PACKAGE",
            description: "The selected system image of the emulator",
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :emulator_device,
            env_name: "MAESTRO_AVD_DEVICE",
            description: "Device",
            default_value: "Nexus 5",
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :location,
            env_name: "MAESTRO_AVD_LOCATION",
            description: "Set location of the emulator '<longitude> <latitude>'",
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
