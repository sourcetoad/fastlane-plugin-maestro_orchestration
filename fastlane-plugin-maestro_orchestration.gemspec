lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/maestro_orchestration/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-maestro_orchestration'
  spec.version       = Fastlane::MaestroOrchestration::VERSION
  spec.author        = 'Nemanja Risteski'
  spec.email         = 'nemanja.risteski@sourcetoad.com'

  spec.summary       = 'Plugin for maestro testing framework.'
  # spec.homepage      = "https://github.com/<GITHUB_USERNAME>/fastlane-plugin-maestro_orchestration"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 2.6'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency
  # spec.add_dependency 'your-dependency', '~> 1.0.0'
  spec.add_dependency('bundler')
  spec.add_dependency('fastlane', '>= 2.225.0')
  spec.add_dependency('fastlane-plugin-android_emulator', '~> 1.2', '>= 1.2.1')
  spec.add_dependency('pry')
  spec.add_dependency('rake')
  spec.add_dependency('rspec')
  spec.add_dependency('rspec_junit_formatter')
  spec.add_dependency('rubocop', '1.50.2')
  spec.add_dependency('rubocop-performance')
  spec.add_dependency('rubocop-require_tools')
  spec.add_dependency('simplecov')
end
