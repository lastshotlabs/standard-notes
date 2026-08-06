# Standard Notes journal

Private Standard Notes sync infrastructure for `ds1`, deployed at:

- `https://journal.jdealla.com` — sync and authentication API
- `https://journal-files.jdealla.com` — encrypted file API

The native Standard Notes clients encrypt journal contents before sending them
to this server. Both published container ports bind only to host loopback;
Cloudflare Tunnel supplies public HTTPS without an inbound firewall opening.

## First sign-in

Install the Standard Notes app. At the sign-in screen choose **Advanced
options**, select a custom sync server, and enter:

```text
https://journal.jdealla.com
```

Register the owner's account once. Then immediately disable further account
creation on ds1:

```bash
sudo /mnt/storage/apps/standard-notes/scripts/lock-registration.sh
```

The account passphrase is the journal's encryption secret. Store it in the
password manager: the server cannot recover it or decrypt journal entries.

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
`/etc/homeserver/standard-notes-backup.env`. Losing both that file and every
configured recovery copy makes the backup repository unreadable.

## Full recovery

1. Restore the latest Restic snapshot to a temporary directory.
2. Restore `/etc/homeserver/standard-notes.env` with `0600 deploy:deploy`.
3. Recreate the Compose project and wait for MySQL to become healthy.
4. Import `standard-notes.sql.gz` into `standard_notes_db`.
5. Restore the `uploads/` tree and restart `server`.
6. Confirm `/healthcheck` through both HTTPS endpoints before reconnecting clients.
