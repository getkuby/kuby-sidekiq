$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'kuby/sidekiq/version'

Gem::Specification.new do |s|
  s.name     = 'kuby-sidekiq'
  s.version  = ::Kuby::Sidekiq::VERSION
  s.authors  = ['Cameron Dutro']
  s.email    = ['camertron@gmail.com']
  s.homepage = 'http://github.com/getkuby/kuby-sidekiq'

  s.description = s.summary = 'Sidekiq plugin for Kuby.'

  s.platform = Gem::Platform::RUBY

  s.add_dependency 'kuby-kube-db', '~> 0.2'

  s.require_path = 'lib'
  s.files = Dir['{lib,spec}/**/*', 'Gemfile', 'LICENSE', 'CHANGELOG.md', 'README.md', 'Rakefile', 'kuby-sidekiq.gemspec']
end
