#
# Be sure to run `pod lib lint RTBackendTalk.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RTBackendTalk'
  s.version          = '0.1.19'
  s.summary          = 'A library to add support for network requests over Alamofire'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This library offers engine for creating network requests and processing them.
                       DESC

  s.homepage         = 'https://github.com/Rentateam/rtbackendtalk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'RentaTeam' => 'info@rentateam.ru' }
  s.source           = { :git => 'https://github.com/Rentateam/rtbackendtalk.git', :tag => s.version.to_s }
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }

  s.swift_version = '5.0'
  s.ios.deployment_target = '10.0'

  s.source_files = 'RTBackendTalk/Classes/**/*'
  
  s.dependency 'Alamofire', '~> 5.4.1'
end
