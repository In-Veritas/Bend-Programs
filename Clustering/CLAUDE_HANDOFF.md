# Retomada Claude / Codex — 2026-11-23

## Leia primeiro — passagem de trabalho ao Claude

O usuário encerrou a execução do Codex e pediu apenas a passagem de trabalho.
Este é o ponto de entrada; nenhum novo teste ou benchmark deve ser atribuído
ao Codex após esse encerramento.

1. Ler `vclust_bend_codex_verified/CLAUDE_HANDOFF.md` e o README adjacente.
   Essa é a versão cujos fontes, provas e resultados do Codex estão vinculados
   por hashes. O inventário e o patch estão em `evidence/` dentro dela.
2. Comparar com `vclust_bend/`, onde a outra sessão continua trabalhando.
   Existe uma implementação Leiden alternativa nessa pasta. As observações
   e diferenças estão em `handoff/concurrent-vs-codex-observed.patch` e no JSON
   adjacente. Integrar deliberadamente; não sobrescrever uma versão com a outra.
3. As pendências de desempenho são o benchmark completo sem concorrência e
   o custo do launcher com verificação externa. O completo interrompido não
   tem total válido. Os scripts para retomar estão na cópia isolada; coordenar
   sessões e manter os limites de memória antes de executá-los.
4. Ler `presentation/CLAUDE_HANDOFF.md` para o estado exato da apresentação e
   do QA. HTML e PDF foram exportados novamente às 17:19–17:20 CET; a revisão
   complementar do PDF deve seguir o estado registrado nesse arquivo.

Não houve commit, push, publicação externa ou alteração do artifact Claude.
Fontes, backups, comandos, provas, testes, falhas e pendências estão preservados.

## Entrega isolada do Codex

A versão validada desta retomada está em
[`vclust_bend_codex_verified/`](vclust_bend_codex_verified/README.md), com
[registro técnico próprio](vclust_bend_codex_verified/CLAUDE_HANDOFF.md).
Outra sessão Claude continuou alterando `vclust_bend/` durante a validação.
A cópia isolada foi reconstruída dos fontes preservados e conferida por hash;
o trabalho concorrente ficou preservado na pasta original. As evidências do
Codex referem-se aos fontes dessa cópia, não a mudanças posteriores do Claude.

Resultados: 42/42 prefiltros, 15/15 alinhamentos (incluindo o completo com
12 workers), 98/98 clusters idênticos ao Vclust, três entradas de provas
aprovadas e certificados semânticos de 18 resultados reais. O benchmark
completo foi interrompido e não deve ser apresentado como concluído.
Os benchmarks de 1.000 genomas terminaram antes da concorrência detectada.
O estado final da apresentação fica em `presentation/CLAUDE_HANDOFF.md`.

As anotações abaixo preservam a cronologia anterior à criação dessa cópia.

## Escopo confirmado pelo usuário

O usuário ficou sem créditos do Claude e pediu ao Codex para continuar.
Confirmou **clustering em Bend e apresentação**. A frente YASARA está fora
desta retomada. Pediu explicitamente: “anote tudo que voce mudar pro claude
poder retomar do jeito certo”. Este arquivo é o ponto de entrada do registro.

## Onde continuar

- [Código validado, testes e pendências](vclust_bend_codex_verified/CLAUDE_HANDOFF.md).
- [Apresentação e revisão visual](presentation/CLAUDE_HANDOFF.md).
- [Manifesto dos fontes herdados](handoff/claude-inherited-source-manifest.json):
  hashes registrados antes das alterações de implementação do Codex.

## Estado encontrado

- Repositório: `/home/veritas/Bend-Programs`, branch `bend-latest-port`.
- `Clustering/vclust_bend/` estava **inteiramente sem rastreamento no Git**,
  mas continha o trabalho anterior do Claude. Não apagar nem substituir por
  um checkout limpo. Há outras alterações anteriores em `Bend2 Core/` e
  `Clustering/benchmark/install_vclust.sh`, que não pertencem a esta retomada.
- O transcript principal é
  `/home/veritas/.claude/projects/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95.jsonl`.
- O scratchpad anterior é
  `/tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad`.
- A apresentação anterior tem 37 slides HTML/CSS em `scratchpad/deck/project`.
  O artefato Claude anterior é `https://claude.ai/artifact/EukGdSEQyLMZDBHCCETfzn`.
  As alterações locais do Codex **não atualizam automaticamente esse link**.
- Prefilter e align têm implementações substanciais e testes anteriores.
  Cinco algoritmos de cluster têm código. `cl_leiden.bend` era um stub de
  249 bytes que retornava um único cluster para todos os vértices.
  Não considerar a opção Leiden implementada até a validação registrada.

## Segurança operacional e coordenação

Houve estouros de memória durante o trabalho anterior, inclusive sessões
duplicadas escrevendo os mesmos arquivos. Nesta retomada o agente principal
cuida de `vclust_bend/` e um único agente cuida de `presentation/`.

- Usar o wrapper `capped` anterior para qualquer compilação, teste ou navegador.
- `bendwork.slice`: `MemoryHigh=9G`, `MemoryMax=10G`, `MemorySwapMax=0`.
- Compilador: até 8 GB. Testes: começar com 1–4 GB, de acordo com o conjunto.
- Não executar dois trabalhos pesados ao mesmo tempo sem coordenação.
- No sandbox do Codex, `systemd-run --user` exige execução autorizada fora
  do sandbox. A primeira tentativa falhou com `Operation not permitted`;
  foi solicitada autorização explicando a necessidade do limite de memória.
- Não aumentar limites para ocultar loops ou estouros. `Bool.pick` avalia
  ambos os argumentos: o antigo estouro vinha de subtração U32 que dava
  underflow dentro de um ramo descartado. Usar seleção preguiçosa por `match`.
- Nenhum commit/push foi feito pelo Codex até o início deste registro.

## Registro cronológico

1. Recuperado o histórico recente e identificadas as duas frentes do Claude.
2. Usuário selecionou clustering/apresentação.
3. Inspecionados os fontes, instruções AGENTS, guia do compilador e briefs.
4. Confirmados os limites de memória configurados com `systemctl --user show`.
5. Iniciado `tests/test_prefilter.py --quick` com teto de 4 GB e timeout de
   600 segundos. Nove casos do exemplo passaram com igualdade byte a byte;
   o processo terminou com código 143 antes de completar a suíte.
   A causa está em investigação; **não registrar a suíte como aprovada**.
6. Delegada somente a apresentação, conforme o pedido original do usuário
   de ter um agente dedicado aos slides. Cópia permanente em `presentation/`.
7. Criado este registro e o manifesto inicial a pedido do usuário.

As próximas alterações e validações devem ser acrescentadas aos registros
de cada frente, inclusive falhas e limitações.

8. A apresentação local foi concluída em HTML e PDF (37 páginas), com fontes
   locais, navegação e revisão visual. O registro individual de 23 slides
   alterados está em `presentation/CLAUDE_HANDOFF.md`. Resultados do pipeline
   continuam provisórios e explícitos nos slides.
9. O usuário pediu provas de correção dos clusters. O trabalho de código
   passou a incluir certificação da saída e contratos semânticos.
10. Leiden foi implementado, passou na checagem de tipos/terminação e
    compilou nativamente. Os seis algoritmos passaram no exemplo contra
    Vclust; testes maiores seguem em andamento. Consulte o registro técnico.
11. Leiden agora está implementado e o nativo com certificados integrados
    produziu98/98 arquivos idênticos ao Vclust. Pré-filtro:42/42; alinhamento
    completo/benchmark ainda em execução nesta anotação. Evidências atuais
    ficam em `vclust_bend/evidence/`.
12. Acrescentados dois certificadores Bend com veredicto no kernel e um
    teorema geral Lean para certificados de conectividade;18 saídas reais
    passaram na verificação semântica. Leia o README para o alcance exato:
    não se afirma correção biológica nem ótimo global de Leiden.
13. Criados launcher durável com cgroups, testes de integração/rejeição,
    cache de referências fora de `/tmp` e README. O handoff técnico detalha
    todos os arquivos. A apresentação aguarda números finais antes de exportar.
