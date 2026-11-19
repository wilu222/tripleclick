# Releasing

macOS ties the Accessibility permission to the app's signature. To keep the permission across
updates, sign releases with the same certificate every time. `make app` signs with a certificate
named `TripleClick Self-Signed`, and falls back to an ad-hoc signature without it.

## Create the certificate (once)

Either use Keychain Access → Certificate Assistant → Create a Certificate (name
`TripleClick Self-Signed`, type Code Signing), or run this in a temporary folder:

```sh
cat > cert.cnf <<'EOF'
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext
[dn]
CN = TripleClick Self-Signed
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config cert.cnf -keyout key.pem -out cert.pem
PW=$(/usr/bin/openssl rand -hex 16)
/usr/bin/openssl pkcs12 -export -inkey key.pem -in cert.pem -name "TripleClick Self-Signed" -out cert.p12 -passout pass:$PW
security import cert.p12 -k ~/Library/Keychains/login.keychain-db -P "$PW" -T /usr/bin/codesign
rm key.pem cert.p12
security find-identity -p codesigning | grep TripleClick   # "NOT_TRUSTED" is expected and fine
```

`-T /usr/bin/codesign` lets `codesign` use the key without a keychain prompt.

## Back up the private key

Keep it out of the repo. In Keychain Access, export `TripleClick Self-Signed` as a
password-protected `.p12` and store it somewhere private. If it's lost, the next release gets a
new identity and users have to grant Accessibility again.

## Publish a release

Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`, then:

```sh
make zip && gh release create v0.1.0 build/TripleClick.zip
```
