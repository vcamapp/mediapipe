require 'xcodeproj'
require 'fileutils'
require_relative 'lib/versions'

root = File.expand_path('..', __dir__)
versions = read_versions(root)
project_dir = File.join(root, 'builder/mediapipe-tasks-vision-wrapper')
project_path = File.join(project_dir, 'MediaPipeTasksVisionWrapper.xcodeproj')
FileUtils.mkdir_p(project_dir) unless Dir.exist?(project_dir)

# iOS public headers come from the official pod; macOS headers are versioned
# in-repo (macos/Headers, generated from the patched fork).
ios_headers_dir = File.join(root, 'builder/Pods/MediaPipeTasksVision/frameworks/MediaPipeTasksVision.xcframework/ios-arm64/MediaPipeTasksVision.framework/Headers')
ios_headers_dir_relative = '../Pods/MediaPipeTasksVision/frameworks/MediaPipeTasksVision.xcframework/ios-arm64/MediaPipeTasksVision.framework/Headers'
macos_headers_dir = File.join(root, 'macos/Headers')
macos_headers_dir_relative = '../../macos/Headers'

def write_umbrella_header(path, headers_dir)
  return unless Dir.exist?(headers_dir)
  imports = Dir[File.join(headers_dir, '*.h')].map { |p| File.basename(p) }.sort
  File.write(path, <<~HEADER)
    #import <Foundation/Foundation.h>
    #{imports.reject { |name| name == 'MediaPipeTasksVision.h' }.map { |name| "#import <MediaPipeTasksVision/#{name}>" }.join("\n")}

    FOUNDATION_EXPORT double MediaPipeTasksVisionVersionNumber;
    FOUNDATION_EXPORT const unsigned char MediaPipeTasksVisionVersionString[];
  HEADER
end

write_umbrella_header(File.join(project_dir, 'MediaPipeTasksVision/MediaPipeTasksVision.h'), ios_headers_dir)
abort('macos/Headers is missing; the macOS public headers are versioned in-repo.') unless Dir.exist?(macos_headers_dir)
FileUtils.mkdir_p(File.join(project_dir, 'MediaPipeTasksVisionMac'))
write_umbrella_header(File.join(project_dir, 'MediaPipeTasksVisionMac/MediaPipeTasksVision.h'), macos_headers_dir)

project = Xcodeproj::Project.new(project_path)

def configure_target(target, versions, infoplist)
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.vcamapp.mediapipe.tasks.vision'
    config.build_settings['PRODUCT_NAME'] = 'MediaPipeTasksVision'
    config.build_settings['MACH_O_TYPE'] = 'mh_dylib'
    config.build_settings['DEFINES_MODULE'] = 'YES'
    config.build_settings['SKIP_INSTALL'] = 'NO'
    config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++20'
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
    config.build_settings['ARCHS'] = 'arm64'
    config.build_settings['MARKETING_VERSION'] = versions.fetch('PACKAGE_VERSION')
    config.build_settings['CURRENT_PROJECT_VERSION'] = versions.fetch('PACKAGE_BUILD')
    config.build_settings['PUBLIC_HEADERS_FOLDER_PATH'] = 'Headers'
    config.build_settings['INSTALLHDRS_COPY_PHASE'] = 'YES'
    config.build_settings['INFOPLIST_FILE'] = infoplist
    config.build_settings['MODULEMAP_FILE'] = '$(SRCROOT)/MediaPipeTasksVision/module.modulemap'
    config.build_settings['HEADER_SEARCH_PATHS'] = '$(inherited)'
    config.build_settings['OTHER_LDFLAGS'] = '$(inherited) -ObjC -lc++'
  end
end

def link_frameworks(project, target, names)
  names.each do |framework|
    file = project.frameworks_group.new_file("System/Library/Frameworks/#{framework}.framework")
    target.frameworks_build_phase.add_file_reference(file)
  end
end

# --- iOS target -------------------------------------------------------------
ios_target = project.new_target(:framework, 'MediaPipeTasksVision', :ios, versions.fetch('MINIMUM_IOS_VERSION'))
ios_target.source_build_phase.add_file_reference(project.main_group.new_file('MediaPipeTasksVision/MPPForceLink.mm'))
ios_umbrella = project.main_group.new_file('MediaPipeTasksVision/MediaPipeTasksVision.h')
ios_target.headers_build_phase.add_file_reference(ios_umbrella, :public)
Dir[File.join(ios_headers_dir, '*.h')].each do |header|
  ref = project.main_group.new_file(File.join(ios_headers_dir_relative, File.basename(header)))
  ios_target.headers_build_phase.add_file_reference(ref, :public)
end
configure_target(ios_target, versions, 'MediaPipeTasksVision/Info.plist')
link_frameworks(project, ios_target, %w[AVFoundation Accelerate CoreGraphics CoreImage CoreMedia CoreVideo Foundation ImageIO Metal MetalKit OpenGLES QuartzCore Security UIKit])

# --- macOS target (CPU-only, headers from the patched fork) -----------------
macos_target = project.new_target(:framework, 'MediaPipeTasksVisionMac', :osx, versions.fetch('MINIMUM_MACOS_VERSION'))
macos_target.source_build_phase.add_file_reference(project.main_group.new_file('MediaPipeTasksVision/MPPForceLink.mm'))
macos_umbrella = project.main_group.new_file('MediaPipeTasksVisionMac/MediaPipeTasksVision.h')
macos_target.headers_build_phase.add_file_reference(macos_umbrella, :public)
Dir[File.join(macos_headers_dir, '*.h')].each do |header|
  ref = project.main_group.new_file(File.join(macos_headers_dir_relative, File.basename(header)))
  macos_target.headers_build_phase.add_file_reference(ref, :public)
end
configure_target(macos_target, versions, 'MediaPipeTasksVision/Info-macOS.plist')
# No UIKit / OpenGLES / Metal on the CPU-only macOS build. AppKit is required
# by the statically linked OpenCV imgcodecs.
link_frameworks(project, macos_target, %w[AVFoundation Accelerate AppKit CoreGraphics CoreImage CoreMedia CoreVideo Foundation ImageIO QuartzCore Security])

project.save
