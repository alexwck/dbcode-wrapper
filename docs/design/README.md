# Database-client redesign

The visual source of truth is [database-client-redesign-reference.png](./database-client-redesign-reference.png).

The redesign presents DBCode as a dedicated database application:

- Query and Results are the primary workspace.
- Results starts on the right on wide windows, moves below on narrow windows, and can be docked either way by the user.
- Connections, History, Library, Account, Messages, and database metadata remain DBCode-owned surfaces.
- Project `.sql` files open as named query tabs through the SQL-only query-document entry.
- DuckDB, SQLite, Parquet, CSV, and other database or data files enter through DBCode Connections.
- Code OSS remains an internal extension host. Explorer, Extensions, Source Control, terminal, Command Palette, and other general IDE surfaces stay hidden.

This document replaces prototype labels with a description of the actual design and behavior.
