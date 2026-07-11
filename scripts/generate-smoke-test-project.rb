require 'fileutils'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'smoke-test/MediaPipeSmokeTest.xcodeproj')
resources = File.join(root, '.build-artifacts/smoke-test-resources')
framework = '$(SRCROOT)/../.build-artifacts/MediaPipeTasksVision.xcframework/ios-arm64-simulator'
project = Xcodeproj::Project.new(project_path)
target = project.new_target(:unit_test_bundle, 'MediaPipeSmokeTests', :ios, '17.0')
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.vcamapp.mediapipe.smoketests'
  config.build_settings['SWIFT_VERSION'] = '5.9'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['ARCHS'] = 'arm64'
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] = [framework, '$(PLATFORM_DIR)/Developer/Library/Frameworks']
  config.build_settings['OTHER_LDFLAGS'] = '-framework MediaPipeTasksVision -framework Testing'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
source = project.main_group.new_file('MediaPipeSmokeTests.swift')
target.source_build_phase.add_file_reference(source)
resources_group = project.main_group.new_group('Resources')
Dir[File.join(resources, '*')].each do |file|
  target.resources_build_phase.add_file_reference(resources_group.new_file(File.join('../.build-artifacts/smoke-test-resources', File.basename(file))))
end
framework_ref = project.main_group.new_file('../.build-artifacts/MediaPipeTasksVision.xcframework/ios-arm64-simulator/MediaPipeTasksVision.framework')
target.frameworks_build_phase.add_file_reference(framework_ref)
embed_phase = target.new_copy_files_build_phase('Embed Frameworks')
embed_phase.dst_subfolder_spec = '10'
embed_file = embed_phase.add_file_reference(framework_ref)
embed_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy'] }
testing_ref = project.frameworks_group.new_file('System/Library/Frameworks/Testing.framework')
target.frameworks_build_phase.add_file_reference(testing_ref)
project.save
