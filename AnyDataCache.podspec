#
# Be sure to run `pod lib lint AnyDataCache.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AnyDataCache'
  s.version          = '0.1.0'
  s.summary          = 'A simple data caching framework based on Realm database.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
'This datacaching library has following features: \
1. Caching data on background thread. \
2. You can set expiry time and it will delete data automatically after expiry time. \
3. You can specify disk space in MBs and library will automatically delete old items if disk spce is more than the limit set. \
4. You can mark an item for "autodelete" which is by default true. So it is set to false, librery wont delete such items and will wait for your instructions to delete them.'
                       DESC

  s.homepage         = 'https://github.com/vijayendra-tripathi/AnyDataCache'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Vijayendra Tripathi' => 'vijayendra.t.inbox@gmail.com' }
  s.source           = { :git => 'https://github.com/vijayendra-tripathi/AnyDataCache.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/vijayendra_t'

  s.ios.deployment_target = '10.0'
  s.swift_version = '5.0'

  s.source_files = 'AnyDataCache/Classes/**/*'
  
  # s.resource_bundles = {
  #   'AnyDataCache' => ['AnyDataCache/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit'
  s.dependency 'RealmSwift', '~> 4.3.1'
end
