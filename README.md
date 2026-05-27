# Baggage Conveyor — Take-home Assignment

A Roblox baggage conveyor belt built with Knit, Replica (Mad Studio), Rodux,
and Component. Bags spawn on one end, slide along a 50-stud belt at 8 studs/s,
and despawn on the other end with spawn/despawn animations. The first player
to join controls the spawn rate (0.1–10 bags/sec) via a programmatic slider
UI; the role transfers when they leave. Clicking a bag prints its id on both
client and server.

## Architecture

Authoritative state lives in a single server-side **Replica** (`Bags`,
`SpawnRate`, `OperatorUserId`). Clients subscribe via ReplicaClient and feed
every delta into a **Rodux store**. Bag parts exist **only on each client** —
the server never replicates per-frame CFrames. Instead, each bag carries a
spawn-time stamp; clients compute `position = lerp(start, end, elapsed * speed)`
locally every RenderStepped. This keeps per-client network traffic far below
the 4 KB/s budget even when the belt is fully loaded.

See [MATCHMAKING.md](MATCHMAKING.md) for the open-ended skill-based
matchmaking design write-up.

## File layout

```
src/
  shared/        BagConfig, ConveyorMath, ConveyorModel
  server/        init.server.luau, Services/, Replicas/
  client/        init.client.luau, Controllers/, Components/, Store/, UI/
```

## Getting started

Install toolchain + packages:

```sh
aftman install           # rojo, wally
wally install            # all Wally dependencies
```

Sync to Roblox Studio:

```sh
rojo serve
```

Open Studio, connect via the Rojo plugin, then press Play.

## Verification checklist

- Belt model is at the world origin, bags spawn at the left endcap (green) and
  despawn at the right endcap (red).
- Two test clients (Test menu → "Local Server" with 2 players): each client
  sees the same bag colors, materials, and positions.
- Click a bag: `[Client] <id>` in client output, `[Server] <id>` on server.
- First player has the slider; second player does not. First player leaves →
  slider transfers to the second player with their persisted spawn rate from
  ProfileStore.
- Stats panel (View → Stats → Network → Data In/Out): per-client receive
  rate stays well under 4 KB/s even at the slider's max (10 bags/sec).
