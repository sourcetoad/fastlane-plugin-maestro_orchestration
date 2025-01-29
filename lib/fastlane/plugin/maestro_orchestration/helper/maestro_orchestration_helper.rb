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

      def self.wait_for_emulator_to_boot(adb, max_retries, serial)
        retries = 0
        booted = false

        while retries < max_retries
          result = `#{adb.adb_path} -e shell getprop sys.boot_completed`.strip
          UI.message("ADB Response (sys.boot_completed): #{result.inspect}")

          if result == "1"
            booted = true
            break
          elsif result.empty? || result.include?("device offline") || result.include?("device unauthorized")
            UI.error("ADB issue detected: #{result}")
          end

          retries += 1
          UI.message("Retrying... Attempt #{retries}/#{max_retries}")

          wait_interval = [1 + (2**retries), 30].min

          UI.message("Waiting for #{wait_interval} seconds before retrying...")
          sleep(wait_interval)
        end

        booted
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
          # First search for cmdline-tools dir
          cmdline_tools_path = File.join(android_home, "cmdline-tools")

          # Find the first available 'bin' folder within cmdline-tools
          available_path = Dir.glob(File.join(cmdline_tools_path, "*", "bin")).first
          raise "No valid bin path found in #{cmdline_tools_path}" unless available_path

          avdmanager_path = File.join(available_path, "avdmanager")
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

    class EmulatorHelper
      attr_accessor :emulator_path

      def initialize(emulator_path: nil)
        android_home = ENV.fetch('ANDROID_HOME', nil) || ENV.fetch('ANDROID_SDK_ROOT', nil)
        if (emulator_path.nil? || emulator_path == "avdmanager") && android_home
          emulator_path = File.join(android_home, "emulator", "emulator")
        end

        self.emulator_path = Helper.get_executable_path(File.expand_path(emulator_path))
      end

      def trigger(command: nil)
        raise "emulator_path is not set" unless emulator_path

        # Build and execute the command
        command = [emulator_path.shellescape, command].compact.join(" ").strip
        Action.sh(command)
      end

      # Start an emulator instance
      def start_emulator(name:, port:)
        raise "Emulator name is required" if name.nil? || name.empty?
        raise "Port is required" if port.nil? || port.to_s.empty?

        command = [
          "-avd #{name.shellescape}",
          "-port #{port.shellescape}",
          "-wipe-data",
          "-no-boot-anim",
          "-no-snapshot",
          "-no-audio",
          "> /dev/null 2>&1 &"
        ].join(" ")

        UI.message("Starting emulator #{name} on port #{port}...")
        trigger(command: command)
      end
    end
  end
end
