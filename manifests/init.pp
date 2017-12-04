# == Class: nubis_storage
#
# Full description of class nubis_storage here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'nubis_storage':
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2015 Your name here, unless otherwise noted.
#

class nubis_storage {
}

define nubis::storage($type="ceph", $owner="root", $group="root", $mode="0755" ) {

  # Create the mountpoint
  file { ["/data", "/data/$name"]:
    ensure => directory,
    owner => $owner,
    group => $group,
    mode  => $mode,
  }

  case $type {
    'ceph': { 
      nubis::storage::ceph { "$name": }
    }
    'efs': {
      nubis::storage::efs { "$name":
        owner => $owner,
        group => $group,
        mode  => $mode,
      }
    }
    default: {
      fail("Unsupported storage type : '$type'")
    }
  }

}

define nubis::storage::efs($owner, $group, $mode) {
  notice("Using EFS")
  class {'nfs::client':
  }

  # make sure we run right after Consul is up, before confd and others
  file { "/etc/nubis.d/01-efs-${name}":
    ensure => present,
    group => 0,
    owner => 0,
    mode => '0755',
    content => template("${module_name}/efs-startup"),
  }

}

define nubis::storage::ceph {
  notice("Using Ceph")
  if $::osfamily == 'Debian' {
    package { [ "ceph-fs-common", "ceph-common" ]:
      ensure => latest,
    }
  }
  elsif $::osname == 'Amazon' {
    package { "ceph":
      ensure => latest,
    }
    # need to fix #! to use python26
    exec { "fix-ceph-shebang":
      command => "sed -i -e '1c#!/usr/bin/env python26' /usr/bin/ceph*",
      require => Package["ceph"],
    }
  }

  file { "/etc/ceph":
    ensure => directory,
  }

  file { "/etc/ceph/ceph.conf":
    require => File["/etc/ceph"],
    ensure => present,
    group => 0,
    owner => 0,
    mode => '0644',
    source => "puppet:///modules/${module_name}/ceph.conf",
  }

  if $::osfamily == 'Debian' {
    $mount_options = "defaults,nobootwait"
  }
  else {
    $mount_options = "defaults"
  }

  mount { "/data/$name":
    require => File["/data/$name"],
    ensure  => present,
    device  => "ceph-storage-%%NUBIS_STACK%%.ceph-mon.service.consul:/",
    fstype  => "ceph",
    options => $mount_options,
  }

  file { "/etc/nubis.d/ceph":
    ensure => present,
    group => 0,
    owner => 0,
    mode => '0755',
    source => "puppet:///modules/${module_name}/ceph-startup",
  }
}
