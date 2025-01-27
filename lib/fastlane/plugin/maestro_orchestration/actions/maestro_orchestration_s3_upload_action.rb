require 'fastlane/action'
require 'aws-sdk-s3'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/maestro_orchestration_helper'

module Fastlane
  module Actions
    class MaestroOrchestrationS3UploadAction < Action
      def self.run(params)
        required_params = [:folder_path, :bucket, :version, :device]
        missing_params = required_params.select { |param| params[param].nil? }

        if missing_params.any?
          missing_params.each do |param|
            UI.error("Missing parameter: #{param}")
          end
          raise "Missing required parameters: #{missing_params.join(', ')}"
        end

        UI.message("Uploading screenshots to S3...")

        s3_client = Aws::S3::Client.new(
          region: ENV.fetch('AWS_REGION', 'us-east-1'),
        )

        # Define the base folder path in S3
        base_path = "projects/PAD/screenshots/ver:#{params[:version]}"
        base_path += "/theme:#{params[:theme]}" if params[:theme]
        base_path += "/device:#{params[:device]}"

        UI.message("Folder path: #{params[:folder_path]}")
        Dir.glob("#{params[:folder_path]}/*").each do |file|
          next if File.directory?(file)

          file_name = File.basename(file)
          s3_key = File.join(base_path, file_name)
          UI.message("\nThis is the key: #{s3_key}\n")

          UI.message("Uploading #{file} to s3://#{params[:bucket]}/#{s3_key}")
          s3_client.put_object(bucket: params[:bucket], key: s3_key, body: File.open(file))
        end

        UI.success("Upload to S3 completed.")
      end

      def self.description
        "Uploads files to an S3 bucket."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :folder_path,
            env_name: "MAESTRO_SCREENSHOTS_FOLDER_PATH",
            description: "Path to the folder to be uploaded to S3",
            optional: false,
            verify_block: proc do |value|
              UI.user_error!("You must provide a valid folder path using the `folder_path` parameter.") unless value && !value.strip.empty?
              UI.user_error!("The folder path does not exist: #{value}") unless File.directory?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :bucket,
            env_name: "MAESTRO_SCREENSHOTS_S3_BUCKET",
            description: "The S3 bucket name where files will be uploaded",
            optional: false,
            verify_block: proc do |value|
              UI.user_error!("You must provide a valid S3 bucket name using the `bucket` parameter.") unless value && !value.strip.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :version,
            env_name: "MAESTRO_SCREENSHOTS_APP_VERSION",
            description: "Version of the app that screenshots are taken from",
            optional: false,
            verify_block: proc do |value|
              UI.user_error!("You must provide a version using the `version` parameter.") unless value && !value.strip.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :device,
            env_name: "MAESTRO_SCREENSHOTS_DEVICE",
            description: "Device type: android or ios",
            type: String,
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :theme,
            env_name: "MAESTRO_SCREENSHOTS_APPLICATION_THEME",
            description: "Optional theme parameter (e.g., dark or light)",
            default_value: nil,
            optional: true
          )
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end

# Set up variable for base path because it cannot be exposed this much