describe Fastlane::Actions::MaestroOrchestrationAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The maestro_orchestration plugin is working!")

      Fastlane::Actions::MaestroOrchestrationAction.run(nil)
    end
  end
end
