require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/maestro_orchestration_helper'

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

        UI.message("FOLDER PATH parameter is: #{params[:folder_path]}\n\n")
        Helper::MaestroOrchestrationHelper.upload_to_s3(folder_path: params[:folder_path], bucket: params[:bucket], version: params[:version], device: "ios", theme: params[:theme])
      end

      def self.boot_ios_simulator(params)
        device_name = params[:simulator_name]
        device_type = params[:device_type]

        UI.message("Killing already booted iOS simulator...")
        system("xcrun simctl shutdown booted")

        UI.message("Device name: #{device_name}")
        simulators_list = `xcrun simctl list devices`.strip

        unless simulators_list.include?(device_name)
          UI.error("Simulator '#{device_name}' not found.")
          UI.message("Creating new simulator...")
          system("xcrun simctl create '#{device_name}' #{device_type}")
          # Refresh the list of simulators
          simulators_list = `xcrun simctl list devices`.strip
        end

        device_status = simulators_list.match(/#{Regexp.quote(device_name)}.*\(([^)]+)\) \(([^)]+)\)/)
        UI.message("Device status: #{device_status}")
        device_id = device_status[1]
        device_state = device_status[2]
        if device_status && device_state.casecmp('Booted').zero?
          UI.success("#{device_name} is already booted.")
        else
          UI.message("#{device_name} is not booted. Booting now...")
          system("xcrun simctl boot '#{device_id}'")
          UI.message("Waiting for the simulator to boot...")
          until `xcrun simctl list devices`.include?("#{device_name} (#{device_id}) (Booted)")
            UI.message("Waiting for the simulator to boot...")
            sleep(5)
          end
          UI.success("Simulator '#{device_name}' is booted.")
        end
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
            env_name: "MAESTRO_IOS_DEVICE",
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
            key: :bucket,
            env_name: "S3_BUCKET",
            description: "The S3 bucket name where files will be uploaded",
            default_value: "pad",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :folder_path,
            env_name: "MAESTRO_SCREENSHOTS_FOLDER_PATH",
            description: "Path to the folder to be uploaded to S3",
            default_value: File.expand_path("../../.maestro/ios/screenshots", FastlaneCore::Helper.fastlane_enabled_folder_path),
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :version,
            env_name: "APP_VERSION",
            description: "Version of the app that screenshots are taken from",
            optional: false,
            verify_block: proc do |value|
              UI.user_error!("You must provide a version using the `version` parameter.") unless value && !value.strip.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :theme,
            env_name: "APPLICATION_THEME",
            description: "Optional theme parameter (e.g., dark or light)",
            default_value: nil,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :hmac_secret,
            env_name: "HMAC_SECRET",
            description: "The HMAC secret used to sign the payload",
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :url,
            env_name: "WEBHOOK_URL",
            description: "The URL to send the API request to",
            optional: false
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
