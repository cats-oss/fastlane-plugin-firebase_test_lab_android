require 'fastlane_core/ui/ui'

module Fastlane

  # Outcome
  PASSED = 'Passed'
  FAILED = 'Failed'
  SKIPPED = 'Skipped'
  INCONCLUSIVE = 'Inconclusive'

  module Helper

    def self.gcs_result_bucket_url(bucket, dir)
      "https://console.developers.google.com/storage/browser/#{bucket}/#{CGI.escape(dir)}"
    end

    def self.gcs_object_url(bucket, path)
      "https://storage.googleapis.com/#{bucket}/#{CGI.escape(path)}"
    end

    def self.firebase_test_lab_histories_url(project_id)
      "https://console.firebase.google.com/u/0/project/#{project_id}/testlab/histories/"
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
      Action.sh("set +e; gcloud beta firebase test android run #{arguments}; set -e")
    end

    def self.copy_from_gcs(bucket_and_path, copy_to)
      UI.message("Copy from gs://#{bucket_and_path}")
      Action.sh("gsutil -m cp -r gs://#{bucket_and_path} #{copy_to}")
    end

    def self.set_public(bucket_and_path)
      UI.message("Set public for reading gs://#{bucket_and_path}")
      Action.sh("gsutil -m acl -r set public-read gs://#{bucket_and_path}")
    end

    def self.is_failure(outcome)
      outcome == FAILED || outcome == INCONCLUSIVE
    end

    def self.if_need_dir(path)
      dirname = File.dirname(path)
      unless File.directory?(dirname)
        UI.message("Crate directory: #{dirname}")
        FileUtils.mkdir_p(dirname)
      end
      path
    end

    def self.split_device_name(axis_value)
      # Sample Nexus6P-23-ja_JP-portrait
      array = axis_value.split("-")
      "#{array[0]} (API #{array[1]})"
    end

    def self.emoji_status(outcome)
      # Github emoji list
      # https://github.com/ikatyang/emoji-cheat-sheet
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

    def self.random_emoji_cat
      # Github emoji list
      # https://github.com/ikatyang/emoji-cheat-sheet#cat-face
      %w(:smiley_cat: :smile_cat: :joy_cat: :heart_eyes_cat: :smirk_cat: :kissing_cat:).sample
    end

    def self.make_slack_text(json)
      success = true
      json.each do |status|
        success = !is_failure(status["outcome"])
        break unless success
      end

      body = json.map { |status|
        outcome = status["outcome"]
        emoji = emoji_status(outcome)
        device = split_device_name(status["axis_value"])
        "#{device}: #{emoji} #{outcome}\n"
      }.inject(&:+)
      return success, body
    end

    def self.make_github_text(json, project_id, bucket, dir, test_type)
      print "============>>>>>>>>> " + json.to_s

      prefix = "<img src=\"https://github.com/cats-oss/fastlane-plugin-firebase_test_lab_android/blob/master/art/firebase_test_lab_logo.png?raw=true\" width=\"65%\" loading=\"lazy\" />"
      cells = json.map { |data|
        axis = data["axis_value"]
        device = split_device_name(axis)
        outcome = data["outcome"]
        status = "#{emoji_status(outcome)} #{outcome}"
        message = data["test_details"]
        logcat = "<a href=\"#{gcs_object_url(bucket, "#{dir}/#{axis}/logcat")}\" target=\"_blank\" >#{random_emoji_cat}</a>"
        if test_type == "robo"
          sitemp = "<img src=\"#{gcs_object_url(bucket, "#{dir}/#{axis}/artifacts/sitemap.png")}\" height=\"64px\" loading=\"lazy\" target=\"_blank\" />"
        else
          sitemp = "--"
        end

        "| **#{device}** | #{status} | #{message} | #{logcat} | #{sitemp} |\n"
      }.inject(&:+)
      comment = <<~EOS
        #{prefix}

        ### Results
        Firebase console: [#{project_id}](#{Helper.firebase_test_lab_histories_url(project_id)}) 
        Test results: [#{dir}](#{Helper.gcs_result_bucket_url(bucket, dir)})

        | :iphone: Device | :thermometer: Status | :memo: Message | :eyes: Logcat | :japan: Sitemap | 
        | --- | :---: | --- | :---: | :---: |
        #{cells}
      EOS
      return prefix, comment
    end

    def self.is_success(json)
      success = true

      json.each do |status|
        success = !is_failure(status["outcome"])
        break unless success
      end

      return success
    end
  end
end