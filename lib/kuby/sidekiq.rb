require 'kuby'
require 'kuby/sidekiq/plugin'

Kuby.register_plugin(:sidekiq, Kuby::Sidekiq::Plugin)
