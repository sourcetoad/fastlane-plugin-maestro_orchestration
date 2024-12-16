describe Fastlane::Actions::MaestroOrchestrationIosAction do
  describe 'Parameter Passing' do
    it 'makes sure that all the parameters are passed' do
      valid_params = {
        simulator_device: "iPhone 14",
        scheme: "MyAppScheme",
        workspace: "MyApp.xcworkspace",
        maestro_flow_file: "flows.yaml"
        }
      %i[simulator_device scheme workspace maestro_flow_file].each do |key|
        expect(valid_params[key]).not_to be_nil
      end
    end

    it 'throws error if maestro_flow_file is not provided' do
      invalid_params = {
        simulator_device: "iPhone 14",
        scheme: "MyAppScheme",
        workspace: "MyApp.xcworkspace"
        }
      expect { Fastlane::Actions::MaestroOrchestrationIosAction.run(invalid_params) }.to raise_error("Missing required parameters: maestro_flow_file")
    end

    it 'throws error if simulator_device is not provided' do
      invalid_params = {
        maestro_flow_file: "flows.yaml",
        scheme: "MyAppScheme",
        workspace: "MyApp.xcworkspace"
        }
      expect { Fastlane::Actions::MaestroOrchestrationIosAction.run(invalid_params) }.to raise_error("Missing required parameters: simulator_device")
    end

    it 'throws error if scheme is not provided' do
      invalid_params = {
        simulator_device: "iPhone 14",
        maestro_flow_file: "flows.yaml",
        workspace: "MyApp.xcworkspace"
        }
      expect { Fastlane::Actions::MaestroOrchestrationIosAction.run(invalid_params) }.to raise_error("Missing required parameters: scheme")
    end

    it 'throws error if workspace is not provided' do
      invalid_params = {
        simulator_device: "iPhone 14",
        scheme: "MyAppScheme",
        maestro_flow_file: "flows.yaml"
        }
      expect { Fastlane::Actions::MaestroOrchestrationIosAction.run(invalid_params) }.to raise_error("Missing required parameters: workspace")
    end
  end
end

describe Fastlane::Actions::MaestroOrchestrationAndroidAction do
  describe 'Parameter Passing' do
    it "makes sure that all the parameters are passed" do
      valid_params = {
        package: "system-images;android-29;google_apis;x86",
        device: "Nexus 5X",
        flow_file: "flows.yaml"
      }

      %i[package device flow_file].each do |key|
        expect(valid_params[key]).not_to be_nil
      end
    end

    it 'throws error if emulator_device is not provided' do
      invalid_params = {
        emulator_name: "Pixel_3_API_29",
        sdk_dir: "/Users/username/Library/Android/sdk",
        emulator_package: "system-images;android-29;google_apis;x86",
        emulator_port: "5554",
        maestro_flow_file: "flows.yaml"
        }
      expect { Fastlane::Actions::MaestroOrchestrationAndroidAction.run(invalid_params) }.to raise_error("Missing required parameters: emulator_device")
    end

    it 'throws error if emulator_package is not provided' do
      invalid_params = {
        emulator_name: "Pixel_3_API_29",
        sdk_dir: "/Users/username/Library/Android/sdk",
        emulator_device: "Nexus 5X",
        emulator_port: "5554",
        maestro_flow_file: "flows.yaml"
        }
      expect { Fastlane::Actions::MaestroOrchestrationAndroidAction.run(invalid_params) }.to raise_error("Missing required parameters: emulator_package")
    end

    it 'throws error if maestro_flow_file is not provided' do
      invalid_params = {
        emulator_name: "Pixel_3_API_29",
        sdk_dir: "/Users/username/Library/Android/sdk",
        emulator_package: "system-images;android-29;google_apis;x86",
        emulator_device: "Nexus 5X",
        emulator_port: "5554"
        }
      expect { Fastlane::Actions::MaestroOrchestrationAndroidAction.run(invalid_params) }.to raise_error("Missing required parameters: maestro_flow_file")
    end
  end
end
