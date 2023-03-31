**NOTE**: The documentation below refers to an unreleased version of kuby-sidekiq.

## kuby-sidekiq

Sidekiq plugin for [Kuby](https://github.com/getkuby/kuby-core).

## Intro

The Sidekiq plugin makes it easy to run a deployment of Sidekiq workers for your Rails app. Behind the scenes it uses [kuby-redis](https://github.com/getkuby/kuby-redis) to stand up an instance of Redis and Kubernetes deployments to start the desired number of workers.

## Configuration

Add the kuby-sidekiq and [sidekiq](https://github.com/mperham/sidekiq) gems to your Gemfile and run `bundle install`.

Require the plugin in your kuby.rb file and configure it, eg:

```ruby
require 'kuby/sidekiq'

Kuby.define(:production) do
  kubernetes do

    add_plugin(:sidekiq) do
      replicas 2  # run two workers
    end

  end
end
```

Next, run the setup command, eg:

```bash
bundle exec kuby -e production setup
```

## Connecting to Redis

Add a Sidekiq initializer to your Rails app and tell Sidekiq how to connect to Redis:

```ruby
# config/initializers/sidekiq.rb

if Rails.env.production?
  require 'kuby'

  Kuby.load!

  Sidekiq.configure_server do |config|
    config.redis = Kuby.environment.kubernetes.plugin(:sidekiq).connection_params
  end

  Sidekiq.configure_client do |config|
    config.redis = Kuby.environment.kubernetes.plugin(:sidekiq).connection_params
  end
end
```

### Build and Deploy

Now that Sidekiq has been installed and configured, build, push, and deploy your app the usual way, eg:

```bash
bundle exec kuby -e production build
bundle exec kuby -e production push
bundle exec kuby -e production deploy
```

## Advanced Configuration

If you have a more complex setup for Sidekiq you can specify the processes you need to create. The options method allow you to
provide command line arguments to Sidekiq in order to either specify a non-default `sidekiq.yml` file or queues for a process to
run. The process name is required.

```ruby
require 'kuby/sidekiq'

Kuby.define(:production) do
  kubernetes do

    add_plugin(:sidekiq) do
      replicas 2  # sets the default number of replicas for each process


      process('default') # sidekiq uses sidekiq.yml by default and has 2 replicas

      process('slow_process') do
        options ['-C', 'config/slow_sidekiq.yml']
        replicas 4 # override default number of replicas
      end

      process('queue_processor') do
        options ['-q', 'critical', '-q', 'less_critical']
      end
    end
  end
end
```

## License

Licensed under the MIT license. See LICENSE for details.

## Authors

* Cameron C. Dutro: http://github.com/camertron
