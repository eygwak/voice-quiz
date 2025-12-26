platform :ios, '16.0'

target 'VoiceQuiz' do
  use_frameworks!

  # No external dependencies - using native frameworks only
  # - Speech Recognition: Apple Speech Framework
  # - Text-to-Speech: AVSpeechSynthesizer
  # - Audio Session: AVFoundation
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
    end
  end
end
