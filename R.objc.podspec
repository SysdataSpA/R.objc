#
# Be sure to run `pod lib lint R.objc.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|

  s.name             = 'R.objc'
  s.version          = '0.1.0'
  s.summary          = 'Get autocompleted localizable strings and asset catalogue images names'
  s.description      = <<-DESC
Freely inspired by R.swift: get autocompleted localizable strings and asset catalogue images names.
You can have:
- Compile time check: no more incorrect strings that make your app crash at runtime
- Autocompletion: never have to guess that image name again
                       DESC

  s.homepage         = 'https://github.com/SysdataSpA/R.objc'
  s.license          = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.author           = { 'Sysdata SpA' => 'team.mobile@sysdata.it' }
  s.source           = { :http => 'https://github.com/SysdataSpA/R.objc/releases/download/v#{spec.version}/robjc-#{spec.version}.zip' }
  s.requires_arc     = true

  s.preserve_paths = "robjc"
  s.source_files = 'R.objc/Classes/**/*'
end
