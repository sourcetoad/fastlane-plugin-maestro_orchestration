# describe Fastlane::Actions::MaestroOrchestrationIosAction do
#   describe '#run' do
#     let(:params) do
#       {
#         simulator_device: "iPhone 15",
#         scheme: "bluetooth_test",
#         workspace: "bluetooth_test.xcworkspace",
#         maestro_flows: "../.maestro/flow_ios.yaml"
#       }
#     end

#     before do
#       allow(Fastlane::UI).to receive(:message)
#       allow(Fastlane::UI).to receive(:success)
#       allow(Fastlane::UI).to receive(:error)
#       allow(Fastlane::UI).to receive(:user_error!)
#       allow(Fastlane::UI).to receive(:warning)
#       allow_any_instance_of(Fastlane::Actions::MaestroOrchestrationIosAction).to receive(:system)
#       allow_any_instance_of(Fastlane::Actions::MaestroOrchestrationIosAction).to receive(:sh)
#       allow_any_instance_of(Fastlane::Actions::MaestroOrchestrationIosAction).to receive(:sleep)
#     end

#     it 'boots the simulator if not already booted' do
#       # Mocking system call for booting the simulator
#       allow(Fastlane::Actions::MaestroOrchestrationIosAction).to receive(:system).with("xcrun simctl boot 'iPhone 15'")

#       expect(Fastlane::UI).to receive(:message).with("iPhone 15 is not booted. Booting now...")
#       expect(Fastlane::UI).to receive(:message).with("Waiting for the simulator to boot...")
#       expect(Fastlane::UI).to receive(:success).with("Simulator 'iPhone 15' is booted.")

#       Fastlane::Actions::MaestroOrchestrationIosAction.run(params)
#     end

#     it 'builds and installs the iOS app' do
#       expect(Fastlane::UI).to receive(:message).with("Building iOS app with scheme: bluetooth_test")
#       expect(Fastlane::UI).to receive(:message).with("Found .app file at: /path/to/app")
#       expect(Fastlane::UI).to receive(:success).with("App installed on iOS simulator.")

#       Fastlane::Actions::MaestroOrchestrationIosAction.run(params)
#     end
#   end
# end
