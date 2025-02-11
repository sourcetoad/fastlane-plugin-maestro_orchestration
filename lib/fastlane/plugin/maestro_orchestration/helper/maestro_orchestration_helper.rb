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
  end
end
