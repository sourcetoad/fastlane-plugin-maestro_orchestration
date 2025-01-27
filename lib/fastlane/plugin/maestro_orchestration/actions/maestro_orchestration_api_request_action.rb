require 'fastlane/action'
require 'openssl'
require 'net/http'
require 'uri'
require 'json'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/maestro_orchestration_helper'

module Fastlane
  module Actions
    class ApiRequestAction < Action
      def self.run(params)
        required_params = [:version, :device, :hmac_secret, :url]
        missing_params = required_params.select { |param| params[param].nil? }

        if missing_params.any?
          missing_params.each do |param|
            UI.error("Missing parameter: #{param}")
          end
          raise "Missing required parameters: #{missing_params.join(', ')}"
        end

        base_path = "#{params[:s3_path]}/ver:#{params[:version]}"
        base_path += "/theme:#{params[:theme]}" if params[:theme]
        base_path += "/device:#{params[:device]}"

        payload = {
          message: "Screenshots uploaded",
          version: params[:version],
          folder_path: base_path
        }

        signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', params[:hmac_secret], payload.to_json)}"

        uri = URI.parse(params[:url])
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        request = Net::HTTP::Post.new(uri.path, {
          "Content-Type" => "application/json",
          "X-Action-Signature" => signature
        })
        request.body = payload.to_json

        response = http.request(request)

        if response.code.to_i == 200
          UI.success("API request successful: #{response.body}")
        else
          UI.user_error("API request failed: #{response.body}")
        end
      end

      def self.description
        "Sends an API request with a signed payload."
      end

      def self.available_options
        [
          folder_path_option,
          bucket_option,
          version_option,
          device_option,
          theme_option,
          hmac_secret_option,
          url_option
        ]
      end

      def self.s3_path_option
        FastlaneCore::ConfigItem.new(
          key: :s3_path,
          env_name: "MAESTRO_SCREENSHOTS_S3_PATH",
          description: "The base S3 path (after the bucket name) where files will be uploaded: $bucket/$s3_path",
          default_value: ENV.fetch("MAESTRO_ORCHESTRATION_S3_PATH"),
          optional: false
        )
      end

      def self.version_option
        FastlaneCore::ConfigItem.new(
          key: :version,
          env_name: "MAESTRO_SCREENSHOTS_APP_VERSION",
          description: "Version of the app that screenshots are taken from",
          optional: false,
          verify_block: proc do |value|
            UI.user_error!("You must provide a version using the `version` parameter.") unless value && !value.strip.empty?
          end
        )
      end

      def self.device_option
        FastlaneCore::ConfigItem.new(
          key: :device,
          env_name: "MAESTRO_SCREENSHOTS_DEVICE",
          description: "Device type: android or ios",
          type: String,
          optional: false,
          verify_block: proc do |value|
            UI.user_error!("You must specify a device type (android or ios).") unless %w[android ios].include?(value.downcase)
          end
        )
      end

      def self.theme_option
        FastlaneCore::ConfigItem.new(
          key: :theme,
          env_name: "MAESTRO_SCREENSHOTS_APPLICATION_THEME",
          description: "Optional theme parameter (e.g., dark or light)",
          default_value: nil,
          optional: true
        )
      end

      def self.hmac_secret_option
        FastlaneCore::ConfigItem.new(
          key: :hmac_secret,
          env_name: "MAESTRO_SCREENSHOTS_HMAC_SECRET",
          description: "The HMAC secret used to sign the payload",
          optional: false,
          verify_block: proc do |value|
            UI.user_error!("You must provide a valid HMAC secret using the `hmac_secret` parameter.") unless value && !value.strip.empty?
          end
        )
      end

      def self.url_option
        FastlaneCore::ConfigItem.new(
          key: :url,
          env_name: "MAESTRO_SCREENSHOTS_WEBHOOK_URL",
          description: "The URL to send the API request to",
          optional: false,
          verify_block: proc do |value|
            UI.user_error!("You must provide a valid URL using the `url` parameter.") unless value && !value.strip.empty?
            UI.user_error!("The provided URL is invalid: #{value}") unless value.match?(URI::DEFAULT_PARSER.make_regexp)
          end
        )
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
