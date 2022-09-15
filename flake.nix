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
                PASSWORD="$( ${generate_random_password}/bin/generate_random_password 64 abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 ,.-_ )"
                ${create_op_secret}/bin/create_op_secret "$@" \
                    "sha256=$(${crypt_sha256}/bin/crypt_sha256 "$PASSWORD")" \
                    "sha512=$(${crypt_sha512}/bin/crypt_sha512 "$PASSWORD")" \
                    "bcrypt=$(${crypt_bcrypt}/bin/crypt_bcrypt "$PASSWORD")" \
                    password="$PASSWORD" | grep -vE '^ *password:'
              '');
            buildCommand = ''
              mkdir -p $out/bin
              cat $script > $out/bin/op
              chmod +x $out/bin/op
            '';
          };
	  op-cli = pkgs._1password;
	  stdout = pkgs.stdenv.mkDerivation {
	    name = "stdout";
	    script = (pkgs.writers.writeBash "stdout"
	      ''
                PASSWORD="$( ${generate_random_password}/bin/generate_random_password 64 abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 ,.-_ )"
		echo "password: $PASSWORD"
		echo
		echo "crypts:"
		printf '  %s %s\n' sha256 "$(${crypt_sha256}/bin/crypt_sha256 "$PASSWORD")"
		printf '  %s %s\n' sha512 "$(${crypt_sha512}/bin/crypt_sha512 "$PASSWORD")"
		printf '  %s %s\n' bcrypt "$(${crypt_bcrypt}/bin/crypt_bcrypt "$PASSWORD")" 
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
