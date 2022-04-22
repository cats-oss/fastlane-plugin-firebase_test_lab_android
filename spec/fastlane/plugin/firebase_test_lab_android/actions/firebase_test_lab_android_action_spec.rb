require 'spec_helper'

describe Fastlane::Actions::FirebaseTestLabAndroidAction do
  describe '.run' do
    subject { described_class.run(params) }

    before do
      allow(Fastlane::Helper).to receive(:config)
      allow(Fastlane::Helper).to receive(:authenticate)
      allow(Fastlane::Helper).to receive(:run_tests)
      allow(Fastlane::Helper).to receive(:if_need_dir)
      allow(Fastlane::Helper).to receive(:copy_from_gcs)
      allow(Fastlane::Helper).to receive(:set_public)
      allow(Fastlane::Helper).to receive(:make_slack_text)
      allow(Fastlane::Helper).to receive(:make_github_text)
      allow(File).to receive(:read).with(params[:console_log_file_name]).and_return json
    end

    let(:params) do
      {
        project_id: 'test',
        gcloud_service_key_file: 'test.json',
        type: 'robo',
        devices: [{
          model: 'Nexus6',
          version: '21',
          locale: 'en_US',
          orientation: 'portrait'
        }],
        app_apk: 'test.apk',
        timeout: '3m',
        use_orchestrator: false,
        gcloud_components_channel: 'stable',
        console_log_file_name: './console_output.log',
        extra_options: '',
        download_dir: "download",
        publish_result: publish_result,
      }
    end

    let(:json) do
      <<~EOF
      [
        {
          "axis_value": "Nexus6P-23-ja_JP-portrait",
          "outcome": "Passed",
          "test_details": "--"
        },
        {
          "axis_value": "Pixel2-28-en_US-portrait",
          "outcome": "Passed",
          "test_details": "--"
        }
      ]
      EOF
    end

    context 'with publish_result is true' do
      let(:publish_result) { true }

      it 'sets the specified GCS object to public-read ACL' do
        expect(Fastlane::Helper).to receive(:set_public)
        subject
      end
    end

    context 'with publish_result is false' do
      let(:publish_result) { false }

      it 'does not manipulate ACL of the specified GCS object' do
        expect(Fastlane::Helper).not_to receive(:set_public)
        subject
      end
    end
  end
end
