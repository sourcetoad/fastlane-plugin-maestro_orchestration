lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/maestro_orchestration/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-maestro_orchestration'
  spec.version       = Fastlane::MaestroOrchestration::VERSION
  spec.author        = 'Nemanja Risteski'
  spec.email         = 'nemanja.risteski@sourcetoad.com'
  spec.summary       = 'Plugin for maestro testing framework.'
  spec.homepage      = "https://github.com/sourcetoad/fastlane-plugin-maestro_orchestration"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 2.6'
  spec.add_dependency('fastlane-plugin-android_emulator', '~> 1.2', '>= 1.2.1')
end
