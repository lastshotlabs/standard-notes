# Standard Notes journal

Private Standard Notes sync infrastructure for `ds1`, deployed at:

- `https://journal.jdealla.com` — self-hosted web journal
- `https://journal-sync.jdealla.com` — sync and authentication API
- `https://journal-files.jdealla.com` — encrypted file API

The Standard Notes web, desktop, and mobile clients encrypt journal contents
before sending them to this server. All published container ports bind only to
host loopback; Cloudflare Tunnel supplies public HTTPS without an inbound
firewall opening.

## First sign-in

Install the Standard Notes app. At the sign-in screen choose **Advanced
options**, select a custom sync server, and enter:

```text
https://journal-sync.jdealla.com
```

The self-hosted web client at `https://journal.jdealla.com` is configured to
use this custom sync server by default. The native mobile and desktop clients
still require the one-time custom sync-server selection above.

Browser authentication cookies are scoped to `jdealla.com` so the web origin
can maintain a session with the separate `journal-sync` origin. They are
Secure, SameSite=Lax, and not partitioned.

Register the owner's account once. Then immediately disable further account
creation on ds1:

```bash
sudo /mnt/storage/apps/standard-notes/scripts/lock-registration.sh
```

The account passphrase is the journal's encryption secret. Store it in the
password manager: the server cannot recover it or decrypt journal entries.

## Server-side features

The official self-hosting documentation permits assigning the local account a
`PRO_USER` role and `PRO_PLAN` subscription. Activate that server-side feature
set with:

```bash
sudo /mnt/storage/apps/standard-notes/scripts/activate-server-features.sh
```

The script requires exactly one account, creates a fresh encrypted backup, and
applies the records idempotently. This does not unlock separately licensed
client-side features such as Super Notes or nested tags; those require an
offline client subscription from Standard Notes.

## Production configuration

Secrets live only in `/etc/homeserver/standard-notes.env`, owned by
`deploy:deploy` with mode `0600`. The checked-in `.env.example` documents all
required variables. Generate every placeholder independently with:

```bash
openssl rand -hex 32
```

The deployment follows the official Standard Notes V2 four-container layout.
Container image indexes are digest-pinned; Dependabot proposes reviewed digest
updates rather than silently changing the running server.

## Backups

`standard-notes-backup.timer` creates a transactionally consistent MySQL dump
nightly, then backs up the dump, encrypted uploads, deployment definition, and
production environment into a Restic repository on the NAS. Restic encrypts
the repository independently of Standard Notes' own client-side encryption.

Retention is 7 daily, 5 weekly, and 12 monthly snapshots. Verify the latest
snapshot without touching production:

```bash
sudo /mnt/storage/apps/standard-notes/scripts/restore-check.sh
```

The Restic password is stored only in
`/etc/homeserver/standard-notes-backup.env` on ds1. A root-only recovery copy
lives at `/etc/standard-notes-restic-password` on ds2, physically beside the
repository but outside its NFS export. Losing both copies makes the backup
repository unreadable.

The NAS repository is mounted on ds1 from
`192.168.86.69:/tank/files` at `/mnt/nas-backups`. The host's `/etc/fstab`
uses a persistent NFSv4 automount; the database never runs on NFS.

## Full recovery

1. Restore the latest Restic snapshot to a temporary directory.
2. Restore `/etc/homeserver/standard-notes.env` with `0600 deploy:deploy`.
3. Recreate the Compose project and wait for MySQL to become healthy.
4. Import `standard-notes.sql.gz` into `standard_notes_db`.
5. Restore the `uploads/` tree and restart `server`.
6. Confirm the web root and `/healthcheck` through both API HTTPS endpoints before reconnecting clients.
