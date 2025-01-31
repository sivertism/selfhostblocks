# Home Assistant Demo {#demo-homeassistant}

**This whole demo is highly insecure as all the private keys are available publicly. This is
only done for convenience as it is just a demo. Do not expose the VM to the internet.**

The [`flake.nix`](./flake.nix) file sets up Home Assistant server that uses a LDAP server to
setup users in only about [15 lines](./flake.nix#L29-L45) of related code.

This guide will show how to deploy this setup to a Virtual Machine, like showed
[here](https://nixos.wiki/wiki/NixOS_modules#Developing_modules), in 6 commands.

## Deploy to the VM {#deploy-to-the-vm}

Build the VM with:

```bash
nixos-rebuild build-vm-with-bootloader --fast -I nixos-config=./configuration.nix -I nixpkgs=.
```

Start the VM with (this call is blocking, so I advice adding a `&` at the end of the command otherwise
you will need to run the rest of the commands in another terminal):

```bash
QEMU_NET_OPTS="hostfwd=tcp::2222-:2222,hostfwd=tcp::8080-:80" ./result/bin/run-nixos-vm
```

With the VM started, print the VM's public age key with the following command.

```bash
nix shell nixpkgs#ssh-to-age --command sh -c 'ssh-keyscan -p 2222 -4 localhost | ssh-to-age'
```

The output will look like so. The value you need is the one staring with `age`.

```
# localshost:2222 SSH-2.0-OpenSSH_9.1
# localhost:2222 SSH-2.0-OpenSSH_9.1
# localhost:2222 SSH-2.0-OpenSSH_9.1
# localhost:2222 SSH-2.0-OpenSSH_9.1
# localhost:2222 SSH-2.0-OpenSSH_9.1
skipped key: got ssh-rsa key type, but only ed25519 keys are supported
age1l9dyy02qhlfcn5u9s4y2vhsvjtxj2c9avrpat6nvjd6rjar3tflq66jtz0
```

Now, make the `secrets.yaml` file decryptable in the VM. This change will appear in `git status` but
you don't need to commit this.

```bash
SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
  --config sops.yaml -r -i \
  --add-age age1l9dyy02qhlfcn5u9s4y2vhsvjtxj2c9avrpat6nvjd6rjar3tflq66jtz0 \
  secrets.yaml
```

If you forget this step, the deploy will seem to go fine but the secrets won't be populated and
neither LLDAP nor Home Assistant will start.

Make the ssh key private:

```bash
chmod 600 sshkey
```

This is only needed because git mangles with the permissions. You will not even see this change in
`git status`.

Finally, deploy with:

```bash
SSH_CONFIG_FILE=ssh_config nix run nixpkgs#colmena --impure -- apply
```

This step will require you to accept the host's fingerprint. The deploy will take a few minutes the
first time and subsequent deploys will take around 15 seconds.

## Access Home Assistant Through Your Browser {#access-home-assistant-through-your-browser}

Add the following entry to your `/etc/hosts` file:

```nix
networking.hosts = {
  "127.0.0.1" = [ "ha.example.com" "ldap.example.com" ];
};
```

Which produces:

```bash
$ cat /etc/hosts
127.0.0.1 ha.example.com ldap.example.com
```

    Go to [http://ldap.example.com:8080](http://ldap.example.com:8080) and login with:
- username: `admin`
- password: the value of the field `lldap.user_password` in the `secrets.yaml` file which is `fccb94f0f64bddfe299c81410096499a`.

Create the group `homeassistant_user` and a user assigned to that group.

Go to [http://ha.example.com:8080](http://ha.example.com:8080) and login with the
user and password you just created above.

## In More Details {#in-more-details}

### Files {#files}

- [`flake.nix`](./flake.nix): nix entry point, defines one target host for
  [colmena](https://colmena.cli.rs) to deploy to as well as the selfhostblock's config for
  setting up the home assistant server paired with the LDAP server.
- [`configuration.nix`](./configuration.nix): defines all configuration required for colmena
  to deploy to the VM. The file has comments if you're interested.
- [`hardware-configuration.nix`](./hardware-configuration.nix): defines VM specific layout.
  This was generated with nixos-generate-config on the VM.
- Secrets related files:
  - [`keys.txt`](./keys.txt): your private key for sops-nix, allows you to edit the `secrets.yaml`
    file. This file should never be published but here I did it for convenience, to be able to
    deploy to the VM in less steps.
  - [`secrets.yaml`](./secrets.yaml): encrypted file containing required secrets for Home Assistant
    and the LDAP server. This file can be publicly accessible.
  - [`sops.yaml`](./sops.yaml): describes how to create the `secrets.yaml` file. Can be publicly
    accessible.
- SSH related files:
  - [`sshkey(.pub)`](./sshkey): your private and public ssh keys. Again, the private key should usually not
    be published as it is here but this makes it possible to deploy to the VM in less steps.
  - [`ssh_config`](./ssh_config): the ssh config allowing you to ssh into the VM by just using the
    hostname `example`. Usually you would store this info in your `~/.ssh/config` file but it's
    provided here to avoid making you do that.

### Virtual Machine {#virtual-machine}

_More info about the VM._

We use `build-vm-with-bootloader` instead of just `build-vm` as that's the only way to deploy to the VM.

The VM's User and password are both `nixos`, as setup in the [`configuration.nix`](./configuration.nix) file under
`user.users.nixos.initialPassword`.

You can login with `ssh -F ssh_config example`. You just need to accept the fingerprint.

The VM's hard drive is a file name `nixos.qcow2` in this directory. It is created when you first create the VM and re-used since. You can just remove it when you're done.

That being said, the VM uses `tmpfs` to create the writable nix store so if you stumble in a disk
space issue, you must increase the
`virtualisation.vmVariantWithBootLoader.virtualisation.memorySize` setting.

### Secrets {#secrets}

_More info about the secrets._

The private key in the `keys.txt` file is created with:

```bash
$ nix shell nixpkgs#age --command age-keygen -o keys.txt
Public key: age1algdv9xwjre3tm7969eyremfw2ftx4h8qehmmjzksrv7f2qve9dqg8pug7
```

We use the printed public key in the `admin` field of the `sops.yaml` file.

The `secrets.yaml` file must follow the format:

```yaml
home-assistant: |
    name: "My Instance"
    country: "US"
    latitude_home: "0.100"
    longitude_home: "-0.100"
    time_zone: "America/Los_Angeles"
    unit_system: "metric"
lldap:
    user_password: XXX...
    jwt_secret: YYY...
```

> Important: the value of the `home-assistant` field is a string that looks like yaml. Do _not_
> remove the pipe (|) sign.

You can generate random secrets with:

```bash
$ nix run nixpkgs#openssl -- rand -hex 64
```

If you choose a password too small, ldap could refuse to start.

#### Why do we need the VM's public key {#public-key-necessity}

The [`sops.yaml`](./sops.yaml) file describes what private keys can decrypt and encrypt the
[`secrets.yaml`](./secrets.yaml) file containing the application secrets. Usually, you will create and add
secrets to that file and when deploying, it will be decrypted and the secrets will be copied
in the `/run/secrets` folder on the VM. We thus need one private key for you to edit the
[`secrets.yaml`](./secrets.yaml) file and one in the VM for it to decrypt the secrets.

Your private key is already pre-generated in this repo, it's the [`sshkey`](./sshkey) file. But when
creating the VM in the step above, a new private key and its accompanying public key were
automatically generated under `/etc/ssh/ssh_host_ed25519_key` in the VM. We just need to get the
public key and add it to the `secrets.yaml` which we did in the Deploy section.

To open the `secrets.yaml` file and optionnally edit it, run:

```bash
SOPS_AGE_KEY_FILE=keys.txt nix run --impure nixpkgs#sops -- \
  --config sops.yaml \
  secrets.yaml
```

### SSH {#ssh}

The private and public ssh keys were created with:

```bash
ssh-keygen -t ed25519 -f sshkey
```

You don't need to copy over the ssh public key over to the VM as we set the `keyFiles` option which copies the public key when the VM gets created.
This allows us also to disable ssh password authentication.

For reference, if instead you didn't copy the key over on VM creating and enabled ssh
authentication, here is what you would need to do to copy over the key:

```bash
$ nix shell nixpkgs#openssh --command ssh-copy-id -i sshkey -F ssh_config example
```

### Deploy {#deploy}

If you get a NAR hash mismatch error like hereunder, you need to run `nix flake lock --update-input
selfhostblocks`.

```
error: NAR hash mismatch in input ...
```
