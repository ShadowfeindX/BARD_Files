# Developer guide

How to set up, build and extend the B.A.R.D. Files platform. It is updated in the same PR as the change it describes (CLAUDE.md §10). The design lives in [../architecture/](../architecture/README.md).

| Page | What it covers |
|---|---|
| [setup.md](setup.md) | Toolchain, first build, the checks CI runs, workspace layout, adding a package |
| [engine.md](engine.md) | Engine core: commands, events, components, state, expressions, RNG; how to add a command, event or component |
| [packs.md](packs.md) | Rules packs: the command-line validator, what the loader checks, pending-D values, deprecation, content hash |
| [session.md](session.md) | Session host and participant: the loop, the rules the host keeps, how to plug in a codec, transport or store |
