#!/usr/bin/env bash

# Publish the public half of the Maven Central signing key to the key
# servers that Central looks the key up on.
#
# Central does not verify a bundle against the key material that travels
# with it. It looks the public key up, by the fingerprint registered on the
# namespace, on one of the key servers it supports:
#
#   https://central.sonatype.com/docs/publish/publish-portal/maven/
#
# The private key lives in the repository secret, so its public half has to
# be published separately, and nothing does that on its own. Without it
# Central rejects the bundle with:
#
#   Could not find a public key by the key fingerprint. Please ensure it is
#   uploaded to one of the PGP servers we support.
#
# The key server that answers first is keyserver.ubuntu.com, which accepts
# an upload over plain HTTPS without credentials; keys.openpgp.org is
# attempted as well, since Central lists both.
#
# Usage: publish_central_gpg_key.sh <output-public-key.asc>
#
# Reads the key from MAVEN_CENTRAL_GPG_PRIVATE_KEY and its passphrase from
# MAVEN_CENTRAL_GPG_PASSPHRASE. Neither value is ever printed.

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $(basename "$0") <output-public-key.asc>" >&2
    exit 2
fi

output="$1"

: "${MAVEN_CENTRAL_GPG_PRIVATE_KEY:?MAVEN_CENTRAL_GPG_PRIVATE_KEY is not set}"
: "${MAVEN_CENTRAL_GPG_PASSPHRASE:?MAVEN_CENTRAL_GPG_PASSPHRASE is not set}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# An isolated keyring, so the run does not depend on - or disturb - the
# keyring of whoever runs it.
mkdir -m 700 "$work/gnupg"

printf '%s' "${MAVEN_CENTRAL_GPG_PRIVATE_KEY}" > "$work/signing-key.asc"
gpg --homedir "$work/gnupg" --batch --yes --pinentry-mode loopback \
    --passphrase "${MAVEN_CENTRAL_GPG_PASSPHRASE}" \
    --import "$work/signing-key.asc"
rm -f "$work/signing-key.asc"

fingerprint="$(gpg --homedir "$work/gnupg" --batch --with-colons --list-secret-keys |
    awk -F: '/^fpr:/ { print $10; exit }')"
if [ -z "${fingerprint}" ]; then
    echo "error: no secret key found after the import" >&2
    exit 1
fi
echo "Signing key fingerprint: ${fingerprint}"

# The state of the key decides whether Central accepts a signature made
# with it, so report it rather than only the fingerprint.
gpg --homedir "$work/gnupg" --batch --list-secret-keys "${fingerprint}"

gpg --homedir "$work/gnupg" --batch --yes --armor --export "${fingerprint}" > "$output"
exported="$(gpg --batch --with-colons --show-keys "$output" |
    awk -F: '/^fpr:/ { print $10; exit }')"
if [ "${exported}" != "${fingerprint}" ]; then
    echo "error: the exported key does not match the imported key" >&2
    exit 1
fi
echo "Exported ${exported} ($(wc -c < "$output" | tr -d ' ') bytes) to ${output}"

# gpg --send-keys is the canonical path: the HKP endpoint rejects an
# armored key that is posted to it as a request body, and the key server
# only serves the armored form it was given.
gpg --homedir "$work/gnupg" --batch --yes \
    --keyserver hkps://keyserver.ubuntu.com \
    --send-keys "${fingerprint}" || echo "::warning::gpg --send-keys failed"

# keys.openpgp.org hides unverified addresses, but Central only needs the
# key by fingerprint, so the upload is worth attempting.
gpg --homedir "$work/gnupg" --batch --yes \
    --keyserver hkps://keys.openpgp.org \
    --send-keys "${fingerprint}" || echo "::warning::keys.openpgp.org refused the key"

ok=1
for server in keyserver.ubuntu.com keys.openpgp.org; do
    served=""
    # A key server can answer "not found" for a key it was asked to serve a
    # moment ago, so the lookup is retried before it is called a failure.
    for attempt in 1 2 3; do
        if curl -sS --max-time 60 -o "$work/fetched-${server}.asc" \
            "https://${server}/pks/lookup?op=get&options=mr&search=0x${fingerprint}"; then
            served="$(gpg --batch --with-colons --show-keys "$work/fetched-${server}.asc" 2>/dev/null |
                awk -F: '/^fpr:/ { print $10; exit }')"
        fi
        if [ "${served}" = "${fingerprint}" ]; then
            break
        fi
        sleep 5
    done
    if [ "${served}" = "${fingerprint}" ]; then
        echo "${server}: serves ${served}"
    else
        echo "::warning::${server}: serves '${served:-nothing}', expected ${fingerprint}"
        ok=0
    fi
done

if [ "${ok}" != "1" ]; then
    echo "error: the signing key is not available on every key server" >&2
    exit 1
fi

echo "The signing key is published on every key server Central supports."
