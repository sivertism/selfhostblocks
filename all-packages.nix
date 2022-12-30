{ distribution ? null
, services ? null
, system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system; }
, utils ? null
}:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = rec {
    PostgresDB = callPackage ./postgresdb {};
    mkPostgresDB = callPackage ./postgresdb/mkdefault.nix {inherit PostgresDB;};

    HaproxyConfig = callPackage ./haproxy/config.nix {inherit utils;};
    mkHaproxyConfig = callPackage ./haproxy/mkconfig.nix {inherit HaproxyConfig;};
    HaproxyService = callPackage ./haproxy/unit.nix {inherit utils;};
    mkHaproxyService = callPackage ./haproxy/mkunit.nix {inherit HaproxyService;};

    CaddyConfig = callPackage ./caddy/config.nix {inherit utils;};
    CaddyService = callPackage ./caddy/unit.nix {inherit utils;};
    CaddySiteConfig = callPackage ./caddy/siteconfig.nix {inherit utils;};
    mkCaddySiteConfig = callPackage ./caddy/mksiteconfig.nix {inherit CaddySiteConfig;};

    NginxService = callPackage ./nginx/unit.nix {inherit utils;};
    mkNginxService = callPackage ./nginx/mkunit.nix {inherit NginxService;};
    NginxSiteConfig = callPackage ./nginx/siteconfig.nix {inherit utils;};
    mkNginxSiteConfig = callPackage ./nginx/mksiteconfig.nix {inherit NginxSiteConfig;};

    PHPConfig = callPackage ./php/config.nix {inherit utils;};
    mkPHPSiteConfig = callPackage ./php/siteconfig.nix {inherit PHPConfig;};

    PHPFPMConfig = callPackage ./php-fpm/config.nix {inherit utils;};
    mkPHPFPMConfig = callPackage ./php-fpm/mkconfig.nix {inherit PHPFPMConfig;};
    PHPFPMService = callPackage ./php-fpm/unit.nix {inherit utils;};
    mkPHPFPMService = callPackage ./php-fpm/mkunit.nix {inherit PHPFPMService;};
    PHPFPMSiteConfig = callPackage ./php-fpm/siteconfig.nix {inherit utils;};
    mkPHPFPMSiteConfig = callPackage ./php-fpm/mksiteconfig.nix {inherit PHPFPMSiteConfig;};

    KeycloakConfig = callPackage ./keycloak/config.nix {inherit utils;};
    mkKeycloakConfig = callPackage ./keycloak/mkconfig.nix {inherit KeycloakConfig;};
    KeycloakService = callPackage ./keycloak/unit.nix {inherit utils;};
    mkKeycloakService = callPackage ./keycloak/mkunit.nix {inherit KeycloakService;};

    mkKeycloakHaproxyService = callPackage ./keycloak-haproxy/unit.nix {inherit utils;};

    KeycloakCliConfig = callPackage ./keycloak-cli-config/config.nix {inherit utils;};
    mkKeycloakCliConfig = callPackage ./keycloak-cli-config/mkconfig.nix {inherit KeycloakCliConfig;};
    KeycloakCliService = callPackage ./keycloak-cli-config/unit.nix {inherit utils;};
    mkKeycloakCliService = callPackage ./keycloak-cli-config/mkunit.nix {inherit KeycloakCliService;};

    TtrssEnvironment = callPackage ./ttrss/environment.nix {};
    TtrssConfig = callPackage ./ttrss/config.nix {};
    mkTtrssConfig = callPackage ./ttrss/mkconfig.nix {inherit TtrssConfig;};
    TtrssUpdateService = callPackage ./ttrss/update.nix {inherit utils;};
    mkTtrssUpdateService = callPackage ./ttrss/mkupdate.nix {inherit TtrssUpdateService;};
    TtrssUpgradeDBService = callPackage ./ttrss/dbupgrade.nix {};
    mkTtrssUpgradeDBService = callPackage ./ttrss/mkdbupgrade.nix {inherit TtrssUpgradeDBService;};
    TtrssPHPNormalizeHeaders = callPackage ./ttrss/normalize-headers.nix {inherit utils;};
    mkTtrssPHPNormalizeHeaders = callPackage ./ttrss/mk-normalize-headers.nix {inherit TtrssPHPNormalizeHeaders;};

    mkVaultwardenWeb = callPackage ./vaultwarden/web.nix {inherit utils;};
    mkVaultwardenService = callPackage ./vaultwarden/unit.nix {inherit utils;};
    vaultwarden = callPackage ./vaultwarden {inherit utils;};
  };
in
self
