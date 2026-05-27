# Skill-based Matchmaking — Design Sketch

The brief asks for a matchmaking system that scales across any team size
(1v1, 2v2, 3v3, …) using whatever services make sense — Roblox or external.
This document describes how I'd build it. No implementation is included.

## TL;DR

```
┌──────────────┐        ┌─────────────────────┐        ┌──────────────┐
│ Game servers │──────► │ MemoryStore queue   │ ◄────► │ Matchmaker   │
│ (Roblox)     │  enq   │ (per mode + region) │  scan  │ (Open Match  │
│              │        │  SortedMap by skill │        │  on GKE)     │
└──────┬───────┘        └─────────────────────┘        └──────┬───────┘
       │                                                       │
       │            ┌──────────────────────────────┐           │
       └──────────► │ Reserved match servers       │ ◄─────────┘
                    │ (TeleportService:Reserve)    │  teleport
                    └──────────┬───────────────────┘    parties
                               │
                               ▼
                    ┌──────────────────────────────┐
                    │ Skill-update service         │
                    │ (Cloudflare Worker + DB)     │
                    └──────────────────────────────┘
                               │
                               ▼
                    ┌──────────────────────────────┐
                    │ ProfileStore (per player)    │
                    │  μ, σ, recent matches        │
                    └──────────────────────────────┘
```

## 1. Skill model

Use **OpenSkill** (Bayesian rating, like TrueSkill but patent-free) — each
player carries `(μ, σ)`:

- `μ` = current best estimate of skill
- `σ` = uncertainty (high on new players, decays with matches played)

`(μ, σ)` is persisted per player in DataStore via **ProfileStore** alongside
the rest of their profile (avoids running a second persistence stack).

The Plackett-Luce update rule generalizes OpenSkill naturally to any N-team
configuration, so the same math handles 1v1, 2v2, 3v3, and free-for-all
without special cases.

## 2. Queue: cross-server with MemoryStore

A single game server only sees its own players, so any cross-server design
needs a global queue. `MemoryStoreService:GetSortedMap()` is the right
primitive (low-latency, fan-out friendly, included in Roblox quota).

Keyspace: **one sorted map per `(mode, region)`** — e.g. `mm:2v2:US-East`,
`mm:3v3:EU-West`. Sorted by skill bucket. Each entry:

```jsonc
{
  "partyId": "abc-123",
  "partySize": 2,
  "muAvg": 25.0,
  "sigmaAvg": 4.1,
  "joinedAt": 1715000000,
  "currentSpread": 2.0   // grows linearly with wait time
}
```

When a player (or party) clicks "Find match," their home server posts an
entry into the appropriate sorted map and parks the player in a lobby
place. When the matchmaker assigns them, the home server gets a teleport
target back over a different channel (MessagingService or polling
MemoryStore subscriptions) and teleports.

## 3. Matchmaker process

A dedicated worker process polls the sorted maps every ~1 second. It can be:

- **A reserved Roblox server** running the matchmaker as a normal script
  (simplest — keeps everything in the Roblox ecosystem), or
- **Open Match on GKE** (Google's open-source matchmaker; gives you battle-tested
  scheduling and clear scaling story if the game grows).

The algorithm per tick, per `(mode, region)` map:

1. Pull all entries within the skill window of the longest-waiting party
   (`currentSpread` defines the window; widens with wait time so old parties
   eventually match even in low-population modes).
2. Greedy-partition selected parties into two (or N) teams of the required
   size, minimizing `|Σμ_A − Σμ_B|` subject to the size constraint.
3. Compute a quality score:
   `quality = (1 − abs(skillDiff) / tolerance) * waitFactor`
4. If `quality >= QUALITY_THRESHOLD`, lock the match: remove all included
   parties from the sorted map, generate a `matchId`, and proceed to handoff.

This deliberately keeps the matchmaker stateless (it reads MemoryStore each
tick) so we can run multiple instances behind a leader-election lock if
throughput demands it.

## 4. Match handoff

The matchmaker:

1. `TeleportService:ReserveServer(matchPlaceId)` → `(accessCode, jobId)`
2. For each party: `TeleportService:TeleportAsync(matchPlaceId, players, options)`
   with the access code + `matchId` + team assignment in the teleport data.

The reserved server reads the teleport data on `Players.PlayerAdded`,
verifies the `matchId`, places players on the assigned team, and starts the
match. If a player fails to teleport within a timeout, the server pushes the
remaining parties back to the queue (with a small `mu` bonus to compensate
for the failed attempt).

## 5. Result reporting & skill update

After a match ends, the game server POSTs a result blob to an **external
endpoint** (Cloudflare Worker is the cheapest sensible choice — Roblox's
HttpService can reach it directly):

```jsonc
{
  "matchId": "...",
  "outcomes": [
    { "team": 0, "rank": 1, "players": ["userIdA", "userIdB"] },
    { "team": 1, "rank": 2, "players": ["userIdC", "userIdD"] }
  ]
}
```

The Worker:

1. Looks up each player's current `(μ, σ)` from a backing DB (or back through
   ProfileStore via DataStore API).
2. Runs the OpenSkill Plackett-Luce update.
3. Writes back the new ratings.

Why externalize this: it keeps rating logic in one place (vs. duplicated
per-mode in N game servers), it's auditable, and it resists clients tampering
with rating updates by exploiting game-server-side bugs.

## 6. Edge cases

- **Solo vs. parties.** Solo queue and party queue go into different sorted
  maps; otherwise a 3-party would block 1v1 matches. For modes like 3v3 we
  let the matchmaker combine smaller parties from the same sorted map into
  one team, but never split a party across teams.
- **Backfill on disconnect.** When a player drops mid-match, the match
  server posts a backfill request to MemoryStore. The matchmaker pulls a
  same-mode same-region party of the missing size with a relaxed quality
  threshold.
- **Anti-abuse.** All `(μ, σ)` updates flow through the Worker, which
  rate-limits per-player and rejects updates that don't correspond to a
  `matchId` it issued.
- **Region / latency.** A separate sorted map per region (US-East, EU-West,
  Asia, …). Players are bucketed by their initial ping to a small set of
  region endpoints, with a fallback expansion to neighboring regions after
  a long wait.
- **Sticky parties.** Parties stay grouped across matches by default; the
  party leader can disband, but joining a queue as a party is the unit of
  matchmaking, not the individual player.

## 7. Why not pure in-game matchmaking?

A single game server only sees the players in its own instance, so naive
in-game matchmaking caps the matchmaking pool at one server's worth of
players. Cross-server queues are mandatory for any non-trivial game. Roblox
MemoryStore is the cheapest primitive for that; Open Match is the right
upgrade once the game outgrows a single-region matchmaker process.
