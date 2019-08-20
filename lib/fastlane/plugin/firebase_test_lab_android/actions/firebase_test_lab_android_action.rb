require 'fastlane/action'

module Fastlane
  module Commands
    def self.config
      "gcloud config set project"
    end

    def self.auth
      "gcloud auth activate-service-account"
    end

    def self.run_tests
      "gcloud firebase test android run"
    end
  end

  module Actions
    class FirebaseTestLabAndroidAction < Action
      PIPE = "testlab-pipe"

      def self.run(params)
        UI.message("Starting...")

        UI.message("Set Google Cloud target project.")
        Action.sh("#{Commands.config} #{params[:project_id]}")

        UI.message("Authenticate with Google Cloud.")
        Action.sh("#{Commands.auth} --key-file #{params[:gcloud_service_key_file]}")

        UI.message("Running...")
        Action.sh("rm #{PIPE}") if File.exist?(PIPE)
        Action.sh("mkfifo #{PIPE}")
        Action.sh("set +e;"\
                  "tee #{params[:console_log_file_name]} < #{PIPE} & "\
                  "#{Commands.run_tests} "\
                  "--type #{params[:type]} "\
                  "--app #{params[:app_apk]} "\
                  "#{"--test #{params[:app_test_apk]} " unless params[:app_test_apk].nil?}"\
                  "#{params[:devices].map { |d| "--device model=#{d[:model]},version=#{d[:version]},locale=#{d[:locale]},orientation=#{d[:orientation]} " }.join}"\
                  "--timeout #{params[:timeout]} "\
                  "#{params[:extra_options]} "\
                  "> #{PIPE} 2>&1;"\
                  "set -e")
        Action.sh("rm #{PIPE}") if File.exist?(PIPE)

        if params[:notify_to_slack]
          output = File.read(params[:console_log_file_name])
          failed = output.include?("Failed") || output.include?("Inconclusive")
          other_action.slack(message: output,
                             success: !failed,
                             use_webhook_configured_username_and_icon: true,
                             default_payloads: [:git_branch, :git_author, :last_git_commit])
        end
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
                                      is_string: true,
                                      optional: true,
                                      default_value: "5m"),
         FastlaneCore::ConfigItem.new(key: :app_apk,
                                      env_name: "APP_APK",
                                      description: "The path for your android app apk",
                                      is_string: true,
                                      optional: false),
         FastlaneCore::ConfigItem.new(key: :app_test_apk,
                                      env_name: "APP_TEST_APK",
                                      description: "The path for your android test apk. Default: empty string",
                                      is_string: true,
                                      optional: true,
                                      default_value: nil),
         FastlaneCore::ConfigItem.new(key: :console_log_file_name,
                                      env_name: "CONSOLE_LOG_FILE_NAME",
                                      description: "The filename to save the output results. Default: ./console_output.log",
                                      is_string: true,
                                      optional: true,
                                      default_value: "./console_output.log"),
         FastlaneCore::ConfigItem.new(key: :extra_options,
                                      env_name: "EXTRA_OPTIONS",
                                      description: "Extra options that you need to pass to the gcloud command. Default: empty string",
                                      is_string: true,
                                      optional: true,
                                      default_value: ""),
         FastlaneCore::ConfigItem.new(key: :notify_to_slack,
                                      env_name: "NOTIFY_TO_SLACK",
                                      description: "Notify to Slack after finishing of the test. Default: false",
                                      is_string: false,
                                      optional: true,
                                      default_value: false)]
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
        ['firebase_test_lab_android(
              project_id: "cats-firebase",
              gcloud_service_key_file: "fastlane/client-secret.json",
              type: "robo",
              devices: [
                {
                    model: "hammerhead",
                    version: "21",
                    locale: "ja_JP",
                    orientation: "portrait"
                },
                {
                    model: "Pixel2",
                    version: "28"
                }
              ],
              app_apk: "test.apk",
              extra_options: "--robo-directives ignore:image_button_sign_in_twitter=,ignore:text_sign_in_terms_of_service=",
              console_log_file_name: "fastlane/console_output.log",
              timeout: "3m",
              notify_to_slack: true
          )']
      end
    end
  end
end
