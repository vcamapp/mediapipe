require 'xcodeproj'
require 'fileutils'

root = File.expand_path('..', __dir__)
project_dir = File.join(root, 'builder/mediapipe-tasks-vision-wrapper')
project_path = File.join(project_dir, 'MediaPipeTasksVisionWrapper.xcodeproj')
FileUtils.mkdir_p(project_dir) unless Dir.exist?(project_dir)
headers_dir = File.join(root, 'builder/Pods/MediaPipeTasksVision/frameworks/MediaPipeTasksVision.xcframework/ios-arm64/MediaPipeTasksVision.framework/Headers')
headers_dir_relative = '../Pods/MediaPipeTasksVision/frameworks/MediaPipeTasksVision.xcframework/ios-arm64/MediaPipeTasksVision.framework/Headers'
wrapper_header = File.join(project_dir, 'MediaPipeTasksVision/MediaPipeTasksVision.h')
if Dir.exist?(headers_dir)
  imports = Dir[File.join(headers_dir, '*.h')].map { |path| File.basename(path) }.sort
  File.write(wrapper_header, <<~HEADER)
    #import <Foundation/Foundation.h>
    #{imports.reject { |name| name == 'MediaPipeTasksVision.h' }.map { |name| "#import <MediaPipeTasksVision/#{name}>" }.join("\n")}

    FOUNDATION_EXPORT double MediaPipeTasksVisionVersionNumber;
    FOUNDATION_EXPORT const unsigned char MediaPipeTasksVisionVersionString[];
  HEADER
end
project = Xcodeproj::Project.new(project_path)
target = project.new_target(:framework, 'MediaPipeTasksVision', :ios, '17.0')
target.product_name = 'MediaPipeTasksVision'
source = target.source_build_phase.add_file_reference(project.main_group.new_file('MediaPipeTasksVision/MPPForceLink.mm'))
umbrella = project.main_group.new_file('MediaPipeTasksVision/MediaPipeTasksVision.h')
target.headers_build_phase.add_file_reference(umbrella, :public)
Dir[File.join(headers_dir, '*.h')].each do |header|
  ref = project.main_group.new_file(File.join(headers_dir_relative, File.basename(header)))
  target.headers_build_phase.add_file_reference(ref, :public)
end
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.vcamapp.mediapipe.tasks.vision'
  config.build_settings['MACH_O_TYPE'] = 'mh_dylib'
  config.build_settings['DEFINES_MODULE'] = 'YES'
  config.build_settings['SKIP_INSTALL'] = 'NO'
  config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++20'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['ARCHS'] = 'arm64'
  config.build_settings['PUBLIC_HEADERS_FOLDER_PATH'] = 'Headers'
  config.build_settings['INSTALLHDRS_COPY_PHASE'] = 'YES'
  config.build_settings['INFOPLIST_FILE'] = 'MediaPipeTasksVision/Info.plist'
  config.build_settings['MODULEMAP_FILE'] = '$(SRCROOT)/MediaPipeTasksVision/module.modulemap'
  config.build_settings['HEADER_SEARCH_PATHS'] = '$(inherited)'
  config.build_settings['OTHER_LDFLAGS'] = '$(inherited) -ObjC -lc++'
  %w[AVFoundation Accelerate CoreGraphics CoreImage CoreMedia CoreVideo Foundation ImageIO Metal MetalKit OpenGLES QuartzCore UIKit].each do |framework|
    file = project.frameworks_group.new_file("System/Library/Frameworks/#{framework}.framework")
    target.frameworks_build_phase.add_file_reference(file)
  end
end
project.save
