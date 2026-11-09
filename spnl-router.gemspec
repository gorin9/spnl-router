Gem::Specification.new do |s|
  s.name = 'spnl-router'
  s.version = '0.2.0'
  s.summary = 'Validated static HTTP route compilation for Spinel'
  s.authors = ['gorin9']
  s.homepage = 'https://github.com/gorin9/spnl-router'
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.1'
  s.files = Dir['lib/**/*.rb', 'web/**/*.rb', 'spnl_*/**/*.rb', 'spnl_*.rb', 'native/*', 'bin/*', 'README.md', 'LICENSE', 'spin.toml', 'spinel-packer']
  s.require_paths = ['.', 'lib']
  s.executables = ['spnl-router']
end
