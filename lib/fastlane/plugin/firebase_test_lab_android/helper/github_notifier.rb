require 'fastlane_core/ui/ui'
require 'json'
require 'net/http'
require 'uri'

module Fastlane
  module GitHubNotifier
    def self.fold_comments(github_owner, github_repository, github_pr_number, comment_prefix, summary, github_api_token)
      res = get_comments(github_owner, github_repository, github_pr_number, github_api_token)
      JSON.parse(res.body)
          .select {|comment| comment["body"].start_with?(comment_prefix)}
          .each {|comment|
            body = "<details><summary>#{summary}</summary>\n\n#{comment["body"]}\n\n</details>\n"
            patch_comment(github_owner, github_repository, comment["id"], body, github_api_token)
          }
    end

    def self.delete_comments(github_owner, github_repository, github_pr_number, comment_prefix, github_api_token)
      res = get_comments(github_owner, github_repository, github_pr_number, github_api_token)
      JSON.parse(res.body)
          .select {|comment| comment["body"].start_with?(comment_prefix)}
          .each {|comment| delete_comment(github_owner, github_repository, comment["id"], github_api_token)}
    end

    def self.get_comments(github_owner, github_repository, github_pr_number, github_api_token)
      api_url = "https://api.github.com/repos/#{github_owner}/#{github_repository}/issues/#{github_pr_number}/comments"
      UI.message "get comments #{api_url}"

      uri = URI.parse(api_url)
      req = Net::HTTP::Get.new(uri)
      req["Content-Type"] = "application/json"
      req["Authorization"] = "token #{github_api_token}"

      res = Net::HTTP.start(uri.hostname, uri.port, {use_ssl: uri.scheme = "https"}) {|http| http.request(req)}
      UI.message "#{res.code}\n#{res.body}"

      res
    end

    def self.put_comment(github_owner, github_repository, github_pr_number, body, github_api_token)
      api_url = "https://api.github.com/repos/#{github_owner}/#{github_repository}/issues/#{github_pr_number}/comments"
      UI.message "put comment #{api_url}"

      uri = URI.parse(api_url)
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Authorization"] = "token #{github_api_token}"
      req.body = {:body => body}.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, {use_ssl: uri.scheme = "https"}) {|http| http.request(req)}
      UI.message "#{res.code}\n#{res.body}"

      res
    end

    def self.patch_comment(github_owner, github_repository, comment_id, body, github_api_token)
      api_url = "https://api.github.com/repos/#{github_owner}/#{github_repository}/issues/comments/#{comment_id}"
      UI.message "patch comment #{api_url}"

      uri = URI.parse(api_url)
      req = Net::HTTP::Patch.new(uri)
      req["Content-Type"] = "application/json"
      req["Authorization"] = "token #{github_api_token}"
      req.body = {:body => body}.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, {use_ssl: uri.scheme = "https"}) {|http| http.request(req)}
      UI.message "#{res.code}\n#{res.body}"

      res
    end

    def self.delete_comment(github_owner, github_repository, comment_id, github_api_token)
      api_url = "https://api.github.com/repos/#{github_owner}/#{github_repository}/issues/comments/#{comment_id}"
      UI.message "delete comment #{api_url}"

      uri = URI.parse(api_url)
      req = Net::HTTP::Delete.new(uri)
      req["Content-Type"] = "application/json"
      req["Authorization"] = "token #{github_api_token}"

      res = Net::HTTP.start(uri.hostname, uri.port, {use_ssl: uri.scheme = "https"}) {|http| http.request(req)}
      UI.message "#{res.code}\n#{res.body}"

      res
    end
  end
end