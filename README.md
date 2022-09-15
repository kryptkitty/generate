# `generate`
a nix flake for generating passwords and their crypts

## Overview

This nix flake may be used to generate passwords, generate crypts, generate both, and/or send them to 1password and possibly other places in the future.

Currently, there is no way to configure the password generated.
It will always contain 64 chars from the sets `a-z` `A-Z` `0-9` `-_,.` with at least one from each.

### Examples

#### `stdout`

Use this package to generate a password and output it to stdout.

```bash
nix run github:kryptkitty/generate#
# these are the same.  stdout is the default
nix run github:kryptkitty/generate#stdout
```

```
password: rvAJOa1zA2G490bbkqIKmjImPCKn1zSjjtaTbnLMZ_GvJ2Q8g5P,B8EGRxx8s5Oi

crypts:
  sha256 $5$rounds=2560000$9wF4mQSErSLhef2t$WKjvPeDX/ehqAEKbmDVJS7N4uPAPuRtfMcgqWBMP.UD
  sha512 $6$rounds=2560000$35Y/bXetZHOg3BVC$/e2q/NhkjfPUnI5mxHxD8IVXZUy9T8UfefVnk7szv9QIo1xXbC3g7FFHiSW31NUY/3l/YntqXW.kqyoeJn9ov/
  bcrypt $2b$12$BgxFx4yYHlV7r/br/Fsz2u8d8oJQlkckyHiOGDsTbvsuFBYUEqnfy
```

#### `op`

Use this package to generate a password and output it to 1password.

Any passed commands are fed to `op item create` verbatim.


```bash
nix run github:kryptkitty/generate#op -- --vault=infrastructure username=radguy
```

```
ID:          zynyoqme334he62o3xhn5hfgsa
Title:       Untitled Login
Vault:       infrastructure (zizmm614naw4ahoorbc2arowqa)
Created:     now
Updated:     now
Favorite:    false
Version:     0
Category:    LOGIN
Fields:
  username:    radguy
  sha256:      $5$rounds=2560000$yFwWj9EcHxI26d4F$1GSiJvHEsk8USIhPIws105JVGAfydfdo0ALzIOpgeX3
  sha512:      $6$rounds=2560000$pXkqp3w9QqA4nFY1$TPF7NiHlGrFWdB6.FQoXlCGpv6wp7UZbTi2r39WjsDqMrKMTp8sBw3YrCYRiW3D7wm9XKN.SGIMjY3c0kl5tk1
  bcrypt:      $2b$12$FNGlnidQ0PoFluHeQyb0Le0xUM9JHJgnwhXKbXOvD8VDoA3r5gLx6
```

##### `op-cli`

This package invokes the 1password cli directly.  You might use it to sign in to op cli to use the `op` package above.

```bash
eval $(nix run github:kryptkitty/generate#op-cli signin)
Enter the password for radguy@cool.net at my.1password.com:
```


