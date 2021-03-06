# == class: keystone::federation::oidc
#
# == Parameters
#
# [*methods*]
#  A list of methods used for authentication separated by comma or an array.
#  The allowed values are: 'external', 'password', 'token', 'oauth1', 'saml2'
#  (Required) (string or array value).
#  Note: The external value should be dropped to avoid problems.
#
# [*idp_name*]
#  The name name associated with the IdP in Keystone.
#  (Required) String value.
#
# [*protocol_name*]
#  The name for your protocol associated with the IdP.
#  (Required) String value.
#
# [*trusted_dashboard*]
#  Specify URLs of trusted horizon servers. This setting ensures that keystone
#  only sends token data back to trusted servers.
#  (Required) String value.
#
# [*remote_id_attribute*]
#  A remote id attribute indicates the header to retrieve from the WSGI
#  environment. This header contains information about the identity of the
#  identity provider, see
#  http://docs.openstack.org/developer/keystone/federation/websso.html
#  (Required) String value.
#
# [*admin_port*]
#  A boolean value to ensure that you want to configure K2K Federation
#  using Keystone VirtualHost on port 35357.
#  (Optional) Defaults to false.
#
# [*main_port*]
#  A boolean value to ensure that you want to configure K2K Federation
#  using Keystone VirtualHost on port 5000.
#  (Optional) Defaults to true.
#
# [*module_plugin*]
#  The plugin for authentication acording to the choice made with protocol and
#  module.
#  (Optional) Defaults to 'keystone.auth.plugins.mapped.Mapped' (string value)
#
# [*template_order*]
#  This number indicates the order for the concat::fragment that will apply
#  the shibboleth configuration to Keystone VirtualHost. The value should
#  The value should be greater than 330 an less then 999, according to:
#  https://github.com/puppetlabs/puppetlabs-apache/blob/master/manifests/vhost.pp
#  The value 330 corresponds to the order for concat::fragment  "${name}-filters"
#  and "${name}-limits".
#  The value 999 corresponds to the order for concat::fragment "${name}-file_footer".
#  (Optional) Defaults to 331.
#
class keystone::federation::oidc (
  $idp_name,
  $client_id,
  $client_secret,
  $crypto_passphrase,
  $provider_metadata_url,
  $admin_port             = false,
  $main_port              = true,
  $module_plugin          = 'keystone.auth.plugins.mapped.Mapped',
  $methods                = [ "password", "token", "oidc" ],
  $redirect_uri           = "http://${::fqdn}:5000/v3/auth/OS-FEDERATION/websso/oidc/redirect",
  $response_type          = "id_token",
  $scope                  = [ "openid", "email", "profile" ],
  $claim_prefix           = "OIDC-",
  $remote_id_attribute    = "HTTP_OIDC_ISS",
  $template_order         = 331,
  $trusted_dashboard      = "https://${::fqdn}/dashboard/auth/websso/",
) {

  include ::apache
  include ::keystone::params

  # Enable mod_auth_openidc
  ::apache::mod { 'auth_openidc': }
  ensure_packages([$::keystone::params::oidc_package_name], {
    ensure => present
  })

  # Note: if puppetlabs-apache modify these values, this needs to be updated
  if $template_order <= 330 or $template_order >= 999 {
    fail('The template order should be greater than 330 and less than 999.')
  }

  if ('external' in $methods ) {
    fail('The external method should be dropped to avoid any interference with some Apache SP setups, where a REMOTE_USER env variable is always set, even as an empty value.')
  }

  if !('oidc' in $methods ) {
    fail('Methods should contain oidc as one of the auth methods.')
  }else{
    if ($module_plugin != 'keystone.auth.plugins.mapped.Mapped') {
      fail('The plugin for oidc should be keystone.auth.plugins.mapped.Mapped')
    }
  }

  validate_bool($admin_port)
  validate_bool($main_port)

  if( !$admin_port and !$main_port){
    fail('No VirtualHost port to configure, please choose at least one.')
  }

  keystone_config {
    'auth/methods': value => join(any2array($methods),',');
    'auth/oidc':    value => $module_plugin;
  }

  keystone_config {
    'oidc/remote_id_attribute': value => $remote_id_attribute
  }

  keystone_config {
    'federation/trusted_dashboard': value => $trusted_dashboard
  }

  if $admin_port {
    concat::fragment { 'configure_oidc_on_port_35357':
      target  => "${keystone::wsgi::apache::priority}-keystone_wsgi_admin.conf",
      content => template('keystone/oidc.conf.erb'),
      order   => $template_order,
    }
  }

  if $main_port {
    concat::fragment { 'configure_oidc_on_port_5000':
      target  => "${keystone::wsgi::apache::priority}-keystone_wsgi_main.conf",
      content => template('keystone/oidc.conf.erb'),
      order   => $template_order,
    }
  }

}
