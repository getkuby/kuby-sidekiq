require 'securerandom'
require 'kuby/redis'

module Kuby
  module Sidekiq
    class Plugin < ::Kuby::Plugin
      extend ::KubeDSL::ValueFields

      ROLE = 'worker'.freeze

      value_field :replicas, default: 1

      def url
        redis_instance.url
      end

      def configure(&block)
        instance_eval(&block) if block
      end

      def after_configuration
        environment.kubernetes.add_plugin(:redis) do
          instance :sidekiq
        end

        return unless rails_app

        deployment.spec.template.spec.container(:worker).merge!(
          rails_app.deployment.spec.template.spec.container(:web), fields: [:env_from]
        )
      end

      def before_deploy(manifest)
        image_with_tag = "#{docker.image.image_url}:#{kubernetes.tag || Kuby::Docker::LATEST_TAG}"

        deployment do
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

      def resources
        @resources ||= [
          service_account,
          deployment
        ]
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

      def deployment(&block)
        context = self

        @deployment ||= KubeDSL.deployment do
          metadata do
            name "#{context.selector_app}-sidekiq-#{ROLE}"
            namespace context.namespace.metadata.name

            labels do
              add :app, context.selector_app
              add :role, ROLE
            end
          end

          spec do
            replicas context.replicas

            selector do
              match_labels do
                add :app, context.selector_app
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
                  add :app, context.selector_app
                  add :role, ROLE
                end
              end

              spec do
                container(:worker) do
                  name "#{context.selector_app}-sidekiq-#{ROLE}"
                  image_pull_policy 'IfNotPresent'
                  command %w(bundle exec sidekiq)
                end

                image_pull_secret do
                  name context.kubernetes.registry_secret.metadata.name
                end

                restart_policy 'Always'
                service_account_name context.service_account.metadata.name
              end
            end
          end
        end

        @deployment.instance_eval(&block) if block
        @deployment
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
