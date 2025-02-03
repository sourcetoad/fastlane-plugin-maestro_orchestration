require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/maestro_orchestration_helper'
require 'fileutils'

module Fastlane
  module Actions
    class MaestroOrchestrationIosAction < Action
      def self.run(params)
        required_params = [:scheme, :workspace, :maestro_flow_file]
        missing_params = required_params.select { |param| params[param].nil? }

        if missing_params.any?
          missing_params.each do |param|
            UI.error("Missing parameter: #{param}")
          end
          raise "Missing required parameters: #{missing_params.join(', ')}"
        end

        if params[:clear_maestro_logs]
          UI.message("Clearing previous Maestro logs using Ruby...")
          logs_path = File.expand_path("~/.maestro/tests/*")
        
          Dir.glob(logs_path).each do |file|
            FileUtils.rm_rf(file)
          end
        
          UI.success("Previous Maestro logs cleared.")
        end

        boot_ios_simulator(params)
        demo_mode(params)
        build_and_install_ios_app(params)

        UI.message("Running Maestro tests on iOS...")

        simulators_list = `xcrun simctl list devices`.strip
        device_status = simulators_list.match(/#{Regexp.quote(params[:simulator_name])}.*\(([^)]+)\) \(([^)]+)\)/)
        device_id = device_status[1]
        `maestro --device #{device_id} test #{params[:maestro_flow_file]}`
        UI.success("Finished Maestro tests on iOS.")

        UI.message("Killing iOS simulator...")
        system("xcrun simctl shutdown booted")
        UI.success("iOS simulator killed. Process finished.")
      end

      def self.boot_ios_simulator(params)
        device_name = params[:simulator_name]
        device_type = params[:device_type]

        UI.message("Shutting down any booted iOS simulator...")
        system("xcrun simctl shutdown booted")

        UI.message("Checking if simulator '#{device_name}' exists...")
        simulators_list = `xcrun simctl list devices -j`
        simulator_data = JSON.parse(simulators_list)["devices"].values.flatten

        existing_simulator = simulator_data.find { |sim| sim["name"] == device_name }

        if existing_simulator
          device_id = existing_simulator["udid"]
          UI.message("Found existing simulator '#{device_name}' with ID #{device_id}. Deleting it...")
          system("xcrun simctl delete #{device_id}")
        end

        UI.message("Creating a new simulator '#{device_name}'...")
        system("xcrun simctl create '#{device_name}' #{device_type}")

        # Refresh simulator list after creation
        simulators_list = `xcrun simctl list devices -j`
        new_simulator = JSON.parse(simulators_list)["devices"].values.flatten.find { |sim| sim["name"] == device_name }

        unless new_simulator
          UI.user_error!("Failed to create simulator '#{device_name}'.")
        end

        new_device_id = new_simulator["udid"]
        UI.message("Booting the new simulator '#{device_name}' (ID: #{new_device_id})...")
        system("xcrun simctl boot '#{new_device_id}'")

        UI.message("Waiting for the simulator to fully boot...")
        until `xcrun simctl list devices`.include?("#{device_name} (#{new_device_id}) (Booted)")
          UI.message("Waiting for the simulator to boot...")
          sleep(10)
        end

        UI.success("Simulator '#{device_name}' is booted and ready.")
      end

      def self.demo_mode(params)
        UI.message("Setting demo mode on #{params[:simulator_name]}...")
        sh("xcrun simctl status_bar '#{params[:simulator_name]}' override --time '09:30'")
        sh("xcrun simctl status_bar '#{params[:simulator_name]}' override --batteryState charged --batteryLevel 100")
        sh("xcrun simctl status_bar '#{params[:simulator_name]}' override --wifiBars 3 --cellularBars 4")
      end

      def self.build_and_install_ios_app(params)
        UI.message("Building iOS app with scheme: #{params[:scheme]}")
        other_action.gym(
          workspace: params[:workspace],
          scheme: params[:scheme],
          destination: "platform=iOS Simulator,name=#{params[:simulator_name]}",
          configuration: "Release",
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
        app_path = Dir["#{derived_data_path}/**/Release-iphonesimulator/#{params[:scheme]}.app"].first

        if app_path.nil?
          UI.user_error!("Error: .app file not found in DerivedData.")
        end

        UI.message("Found .app file at: #{app_path}")
        sh("xcrun simctl install booted '#{app_path}'")
        UI.success("App installed on iOS simulator.")
      end

      def self.description
        "Boots an iOS simulator, builds the app, installs it, and runs Maestro tests"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :simulator_name,
            env_name: "MAESTRO_IOS_DEVICE_NAME",
            description: "The iOS simulator device to boot",
            default_value: "iPhone 15",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :device_type,
            env_name: "MAESTRO_IOS_DEVICE",
            description: "The iOS simulator device type for new simulator",
            default_value: "com.apple.CoreSimulator.SimDeviceType.iPhone-15",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            env_name: "MAESTRO_IOS_SCHEME",
            description: "The iOS app scheme to build",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :workspace,
            env_name: "MAESTRO_IOS_WORKSPACE",
            description: "The Xcode workspace",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :maestro_flow_file,
            env_name: "MAESTRO_IOS_FLOW_FILE",
            description: "The path to the Maestro flows YAML file",
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
        platform == :ios
      end
    end
  end
end
