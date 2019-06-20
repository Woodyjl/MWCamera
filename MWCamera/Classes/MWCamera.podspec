#
# Be sure to run `pod lib lint MWCamera.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MWCamera'
  s.version          = '0.1.0'
  s.summary          = 'This is a summary of MWCamera.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This pod is a camera library that always for simpler snapchat like camera implementation.
                       DESC

  s.homepage         = 'https://github.com/woodyjl/MWCamera'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'woodyjl' => 'woodyjeanlouis@gmail.com' }
  s.source           = { :git => 'https://github.com/woodyjl/MWCamera.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '11.2'

  s.source_files = 'MWCamera/Classes/**/*'
  s.swift_version = '4.2'
  
  # s.resource_bundles = {
  #   'MWCamera' => ['MWCamera/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'AVFoundation'
  # s.dependency 'SwiftLint'
end
