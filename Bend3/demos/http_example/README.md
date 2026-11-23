# http_example

A tiny stateful counter server, the reference use of `../HTTP.bend` on
Bend 2.0.40. The `Counter` state is threaded through every request by
`HTTP.serve`; connections are read concurrently but handled one at a time,
in arrival order, by the state owner.

| route | answer |
|---|---|
| `GET /` | `index.html`, read from disk on every request |
| `GET /state` | `{"count":N,"requests":R,"note":"..."}` |
| `POST /inc` | adds the body's number (empty body: 1), answers the new state |
| `GET /echo?msg=...` | the percent-decoded `msg`, as a JSON string |
| other paths / methods | `404` / `405` |

## Build and run

```sh
cd Bend3/demos/http_example
bend main.bend --check-only          # ALL PROOFS CHECK
bend main.bend -o /tmp/http_example  # native build (~3 s)
/tmp/http_example                    # serves http://127.0.0.1:8099 (all interfaces)
```

Start it from this folder: `GET /` reads `index.html` relative to the
current directory.

```sh
curl -s http://127.0.0.1:8099/state                       # {"count":0,"requests":1,"note":""}
curl -s -X POST --data-binary 5 http://127.0.0.1:8099/inc # {"count":5,"requests":2,"note":"added 5"}
curl -s 'http://127.0.0.1:8099/echo?msg=hi%20there'       # "hi there"
```

## Verified (2026-11-23, bend 2.0.40, Linux x86_64)

- All routes above, 404, 405, a 300 KB POST body (several TCP chunks), JSON
  escaping (`"`, `\`, newline, tab, control chars), malformed request (400),
  header-only half-closed request (400), idle connection (408 after 10 s,
  and other clients are served meanwhile).
- 200 sequential `POST /inc` in 1.0 s, then 1000 sequential `GET /state`
  in 4.9 s, then 100 POSTs from 20 parallel clients: every increment
  counted, RSS flat at 21 MB across all three runs, 6 open fds before
  and after (no socket leak).
