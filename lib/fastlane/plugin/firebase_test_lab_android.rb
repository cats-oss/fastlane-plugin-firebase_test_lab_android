require 'fastlane/plugin/firebase_test_lab_android/version'

module Fastlane
  module FirebaseTestLabAndroid
    def self.all_classes
      Dir[File.expand_path('**/{actions}/*.rb', File.dirname(__FILE__))]
    end
  end
end

# By default we want to import all available actions
# A plugin can contain any number of actions and plugins
Fastlane::FirebaseTestLabAndroid.all_classes.each do |current|
  require current
end
