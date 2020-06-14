require 'securerandom'

module Kuby
  module Sidekiq
    class Plugin < ::Kuby::Kubernetes::Plugin
      extend ::KubeDSL::ValueFields

      ROLE = 'worker'.freeze

      value_fields :replicas

      def after_initialize
        @replicas = 1
      end

      def after_configuration
        rails_app = definition.kubernetes.plugin(:rails_app)
        return unless rails_app

        rails_web = rails_app.deployment.spec.template.spec.container(:web)

        # This is some seriously awful hackery. It would be really nice if
        # KubeDSL provided a way to merge objects together at an arbitrary
        # nesting level.
        deployment.spec.template.spec.container(:worker) do
          @env_froms ||= {}

          rails_web.env_froms.each do |env_from|
            @env_froms[SecureRandom.hex] = env_from.dup
          end
        end
      end

      def resources
        @resources ||= [
          service_account,
          deployment,
          redis
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
                  image context.definition.docker.metadata.image_with_tag
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

      def redis(&block)
        context = self

        @redis ||= Kuby::KubeDB.redis do
          api_version 'kubedb.com/v1alpha1'

          metadata do
            name "#{context.selector_app}-sidekiq-redis"
            namespace context.kubernetes.namespace.metadata.name
          end

          spec do
            version '4.0-v1'
            storage_type 'Durable'

            storage do
              storage_class_name context.storage_class_name
              access_modes ['ReadWriteOnce']

              resources do
                requests do
                  add :storage, '50Mi'
                end
              end
            end
          end
        end

        @redis.instance_eval(&block) if block
        @redis
      end

      def storage_class_name
        kubernetes.provider.storage_class_name
      end

      def kubernetes
        definition.kubernetes
      end

      def selector_app
        kubernetes.selector_app
      end

      def namespace
        kubernetes.namespace
      end
    end
  end
end
