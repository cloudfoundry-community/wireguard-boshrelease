# wireguard-boshrelease

BOSH release for [WireGuard](https://www.wireguard.com/) VPN endpoints.

Kernel WireGuard only — requires ubuntu-noble stemcells (the wireguard
module ships in-kernel from 5.6). `wireguard-tools` is built from the
upstream source tarball; there is no userspace (wireguard-go) fallback.

## Design

- The `wireguard` job drives the interface with explicit `ip` and `wg`
  commands via a bpm-managed `wireguard-agent` supervisor — not
  `wg-quick` (which is one-shot and fights reconcile-without-teardown;
  it is still installed for operator debugging).

- Peer changes apply via `wg syncconf` on redeploy: the interface is
  never recreated, so established sessions survive.

- Stops and restarts leave the tunnel up by default; set
  `wireguard.teardown_on_stop: true` to change that.

- NAT and firewall policy live outside this release. The job only
  toggles `net.ipv4.ip_forward` / IPv6 forwarding sysctls when
  `wireguard.forwarding.*` is enabled. Colocate the `iptables` job from
  the [networking release](https://bosh.io/releases/github.com/cloudfoundry-community/networking-release)
  for MASQUERADE/FORWARD rules.

- `smoke-tests` is a colocated errand (run it on the wireguard instance
  group): a remote errand VM cannot verify WireGuard because
  unauthenticated UDP is silently dropped.

## Jobs

| Job | Purpose |
|-----|---------|
| `wireguard` | Kernel WireGuard interface lifecycle + reconcile loop |
| `smoke-tests` | Colocated errand verifying interface, port, peers |

See `jobs/*/spec` for the full property contract.

## Keys

WireGuard uses base64 Curve25519 keypairs (not x509). Generate with:

```sh
wg genkey | tee private.key | wg pubkey > public.key
```

Both `wireguard.private_key` and `wireguard.public_key` are required;
pre-start cross-validates the pair and fails fast on drift.

## Quick start

```sh
bosh update-cloud-config manifests/cloud-config.yml
bosh -d wireguard deploy manifests/wireguard.yml \
  -o manifests/ops/standalone.yml \
  -v wireguard_private_key="$(wg genkey)" \
  ...
bosh -d wireguard run-errand smoke-tests
```

## Development

```sh
scripts/add-blob.sh 1.0.20260223   # fetch + verify + bosh add-blob
cp config/private.yml.example config/private.yml  # S3 creds
bosh upload-blobs
bosh create-release --force
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
