require 'fastlane_core/ui/ui'

module Fastlane

  # Outcome
  PASSED = 'Passed'
  FAILED = 'Failed'
  SKIPPED = 'Skipped'
  INCONCLUSIVE = 'Inconclusive'

  module Helper

    def self.gcs_result_bucket_url(bucket, path)
      "https://console.developers.google.com/storage/browser/#{bucket}/#{CGI.escape(path)}"
    end

    def self.firebase_test_lab_histories_url(project_id)
      "https://console.firebase.google.com/u/0/project/#{project_id}/testlab/histories/"
    end

    def self.firebase_object_url(bucket, path)
      "https://firebasestorage.googleapis.com/v0/b/#{bucket}/o/#{CGI.escape(path)}?alt=media"
    end

    def self.config(project_id)
      UI.message "Set Google Cloud target project"
      Action.sh("gcloud config set project #{project_id}")
    end

    def self.authenticate(gcloud_key_file)
      UI.message "Authenticate with GCP"
      Action.sh("gcloud auth activate-service-account --key-file #{gcloud_key_file}")
    end

    def self.run_tests(arguments)
      UI.message("Test running...")
      Action.sh("gcloud firebase test android run #{arguments}")
    end

    def self.is_failure(outcome)
      outcome == FAILED || outcome == INCONCLUSIVE
    end

    def self.emoji_status(outcome)
      # Github emoji list
      # https://gist.github.com/rxaviers/7360908
      return case outcome
             when PASSED
               ":tada:"
             when FAILED
               ":fire:"
             when INCONCLUSIVE
               ":warning:"
             when SKIPPED
               ":expressionless:"
             else
               ":question:"
             end
    end

    def self.format_device_name(axis_value)
      # Sample Nexus6P-23-ja_JP-portrait
      array = axis_value.split("-")
      "#{array[0]} (API #{array[1]})"
    end

    def self.make_slack_text(json)
      success = true
      json.each do |status|
        success = !Helper.is_failure(status["outcome"])
        break unless success
      end

      body = json.map { |status|
        outcome = status["outcome"]
        emoji = Helper.emoji_status(outcome)
        device = Helper.format_device_name(status["axis_value"])
        "#{device}: #{emoji} #{outcome}\n"
      }.inject(&:+)
      return success, body
    end

    def self.make_github_text(json, project_id, bucket, path)
      prefix = "<p align=\"center\"><img src=https://github.com/cats-oss/fastlane-plugin-firebase_test_lab_android/blob/master/art/firebase_test_lab_logo.png?raw=true width=75%/></p>"
      cells = json.map { |status|
        outcome = status["outcome"]
        emoji = Helper.emoji_status(outcome)
        device = Helper.format_device_name(status["axis_value"])
        "| #{device} | #{emoji} #{outcome} | #{status["test_details"]} |\n"
      }.inject(&:+)
      comment = <<~EOS
        #{prefix}

        ### Results
        Firebase Console: [#{project_id}](#{Helper.firebase_test_lab_histories_url(project_id)}) 
        Test results: [#{path}](#{Helper.gcs_result_bucket_url(bucket, path)})

        | Device | Status | Details |
        | --- | --- | --- |
        #{cells}
      EOS
      return prefix, comment
    end
  end
end