require 'fastlane/action'
require_relative '../helper/maestro_orchestration_helper'

module Fastlane
  module Actions
    class MaestroOrchestrationAction < Action
      def self.run(params)
        platform = params[:platform]
        device_name = params[:simulator_device]

        if platform == 'ios'
          boot_ios_simulator(device_name)
          build_and_install_ios_app(params)
        elsif platform == 'android'
          boot_android_emulator(params[:android_emulator_name])
          build_and_install_android_app(params)
        else
          UI.user_error!("Unsupported platform: #{platform}. Please specify 'ios' or 'android'.")
        end

        UI.message("Running Maestro tests...")
        sh("maestro test #{params[:maestro_flows]}")

        UI.success("Finished Maestro tests.")
      end

      # Boot iOS simulator
      def self.boot_ios_simulator(device_name)
        # Fetch the list of all simulators and their statuses
        simulators_list = `xcrun simctl list devices`.strip
        
        # Check if the specified device exists in the list
        unless simulators_list.include?(device_name)
          UI.error("Simulator '#{device_name}' not found.")
          return
        end
      
        # Check if the device is already booted
        device_status = simulators_list.match(/#{Regexp.quote(device_name)}.*\((.*?)\)/)
        
        if device_status && device_status[1].casecmp('Booted').zero?
          UI.success("#{device_name} is already booted.")
        else
          UI.message("#{device_name} is not booted. Booting now...")
          system("xcrun simctl boot '#{device_name}'") # Use system to execute shell command
          UI.message("Waiting for the simulator to boot...")
          sleep(5)
          UI.success("Simulator '#{device_name}' is booted.")
        end
      end
      

      # Build and install iOS app
      def self.build_and_install_ios_app(params)
        UI.message("Building iOS app with scheme: #{params[:scheme]}")
        other_action.gym(
          workspace: params[:workspace],
          scheme: params[:scheme],
          destination: "platform=iOS Simulator,name=#{params[:simulator_device]}",
          configuration: "Debug",
          clean: true,
          sdk: "iphonesimulator",
          build_path: "./build",
          skip_archive: true,
          skip_package_ipa: true,
          include_symbols: false,
          include_bitcode: false,
          xcargs: "-UseModernBuildSystem=YES"
        )

        derived_data_path = File.expand_path("~/Library/Developer/Xcode/DerivedData")
        app_path = Dir["#{derived_data_path}/**/#{params[:scheme]}.app"].first
        
        UI.message("App path: #{app_path}")

        if app_path.nil?
          UI.user_error!("Error: .app file not found in DerivedData.")
        end

        ENV["APP_PATH"] = app_path
        UI.message("Found .app file at: #{app_path}")

        UI.message("Installing app on iOS simulator...")
        sh("xcrun simctl install booted '#{app_path}'")
        UI.success("App installed on iOS simulator.")
      end

      # Boot Android emulator
      def self.boot_android_emulator(emulator_name)
        UI.message("Booting Android emulator: #{emulator_name}")
        sh("adb start-server")
        sh("emulator -avd #{emulator_name} &")

        # Wait for the emulator to fully boot
        loop do
          status = sh("adb shell getprop sys.boot_completed").strip
          break if status == '1'

          UI.message("Waiting for Android emulator to finish booting...")
          sleep(2) # Minimal polling delay
        end

        UI.success("Android emulator '#{emulator_name}' is booted.")
      end

      # Build and install Android app
      def self.build_and_install_android_app(params)
        UI.message("Building Android app...")
        sh("./gradlew assembleDebug") # Adjust as needed

        apk_path = Dir["app/build/outputs/apk/debug/app-debug.apk"].first

        if apk_path.nil?
          UI.user_error!("Error: APK file not found in build outputs.")
        end

        ENV["APK_PATH"] = apk_path
        UI.message("Found APK file at: #{apk_path}")

        UI.message("Installing APK on Android emulator...")
        sh("adb install -r '#{apk_path}'")
        UI.success("APK installed on Android emulator.")
      end

      def self.description
        "Boots a simulator or emulator, builds the app, installs it, and runs Maestro tests"
      end

      def self.authors
        ["Your Name"]
      end

      def self.return_value
        nil
      end

      def self.details
        "This plugin automates simulator/emulator orchestration, app building, installation, and Maestro test execution for both iOS and Android."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :platform,
            description: "The platform to run (ios or android)",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :simulator_device,
            description: "The iOS simulator device to boot",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            description: "The iOS app scheme to build",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :workspace,
            description: "The Xcode workspace",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :android_emulator_name,
            description: "The Android emulator name",
            optional: true,
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
        [:ios, :android].include?(platform)
      end
    end
  end
end
