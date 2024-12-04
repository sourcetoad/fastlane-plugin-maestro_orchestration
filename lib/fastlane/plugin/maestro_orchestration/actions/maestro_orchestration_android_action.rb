require 'fastlane/action'
require 'fastlane/plugin/android_emulator'

module Fastlane
  module Actions
    class MaestroOrchestrationAndroidAction < Action
      def self.run(params)
        Fastlane::Actions::AndroidEmulatorAction.run(
          name: params[:android_emulator_name],
          sdk_dir: params[:sdk_dir],
          package: params[:emulator_package],
          device: params[:emulator_device],
          demo_mode: params[:emulator_demo_mode],
          port: params[:emulator_port],
          cold_boot: params[:emulator_cold_boot],
          additional_options: params[:emulator_additional_options]
        )
        
        build_and_install_android_app(params)
        

        UI.message("Running Maestro tests on Android...")
        sh("maestro test #{params[:maestro_flows]}")

        UI.success("Finished Maestro tests on Android.")
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

      def self.authors
        ["Your Name"]
      end

      def self.available_options
        [
            FastlaneCore::ConfigItem.new(
                key: :sdk_dir,
                env_name: "ANDROID_SDK_DIR",
                description: "Path to the Android SDK DIR",
                default_value: ENV['ANDROID_HOME'] || ENV['ANDROID_SDK_ROOT'] || ENV['ANDROID_SDK'],
                optional: false,
                verify_block: proc do |value|
                    UI.user_error!("No ANDROID_SDK_DIR given, pass using `sdk_dir: 'sdk_dir'`") unless value and !value.empty? 
                end
                ),
            FastlaneCore::ConfigItem.new(
                key: :emulator_package,
                env_name: "AVD_PACKAGE",
                description: "The selected system image of the emulator",
                optional: false
                ),
            FastlaneCore::ConfigItem.new(
                key: :android_emulator_name,
                env_name: "AVD_NAME",
                description: "Name of the AVD",
                default_value: "fastlane",
                optional: false
                ),
            FastlaneCore::ConfigItem.new(
                key: :emulator_device,
                env_name: "AVD_DEVICE",
                description: "Device",
                default_value: "Nexus 5",
                optional: false
                ),
            FastlaneCore::ConfigItem.new(
                key: :emulator_port,
                env_name: "AVD_PORT",
                description: "Port of the emulator",
                default_value: "5554",
                optional: false
                ),
            FastlaneCore::ConfigItem.new(
                key: :location,
                env_name: "AVD_LOCATION",
                description: "Set location of the emulator '<longitude> <latitude>'",
                optional: true
                ),
            FastlaneCore::ConfigItem.new(
                key: :emulator_demo_mode,
                env_name: "AVD_DEMO_MODE",
                description: "Set the emulator in demo mode",
                is_string: false,
                default_value: true
                ),
            FastlaneCore::ConfigItem.new(
                key: :emulator_cold_boot,
                env_name: "AVD_COLD_BOOT",
                description: "Create a new AVD every run",
                is_string: false,
                default_value: false
                ),
            FastlaneCore::ConfigItem.new(key: :emulator_additional_options,
                env_name: "AVD_ADDITIONAL_OPTIONS",
                description: "Set additional options of the emulation",
                type: Array,
                is_string: false,
                optional: true
                ),
            FastlaneCore::ConfigItem.new(
                key: :maestro_flows,
                description: "The path to the Maestro flows YAML file",
                optional: false,
                type: String
                ),
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
