#
# Cookbook Name:: wrapper
# Recipe:: default
#
# Copyright 2014, Rackspace
#
#
%w(
  stack_commons::mysql_base
  stack_commons::postgresql_master
  stack_commons::rabbitmq
  stack_commons::varnish
  stack_commons::redis_master
  stack_commons::redis_slave
  stack_commons::redis_sentinel
).each do |recipe|
  include_recipe recipe
end
