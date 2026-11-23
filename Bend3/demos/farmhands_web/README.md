# Farmhands

Farmhands é uma aplicação web multiplayer para rede local inspirada no ciclo
social de visita a fazendas do *Colheita Feliz*. O servidor, as regras, o
relógio, o estado persistente e as decisões de autenticação são escritos em
Bend3; o JavaScript apenas desenha snapshots JSON e envia ações explícitas.

## Jogar na rede local

```sh
cd bend3
./gabriel_demos/farmhands_web/build.sh
FARMHANDS_PORT=8093 ./gabriel_demos/farmhands_web/start.sh
```

Abra `http://<ip-local-da-maquina>:8093` em cada dispositivo. O servidor escuta
em `0.0.0.0`. `FARMHANDS_DATA_DIR` pode apontar para outro diretório; por padrão
os CSVs ficam em `gabriel_demos/farmhands_web/data/`.

## Regras desta versão de teste

- A fazenda tem 2 × 6 lotes e começa com quatro desbloqueados.
- Nabo, cenoura, rabanete e tomate levam 15, 24, 36 e 48 segundos.
- Um lote rende 12 unidades. Cada roubo leva 3 (25%), só uma vez por visitante.
- Há no máximo três roubos por plantio; portanto o dono conserva pelo menos 3.
- Cada visitante pode roubar no máximo dois plantios por dia de cada dono.
- Colher vende a produção automaticamente e também a registra no inventário.

As credenciais são persistidas em `credentials.csv` como nome, sal aleatório e
PBKDF2-HMAC-SHA-256 (60.000 iterações); senhas em texto puro não são gravadas.
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
bun bend-ts/src/main.ts gabriel_demos/farmhands_web/farmhands_logic.bend --eval test
bun bend-ts/src/main.ts gabriel_demos/farmhands_web/web_farmhands.bend --no-halt
bun gabriel_demos/farmhands_web/test_client.mjs
FARMHANDS_BIN=/caminho/para/web_farmhands bun gabriel_demos/farmhands_web/test_server.mjs
```

O teste HTTP cria quatro usuários num diretório temporário, espera um nabo
amadurecer, exercita os limites de roubo, reinicia o processo, autentica de novo
e confere o estado carregado dos CSVs.

## Investigação do Bend

Esta implementação foi portada e realmente checada com o CLI atual
`bend-ts/src/main.ts`. A ordem de padrões-coringa, anotações obrigatórias em
`do IO` e a atualização da sintaxe de igualdade foram inconveniências de
programação, não defeitos do Bend, e por isso não são registradas como bugs.
Até agora este programa não produziu uma falha atribuível ao compilador/runtime.
