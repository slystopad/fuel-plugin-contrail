#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

include contrail

Exec { path => '/bin:/sbin:/usr/bin:/usr/sbin', refresh => 'echo NOOP_ON_REFRESH', timeout => 1800}

if $contrail::node_name =~ /^contrail.\d+$/ {
  class { 'contrail::vip': } ->
  class { 'contrail::database': } ->
  notify{"Waiting for cassandra nodes: ${contrail::contrail_node_num}":} ->
    exec {'wait_for_cassandra':
      provider  => 'shell',
      command   => "if [ `nodetool status|grep ^UN|wc -l` -lt ${contrail::contrail_node_num} ]; then exit 1; fi",
      tries     => 10, # wait for whole cluster is up: 10 tries every 30 seconds = 5 min
      try_sleep => 30,
  }
}
