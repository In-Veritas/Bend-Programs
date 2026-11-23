# Farmhands

Farmhands é uma aplicação web multiplayer para rede local inspirada no ciclo
social de visita a fazendas do *Colheita Feliz*. O servidor, as regras, o
relógio, o estado persistente e as decisões de autenticação são escritos em
Bend3; o JavaScript apenas desenha snapshots JSON e envia ações explícitas.

## Jogar na rede local

Requer o comando `bend` (Bend 2.0.40) no `PATH`. A partir da raiz do
repositório (`start.sh` compila na primeira execução e entra na raiz sozinho):

```sh
./Bend3/demos/farmhands_web/build.sh
FARMHANDS_PORT=8093 ./Bend3/demos/farmhands_web/start.sh
```

O binário vai para `Bend3/demos/farmhands_web/build/` (ignorado pelo git).
Abra `http://<ip-local-da-maquina>:8093` em cada dispositivo. O servidor escuta
em `0.0.0.0`. `FARMHANDS_DATA_DIR` pode apontar para outro diretório; por padrão
os CSVs ficam em `Bend3/demos/farmhands_web/data/`. O mesmo jogo também é
servido pelo hub BendJogos em `http://<ip>:8090/farmhands`, com os mesmos CSVs.

## Hub interface

`web_farmhands.bend` exposes, for
`import ../farmhands_web/web_farmhands.bend as Farm`:

- `Farm.Game` — the whole server state (`is Data`: credentials, sessions,
  farm, CSV paths, wall-clock base);
- `Farm.init() -> IO(Game)` — reads `FARMHANDS_DATA_DIR`, loads and rewrites
  both CSVs, and reads the Unix time once (`date +%s` through Base's
  `Process.run`);
- `Farm.route(req, g) -> IO(Game & HTTP.Response)` — reads the clock itself;
  `Farm.route_at(req, g, now)` takes wall-clock seconds.

Both accept paths with or without the leading `/farmhands` (`/farmhands/api/...`
in the hub, `/api/...` standalone); `index.html` picks its API base from its own
location. `main` reads `FARMHANDS_PORT` (default 8093), listens, prints
`Farmhands listening on 0.0.0.0:<port>` and calls `HTTP.serve_on(~Game,
~route, listener, g)`.

## Regras desta versão de teste

- A fazenda tem 2 × 6 lotes e começa com quatro desbloqueados.
- Nabo, cenoura, rabanete e tomate levam 15, 24, 36 e 48 segundos.
- Um lote rende 12 unidades. Cada roubo leva 3 (25%), só uma vez por visitante.
- Há no máximo três roubos por plantio; portanto o dono conserva pelo menos 3.
- Cada visitante pode roubar no máximo dois plantios por dia de cada dono.
- Colher vende a produção automaticamente e também a registra no inventário.

As credenciais são persistidas em `credentials.csv` como nome, sal aleatório e
PBKDF2-HMAC-SHA-256 (60.000 iterações); senhas em texto puro não são gravadas.
O PBKDF2 agora é Bend puro (`pbkdf2.bend`, ~45 ms por senha no binário nativo),
com saída idêntica ao antigo efeito C `effs/password_hash.c` (conferida com
`hashlib.pbkdf2_hmac` do Python, inclusive senha UTF-8 e senha maior que 64
bytes); o arquivo C fica só como registro histórico. Os horários dos plantios
são segundos Unix: o relógio do Base é monotônico, então `init` lê `date +%s`
uma vez e soma o tempo monotônico decorrido.
O estado das fazendas, plantios e roubos fica em `farm_state.csv`. Sessões são
tokens aleatórios mantidos apenas na memória e expiram quando o servidor reinicia.
Este é um login simples para uma LAN confiável: não há TLS, recuperação de senha,
rate limiting nem proteção contra um administrador da máquina.

## Provas e testes

`farmhands_logic.bend` contém 12 provas verificadas pelo compilador: quatro
lotes iniciais; roubo igual a um quarto; rendimentos exatos após zero, um, dois e
três roubos; reserva mesmo com uma contagem excessiva; fechamento após três
roubos; limite diário; detecção do mesmo visitante; distinção de outro visitante;
e contagem exata de dois roubos.

```sh
bend Bend3/demos/farmhands_web/farmhands_logic.bend --check-only   # ALL PROOFS CHECK (12 laws)
bend Bend3/demos/farmhands_web/farmhands_logic.bend                # 12 (auditoria em tempo de execução)
bend Bend3/demos/farmhands_web/web_farmhands.bend --check-only     # ALL PROOFS CHECK
bun Bend3/demos/farmhands_web/test_client.mjs
bun Bend3/demos/farmhands_web/test_server.mjs   # usa build/web_farmhands, ou FARMHANDS_BIN
```

Na migração para Bend 2.0.40 as doze provas viraram `law`s com a prova no
`def` de mesmo nome; os antigos valores-verdade 0/1 em U32 são `Bool`
(`= 0` virou `== False{}`, `= 1` virou `== True{}`). Nenhum `@unsafe` nem
código estrangeiro: tudo passa com ALL PROOFS CHECK.

O teste HTTP cria quatro usuários num diretório temporário, espera um nabo
amadurecer, exercita os limites de roubo, reinicia o processo, autentica de novo
e confere o estado carregado dos CSVs.

## Investigação do Bend

Esta implementação foi portada para Bend 2.0.40 e checada com `bend`.
Antes disso, foi checada com o CLI `bend-ts/src/main.ts`. A ordem de padrões-coringa, anotações obrigatórias em
`do IO` e a atualização da sintaxe de igualdade foram inconveniências de
programação, não defeitos do Bend, e por isso não são registradas como bugs.
Até agora este programa não produziu uma falha atribuível ao compilador/runtime.
