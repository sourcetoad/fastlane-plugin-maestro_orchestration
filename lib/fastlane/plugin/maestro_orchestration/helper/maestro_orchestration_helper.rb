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
      def self.stop_all_emulators(adb)
        UI.message("Stop all running emulators...")
        devices = adb.load_all_devices
        UI.success("Devices: #{devices}")

        devices.each do |device|
          UI.message("Stopping emulator: #{device.serial}")
          adb.trigger(command: "emu kill", serial: device.serial)
          sleep(10)
        end
        UI.message("Waiting for all emulators to stop...")
        sleep(10)
      end

      def self.handle_boot_failure(params, avdmanager, adb, emulator)
        adb.trigger(command: "kill-server")
        adb.trigger(command: "emu kill", serial: "emulator-#{params[:emulator_port]}")
        sleep(5)
        avdmanager.delete_avd(name: params[:emulator_name])

        UI.message("Creating new AVD...")
        avdmanager.create_avd(name: params[:emulator_name], package: params[:emulator_package], device: params[:emulator_device])

        UI.message("Restarting ADB server...")
        adb.trigger(command: "start-server")
        UI.message("ADB server restarted. Starting new emulator...")

        emulator.start_emulator(name: params[:emulator_name], port: params[:emulator_port])
        adb.trigger(command: "wait-for-device", serial: "emulator-#{params[:emulator_port]}")
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

      def self.clear_maestro_logs
        logs_path = File.expand_path("~/.maestro/tests")

        unless Dir.exist?(logs_path)
          UI.message("No Maestro logs directory found.")
          return
        end

        UI.message("Clearing previous Maestro logs using")

        # Handle file and directory removal separately
        Dir.glob(File.join(logs_path, "*")).each do |path|
          if File.directory?(path)
            clear_directory(path)
          else
            delete_file(path)
          end
        end

        UI.success("Previous Maestro logs cleared.")
      end

      def self.clear_directory(directory_path)
        Dir.glob(File.join(directory_path, "**", "*")).reverse_each do |subpath|
          if File.directory?(subpath)
            Dir.rmdir(subpath)
          else
            File.delete(subpath)
          end
        rescue StandardError => e
          UI.error("Error removing #{subpath}: #{e.message}")
        end

        Dir.rmdir(directory_path)
      rescue StandardError => e
        UI.error("Error removing directory #{directory_path}: #{e.message}")
      end

      def self.delete_file(file_path)
        File.delete(file_path)
      rescue StandardError => e
        UI.error("Error removing file #{file_path}: #{e.message}")
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

      # Delete an existing AVD
      def delete_avd(name:)
        raise "AVD name is required" if name.nil? || name.empty?

        command = [
          "delete avd",
          "-n #{name.shellescape}"
        ].join(" ")

        trigger(command: command)
      end

      # Handle existing AVD, deleting to ensure fresh setup
      def handle_existing_avd(emulator_name)
        UI.message("Checking if AVD exists with name: #{emulator_name}...")
        avd_exists = `#{avdmanager_path} list avd`.include?(emulator_name)

        if avd_exists
          UI.message("AVD found, deleting existing AVD: #{emulator_name}...")
          delete_avd(name: emulator_name)
        else
          UI.message("No existing AVD found with that name.")
        end
      end

      # Creates an AVD and starts an emulator
      def create_and_start_emulator(params, emulator, adb)
        UI.message("Setting up new Android emulator...")
        create_avd(name: params[:emulator_name], package: params[:emulator_package], device: params[:emulator_device])

        UI.message("Debug statement to check created AVDs")
        UI.message(`#{avdmanager_path} list avd`)

        UI.message("Starting Android emulator...")
        emulator.start_emulator(name: params[:emulator_name], port: params[:emulator_port])
        adb.trigger(command: "wait-for-device", serial: "emulator-#{params[:emulator_port]}")
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
          "> emulator_logs 2>&1 &"
          # "> /dev/null 2>&1 &"
        ].join(" ")

        UI.message("Starting emulator #{name} on port #{port}...")
        trigger(command: command)
      end
    end
  end
end
