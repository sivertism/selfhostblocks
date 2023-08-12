{ config, pkgs, lib, ... }:

let
  cfg = config.shb.nextcloud;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.nextcloud = {
    enable = lib.mkEnableOption "selfhostblocks.nextcloud-server";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which home-assistant will be served.";
      example = "nextcloud";
    };

    domain = lib.mkOption {
      description = lib.mdDoc "Domain to serve sites under.";
      type = lib.types.str;
      example = "domain.com";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location";
      example = "secrets/nextcloud.yaml";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = {
      nextcloud = {
        name = "nextcloud";
        group = "nextcloud";
        isSystemUser = true;
      };
    };

    users.groups = {
      nextcloud = {
        members = [ "backup" ];
      };
    };

    # LDAP is manually configured through
    # https://github.com/lldap/lldap/blob/main/example_configs/nextcloud.md, see also
    # https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_ldap.html
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud26;

      # Enable php-fpm and nginx which will be behind the shb haproxy instance.
      hostName = fqdn;

      config = {
        dbtype = "pgsql";
        adminuser = "root";
        adminpassFile = "/run/secrets/nextcloud/adminpass";
        # Not using dbpassFile as we're using socket authentication.
        defaultPhoneRegion = "US";
        trustedProxies = [ "127.0.0.1" ];
      };
      database.createLocally = true;

      # Enable caching using redis https://nixos.wiki/wiki/Nextcloud#Caching.
      configureRedis = true;
      caching.apcu = false;
      # https://docs.nextcloud.com/server/26/admin_manual/configuration_server/caching_configuration.html
      caching.redis = true;

      # Adds appropriate nginx rewrite rules.
      webfinger = true;

      # Very important for a bunch of scripts to load correctly. Otherwise you get Content-Security-Policy errors. See https://docs.nextcloud.com/server/13/admin_manual/configuration_server/harden_server.html#enable-http-strict-transport-security
      https = true;

      extraOptions = {
        "overwrite.cli.url" = "https://" + fqdn;
        "overwritehost" = fqdn;
         # 'trusted_domains' needed otherwise we get this issue https://help.nextcloud.com/t/the-polling-url-does-not-start-with-https-despite-the-login-url-started-with-https/137576/2
        "trusted_domains" = [ fqdn ];
        "overwriteprotocol" = "https"; # Needed if behind a reverse_proxy
        "overwritecondaddr" = ""; # We need to set it to empty otherwise overwriteprotocol does not work.
      };

      phpOptions = {
        # The OPcache interned strings buffer is nearly full with 8, bump to 16.
        catch_workers_output = "yes";
        display_errors = "stderr";
        error_reporting = "E_ALL & ~E_DEPRECATED & ~E_STRICT";
        expose_php = "Off";
        "opcache.enable_cli" = "1";
        "opcache.fast_shutdown" = "1";
        "opcache.interned_strings_buffer" = "16";
        "opcache.max_accelerated_files" = "10000";
        "opcache.memory_consumption" = "128";
        "opcache.revalidate_freq" = "1";
        "openssl.cafile" = "/etc/ssl/certs/ca-certificates.crt";
        short_open_tag = "Off";

        # Needed to avoid corruption per https://docs.nextcloud.com/server/21/admin_manual/configuration_server/caching_configuration.html#id2
        "redis.session.locking_enabled" = "1";
        "redis.session.lock_retries" = "-1";
        "redis.session.lock_wait_time" = "10000";
      };
    };

    # Secret needed for services.nextcloud.config.adminpassFile.
    sops.secrets."nextcloud/adminpass" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "nextcloud";
      group = "nextcloud";
    };

    services.nginx.virtualHosts.${fqdn} = {
      # listen = [ { addr = "0.0.0.0"; port = 443; } ];
      sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
      sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
      forceSSL = true;
    };

    systemd.services.phpfpm-nextcloud.serviceConfig = {
      # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
      UMask = lib.mkForce "0027";
    };

    # Sets up backup for Nextcloud.
    shb.backup.instances.nextcloud = {
      sourceDirectories = [
        config.services.nextcloud.datadir
      ];
      excludePatterns = [".rnd"];
    };
  };
}
