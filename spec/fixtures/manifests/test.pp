# A test manifest with various style issues.
class test {
  file { '/tmp/foo':
    ensure => present,
    mode   => 644,
    owner  => "root",
  }

  $MyVar = 'hello'

  package { 'httpd':
    ensure => installed,
  }

  notify { $osfamily: }
}
