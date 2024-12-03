require 'fastlane/action'

module Fastlane
  module Actions
    class MaestroOrchestrationIosAction < Action
      def self.run(params)
        device_name = params[:simulator_device]
        boot_ios_simulator(device_name)
        build_and_install_ios_app(params)

        UI.message("Running Maestro tests on iOS...")
        `maestro test #{params[:maestro_flows]}`
        UI.success("Finished Maestro tests on iOS.")
      end

      def self.boot_ios_simulator(device_name)
        simulators_list = `xcrun simctl list devices`.strip

        unless simulators_list.include?(device_name)
          UI.error("Simulator '#{device_name}' not found.")
          return
        end

        device_status = simulators_list.match(/#{Regexp.quote(device_name)}.*\((.*?)\)/)
        if device_status && device_status[1].casecmp('Booted').zero?
          UI.success("#{device_name} is already booted.")
        else
          UI.message("#{device_name} is not booted. Booting now...")
          system("xcrun simctl boot '#{device_name}'")
          UI.message("Waiting for the simulator to boot...")
          sleep(5)
          UI.success("Simulator '#{device_name}' is booted.")
        end
      end

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

      def self.authors
        ["Your Name"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :simulator_device,
            description: "The iOS simulator device to boot",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            description: "The iOS app scheme to build",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :workspace,
            description: "The Xcode workspace",
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
        platform == :ios
      end
    end
  end
end
