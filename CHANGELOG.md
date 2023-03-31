## 0.5.0
* Support for multiple configurable Sidekiq processes (#2, @zhall0624)

## 0.4.0
* Use kuby-redis v0.2, which uses the Spotahome Redis operator instead of KubeDB.

## 0.3.0
* Conform to new plugin architecture.
* Accept `environment` instead of `definition` instances.

## 0.2.0
* Upgrade to kube-dsl 0.4.
* Take advantage of kube-dsl's new `#merge!` functionality to pull envFroms from the rails_app plugin.

## 0.1.0
* Birthday!
