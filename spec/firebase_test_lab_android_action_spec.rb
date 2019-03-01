describe Fastlane::Actions::FirebaseTestLabAndroidAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The firebase_test_lab_android plugin is working!")

      Fastlane::Actions::FirebaseTestLabAndroidAction.run(nil)
    end
  end
end
