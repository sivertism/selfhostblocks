{ config, pkgs, lib, ... }:

let
  cfg = config.shb.ldap;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.ldap = {
    enable = lib.mkEnableOption "the LDAP service";

    dcdomain = lib.mkOption {
      type = lib.types.str;
      description = "dc domain to serve.";
      example = "dc=mydomain,dc=com";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which the LDAP service will be served.";
      example = "grafana";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain under which the LDAP service will be served.";
      example = "mydomain.com";
    };

    ldapPort = lib.mkOption {
      type = lib.types.port;
      description = "Port on which the server listens for the LDAP protocol.";
      default = 3890;
    };

    webUIListenPort = lib.mkOption {
      type = lib.types.port;
      description = "Port on which the web UI is exposed.";
      default = 17170;
    };

    ldapUserPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the LDAP admin user password.";
    };

    jwtSecretFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the JWT secret.";
    };

    restrictAccessIPRange = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Set a local network range to restrict access to the UI to only those IPs.";
      example = "192.168.1.1/24";
      default = null;
    };

    debug = lib.mkOption {
      description = "Enable debug logging.";
      type = lib.types.bool;
      default = false;
    };
  };

  
  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;

      virtualHosts.${fqdn} = {
        forceSSL = lib.mkIf config.shb.ssl.enable true;
        sslCertificate = lib.mkIf config.shb.ssl.enable "/var/lib/acme/${cfg.domain}/cert.pem";
        sslCertificateKey = lib.mkIf config.shb.ssl.enable "/var/lib/acme/${cfg.domain}/key.pem";
        locations."/" = {
          extraConfig = ''
            proxy_set_header Host $host;
          '' + (if isNull cfg.restrictAccessIPRange then "" else ''
            allow ${cfg.restrictAccessIPRange};
            deny all;
          '');
          proxyPass = "http://${toString config.services.lldap.settings.http_host}:${toString config.services.lldap.settings.http_port}/";
        };
      };
    };

    users.users.lldap = {
      name = "lldap";
      group = "lldap";
      isSystemUser = true;
    };

    users.groups.lldap = {
      members = [ "backup" ];
    };

    services.lldap = {
      enable = true;

      environment = {
        LLDAP_JWT_SECRET_FILE = toString cfg.jwtSecretFile;
        LLDAP_LDAP_USER_PASS_FILE = toString cfg.ldapUserPasswordFile;

        RUST_LOG = lib.mkIf cfg.debug "debug";
      };

      settings = {
        http_url = "https://${fqdn}";
        http_host = "127.0.0.1";
        http_port = cfg.webUIListenPort;

        ldap_host = "127.0.0.1";
        ldap_port = cfg.ldapPort;

        ldap_base_dn = cfg.dcdomain;

        verbose = cfg.debug;
      };
    };

    shb.backup.instances.lldap = {
      sourceDirectories = [
        "/var/lib/lldap"
      ];
    };
  };
}
