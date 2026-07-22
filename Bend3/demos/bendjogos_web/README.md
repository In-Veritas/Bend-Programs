# BendJogos.com.br

BendJogos.com.br is the LAN hub for the browser games and interactive demos in
`gabriel_demos/`.

The hub provides:

- Snake Arena — four-player LAN game under `/snake`
- Cell Arena — four-player LAN game under `/cells`
- Balloon Defense — single-player browser game served by the hub
- Helicopter — single-player browser game served by the hub
- Tic-tac-toe — two-player LAN game under `/tic`
- Bar Bench — server-computed Bend demo under `/bar`
- Elements — server-computed Bend demo under `/elements`
- Social lounge — in-memory accounts, friend requests, presence, friend-only
  chat, and game invitations under `/social` and directly on the home page

From the repository root, build every service once:

```sh
./gabriel_demos/bendjogos_web/build.sh
```

Then start the full hub:

```sh
./gabriel_demos/bendjogos_web/start.sh
```

Open `http://<server-lan-ip>:8090` on any desktop or mobile device connected to
the same local network. Every route and every game uses this one port.

`BendJogos.com.br` is the displayed site name. To use that exact hostname on a
LAN, configure local DNS or a hosts-file entry that maps it to the server's LAN
address; otherwise use the IP address directly.

`start.sh` starts one Bend process. The host firewall only needs to allow port
8090.

The social store is intentionally in memory for this LAN demo, so accounts,
sessions, friendships, messages, and invites disappear on restart. Online
presence expires after inactivity, and game pages publish the signed-in
player's current game. Passwords are reduced to a compact digest rather than
stored in clear text, but this is not a production password KDF or an HTTPS
deployment.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md) for the
versioned issue log, reproductions, resolutions, and current limitations.
