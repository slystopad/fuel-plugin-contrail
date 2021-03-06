#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

class contrail::controller {

# Resources defaults
  Package { ensure => present }

  File {
    ensure  => present,
    mode    => '0644',
    owner   => root,
    group   => root,
    require => Package['neutron-plugin-contrail'],
  }

  Exec { path => '/usr/bin:/usr/sbin:/bin:/sbin' }

# Packages
  package { 'neutron-server': } ->
  package { 'python-contrail': } ->
  package { 'neutron-plugin-contrail': } ->
  package { 'contrail-heat': }

# Configuration files for HAProxy
  file {'/etc/haproxy/conf.d/094-web_for_contrail.cfg':
    ensure  => present,
    content => template('contrail/094-web_for_contrail.cfg.erb'),
    notify  => Service['haproxy'],
  }
  file {'/etc/haproxy/conf.d/095-rabbit_for_contrail.cfg':
    ensure  => present,
    content => template('contrail/095-rabbit_for_contrail.cfg.erb'),
    notify  => Service['haproxy'],
  }

# Nova configuration
  nova_config {
    'DEFAULT/network_api_class': value=> 'nova.network.neutronv2.api.API';
    'DEFAULT/neutron_url': value => "http://${contrail::mos_mgmt_vip}:9696";
    'DEFAULT/neutron_url_timeout': value=> '300';
    'DEFAULT/neutron_admin_auth_url': value=> "http://${contrail::mos_mgmt_vip}:35357/v2.0";
    'DEFAULT/firewall_driver': value=> 'nova.virt.firewall.NoopFirewallDriver';
    'DEFAULT/enabled_apis': value=> 'ec2,osapi_compute,metadata';
    'DEFAULT/security_group_api': value=> 'neutron';
    'DEFAULT/service_neutron_metadata_proxy': value=> 'True';
  }

# Neutron configuration
  neutron_config {
    'DEFAULT/core_plugin': value => 'neutron_plugin_contrail.plugins.opencontrail.contrail_plugin.NeutronPluginContrailCoreV2';
    'DEFAULT/api_extensions_path': value => 'extensions:/usr/lib/python2.7/dist-packages/neutron_plugin_contrail/extensions';
    'DEFAULT/service_plugins': value => 'neutron_plugin_contrail.plugins.opencontrail.loadbalancer.plugin.LoadBalancerPlugin';
    'DEFAULT/allow_overlapping_ips': value => 'True';
    'service_providers/service_provider': value => 'LOADBALANCER:Opencontrail:neutron_plugin_contrail.plugins.opencontrail.loadbalancer.driver.OpencontrailLoadbalancerDriver:default';
    'QUOTAS/quota_network': value => '-1';
    'QUOTAS/quota_subnet': value => '-1';
    'QUOTAS/quota_port': value => '-1';
    } ->
  file {'/etc/neutron/plugins/opencontrail/ContrailPlugin.ini':
    content => template('contrail/ContrailPlugin.ini.erb'),
  } ->
  file {'/etc/neutron/plugin.ini':
    ensure => link,
    target  => '/etc/neutron/plugins/opencontrail/ContrailPlugin.ini'
  }

# Contrail-specific heat templates settings
  ini_setting { 'contrail-user':
  ensure  => present,
  path    => '/etc/heat/heat.conf',
  section => 'clients_contrail',
  setting => 'user',
  value   => 'neutron',
  } ->
  ini_setting { 'contrail-password':
      ensure  => present,
      path    => '/etc/heat/heat.conf',
      section => 'clients_contrail',
      setting => 'password',
      value   => $contrail::service_token,
  } ->
  ini_setting { 'contrail-tenant':
      ensure  => present,
      path    => '/etc/heat/heat.conf',
      section => 'clients_contrail',
      setting => 'tenant',
      value   => 'services',
  } ->
  ini_setting { 'contrail-api_server':
      ensure  => present,
      path    => '/etc/heat/heat.conf',
      section => 'clients_contrail',
      setting => 'api_server',
      value   => $contrail::contrail_mgmt_vip,
  } ->
  ini_setting { 'contrail-auth_host_ip':
      ensure  => present,
      path    => '/etc/heat/heat.conf',
      section => 'clients_contrail',
      setting => 'auth_host_ip',
      value   => $contrail::mos_mgmt_vip,
  } ->
  ini_setting { 'contrail-api_base_url':
      ensure  => present,
      path    => '/etc/heat/heat.conf',
      section => 'clients_contrail',
      setting => 'api_base_url',
      value   => '/',
  }

# Services
  service {'haproxy':
    ensure     => running,
    hasrestart => true,
    restart    => '/sbin/ip netns exec haproxy service haproxy reload',
    subscribe  => [File['/etc/haproxy/conf.d/094-web_for_contrail.cfg'],
                  File['/etc/haproxy/conf.d/095-rabbit_for_contrail.cfg'],
                  ]
  }
  service {'heat-engine':
    ensure    => running,
    enable    => true,
    require   => Package['contrail-heat'],
    subscribe => Ini_setting['contrail-api_base_url'],
  }
  service { 'neutron-server':
    ensure      => running,
    enable      => true,
    require     => [Package['neutron-server'],
                    Package['neutron-plugin-contrail'],
                    ],
    subscribe   => [File['/etc/neutron/plugins/opencontrail/ContrailPlugin.ini'],
                    File['/etc/neutron/plugin.ini'],
                    ],
  }

}