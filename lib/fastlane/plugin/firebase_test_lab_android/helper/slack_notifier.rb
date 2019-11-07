require 'fastlane/action'
require 'fastlane_core/ui/ui'
require 'json'

module Fastlane
  module SlackNotifier
    def self.notify(slack_url, message, success)
      slackArgs = Fastlane::ConfigurationHelper.parse(Fastlane::Actions::SlackAction, {
          slack_url: slack_url,
          message: message,
          success: success,
          use_webhook_configured_username_and_icon: true,
          default_payloads: [:git_branch, :git_author, :last_git_commit]
      })
      Fastlane::Actions::SlackAction.run(slackArgs)
    end
  end
end