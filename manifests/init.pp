#
class chocolatey_builder (
  $watch_folder,
  $output_dir,
  $watch_interval        = 10, # In seconds
  $service_name          = 'chocolatey_builder',
  $install_dir           = "C:\\ProgramData\\${service_name}",
  $log_location          = $install_dir,
  $service_ensure        = 'running',
  $service_enable        = true,
  $service_user          = undef,
  $service_password      = undef,
  $install_nssm          = true,
  $nssm_version          = 'installed',
  $nssm_source           = undef,
  $chocolatey_installdir = 'C:\\ProgramData\\chocolatey',
){
  if $install_nssm {
    # NSSM will need to have a Chocolatey package built for it before it can be
    # installed.
    # NSSM is a Non-Sucking Service Manager, basically you tell it what command
    # to run and it registers that as a service and handles logging etc.
    package { 'nssm':
      ensure => $nssm_version,
      source => $nssm_source,
      before => Exec['create_service'],
    }
  }

  # These templates are how chocolatey builds the packages, you pass in some
  # parameters and chocolatey dumps them into the metadata xml file and an
  # install and uninstall script
  file { 'chocolatey_template':
    ensure  => directory,
    path    => "${chocolatey_installdir}\\templates\\iis_site",
    source  => 'puppet:///modules/chocolatey_builder/iis_site',
    recurse => true,
  }

  file { 'chocolatey_template_dir':
    ensure => directory,
    path   => "${chocolatey_installdir}\\templates"
  }

  file { 'chocolatey_builder_installdir':
    ensure => directory,
    path   => $install_dir,
  }

  # This script was written by Dylan Ratcliffe dylan.ratcliffe@puppet.com
  # Basically it gets passed a folder to watch and it will call
  # Build-Package.ps1 each time it sees a change. We also pass it the output
  # directory but that hust gets passed through to Build-Package.ps1
  file { 'watcher_script':
    ensure => file,
    path   => "${install_dir}\\Watch-Folder.ps1",
    source => 'puppet:///modules/chocolatey_builder/Watch-Folder.ps1',
    notify => Service['watcher_service'],
  }

  # This is the script that actually does the builds, it gets passed a directory
  # to build and an outout location and turns that directory into a Chocolatey
  # package at the output location. This script logs to a file called:
  # "Build Results.txt" in the input directory.
  file { 'builder_script':
    ensure => file,
    path   => "${install_dir}\\Build-Package.ps1",
    source => 'puppet:///modules/chocolatey_builder/Build-Package.ps1',
    notify => Service['watcher_service'],
  }

  # Here we are using nssm to actually create a service. We just tell it which
  # command to run and what to name the service and NSSM creates it for us
  exec { 'create_service':
    command => "nssm install ${service_name} powershell.exe -Command ${install_dir}\\Watch-Folder.ps1 -Path ${watch_folder} -OutputDir ${output_dir} -WatchIntervalSeconds ${watch_interval}",
    path    => $::path,
    unless  => "nssm status ${service_name}",
  }

  # This sets the logging location for the watcher script
  exec { 'set_log_location_stdout':
    command     => "nssm set ${service_name} AppStdout ${log_location}",
    path        => $::path,
    refreshonly => true,
    subscribe   => Exec['create_service'],
    notify      => Service['watcher_service'],
    require     => Package['nssm'],
  }

  exec { 'set_run_directory':
    command     => "nssm set ${service_name} AppDirectory ${install_dir}",
    path        => $::path,
    refreshonly => true,
    subscribe   => Exec['create_service'],
    notify      => Service['watcher_service'],
    require     => Package['nssm'],
  }

  # This sets the logging location for the watcher script
  exec { 'set_log_location_stderr':
    command     => "nssm set ${service_name} AppStderr ${log_location}",
    path        => $::path,
    refreshonly => true,
    subscribe   => Exec['create_service'],
    notify      => Service['watcher_service'],
    require     => Package['nssm'],
  }

  # TODO: Service needs to load from the correct directory
  if $service_user {
    exec { 'set_user':
      command     => "sc.exe config \'${service_name}\' type= own obj= \"${service_user}\" password= \"${service_password}\"",
      path        => $::path,
      refreshonly => true,
      subscribe   => Exec['create_service'],
      notify      => Service['watcher_service'],
      require     => Package['nssm'],
    }
  }

  # Finally, once the service has been registered we can actually start it.
  # When this is started it means that the folders are actually being watched.
  service { 'watcher_service':
    ensure  => $service_ensure,
    name    => $service_name,
    enable  => $service_enable,
    require => Exec['create_service'],
  }
}
