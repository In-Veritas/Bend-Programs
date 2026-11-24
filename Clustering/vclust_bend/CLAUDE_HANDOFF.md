# Vclust em Bend — registro de continuidade

Atualização inicial: 2026-11-23. Leia também `../CLAUDE_HANDOFF.md`.

## Objetivo herdado

Implementar prefilter/Kmer-db, align/LZ-ANI e cluster/Clusty em Bend,
mantendo os formatos de arquivo e comparando correção, tempo e memória com
Vclust 1.3.1. A apresentação deve refletir resultados medidos e limitações reais.

## Ambiente recuperado

```bash
source /tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad/env.sh
```

- Compilador fonte: `/home/veritas/Bioinformatique/Higher Order Company/Bend`.
- Revisão de referência anterior: `6b806192284fc9c64404d9b0b59c937f568d87ec`,
  Bend 2.0.40; entrada `bend2/main.ts`.
- Vclust: `../.tools/vclust-1.3.1/bin/vclust`.
- Fontes oficiais locais: `scratchpad/cl/{clusty,igraph}` e outros diretórios
  do scratchpad. Modelo Python: `tests/clusty_model.py`.
- Dados: `../datasets/`; referências prontas: `scratchpad/vc/full/` e
  `scratchpad/vc/s1000/`, além de `scratchpad/al/ref/`.
- Timings anteriores completos realmente existem em `scratchpad/vc/full/log.txt`:
  prefilter 12t 31.21 s / 2458324 KB; align 12t 178.45 s / 696032 KB;
  prefilter 1t 41.16 s / 2429344 KB; align 1t 361.47 s / 178868 KB.
  São medições herdadas, não medidas novamente pelo Codex.

## Estado de cada componente antes das edições

| Componente | Estado herdado e próximo passo |
| --- | --- |
| prefilter | Código e `tests/test_prefilter.py`; retomar a suíte diferencial que parou após nove casos. |
| align | Código com Ctx encaixotado e caminho rápido de literais; consolidar testes reproduzíveis. |
| single, complete, uclust, cd-hit, set-cover | Código e comparações anteriores; repetir testes independentes dos logs antigos. |
| Leiden | **Stub**, retorna um grupo para todos. Implementar antes de comparar. |
| launcher | Comentários citam wrappers que ainda não existem. Criar entrada documentada e mapeamento `-t` para runtime. |
| documentação | Não havia README do pacote. Documentar comandos, escopo e limitações reais. |

## Teste iniciado pelo Codex

Comando, executado em `Clustering/vclust_bend` com autorização fora do sandbox:

```bash
source /tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad/env.sh
CAP=4G capped timeout 600 python3 -u tests/test_prefilter.py --quick
```

Passaram os nove primeiros casos `vclust_example`: padrão, max-seqs 50,
fraction 0.2, max-seqs 1, batch-size 300, batch-size 300/max-seqs 5,
k15/fraction 0.5, k16, k19/fraction 0.3/min-kmers 3.
Todos produziram `identical`. O processo terminou com **143**, sem sumário.
O caso seguinte é `-k 30 --min-ident 0.9`; verificar a execução de referência
e impor timeout por subprocesso. Não presumir que seja falha do código Bend.

## Alterações do Codex

- `../CLAUDE_HANDOFF.md`: ponto de entrada, escopo, estado e limites de memória.
- `../handoff/claude-inherited-source-manifest.json`: hashes dos arquivos herdados.
- Este arquivo: continuidade técnica. **Nenhum fonte `.bend` alterado ainda
  no momento desta entrada inicial.**

## Disciplina para a retomada

Registrar cada fonte alterado e o motivo; cada comando de validação e seu
resultado; cada limitação ainda presente. Não declarar `--check-only` uma
prova matemática completa: o compilador informa que `--verdict` é necessário
para a verificação no kernel BendTT. Não confundir os testes herdados com os
executados nesta retomada.

## Alterações posteriores — Leiden, 2026-11-23

O usuário acrescentou: **“use provas pra garantir que os clusters estejam certos”**.
Isso exige contratos semânticos ligados aos resultados, além de tipos e testes.
Ainda não há alegação de prova de correção do algoritmo completo.

- Backup recuperável dos fontes herdados: `../handoff/claude-inherited-vclust_bend.tar.gz`.
- `cl_leiden.bend`: substituído o stub por iterações, projeção dos níveis e
  coordenação de fastmove/refinamento/agregação.
- `cl_leiden_state.bend`: estado afim, cada array tem um único dono.
  Gerado por `tools/generate_leiden_state.py`, que também foi adicionado.
- `cl_leiden_rng.bend`: PCG32, amostragem inteira, uniformes binary64 e shuffle,
  com constantes conferidas contra o modelo Python do Claude.
- `cl_leiden_common.bend`: utilitários de estado, grupos, renumeração e pesos.
  Preserva a duplicação de arestas produzida pelo Clusty no igraph não dirigido.
- `cl_leiden_move.bend`: movimentação local com fila, desempates estritos e
  atualização de vizinhos instáveis.
- `cl_leiden_refine.bend`: refinamento de singletons com sorteio proporcional
  a exp(ganho/beta), binary search cumulativa e renumeração.
- `cl_leiden_aggregate.bend`: agregação ponderada, mantendo a ordem de somas.
- `cluster.bend`: encaminha erro de limite do Leiden como `Result/Fail` até
  IO, sem escrever um agrupamento parcial. Rejeita beta=0 e mais de 1000
  iterações positivas; iterações negativas têm teto de 1000 passagens.
- Limites internos: 1.000.000 retiradas da fila por nível; 128 tentativas por
  amostragem aleatória; níveis limitados pelo número de vértices. Exaustão
  marca erro, não sucesso. Revisar custo/limites em benchmarking posterior.
- `tests/test_cluster.py`: compara Vclust oficial e binário Bend em seis
  algoritmos, conjuntos reais e grafos aleatórios; timeout por subprocesso,
  preservação de comandos e hashes. `.gitignore` ignora `.work/` e pycache.

### Validações executadas até esta entrada

Os módulos de estado/RNG/utilitários/fastmove/refinamento/Leiden integrado e
`cluster.bend` passaram `bend ARQUIVO --check-only`. Esse comando **não é**
o veredicto do kernel matemático. Compilação nativa também terminou com êxito:

```bash
bend cluster.bend -o /tmp/vclust-codex-cluster
CAP=3G capped timeout 600 python3 -u tests/test_cluster.py --random 8 --full
```

A suíte está em andamento no momento desta entrada. Os seis algoritmos
passaram no exemplo, incluindo Leiden. Conferir `.work/cluster-tests/results.json`
para os demais resultados; não presumir aprovação antes de ler o sumário.

### Sintaxe e cautelas descobertas na implementação

- Bend não permite desestruturar uma tupla computada diretamente. Usados
  eliminadores CPS (`pair`, `gu`, `gd` etc.), cuja definição desestrutura
  um parâmetro. As versões finais passaram no checker.
- Guardas `case ... with condição` não são suportadas; usa-se seleção
  preguiçosa via função e lambda que casa em `Bool`.
- Um comando que juntava patch e checagem foi interrompido na autorização.
  Foi confirmado que `cluster.bend` continuava sem aquela alteração; ela foi
  reaplicada separadamente e checada. Não há patch perdido dessa etapa.
- O modelo e a versão local do igraph usam `!changed` nas iterações negativas.
  O port preserva essa semântica, com limite explícito para evitar loop infinito.

### Próximas ações

1. Ler resultado completo da suíte diferencial; corrigir divergências antes
   de benchmark. Ainda não há benchmark novo publicável.
2. Implementar certificação independente da partição e contratos por algoritmo,
   ligada à saída efetiva. Adicionar provas, tentar `--verdict` no kernel.
3. Lean 4.34.0 não está instalado; `safe.ts` exige exatamente essa versão.
   Foi verificada a release oficial e iniciada consulta dos artefatos oficiais.
4. Retomar o prefilter (timeout no caso k30), consolidar testes de align,
   criar launcher e README reproduzíveis. Atualizar slides 32/36/37 com evidências.

## Resultado da correção e primeira prova no kernel

- A primeira rodada diferencial teve 49/50 arquivos iguais. No grafo
  `random-6-leiden-1` a partição era a mesma, mas dois grupos de tamanho 2
  trocaram de número. Causa: `result()` renumerava os rótulos projetados,
  alterando o desempate do Clusty. Agora `count_labels` conta `max+1` sem
  modificar os rótulos.
- Recompilado `/tmp/vclust-codex-cluster`. Nova suíte:
  `CAP=3G capped timeout 600 python3 -u tests/test_cluster.py --random 20 --full`.
  Resultado: **98/98 idênticos**, incluindo os seis algoritmos no exemplo,
  stratified1000 e EarlyVir completo, e Leiden em 20 grafos aleatórios com
  0/1/2/4 iterações e parâmetros variados.
  Evidência persistente: `evidence/cluster-equivalence-98.json`.
- Instalado Lean oficial **4.34.0** em
  `/home/veritas/.local/opt/lean-4.34.0`, extraído da release oficial GitHub.
  Nenhuma mudança global de PATH. Arquivo baixado em `/tmp/lean-4.34.0-linux.tar.zst`.
  O compilador criou seu kernel em `~/.bend/bendtt/` por hash da fonte/versão.
- Novo `partition_certificate.bend`: predicado estrutural `Partition`,
  decisão executável `check`, prova universal `sound`, tipo `Certified`,
  teorema universal `partition_length` e certificados fechados que rejeitam
  tamanho menor/maior, rótulo fora do intervalo e sentinel não atribuído.
- Comando matemático concluído com exit 0 e **ALL PROOFS CHECK**, sem aviso:

```bash
PATH="/home/veritas/.local/opt/lean-4.34.0/bin:$PATH" bend partition_certificate.bend --verdict
```

  O wrapper `bend` estava sob cgroup de 8 GB. Manifesto com hash e comando:
  `evidence/partition-kernel-verdict.json`.
- `cluster.bend` agora recolhe as atribuições reais do array, passa-as a
  `PC.certify` e só chama `render` se obtiver `Some{certificate}`. Uma falha
  retorna erro antes de escrever saída. Essa integração está em validação;
  o resultado 98/98 anterior é **anterior à integração do certificado**.
- A prova cobre uma atribuição por posição do grafo ativo e rótulos limitados.
  Não prova, sozinha, clique, componentes conexos, qualidade de Leiden,
  equivalência numérica de ANI nem a renderização TSV. Esses contratos
  adicionais continuam sendo trabalho em andamento.

## Certificados integrados e testes ampliados

Esta entrada supera as pendências acima sobre integração dos certificados.

- `clique_certificate.bend` foi criado: `Clique`, `Row`, checadores executáveis,
  `sound` universal e exemplos negativos de encadeamento. `--verdict` passou
  com **ALL PROOFS CHECK / exit 0** em Lean 4.34.0.
- `cluster.bend` agora clona o grafo filtrado antes do algoritmo, confere
  clique no modo complete e partição em todos os modos, inclusive grafo vazio.
  A renderização só é chamada depois de obter os certificados.
- Recompilado e executado `python3 tools/validate.py cluster-tests --full`:
  **98/98 idênticos após integrar ambos os certificados**. Evidência:
  `evidence/cluster-certified-equivalence-98.json`. A correção de numeração
  de Leiden permaneceu; a integração não mudou os arquivos esperados.
- `proofs/Forest.lean`: prova geral por indução forte de que uma floresta com
  pais adjacentes, rank decrescente e raiz preservada induz caminhos à raiz.
  Também prova que fechamento das arestas implica equivalência entre igualdade
  de raízes e conectividade (single linkage). Verificado com `lean`, exit 0.
  Sem axiomas adicionados, `sorry`, `native_decide` ou mathlib.
- `tests/verify_clusters.py`: verificador independente da saída TSV, não
  reexecuta o algoritmo. Confere partição dos identificadores, conectividade,
  e contrato por algoritmo. Emite pais/ranks/raízes e hashes em JSON. O parser
  e os checks finitos em Python não foram formalmente verificados; essa é a
  fronteira explícita entre a prova Lean e os arquivos reais.
- Verificados 18 resultados reais (6 algoritmos × exemplo/1000/completo), todos
  aprovados. `evidence/semantic-contracts.json` resume; `*.forest.json` contém
  os certificados concretos. No completo: single6373, complete7181, uclust6890,
  cd-hit6890, set-cover6618 e leiden6766 grupos para10021 identificadores.

### CLI durável e validação

- `run.py` e `tools/capped.sh`: build por hash da fonte/compilador, limite8G
  para build,3G para execução e10G agregado, sem swap. `-t` vira opção RTS.
  Previne output igual/alias de input, incluindo IDs e certificado. Opções
  repetidas são recusadas para não haver divergência de parsing nos guardas.
- `run.py cluster`: executa em diretório temporário ao lado da saída e só
  publica o TSV depois de passar no verificador semântico. Emite sidecar
  `.certificate.json`. O par TSV/JSON não é atomicamente publicado junto;
  consumidores devem comparar o hash do TSV. Teste integrado ainda pendente
  no instante desta entrada, conferir registro posterior.
- `tools/validate.py`: entradas limitadas para check/build/proofs/guards/testes
  e benchmark. A ação proofs também registra stdout, hash e comando em JSON.
- `tests/certificate_runtime.bend`: injeta rótulos fora do intervalo e um
  agrupamento complete sem aresta na própria função de produção.
- `tests/test_certificates.py`: TSVs adversariais para garantir rejeição de
  duplicatas, omissões, nomes desconhecidos, componentes partidos, grupos
  desconexos e complete/star inválidos. Ainda por executar nesta entrada.
- `tests/test_align.py`: comparação das duas saídas (ANI e IDs), incluindo
  formatos lite/complete e parâmetros. No momento14 casos menores passaram;
  o caso full está em execução. Não contar full antes do encerramento.
- `tests/reference_data.py`: preserva referências antigas em `.work/references`
  e as regenera com Vclust se faltarem. Usado pelos testes de cluster/align.
  Referências e FASTAs com hashes em `evidence/reference-inputs.json`.
- `tests/test_prefilter.py`: timeout por processo/grupo, cache durável,
  gravação de referência em `.partial` antes de rename. O caso k30 foi separado
  da suíte padrão: Vclust/Kmer-db travou também em reprodução isolada, timeout
  de30s/exit124. Não é evidência de bug no Bend. A suíte padrão completa terminou
  **42/42 idênticos**, hashes preservados em `evidence/prefilter-equivalence-42.json`.
- `benchmark.py`: pipeline sequencial Vclust/Bend,1e12threads, saídas em pasta
  única por execução, wall/RSS por GNU time, hashes das quatro saídas. Clusty
  não aceita `-t`, então o parâmetro só é enviado ao Vclust prefilter/align.
  Benchmark ainda por executar nesta entrada; não inventar tempos.
- `align.bend`: apenas comentário corrigido para apontar ao launcher real
  `run.py align -t N`, substituindo o inexistente `align.py`.
- `README.md`: instruções reproduzíveis, tabela precisa de garantias/limites,
  recursos suportados e distinção do frontend antigo.

### Registro de decisões e limites

O benchmark mede o nativo Bend com guardas de partição/clique, excluindo o
verificador externo Python e o build. Não confundir com custo do launcher
completo. Os tempos são amostras únicas de desktop. Testes diferenciais não
provam igualdade universal; os certificados cobrem propriedades do grafo
fornecido e não provam ANI, ausência de falsos negativos ou ótimo de Leiden.
Não foi modificado o compilador. Não houve commit/push/publicação externa.

### Fechamento parcial das verificações,16:44CET

- Provas reexecutadas sem depender do env.sh: `BEND_REPO=... python3
  tools/validate.py proofs`,exit0. Dois `ALL PROOFS CHECK` e Forest.lean
  aprovado. Registros completos em `evidence/proof-verdicts.json`.
- A primeira suíte align teve14/15 casos idênticos: full com1worker atingiu
  timeout600s. Processo/grupo encerrado; memória observada~355MiB,CPU~100%.
  Evidência preservada em `evidence/align-single-thread-attempt.json`.
  Não houve divergência de valores observada nesse caso: não terminou.
- Adicionado `--threads` ao teste de align para verificar12workers.
  O benchmark aceita relatório separado e timeout1200s por estágio.
- `tests/test_cli.py`: cobertura do launcher completo, seis algoritmos com
  e sem representantes, hashes dos certificados e preservação de inputs/
  output anterior em erros. Ainda pendente de execução neste instante.
- `tools/handoff_manifest.py` gera inventário completo e patch contra o
  backup original:25arquivos novos,4modificados,0removidos,16inalterados
  na primeira execução. Regenerar ao terminar qualquer alteração.

### Guardas e launcher aprovados

- `python3 tools/validate.py guards` terminou exit0: os dois probes nativos
  deram `True{}` (ambos os resultados inválidos foram recusados). Registro
  posterior em `evidence/native-guards.json`, identificado como observação
  após o comando. A próxima execução do script grava stdout automaticamente.
- A suíte adversarial tem agora12casos, todos aprovados; também recusa nome
  de algoritmo desconhecido. Evidência `certificate-negative-tests.json`.
- `BEND_REPO=... python3 tools/validate.py cli-tests` terminou exit0 sem o
  env.sh antigo: três etapas,6algoritmos com/sem representantes, sidecars com
  hash correto, parâmetros inválidos preservando saída anterior e bloqueio
  de outputs que aliasam inputs. Registro em `evidence/cli-integration.json`.
- Ação benchmark agora aceita `--threads` para executar a matriz efetivamente
  desejada: stratified1000 em1/12workers, full em12. Cada invocação grava um
  JSON separado, sem apagar a anterior. O benchmark registra plataforma,
  hash dos executáveis e a ordem fixa Vclust→Bend, sem esvaziar page cache.
- Nova suíte `align-tests --full --threads12` em andamento;14casos menores
  já passaram. Memória observada do full~438MiB após o paralelismo começar.

- `run.py` recebeu trava global de build (`.work/build.lock`) e publicação
  do binário por rename após compilação em diretório temporário. Evita builds
  simultâneos e cache parcialmente escrito, problema pertinente à duplicação
  das sessões anteriores. `--build-only` no cache existente passou.

### Alinhamento completo aprovado e início das medidas

- `align-tests --full --threads 12` terminou com **15/15 casos idênticos**,
  conferindo ANI e IDs, inclusive o EarlyVir completo de 10.021 genomas.
  Evidência persistida em `evidence/align-equivalence-15.json`. O timeout
  anterior de 600 s em 1 worker foi preservado como resultado separado.
- Primeiro benchmark, 1.000 genomas/1 worker: Vclust 8,01/10,76/0,24 s;
  Bend 3,48/22,68/0,03 s (prefilter/align/cluster). As quatro saídas coincidem.
  Soma Vclust 19,01 s, Bend 26,19 s. JSON com comandos/RSS/hashes:
  `evidence/benchmark-stratified1000-t1.json`.
- A rodada 1.000/12 já passou: Vclust 8,04/4,45/0,20 s; Bend 1,40/7,94/0,03 s,
  com quatro saídas iguais. O mesmo processo ainda mede o conjunto completo.
- Fronteira de medição: Vclust inclui seu CLI Python oficial, Bend é executado
  como binário nativo, sem run.py nem checker externo. A diferença de cluster
  inclui inicialização Python; não alegar aceleração do kernel pelo fator bruto.
  `tools/measure_certified_cluster.py` medirá o comando certificado completo
  separadamente após terminar a rodada. `tools/validate.py certified-timings`
  executa essa medida sob teto de 3 GiB.
- `tools/certify_existing.py` e ação `semantics` tornam reproduzível a geração
  dos 18 certificados reais, agora incluindo hash do arquivo IDs e thresholds.
  Será executado depois das medidas para não competir por CPU.
