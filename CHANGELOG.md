# Changelog

All notable changes to this project are recorded here (CLAUDE.md §10).

## Unreleased

### Docs
- Architecture specification under `docs/architecture/`: overview and package map, engine (ECS + event sourcing), rules packs, protocol, session actors, migrator, accounts and backend, apps, testing, open decisions for R, and a verification register.
- Architecture spec: compatibility decoding within an engine major (additive-only) with a proposed deprecation mechanism; web build recorded as a lightweight client, with GM hosting on web left open for R.
- Architecture spec: archived logs are frozen (not converted) with a plain-text log kept beside them; migration requires explicit GM confirmation of unrecoverable loss.
- Architecture spec: adopted backend stack (firebase_dart client, Realtime Database for live data, HTTPS-only Dart Cloud Functions, Linux in v1); Firestore and the Cloud Run gateway removed; unproven probe items listed as open.
- Architecture spec: firebase_admin_sdk and firebase_functions approved by R; package facts re-checked on pub.dev where the tool allows.
