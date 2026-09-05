Pod::Spec.new do |s|
  s.name             = 'face_mesh'
  s.version          = '0.0.1'
  s.summary          = 'MediaPipe Face Landmarker bridge for Flutter (iOS).'
  s.description      = 'Streams face blendshapes and head pose from the front camera to Dart.'
  s.homepage         = 'https://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'futuremode2026' => 'dev@example.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*'
  s.resource_bundles = { 'face_mesh_assets' => ['Resources/**/*'] }

  s.dependency 'Flutter'
  s.dependency 'MediaPipeTasksVision'

  s.platform = :ios, '13.0'
  s.static_framework = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
