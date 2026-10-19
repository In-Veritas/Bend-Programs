# Comparação: String versus nucleotídeos compactados em U32

Experimento isolado: os arquivos de produção na raiz do pacote não são
modificados. `baseline/` contém uma cópia da implementação atual; `packed/`
contém os mesmos seis algoritmos com uma representação diferente das bases.
Os hashes dos arquivos de origem estão em `source_hashes.json`.
As tabelas medidas e a interpretação estão em [RESULTADOS.md](RESULTADOS.md).

## O que muda

- A/C/G/T usam 2 bits por base, 16 bases por `U32`.
- Uma sequência com ambiguidades IUPAC usa 4 bits por base, 8 bases por `U32`.
  Símbolos diferentes continuam diferentes; `N` não vira um curinga.
- Cada sequência guarda um `Array<U32>`, largura dos códigos e comprimento real.
  A última palavra tem preenchimento zero, ignorado nas comparações e na saída.
- A conversão acontece uma vez por registro, após a normalização do FASTA.
  Não é um novo formato de arquivo: a entrada e a saída continuam sendo FASTA.
- As sequências completas em texto são descartadas após a conversão. Os
  representantes são decodificados somente na escrita.
- O alinhamento continua sendo a mesma programação dinâmica global: custo de
  edição mínimo, desempate por maior número de bases iguais e os mesmos
  denominadores de identidade. Nenhum filtro de similaridade foi acrescentado.
- O laço interno recebe uma palavra e extrai suas 16 ou 8 bases em registradores,
  com máscaras e deslocamentos. Não consulta o array de bases a cada célula.
- A clonagem necessária às interfaces afins usa `Array.clone`; não usamos
  `Array.fork`, efeitos externos novos ou `@unsafe`.

Há duas limitações deliberadas nesta primeira integração: o reverso complementar
é produzido decodificando, complementando e empacotando novamente; o filtro de
3-mers do CD-HIT decodifica suas entradas para preservar exatamente o hash
ASCII anterior. Seus custos entram nas medições. O modo direto
`CLUSTER_DNA=0` é rejeitado explicitamente pela variante compactada; este
experimento cobre DNA/RNA, incluindo todo o alfabeto IUPAC aceito pelo launcher.

`alignment_cursor.bend` preserva a primeira tentativa: ela criava um cursor a
cada base. `results/pilot.json` registra esse ensaio exploratório, de uma única
medição por caso. A versão medida nas séries finais usa `alignment.bend`, que
processa blocos e evita esse custo por base. O piloto não deve ser misturado
estatisticamente com as séries finais.
Para reproduzir essa implementação inicial, use `prepare.py --alignment cursor`;
para voltar à versão por blocos, use `prepare.py` sem essa opção e valide de novo.

## Arquivos e reprodução

- `prepare.py`: copia a produção e gera a variante compactada com substituições
  verificadas. Atualiza os snapshots; não execute antes de arquivar resultados
  antigos se os arquivos de produção tiverem mudado.
- `packing.bend`: codificação, cópia afim, leitura de blocos e decodificação.
- `alignment.bend`: alinhador que consome palavras compactadas.
- `validate.py`: executa os testes originais nas duas versões e compara
  roundtrips e valores exatos de identidade com uma referência Python.
- `benchmark.py`: compila, aquece, mede processos nativos e verifica suas saídas.
- `inputs/`: entradas sintéticas reprodutíveis e casos de fronteira das palavras.
- `results/`: medições individuais, medianas, CSVs e logs de validação.

Execute da raiz do pacote de clustering. Requer Bun, Clang, Python 3.10+ e os
dados já baixados em `datasets/public_viromes/ready/`.

```sh
python3 experiments/packed_sequences/prepare.py
python3 experiments/packed_sequences/validate.py
python3 experiments/packed_sequences/benchmark.py \
  --datasets synthetic64_128 vclust_prefix1000 --result main
python3 experiments/packed_sequences/benchmark.py \
  --datasets canu_short8 --algorithms single-linkage uclust cd-hit \
  --repeats 3 --result canu
python3 experiments/packed_sequences/benchmark.py \
  --datasets wtdbg2_short8 --algorithms single-linkage --repeats 3 --result wtdbg2
python3 experiments/packed_sequences/benchmark.py \
  --datasets storage1024_2048 --algorithms load-only --result load
python3 experiments/packed_sequences/benchmark.py \
  --datasets vclust_prefix1000 --algorithms single-linkage cd-hit \
  --repeats 3 --reverse --result reverse
python3 experiments/packed_sequences/summarize.py
```

`BEND_REPO` seleciona outro checkout. Sem essa variável, é usado o mesmo
descobrimento de compilador do launcher de produção. Para executar diretamente
um snapshot, passe `--compiler /caminho/para/bend` ao seu `run.py` ou defina
`BEND_REPO`, pois sua profundidade na árvore de diretórios é diferente.

## Método de medição

Executáveis C com Clang `-O2`, uma thread, GPU desligada. Identidade de 95%,
resolução Leiden 0,5 e seed 42. A série principal usa somente a orientação
fornecida; a série `reverse` também considera o reverso complementar.

Cada combinação recebe um aquecimento por variante, seguido de cinco medições
na série principal e no teste de leitura, ou três nas séries complementares.
A ordem baseline/packed é embaralhada com seed fixa a cada repetição. Os
processos rodam sequencialmente. A compilação e o launcher Python não entram
nos tempos; leitura, conversão, clustering e escrita de TSV/FASTA entram.

O tempo é de parede do processo filho. `os.wait4` fornece o pico de RSS desse
processo: memória residente, não tamanho do arquivo nem capacidade virtual do
heap. No macOS, `ru_maxrss` já vem em bytes; no Linux, é convertido de KiB.
Relatamos medianas, com valores individuais e mínimos/máximos disponíveis nos
arquivos. Os hashes de TSV e de representantes devem coincidir entre variantes
e repetições; uma divergência interrompe o benchmark.

O caso `load-only` lê 1.024 registros de 2.048 bases, preserva todos como
representantes e reescreve o FASTA: **não executa clustering**. Isso observa o
custo de leitura, armazenamento e saída sem a programação dinâmica quadrática.
Seu RSS inclui temporários do parser; não mede apenas as bases já compactadas.

As entradas reais são subconjuntos pequenos e enviesados por comprimento.
O exemplo Vclust contém fragmentos de 1.000 bases de referências e variantes
simuladas. Os resultados não caracterizam viromas inteiros nem execução em GPU.
As medições de desempenho usam A/C/G/T; o modo de quatro bits é coberto pelos
testes de correção, não por uma série própria de desempenho.
