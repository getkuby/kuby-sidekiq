require 'securerandom'
require 'kuby/redis'
require_relative 'sidekiq_process'

module Kuby
  module Sidekiq
    class Plugin < ::Kuby::Plugin
      extend ::KubeDSL::ValueFields

      ROLE = 'worker'.freeze

      value_field :replicas, default: 1

      def processes
        @processes ||= []
      end

      def connection_params
        redis_instance.connection_params
      end

      def configure(&block)
        instance_eval(&block) if block
      end

      def after_configuration
        if processes.empty?
          processes << SidekiqProcess.new(plugin: self, default_replicas: replicas)
        end

        environment.kubernetes.add_plugin(:redis) do
          instance :sidekiq do
            custom_config (custom_config || []).concat(['maxmemory-policy noeviction'])
          end
        end

        return unless rails_app

        processes.each do |process|
          process.deployment.spec.template.spec.container(:worker).merge!(
            rails_app.deployment.spec.template.spec.container(:web), fields: [:env_from]
          )

          if rails_app.manage_database? && database = Kuby::Plugins::RailsApp::Database.get(rails_app)
            database.plugin.configure_pod_spec(process.deployment.spec.template.spec)
          end
        end
      end

      def before_deploy(manifest)
        image_with_tag = "#{docker.image.image_url}:#{kubernetes.tag || Kuby::Docker::LATEST_TAG}"

        processes.each do |process|
          process.deployment do
            spec do
              template do
                spec do
                  container(:worker) do
                    image image_with_tag
                  end
                end
              end
            end
          end
        end
      end

      def resources
        @resources ||= [service_account, *processes.map(&:deployment)]
      end

      def service_account(&block)
        context = self

        @service_account ||= KubeDSL.service_account do
          metadata do
            name "#{context.selector_app}-sidekiq-sa"
            namespace context.namespace.metadata.name

            labels do
              add :app, context.selector_app
              add :role, ROLE
            end
          end
        end

        @service_account.instance_eval(&block) if block
        @service_account
      end

      def process(name, &block)
        SidekiqProcess.new(name: name, plugin: self, default_replicas: replicas).tap do |process|
          process.instance_eval(&block) if block
          processes << process
        end
      end

      def redis_instance
        kubernetes.plugin(:redis).instance(:sidekiq)
      end

      def kubernetes
        environment.kubernetes
      end

      def docker
        environment.docker
      end

      def selector_app
        kubernetes.selector_app
      end

      def namespace
        kubernetes.namespace
      end

      def rails_app
        kubernetes.plugin(:rails_app)
      end
    end
  end
end
