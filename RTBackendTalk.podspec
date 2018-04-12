#
# Be sure to run `pod lib lint RTBackendTalk.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RTBackendTalk'
  s.version          = '0.1.0'
  s.summary          = 'A library to add support for network requests over Alamofire'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This library offers engine for creating network requests and processing them.
                       DESC

  s.homepage         = 'https://bitbucket.org/rentateam/rtbackendtalk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'RentaTeam' => 'info@rentateam.ru' }
  s.source           = { :git => 'https://bitbucket.org/rentateam/rtbackendtalk.git', :tag => s.version.to_s }
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.0' }

  s.ios.deployment_target = '10.3'

  s.source_files = 'RTBackendTalk/Classes/**/*'
  
  s.dependency 'Alamofire', '~> 4.7.1'
  s.dependency 'AlamofireActivityLogger', '~> 2.4.0'
  s.dependency 'PromiseKit', '~> 6.2.4'
  s.dependency 'PromiseKit/Alamofire', '~> 6.0'
  s.dependency 'SwiftyJSON', '~> 4.0.0'
end
