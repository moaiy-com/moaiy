# Third-Party Notices

## App Icon Attribution

- Asset: Moai Statue
- Author: ProSymbols
- Source: [Noun Project](https://thenounproject.com/browse/icons/term/moai-statue/)
- License: CC BY 3.0
- Attribution text:
  `Moai Statue by ProSymbols from Noun Project (CC BY 3.0)`
- Original attribution (HTML):
  `Moai Statue by ProSymbols from <a href="https://thenounproject.com/browse/icons/term/moai-statue/" target="_blank" title="Moai Statue Icons">Noun Project</a> (CC BY 3.0)`

## Bundled GnuPG Runtime (`Moaiy/Resources/gpg.bundle`)

Moaiy bundles unmodified command-line executables and shared libraries from the GnuPG project inside `gpg.bundle` to provide zero-configuration OpenPGP key management and encryption on macOS (Apple Silicon `arm64`).

### Architectural & Licensing Boundary

Moaiy (`com.moaiy.app`) is an independent macOS graphical frontend written in Swift. Moaiy **does not** statically or dynamically link against GnuPG or any GPL/LGPL C libraries. All cryptographic operations are performed at arm's length by spawning the standalone `gpg`, `gpg-agent`, `gpgconf`, and `gpg-connect-agent` executables via standard POSIX pipes (`Foundation.Process`) and parsing status-fd/colon-delimited output.

### Included Components & Licenses

| Component | Binary / Library in `gpg.bundle` | Version | License | Upstream Project |
| :--- | :--- | :--- | :--- | :--- |
| **GnuPG** | `bin/gpg`, `bin/gpg-agent`, `bin/gpgconf`, `bin/gpg-connect-agent` | 2.5.21 | GPL-3.0-or-later | [gnupg.org](https://gnupg.org/) |
| **Libgcrypt** | `lib/libgcrypt.20.dylib` | 1.12.2 | LGPL-2.1-or-later | [gnupg.org/software/libgcrypt](https://gnupg.org/software/libgcrypt/) |
| **Libgpg-error** | `lib/libgpg-error.0.dylib` | 1.51+ | LGPL-2.1-or-later | [gnupg.org/software/libgpg-error](https://gnupg.org/software/libgpg-error/) |
| **Libassuan** | `lib/libassuan.9.dylib` | 3.0+ | LGPL-2.1-or-later | [gnupg.org/software/libassuan](https://gnupg.org/software/libassuan/) |
| **Libksba** | `lib/libksba.8.dylib` | 1.6+ | LGPL-3.0-or-later / GPL-2.0-or-later | [gnupg.org/software/libksba](https://gnupg.org/software/libksba/) |
| **nPth** | `lib/libnpth.0.dylib` | 1.8+ | LGPL-2.1-or-later | [gnupg.org/software/npth](https://gnupg.org/software/npth/) |
| **GNU Readline** | `lib/libreadline.8.dylib` | 8.3 | GPL-3.0-or-later | [tiswww.case.edu/php/chet/readline/rltop.html](https://tiswww.case.edu/php/chet/readline/rltop.html) |
| **GNU gettext (`libintl`)** | `lib/libintl.8.dylib` | 0.22+ | LGPL-2.1-or-later | [gnu.org/software/gettext](https://www.gnu.org/software/gettext/) |

### Source Code Availability

Complete corresponding source code for the bundled GnuPG executables and libraries is available from the official GnuPG FTP mirrors ([https://gnupg.org/download/](https://gnupg.org/download/)) and GNU FTP mirrors ([https://ftp.gnu.org/gnu/](https://ftp.gnu.org/gnu/)). Build and bundling scripts used to assemble `gpg.bundle` are included in this repository under `scripts/prepare_gpg_bundle.sh` and `scripts/verify_gpg_bundle.sh`.
