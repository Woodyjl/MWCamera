Pod::Spec.new do |s|
  s.name         = "MWCamera"
  s.version      = "1.0.0"
  s.summary      = "A lightweight framework that helps build apps for photos and video capture."
  s.ios.deployment_target = '11.2'
  s.swift_version = '4.2'
  s.description  = <<-DESC
    MWCamera is a lightweight framework that helps build powerful camera apps for ios! This framework was also inspried by SwiftyCam ✊🏽.
                   DESC
  s.homepage     = "https://github.com/Woodyjl/MWCamera"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Woody Jean-Louis" => "woodyjeanlouis@fiitbuds.com" }
  s.social_media_url   = "https://twitter.com/"
  s.platform     = :ios, "11.2"
  s.source       = { :git => "https://github.com/Woodyjl/MWCamera.git", :tag => s.version }
  s.source_files  = "MWCamera/Classes/*.swift"
end
