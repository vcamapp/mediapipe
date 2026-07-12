require 'fileutils'
require 'xcodeproj'
require_relative 'lib/versions'

root = File.expand_path('..', __dir__)
versions = read_versions(root)
project_path = File.join(root, 'smoke-test/MediaPipeSmokeTest.xcodeproj')
resources = File.join(root, '.build-artifacts/smoke-test-resources')
project = Xcodeproj::Project.new(project_path)

def add_smoke_target(project, resources, name:, platform:, deployment_target:, slice:)
  framework_search_path = "$(SRCROOT)/../.build-artifacts/MediaPipeTasksVision.xcframework/#{slice}"
  target = project.new_target(:unit_test_bundle, name, platform, deployment_target)
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.vcamapp.mediapipe.smoketests'
    config.build_settings['ARCHS'] = 'arm64'
    config.build_settings['FRAMEWORK_SEARCH_PATHS'] = [framework_search_path, '$(PLATFORM_DIR)/Developer/Library/Frameworks']
    config.build_settings['OTHER_LDFLAGS'] = '-framework MediaPipeTasksVision -framework Testing'
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  end
  source = project.main_group.new_file('MediaPipeSmokeTests.swift')
  target.source_build_phase.add_file_reference(source)
  resources_group = project.main_group.new_group("Resources-#{name}")
  Dir[File.join(resources, '*')].each do |file|
    target.resources_build_phase.add_file_reference(resources_group.new_file(File.join('../.build-artifacts/smoke-test-resources', File.basename(file))))
  end
  framework_ref = project.main_group.new_file("../.build-artifacts/MediaPipeTasksVision.xcframework/#{slice}/MediaPipeTasksVision.framework")
  target.frameworks_build_phase.add_file_reference(framework_ref)
  embed_phase = target.new_copy_files_build_phase('Embed Frameworks')
  embed_phase.dst_subfolder_spec = '10'
  embed_file = embed_phase.add_file_reference(framework_ref)
  embed_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy'] }
  testing_ref = project.frameworks_group.new_file('System/Library/Frameworks/Testing.framework')
  target.frameworks_build_phase.add_file_reference(testing_ref)
end

# Both targets compile the same test source; UIKit-only coverage is guarded
# with #if canImport(UIKit) inside the file.
add_smoke_target(project, resources,
                 name: 'MediaPipeSmokeTests', platform: :ios,
                 deployment_target: versions.fetch('MINIMUM_IOS_VERSION'),
                 slice: 'ios-arm64-simulator')
add_smoke_target(project, resources,
                 name: 'MediaPipeSmokeTestsMac', platform: :osx,
                 deployment_target: versions.fetch('MINIMUM_MACOS_VERSION'),
                 slice: 'macos-arm64')
project.save
