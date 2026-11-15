# Sources

Unmodified binaries from Ubuntu 24.04 (noble), amd64, for Claude Code's Bash sandbox. `socat` beside them is a wrapper: it puts `lib/` on the library path and forces IPv4.

| File | SHA-256 | From | License |
|---|---|---|---|
| `bwrap` | `3e33f8255e1411ada346db27028c25ef5ba4fa3327754a2321ea4c8732a3bc10` | bubblewrap 0.9.0-1build1, `usr/bin/bwrap` | LGPL-2.0-or-later |
| `socat.bin` | `71f338e047078773e7e054e1d652cdb9b304e94f7b8c7b11f49d78db1568cd13` | socat 1.8.0.0-4build3, `usr/bin/socat` | GPL-2.0 |
| `lib/libwrap.so.0` | `bf170759385436eaa60892f5422fb16412f7b449b2875a42b6c6a7ad5239791a` | libwrap0 7.6.q-33, `usr/lib/x86_64-linux-gnu/libwrap.so.0` | BSD-style (tcp-wrappers) |
| `socat` | `bd9478e04ec916eff5631c57d1fd0ef329424258265338a9579ae348fdfb1a0e` | this repository | MIT |

| Package | SHA-256 |
|---|---|
| http://archive.ubuntu.com/ubuntu/pool/main/b/bubblewrap/bubblewrap_0.9.0-1build1_amd64.deb | `dde30d1f24da50446d647ed504ec8dc5a714f171974d054c70a589b48ba38b48` |
| http://archive.ubuntu.com/ubuntu/pool/main/s/socat/socat_1.8.0.0-4build3_amd64.deb | `60d2dd3f66ffe387c96dc33369404724a18f0d47d2fa38353112a55efaec180d` |
| http://archive.ubuntu.com/ubuntu/pool/main/t/tcp-wrappers/libwrap0_7.6.q-33_amd64.deb | `36118b862539868408ee056411d6e470068d14c46e5296b29bfb744770f5d2ce` |

Each package's source is in the same pool. `tests/test-pinned-binaries.sh` checks that every file in this folder is listed with its hash; in CI, `tests/verify-sources.sh` downloads each package, checks its hash, and checks that each file above is the one inside it.
