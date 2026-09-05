Pod::Spec.new do |s|
  s.name             = 'screen_capture'
  s.version          = '0.0.1'
  s.summary          = 'ReplayKit screen recording for Flutter (iOS).'
  s.description      = 'Records the app screen, including native camera preview layers.'
  s.homepage         = 'https://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'futuremode2026' => 'dev@example.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'

  s.platform = :ios, '13.0'
  s.static_framework = true
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
