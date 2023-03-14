require 'securerandom'

module Kuby
  module Sidekiq
    # This class creates a deployment for a Sikekiq Process. A process is a single instance
    # of Sidekiq. Each instance can be provided command line options to specify concurrency,
    # config files or queues.
    # https://github.com/sidekiq/sidekiq/wiki/Best-Practices#4-use-precise-terminology
    class SidekiqProcess
      extend ::KubeDSL::ValueFields

      ROLE='worker'

      attr_reader :plugin, :name, :default_replicas

      value_field :replicas, default: nil
      value_field :options, default: []

      def initialize(name: 'default', plugin:, default_replicas:)
        @name = name
        @plugin = plugin
        @default_replicas = default_replicas
      end

      def deployment(&block)
        context = self

        @deployment ||= KubeDSL.deployment do
          metadata do
            name "#{context.plugin.selector_app}-sidekiq-#{ROLE}-#{context.name}"
            namespace context.plugin.namespace.metadata.name

            labels do
              add :app, context.plugin.selector_app
              add :role, ROLE
            end
          end

          spec do
            replicas (context.replicas || context.default_replicas)

            selector do
              match_labels do
                add :app, context.plugin.selector_app
                add :role, ROLE
              end
            end

            strategy do
              type 'RollingUpdate'

              rolling_update do
                max_surge '25%'
                max_unavailable 0
              end
            end

            template do
              metadata do
                labels do
                  add :app, context.plugin.selector_app
                  add :role, ROLE
                end
              end

              spec do
                container(:worker) do
                  name "#{context.plugin.selector_app}-sidekiq-#{ROLE}-#{context.name}"
                  image_pull_policy 'IfNotPresent'
                  command ['bundle', 'exec', 'sidekiq', *context.options]
                end

                image_pull_secret do
                  name context.plugin.kubernetes.registry_secret.metadata.name
                end

                restart_policy 'Always'
                service_account_name context.plugin.service_account.metadata.name
              end
            end
          end
        end

        @deployment.instance_eval(&block) if block
        @deployment
      end
    end
  end
end
