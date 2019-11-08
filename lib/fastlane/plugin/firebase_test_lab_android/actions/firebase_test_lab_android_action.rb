require 'fastlane/action'
require 'json'
require 'fileutils'

module Fastlane
  module Actions
    class FirebaseTestLabAndroidAction < Action

      def self.run(params)
        UI.message("Starting...")

        results_bucket = params[:firebase_test_lab_results_bucket] == nil ? "#{params[:project_id]}_test_results" : params[:firebase_test_lab_results_bucket]
        results_dir = "firebase_test_result_#{DateTime.now.strftime('%Y-%m-%d-%H:%M:%S')}"

        # Create the log file
        dirname = File.dirname(params[:console_log_file_name])
        unless File.directory?(dirname)
          FileUtils.mkdir_p(dirname)
        end

        # Set target project
        Helper.config(params[:project_id])
        # Activate service account
        Helper.authenticate(params[:gcloud_service_key_file])
        # Run Firebase Test Lab
        Helper.run_tests("--type #{params[:type]} "\
                  "--app #{params[:app_apk]} "\
                  "#{"--test #{params[:app_test_apk]} " unless params[:app_test_apk].nil?}"\
                  "#{"--use-orchestrator " if params[:type] == "instrumentation" && params[:use_orchestrator]}"\
                  "#{params[:devices].map { |d| "--device model=#{d[:model]},version=#{d[:version]},locale=#{d[:locale]},orientation=#{d[:orientation]} " }.join}"\
                  "--timeout #{params[:timeout]} "\
                  "--results-bucket #{results_bucket} "\
                  "--results-dir #{results_dir} "\
                  "#{params[:extra_options]} "\
                  "--format=json 1>#{params[:console_log_file_name]}"
        )

        # Sample data
        # [
        #   {
        #     "axis_value": "Nexus6P-23-ja_JP-portrait",
        #     "outcome": "Passed",
        #     "test_details": "--"
        #   },
        #   {
        #     "axis_value": "Pixel2-28-en_US-portrait",
        #     "outcome": "Passed",
        #     "test_details": "--"
        #   }
        # ]
        json = JSON.parse(File.read(params[:console_log_file_name]))

        # Notify to Slack
        if params[:slack_url] != nil
          success, body = Helper.make_slack_text(json)
          SlackNotifier.notify(params[:slack_url], body, success)
        end

        # Notify to Github
        owner = params[:github_owner]
        repository = params[:github_repository]
        pr_number = params[:github_pr_number]
        api_token = params[:github_api_token]
        unless owner.nil? || repository.nil? || pr_number.nil? || api_token.nil?
          prefix, comment = Helper.make_github_text(json, params[:project_id], results_bucket, results_dir)
          # Delete past comments
          GitHubNotifier.delete_comments(owner, repository, pr_number, prefix, api_token)
          GitHubNotifier.put_comment(owner, repository, pr_number, comment, api_token)
        end

        UI.message("Finishing...")
      end

      def self.description
        "Runs Android tests in Firebase Test Lab."
      end

      def self.authors
        ["Wasabeef"]
      end

      def self.return_value
        ["Authenticates with Google Cloud.",
         "Runs tests in Firebase Test Lab.",
         "Fetches the results to a local directory."].join("\n")
      end

      def self.details
        # Optional:
        "Test your app with Firebase Test Lab with ease using fastlane"
      end

      def self.available_options
        [FastlaneCore::ConfigItem.new(key: :project_id,
                                      env_name: "PROJECT_ID",
                                      description: "Your Firebase project id",
                                      is_string: true,
                                      optional: false),
         FastlaneCore::ConfigItem.new(key: :gcloud_service_key_file,
                                      env_name: "GCLOUD_SERVICE_KEY_FILE",
                                      description: "File path containing the gcloud auth key. Default: Created from GCLOUD_SERVICE_KEY environment variable",
                                      is_string: true,
                                      optional: false),
         FastlaneCore::ConfigItem.new(key: :type,
                                      env_name: "TYPE",
                                      description: "Test type. Default: robo (robo/instrumentation)",
                                      is_string: true,
                                      optional: true,
                                      default_value: "robo"),
         FastlaneCore::ConfigItem.new(key: :devices,
                                      description: "Devices to test the app on",
                                      type: Array,
                                      default_value: [{
                                                          model: "Nexus6",
                                                          version: "21",
                                                          locale: "en_US",
                                                          orientation: "portrait"
                                                      }],
                                      verify_block: proc do |value|
                                        if value.empty?
                                          UI.user_error!("Devices cannot be empty")
                                        end
                                        value.each do |current|
                                          if current.class != Hash
                                            UI.user_error!("Each device must be represented by a Hash object, " \
                                               "#{current.class} found")
                                          end
                                          check_has_property(current, :model)
                                          check_has_property(current, :version)
                                          set_default_property(current, :locale, "en_US")
                                          set_default_property(current, :orientation, "portrait")
                                        end
                                      end),
         FastlaneCore::ConfigItem.new(key: :timeout,
                                      env_name: "TIMEOUT",
                                      description: "The max time this test execution can run before it is cancelled. Default: 5m (this value must be greater than or equal to 1m)",
                                      type: String,
                                      optional: true,
                                      default_value: "3m"),
         FastlaneCore::ConfigItem.new(key: :app_apk,
                                      env_name: "APP_APK",
                                      description: "The path for your android app apk",
                                      type: String,
                                      optional: false),
         FastlaneCore::ConfigItem.new(key: :app_test_apk,
                                      env_name: "APP_TEST_APK",
                                      description: "The path for your android test apk. Default: empty string",
                                      type: String,
                                      optional: true,
                                      default_value: nil),
         FastlaneCore::ConfigItem.new(key: :use_orchestrator,
                                      env_name: "USE_ORCHESTRATOR",
                                      description: "If you use orchestrator when set instrumentation test . Default: false",
                                      type: Boolean,
                                      optional: true,
                                      default_value: false),
         FastlaneCore::ConfigItem.new(key: :console_log_file_name,
                                      env_name: "CONSOLE_LOG_FILE_NAME",
                                      description: "The filename to save the output results. Default: ./console_output.log",
                                      type: String,
                                      optional: true,
                                      default_value: "./console_output.log"),
         FastlaneCore::ConfigItem.new(key: :extra_options,
                                      env_name: "EXTRA_OPTIONS",
                                      description: "Extra options that you need to pass to the gcloud command. Default: empty string",
                                      type: String,
                                      optional: true,
                                      default_value: ""),
         FastlaneCore::ConfigItem.new(key: :slack_url,
                                      env_name: "SLACK_URL",
                                      description: "If Notify to Slack after finishing of the test. Set your slack incoming webhook url",
                                      type: String,
                                      optional: true,
                                      default_value: nil),
         FastlaneCore::ConfigItem.new(key: :firebase_test_lab_results_bucket,
                                      env_name: "FIREBASE_TEST_LAB_RESULTS_BUCKET",
                                      description: "Name of Firebase Test Lab results bucket",
                                      type: String,
                                      optional: true,
                                      default_value: nil),
         FastlaneCore::ConfigItem.new(key: :github_owner,
                                      env_name: "GITHUB_OWNER",
                                      description: "Owner name",
                                      type: String,
                                      optional: true,
                                      default_value: nil),
         FastlaneCore::ConfigItem.new(key: :github_repository,
                                      env_name: "GITHUB_REPOSITORY",
                                      description: "Repository name",
                                      type: String,
                                      optional: true,
                                      default_value: nil),
         FastlaneCore::ConfigItem.new(key: :github_pr_number,
                                      env_name: "GITHUB_PR_NUMBER",
                                      description: "Pull request number",
                                      type: String,
                                      optional: true,
                                      default_value: nil),
         FastlaneCore::ConfigItem.new(key: :github_api_token,
                                      env_name: "GITHUB_API_TOKEN",
                                      description: "GitHub API Token",
                                      type: String,
                                      optional: true,
                                      default_value: nil)
        ]
      end

      def self.check_has_property(hash_obj, property)
        UI.user_error!("Each device must have #{property} property") unless hash_obj.key?(property)
      end

      def self.set_default_property(hash_obj, property, default)
        unless hash_obj.key?(property)
          hash_obj[property] = default
        end
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.output
        [['console_output.log', 'A console log when running Firebase Test Lab with gcloud']]
      end

      def self.example_code
        ['before_all do
            ENV["SLACK_URL"] = "https://hooks.slack.com/services/XXXXXXXXX/XXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"
          end

          lane :test do

            # Get Pull request number
            pr_number = ENV["CI_PULL_REQUEST"] != nil ? ENV["CI_PULL_REQUEST"][/(?<=https:\/\/github.com\/cats-oss\/android\/pull\/)(.*)/] : nil

            # Upload to Firebase Test Lab
            firebase_test_lab_android(
              project_id: "cats-firebase",
              gcloud_service_key_file: "fastlane/client-secret.json",
              type: "robo",
              devices: [
                {
                  model: "Nexus6P",
                  version: "23",
                  locale: "ja_JP",
                  orientation: "portrait"
                },
                {
                  model: "Pixel2",
                  version: "28"
                }
              ],
              app_apk: "test.apk",
              # app_test_apk: "androidTest.apk",
              # use_orchestrator: false,
              console_log_file_name: "fastlane/console_output.log",
              timeout: "3m",
              firebase_test_lab_results_bucket: "firebase_cats_test_bucket",
              slack_url: ENV["SLACK_URL"],
              github_owner: "cats-oss",
              github_repository: "fastlane-plugin-firebase_test_lab_android",
              github_pr_number: pr_number,
              github_api_token: ENV["DANGER_GITHUB_API_TOKEN"]
            )
          end']
      end
    end
  end
end
