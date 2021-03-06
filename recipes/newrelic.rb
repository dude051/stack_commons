# Encoding: utf-8
#
# Cookbook Name:: stack_commons
# Recipe:: newrelic
#
# Copyright 2014, Rackspace Hosting
#
# Licensed under the newrelic License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.newrelic.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

stackname = node['stack_commons']['stackname']

# The node['newrelic']['license'] attribute needs to be set for NewRelic to work
if node['newrelic']['license']
  node.set[stackname]['newrelic']['application_monitoring'] = 'true'
  node.override['newrelic']['application_monitoring']['daemon']['ssl'] = true
  node.override['newrelic']['server_monitoring']['ssl'] = true
  node.default['newrelic_meetme_plugin']['license'] = node['newrelic']['license']
  include_recipe 'platformstack::default'

  case stackname
  when 'phpstack'
    include_recipe 'php'  # needed so that we don't install apache by installing the agent
    node.override['newrelic']['php_agent']['agent_action'] = 'upgrade'
    node.default['newrelic']['php_agent']['config_file'] = "#{node['php']['ext_conf_dir']}/newrelic.ini"
    include_recipe 'newrelic::php_agent'
  when 'pythonstack'
    include_recipe 'newrelic::python_agent'
    include_recipe 'python'
    include_recipe 'python::pip'
    python_pip 'setuptools' do
      action :upgrade
      version node['python']['setuptools_version']
    end
  when 'tomcatstack'
    include_recipe 'newrelic::java_agent'
  else
    Chef::Log.warn('No stack specific newrelic configuration')
  end

  # Meetme
  meetme_config = {}
  if node['recipes'].include?('memcached')
    meetme_config['memcached'] = {
      'name' => node['hostname'],
      'host' => 'localhost',
      'port' => 11_211
    }
  end

  if node['recipes'].include?('rabbitmq')
    # needs to be run before hand to set attributes (port specifically)
    include_recipe "#{stackname}::rabbitmq"
    meetme_config['rabbitmq'] = {
      name: node['hostname'],
      host: 'localhost',
      port: node['rabbitmq']['port'],
      username: 'monitor',
      password: node[stackname]['rabbitmq']['monitor_password'],
      api_path: '/api'
    }
  end

  if node['recipes'].include?('nginx')
    template 'nginx-monitor' do
      cookbook stackname
      source 'nginx/sites/monitor.erb'
      path "#{node['nginx']['dir']}/sites-available/monitor.conf"
      owner 'root'
      group 'root'
      mode '0644'
      notifies :reload, 'service[nginx]'
    end

    nginx_site 'monitor' do
      enable true
      notifies :reload, 'service[nginx]'
    end

    meetme_config['nginx'] = {
      'name' => node['hostname'],
      'host' => 'localhost',
      'port' => node['nginx']['status']['port'],
      'path' => '/server-status'
    }
    meetme_config['uwsgi'] = {
      'name' => node['hostname'],
      'host' => 'localhost',
      'port' => node['nginx']['sites'].values[0]['uwsgi_port']
    }
  end
  node.override['newrelic_meetme_plugin']['services'] = meetme_config
  node.default['newrelic_meetme_plugin']['package_name'] = 'newrelic-plugin-agent'

  include_recipe 'newrelic_meetme_plugin'
else
  Chef::Log.warn('The New Relic license attribute is not set!')
end
