# Vclust em Bend

Porte nativo das três etapas do Vclust 1.3.1: pré-filtro Kmer-db 2.3.1,
alinhamento LZ-ANI 1.2.3 e seis algoritmos do Clusty 1.2.2. O cálculo das
etapas está em Bend; Python compila, limita memória, executa e verifica a
saída de clustering. Este pacote é separado do frontend antigo `../run.py`.

## Estado da entrega — 23/11/2026

Esta é a cópia isolada dos fontes validados pelo Codex. Outra sessão Claude
voltou a modificar `../vclust_bend/` durante o trabalho. Os arquivos Bend desta
cópia foram reconstruídos do backup/patch e conferidos contra os hashes da
versão testada, preservando o trabalho concorrente na pasta original.

| Validação | Resultado |
| --- | --- |
| Pré-filtro | 42/42 casos idênticos ao Vclust |
| Alinhamento | 15/15 casos, ANI e IDs idênticos, inclusive 10.021 genomas com 12 workers |
| Clustering | 98/98 saídas idênticas, com certificados nativos integrados |
| Contratos semânticos | 18 resultados reais verificados |
| Provas | Partição e clique em BendTT; floresta/componentes em Lean 4.34.0 |

O alinhamento completo com 1 worker atingiu timeout de 600 s. A execução com
12 workers terminou e passou. O caso k=30 do pré-filtro foi excluído do total
por timeout da ferramenta de referência, como descrito abaixo.

Na amostra de 1.000 genomas, somas dos tempos das três etapas:

| Workers | Vclust CLI | Bend nativo |
| --- | ---: | ---: |
| 1 | 19,01 s | 26,19 s |
| 12 | 12,69 s | 9,37 s |

São amostras únicas, em ordem fixa Vclust→Bend e sem limpar page cache. O tempo
Vclust inclui seu CLI Python; Bend foi medido diretamente nos binários, sem
`run.py` nem o verificador Python, incluindo os guardas nativos. O alinhamento
Bend foi mais lento em ambas as configurações da amostra; pré-filtro e cluster
nativo foram mais rápidos. A diferença de cluster inclui custos de inicialização.

**O benchmark completo não terminou.** Seu processo coordenador recebeu SIGTERM;
o alinhamento órfão foi interrompido pelo Codex após detectar outras execuções
e alterações concorrentes. A origem do SIGTERM não foi determinada. Os tempos
parciais estão preservados e marcados como interrompidos; não constituem uma
comparação completa nem invalidam os testes de equivalência anteriores.

## Executar

Requisitos: Linux com systemd de usuário, Python 3.11+, compilador Bend
2.0.40 e compilador C disponíveis. Revisão testada do checkout fonte:
`6b806192284fc9c64404d9b0b59c937f568d87ec`. Não é necessário usar o antigo
scratchpad `/tmp` para executar o pipeline. Na máquina desta retomada:

```bash
cd /home/veritas/Bend-Programs/Clustering/vclust_bend_codex_verified
export BEND_REPO='/home/veritas/Bioinformatique/Higher Order Company/Bend'
mkdir -p results
python3 run.py prefilter -i ../datasets/public_viromes/original/vclust_example.fasta -o results/filter.txt -t 12
python3 run.py align -i ../datasets/public_viromes/original/vclust_example.fasta --filter results/filter.txt -o results/ani.tsv -t 12
python3 run.py cluster -i results/ani.tsv --ids results/ani.ids.tsv -o results/clusters.tsv --algorithm leiden --metric ani --ani 0.95 -t 1
```

`align` também escreve `ani.ids.tsv`. `cluster` publica o TSV depois de
validar seu contrato semântico e grava `clusters.tsv.certificate.json`, com
hashes dos inputs/saída, parâmetros e testemunha de conectividade. O par de
arquivos não constitui uma transação única; compare o hash de saída do
certificado ao TSV ao consumi-los. Identificadores duplicados são recusados
pelo verificador por tornarem o mapeamento ambíguo.

O launcher usa cache em `.work/bin/` com hash dos fontes e compilador.
Uma trava serializa builds e o binário só entra no cache após a compilação.
`--build-only` imprime o executável. `--compiler CAMINHO` substitui
`BEND_REPO`. `-t N` controla os workers Bend por `+RTS --threads N -RTS`;
passar `-t` diretamente ao binário não configura o runtime.

Os processos ficam em `bendwork.slice` (limite agregado 10 GiB, pressão a
9 GiB, sem swap); compilação até 8 GiB, execução até 3 GiB por padrão.
`--memory 4G` altera o limite do processo, mantendo o teto agregado. O
sandbox do Codex precisa autorizar o acesso ao systemd de usuário. Evitar
compilações e benchmarks simultâneos.

## O que as provas garantem

| Evidência | Contrato e limite |
| --- | --- |
| `partition_certificate.bend`, BendTT `--verdict` | Para qualquer lista aceita, há exatamente uma atribuição por posição ativa e todo rótulo é menor que o limite. O certificado é conferido antes de renderizar a saída nativa. Não exige que todos os rótulos possíveis sejam usados. |
| `clique_certificate.bend`, BendTT `--verdict` | Aceitar implica que cada par distinto com mesmo rótulo tem aresta no grafo fornecido. O modo `complete` usa uma cópia do grafo filtrado anterior ao agrupamento. |
| `proofs/Forest.lean`, Lean 4.34.0 | Arestas de pais, raiz preservada e rank estritamente decrescente implicam caminhos à raiz. Com fechamento das arestas, igualdade de raízes equivale a pertencer ao mesmo componente conexo. |
| `tests/verify_clusters.py`, a cada execução do launcher | Confere todos os identificadores exatamente uma vez, constrói/confere uma floresta; exige componentes exatos em `single`, clique em `complete`, centro adjacente a todos em `uclust`/`cd-hit`/`set-cover`, e conectividade em `leiden`. |
| Comparação byte a byte | Exercita a compatibilidade com Vclust nos casos registrados; não é prova universal de equivalência. |

O parser e o verificador Python permanecem na base de confiança: o teorema
Lean prova a implicação matemática a partir das hipóteses verificadas, não
a implementação de Python. Extração dos arrays, IO, renderização, compilador
e runtime também não foram provados de ponta a ponta. Os contratos referem-se
ao **grafo filtrado recebido**, não demonstram ausência de falsos negativos
no pré-filtro, validade biológica do limiar ANI, equivalência numérica
universal do alinhador nem ótimo global de Leiden. `--check-only` verifica
tipos/terminação; o veredicto matemático é `--verdict`.

## Validar e comparar

O Vclust de referência está em `../.tools/vclust-1.3.1/bin/vclust`.
Dados ficam em `../datasets/`. As referências usadas foram copiadas para
`.work/references/`, com hashes em `evidence/reference-inputs.json`.
Os testes regeneram referências ausentes com Vclust; não dependem da
sobrevivência do antigo `/tmp`. Executar sequencialmente:

```bash
python3 tools/validate.py check
python3 tools/validate.py proofs
python3 tools/validate.py guards
python3 tools/validate.py cli-tests
python3 tools/validate.py prefilter-tests --full
python3 tools/validate.py align-tests --full --threads 12
python3 tools/validate.py cluster-tests --full
python3 tools/validate.py semantics
python3 tools/validate.py benchmark --threads 1
python3 tools/validate.py benchmark --full --threads 12
```

`proofs` precisa de Lean 4.34.0 em PATH ou na instalação local registrada
no script. `guards` injeta atribuições/cliques inválidos na função de produção
e testa TSVs adversariais. Os JSONs em `evidence/` registram as execuções
concluídas; `.work/` contém executáveis, saídas e logs intermediários.
O benchmark faz uma amostra sequencial por ferramenta/configuração, com
1 e 12 workers em prefilter/align e comparação das quatro saídas. Exclui
compilação, launcher Bend e verificador Python das medidas; inclui os guardas
nativos. Vclust é medido pelo CLI Python oficial. Só medir desempenho quando
as outras sessões terminarem para evitar concorrência.
Não interpretar uma amostra em desktop como resultado estatístico.

## Escopo e limitações operacionais

- Algoritmos: `single`, `complete`, `uclust`, `cd-hit`, `set-cover`, `leiden`.
  Leiden reproduz PCG32, ordem de somas binary64, desempates, refinamento,
  agregação e projeção do igraph usado pelo Clusty. Não usa Python para calcular
  os grupos. `tests/clusty_model.py` é referência de testes e parser numérico.
- LZ-ANI aceita `1 <= mal <= 16`, `1 <= msl <= 12`, `1 <= aw <= 32`.
  Há validação explícita dos parâmetros suportados; não prometer todos os
  recursos/formats do CLI Vclust (por exemplo diretórios/gzip).
- O leitor de métricas aceita decimais não negativos com limites declarados
  de tamanho; notação exponencial não é suportada. O formato emitido pelo
  alinhador testado está dentro desse domínio.
- Leiden: beta positivo; no máximo 1000 iterações positivas; iterações negativas
  preservam a semântica da versão de igraph empacotada com teto de segurança.
  Limites internos de fila/sorteio/níveis recusam saída ao esgotar o orçamento.
- A checagem nativa de clique é quadrática em pares de vértices, além da busca
  de vizinhança. É um custo de certificação de `complete`, não uma otimização.
- O caso `prefilter -k 30 --min-ident 0.9` não entra no total aprovado:
  Kmer-db de referência travou no exemplo e foi interrompido após 30 s.
  `tests/test_prefilter.py --include-slow-reference` permite tentar novamente
  com timeout; não foi atribuído como bug do Bend.

## Continuidade

Leia `../CLAUDE_HANDOFF.md` e `CLAUDE_HANDOFF.md` antes de retomar.
A fonte herdada está preservada em `../handoff/`; fontes e evidências da
apresentação estão em `../presentation/`. Nada foi commitado ou publicado
por esta retomada.
