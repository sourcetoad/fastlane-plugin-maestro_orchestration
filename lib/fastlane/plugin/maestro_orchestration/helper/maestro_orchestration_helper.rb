require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'aws-sdk-s3'
require 'openssl'
require 'net/http'
require 'uri'
require 'json'

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

      def self.upload_to_s3(folder_path:, bucket:, version:, device:, theme: nil)
        UI.message("Uploading screenshots to S3...\n")
        s3_client = Aws::S3::Client.new(
          region: ENV.fetch('AWS_REGION', 'us-east-1'),
          endpoint: 'http://s3.docker:10000',
          force_path_style: true
        )

        # Define the base folder path in S3
        base_path = "projects/PAD/screenshots/ver:#{version}"
        base_path += "/theme:#{theme}" if theme
        base_path += "/device:#{device}"

        UI.message("Folder path: #{folder_path}")
        Dir.glob("#{folder_path}/*").each do |file|
          UI.message("This is the file: #{file}")
          next if File.directory?(file)

          file_name = File.basename(file)
          s3_key = File.join(base_path, file_name)
          UI.message("\nThis is the key: #{s3_key}\n")

          UI.message("Uploading #{file} to s3://#{bucket}/#{s3_key}\n")
          s3_client.put_object(bucket: bucket, key: s3_key, body: File.open(file))
        end
        UI.success("Upload to S3 completed.")
      end

      def self.send_api_request(url:, hmac_secret:, folder_path:, version:)
        payload = {
          message: "Screenshots uploaded",
          version: version,
          folder_path: folder_path
        }

        # HMAC signature
        signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', hmac_secret, payload.to_json)}"

        # Parse the URL and set up the HTTP request
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        request = Net::HTTP::Post.new(uri.path, {
          "Content-Type" => "application/json",
          "X-Action-Signature" => signature
        })
        request.body = payload.to_json

        # Execute the HTTP request and handle the response
        response = http.request(request)
        if response.code.to_i == 200
          UI.success("API request successful: #{response.body}")
        else
          UI.error("API request failed: #{response.body}")
        end
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

    class EmulatorHelper
      attr_accessor :emulator_path

      def initialize(emulator_path: nil)
        android_home = ENV.fetch('ANDROID_HOME', nil) || ENV.fetch('ANDROID_SDK_ROOT', nil)
        if (emulator_path.nil? || emulator_path == "avdmanager") && android_home
          emulator_path = File.join(android_home, "emulator", "emulator")
        end
        UI.message("This is the emulator path: #{emulator_path}")

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
          "> /dev/null 2>&1 &"
        ].join(" ")

        UI.message("Starting emulator #{name} on port #{port}...")
        trigger(command: command)
      end
    end
  end
end
