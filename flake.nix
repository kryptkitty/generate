{
  description = "generate many password hashes for unixy systems";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
          config.allowUnfree = true;
        };
        crypts = {
          bcrypt = { name = "bcrypt"; rounds = 12; module = "bcrypt"; };
          sha512 = { name = "sha512"; rounds = 2560000; module = "sha512_crypt"; };
          sha256 = { name = "sha256"; rounds = 2560000; module = "sha256_crypt"; };
        };

        pyLibs = with pkgs.python310Packages; [ bcrypt passlib ];
        genHashScript = {module, rounds, name}: pkgs.stdenv.mkDerivation {
          script = (pkgs.writers.writePython3 "crypt_${name}"
            {libraries = pyLibs;}
            ''
              import sys
              from passlib.hash import ${module} as h
            
              print(h.hash(
                  sys.argv[1],
                  ${if (rounds > 0) then "rounds=${toString rounds}," else ""}
              ))
            '');
          name = "crypt_${name}";
          buildCommand = ''
            mkdir -p $out/bin
            cat $script > $out/bin/crypt_${name}
            chmod +x $out/bin/crypt_${name}
          '';
        };
      in {
        packages = rec {
          crypt_sha512 = genHashScript crypts.sha512;
          crypt_sha256 = genHashScript crypts.sha256;
          crypt_bcrypt = genHashScript crypts.bcrypt;
          generate_random_password = pkgs.stdenv.mkDerivation {
            name = "generate_random_password";
            script = (pkgs.writers.writePython3 "generate_random_password" {} ''
              import sys
              import random

              chars = int(sys.argv[1])
              sets = sys.argv[2:]
              # we will shuffle these initially to ensure we get even coverage of sets
              # in the case where we have more sets than chars.
              pw = list(map(random.choice, sets))
              random.shuffle(pw)
              pw += random.choices("".join(sets), k=chars)
              # now shuffle again to ensure the guaranteed sets are shuffled in rather
              # than at the front.  we will be taking only the first _chars_ chars.
              pw = pw[:chars]
              random.shuffle(pw)
              print("".join(pw))
            '');
            buildCommand = ''
              mkdir -p $out/bin
              cat $script > $out/bin/generate_random_password
              chmod +x $out/bin/generate_random_password
            '';
          };
          create_op_secret = pkgs.stdenv.mkDerivation {
            name = "create_op_secret";
            script = (pkgs.writers.writeBash "create_op_secret" ''
              ${pkgs._1password}/bin/op item create --category login "$@"
            '');
            buildCommand = ''
              mkdir -p $out/bin
              cat $script > $out/bin/create_op_secret
              chmod +x $out/bin/create_op_secret
            '';
          };
          op = pkgs.stdenv.mkDerivation {
            name = "op";
            script = (pkgs.writers.writeBash "op" 
              ''
	        eval "$( ${generate_random_ssh_key}/bin/generate_random_ssh_key )"
                PASSWORD="$( ${generate_random_password}/bin/generate_random_password 64 abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 ,.-_ )"
                ${create_op_secret}/bin/create_op_secret "$@" \
                    "sha256[text]=$(${crypt_sha256}/bin/crypt_sha256 "$PASSWORD")" \
                    "sha512[text]=$(${crypt_sha512}/bin/crypt_sha512 "$PASSWORD")" \
                    "bcrypt[text]=$(${crypt_bcrypt}/bin/crypt_bcrypt "$PASSWORD")" \
		    "ssh_public_key[text]=$SSH_PUBLIC_KEY" \
		    "ssh_private_key=$SSH_PRIVATE_KEY" \
		    "ssh_key_password=$SSH_KEY_PASSWORD" \
                    password="$PASSWORD" | grep -vE '^ *password:'
              '');
            buildCommand = ''
              mkdir -p $out/bin
              cat $script > $out/bin/op
              chmod +x $out/bin/op
            '';
          };
          op-cli = pkgs._1password;
          generate_random_ssh_key = pkgs.stdenv.mkDerivation {
            name = "generate_random_ssh_key";
            script = (pkgs.writers.writeBash "generate_random_ssh_key"
              ''
                set -e
                D="$(mktemp -d)"
                cd "$D"
                PASSWORD="$( ${generate_random_password}/bin/generate_random_password 64 abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 ,.-_ )"
		[ x"$SSH_KEY_COMMENT" = x ] && SSH_KEY_COMMENT="generated by kryptkitty"
		# 146 rounds is what it took for my macbook to take a second for the KDF.
		[ x"$SSH_KEY_KDF_ROUNDS" = x ] && SSH_KEY_KDF_ROUNDS=146
                ssh-keygen -a "$SSH_KEY_KDF_ROUNDS" -q -C "$SSH_KEY_COMMENT" -t ed25519 -f k -N "$PASSWORD" 1>&2
                # we want to use the coreutils printf to get more posixy strings
                ${pkgs.coreutils}/bin/printf '%q=%q\n' SSH_KEY_PASSWORD "$PASSWORD" SSH_PRIVATE_KEY "$(cat k)" SSH_PUBLIC_KEY "$(cat k.pub)"
                ${pkgs.coreutils}/bin/shred k
                rm -f k k.pub
                cd /
                rmdir "$D"
              '');
            buildCommand = ''
              mkdir -p $out/bin
              cat $script > $out/bin/generate_random_ssh_key
              chmod +x $out/bin/generate_random_ssh_key
            '';
          };
          stdout = pkgs.stdenv.mkDerivation {
            name = "stdout";
            script = (pkgs.writers.writeBash "stdout"
              ''
	        eval "$( ${generate_random_ssh_key}/bin/generate_random_ssh_key )"
                PASSWORD="$( ${generate_random_password}/bin/generate_random_password 64 abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 ,.-_ )"
                echo "password: $PASSWORD"
                echo
                echo "crypts:"
                printf '  %s %s\n' sha256 "$(${crypt_sha256}/bin/crypt_sha256 "$PASSWORD")"
                printf '  %s %s\n' sha512 "$(${crypt_sha512}/bin/crypt_sha512 "$PASSWORD")"
                printf '  %s %s\n' bcrypt "$(${crypt_bcrypt}/bin/crypt_bcrypt "$PASSWORD")" 
		echo
		echo "ssh key"
		echo "password: $SSH_KEY_PASSWORD"
		echo "public key: $SSH_PUBLIC_KEY"
		echo "private key:"
		echo "$SSH_PRIVATE_KEY"
              '');
            buildCommand = ''
              mkdir -p $out/bin
              cat $script > $out/bin/stdout
              chmod +x $out/bin/stdout
            '';
          };
          default = stdout;
        };
      }
    );
}
