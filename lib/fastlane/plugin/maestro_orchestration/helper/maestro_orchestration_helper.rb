require 'fastlane_core/ui/ui'
require 'fastlane/action'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)
  Helper = FastlaneCore::Helper unless Fastlane.const_defined?(:Helper)

  module Helper
    class MaestroOrchestrationHelper
      # class methods that you define here become available in your action
      # as `Helper::MaestroOrchestrationHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the maestro_orchestration plugin helper!")
      end
    end

    class AvdHelper
      # Path to the avd binary
      attr_accessor :avdmanager_path
      # Available AVDs
      attr_accessor :avds

      def initialize(avdmanager_path: nil)
        android_home = ENV.fetch('ANDROID_HOME', nil) || ENV.fetch('ANDROID_SDK_ROOT', nil)
        if (avdmanager_path.nil? || avdmanager_path == "avdmanager") && android_home
          avdmanager_path = File.join(android_home, "cmdline-tools", "latest", "bin", "avdmanager")
        end

        self.avdmanager_path = Helper.get_executable_path(File.expand_path(avdmanager_path))
      end

      def trigger(command: nil)
        raise "avdmanager_path is not set" unless avdmanager_path

        # Build and execute the command
        command = [avdmanager_path.shellescape, command].compact.join(" ").strip
        Action.sh(command)
      end

      # Create a new AVD
      def create_avd(name:, package:, device: "pixel_7_pro")
        raise "AVD name is required" if name.nil? || name.empty?
        raise "System image package is required" if package.nil? || package.empty?

        UI.message("This is the package parameter passed: #{package}")

        command = [
          "create avd",
          "-n #{name.shellescape}",
          "-f",
          "-k \"#{package}\"",
          "-d #{device.shellescape}"
        ].join(" ")

        trigger(command: command)
      end
    end
  end
end
