require 'fastlane/action'

module Fastlane
  module Actions
    class MaestroOrchestrationAndroidAction < Action
      def self.run(params)
        boot_android_emulator(params[:android_emulator_name])
        build_and_install_android_app(params)

        UI.message("Running Maestro tests on Android...")
        sh("maestro test #{params[:maestro_flows]}")

        UI.success("Finished Maestro tests on Android.")
      end

      def self.boot_android_emulator(emulator_name)
        UI.message("Booting Android emulator: #{emulator_name}")
        sh("adb start-server")
        sh("emulator -avd #{emulator_name} &")

        loop do
          status = `adb shell getprop sys.boot_completed`.strip
          break if status == '1'

          UI.message("Waiting for Android emulator to finish booting...")
          sleep(2)
        end

        UI.success("Android emulator '#{emulator_name}' is booted.")
      end

      def self.build_and_install_android_app(params)
        UI.message("Building Android app...")
        sh("./gradlew assembleDebug")

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
            key: :android_emulator_name,
            description: "The Android emulator name",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :maestro_flows,
            description: "The path to the Maestro flows YAML file",
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
