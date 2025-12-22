platform :ios, '15.0'

target 'VoiceQuiz' do
  use_frameworks!

  # GoogleWebRTC
  pod 'GoogleWebRTC', '~> 1.1'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      # Fix for GoogleWebRTC simulator build
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
    end
  end

  # Disable input/output validation for WebRTC
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['VALIDATE_WORKSPACE'] = 'NO'
  end
end
