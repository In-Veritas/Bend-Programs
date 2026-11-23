# Resultados da comparação

Data: 2026-10-15. Compilador Bend `014ccd03c43270c151f46679075f7f04593077ea`.
Sistema: `macOS-26.3.1-arm64-arm-64bit-Mach-O`, arquitetura `arm64`.
Clang: `Apple clang version 17.0.0 (clang-1700.6.4.2)`. Bun: `1.3.14`.

Comparação entre a representação original em String e a versão compactada por
blocos. Tempos abaixo são medianas de processos C, com uma thread e GPU
desligada. A conversão de FASTA para palavras compactadas está incluída.
Percentual positivo significa que a variante compactada demorou mais.

## Resultado principal

Não houve uma aceleração consistente da suíte nem redução relevante do pico de
memória neste protótipo. Houve ganho pontual em Leiden, empate aproximado nos
casos de single linkage com contigs reais e regressões em UCLUST/CD-HIT.
O teste de leitura/escrita ficou mais lento e seu pico de RSS foi ligeiramente
maior. A representação compactada permanece isolada para novos experimentos;
estes resultados não justificam substituir a implementação de produção.

## Correção

- 22 testes originais passaram em cada variante, incluindo execução C e JS.
- 47 registros de roundtrip cobrem limites de palavras,
  comprimentos até 30.000 bases, RNA e ambiguidades IUPAC.
- 1681 pares de sequências foram comparados
  com a referência Python em cada backend, variante e opção de orientação.
- Todos os TSVs e FASTAs de representantes das repetições medidas coincidiram
  byte a byte entre as variantes.

## Seis algoritmos — cinco repetições após aquecimento

| Entrada | Algoritmo | Original (s) | Compactado (s) | Tempo compactado | RSS original / compactado (MiB) |
| --- | --- | ---: | ---: | ---: | ---: |
| synthetic64_128 | single-linkage | 0.7162 | 0.7353 | +2.7% | 2.11 / 2.11 |
| synthetic64_128 | complete-linkage | 0.7165 | 0.7210 | +0.6% | 2.11 / 2.12 |
| synthetic64_128 | uclust | 0.1825 | 0.1894 | +3.8% | 2.08 / 2.11 |
| synthetic64_128 | set-cover | 0.7142 | 0.7224 | +1.1% | 2.09 / 2.12 |
| synthetic64_128 | cd-hit | 0.0370 | 0.0419 | +13.2% | 2.11 / 2.16 |
| synthetic64_128 | leiden | 0.8331 | 0.8162 | -2.0% | 2.31 / 2.33 |
| vclust_prefix1000 | single-linkage | 1.4156 | 1.4186 | +0.2% | 2.30 / 2.33 |
| vclust_prefix1000 | complete-linkage | 1.4150 | 1.3937 | -1.5% | 2.30 / 2.34 |
| vclust_prefix1000 | uclust | 1.5007 | 1.5704 | +4.6% | 2.30 / 2.31 |
| vclust_prefix1000 | set-cover | 1.4118 | 1.3904 | -1.5% | 2.30 / 2.34 |
| vclust_prefix1000 | cd-hit | 0.5132 | 0.5638 | +9.9% | 2.33 / 2.36 |
| vclust_prefix1000 | leiden | 1.7644 | 1.6136 | -8.5% | 2.36 / 2.42 |

O conjunto sintético tem 64 registros de 128 bases, com oito famílias e
duplicatas/mutações. O exemplo Vclust tem 12 fragmentos de 1.000 bases; nessa
configuração de 95% não há redução para menos de 12 representantes.

## Contigs reais inteiros — três repetições após aquecimento

| Entrada | Algoritmo | Original (s) | Compactado (s) | Tempo compactado | RSS original / compactado (MiB) |
| --- | --- | ---: | ---: | ---: | ---: |
| canu_short8 | single-linkage | 4.9153 | 4.8972 | -0.4% | 2.78 / 2.77 |
| canu_short8 | uclust | 5.2458 | 5.5388 | +5.6% | 2.77 / 2.75 |
| canu_short8 | cd-hit | 4.7382 | 5.0576 | +6.7% | 2.78 / 2.78 |
| wtdbg2_short8 | single-linkage | 16.6624 | 16.5649 | -0.6% | 3.58 / 3.55 |

Canu: oito contigs de 1.909–3.162 bases. wtdbg2: oito contigs de 4.913–5.966
bases. Nenhum foi truncado. Eles são subconjuntos das coleções de viroma
baixadas anteriormente; os dados já passaram por dereplicação na publicação.

## Reverso complementar — três repetições após aquecimento

| Entrada | Algoritmo | Original (s) | Compactado (s) | Tempo compactado | RSS original / compactado (MiB) |
| --- | --- | ---: | ---: | ---: | ---: |
| vclust_prefix1000 | single-linkage | 2.7850 | 2.7927 | +0.3% | 2.30 / 2.33 |
| vclust_prefix1000 | cd-hit | 1.1238 | 1.2394 | +10.3% | 2.33 / 2.36 |

## Leitura e escrita sem clustering — cinco repetições após aquecimento

| Entrada | Algoritmo | Original (s) | Compactado (s) | Tempo compactado | RSS original / compactado (MiB) |
| --- | --- | ---: | ---: | ---: | ---: |
| storage1024_2048 | load-only | 0.2644 | 0.3463 | +31.0% | 51.25 / 52.31 |

Aqui são 1.024 registros de 2.048 bases (2.097.152 bases). O programa lê,
armazena e reescreve todos os registros; não alinha nem agrupa sequências.
O conteúdo A/C/G/T requer teoricamente 524.288 bytes com dois bits por base,
contra 2.097.152 bytes em ASCII, antes de estruturas, cabeçalhos e temporários.
Isso **não** equivale à redução do RSS: o pico também inclui o parser de texto,
as estruturas do runtime e a saída.

## Interpretação e limites

Os resultados são deste protótipo, destes dados e desta máquina. A troca de
representação preserva as saídas, mas não elimina a programação dinâmica
quadrática. As consultas/escritas à linha de DP continuam presentes em ambas
as versões. A variante compactada ainda paga por conversão, clonagem de arrays,
decodificação do filtro CD-HIT e construção do reverso complementar.

Diferenças pequenas não demonstram ganho estatisticamente significativo.
Não foram medidas GPU, concorrência, viromas completos ou um formato binário
persistente. Nenhum dos algoritmos de produção foi substituído.
As séries de desempenho usam A/C/G/T; a representação de quatro bits para
ambiguidades foi validada quanto à correção, mas não tem uma série de tempos.

As observações individuais, tempos de CPU, picos RSS, hashes de entradas/saídas
e hashes das fontes estão nos JSONs. Os CSVs incluem mínimos e máximos dos
tempos. Os pilotos de uma medição ficam separados das séries finais.

## Reexecução em Linux x86_64 com Bend 2.0.40 (2026-11-23)

Compilador Bend `6b806192284fc9c64404d9b0b59c937f568d87ec` (2.0.40), Linux
x86_64 com 12 threads, Ubuntu clang 21.1.8 e Bun 1.3.14. A carga média ficou
entre 1,2 e 2,8 porque outros processos rodavam na máquina. Os comandos do
README foram usados com `--result linux_bend_2.0.40/<série>`. Os JSON/CSV
novos e os logs de `validate.py` estão em `results/linux_bend_2.0.40/`; os
arquivos originais acima não foram alterados.

- `validate.py`: os 22 testes passaram em cada variante, assim como
  roundtrips e escores exatos em C e JS.
- Todos os hashes de TSV e de representantes das 19 combinações medidas
  coincidem byte a byte com os registrados na execução macOS/014ccd03.
- Os tempos absolutos são cerca de 2,4× maiores nesta máquina. Ao contrário
  do macOS arm64, a variante compactada foi 0,7–17,5% **mais rápida** em todos os
  casos de clustering; o teste `load-only` continua mais lento (+22%).
- Um A/B com single-linkage em `vclust_prefix1000`, na mesma máquina e com o
  Bend 2.0.38 (`de26a917`), deu os mesmos tempos com os dois compiladores
  (baseline 3,38–3,42 s; compactado 2,97–3,39 s). A diferença de sinal se
  deve, portanto, à arquitetura/máquina, não à versão do Bend.
- O RSS de cerca de 23 MiB registrado nesses JSON não é comparável: no Linux,
  `ru_maxrss` conserva através do `exec` o pico do processo Python que fez
  o fork.

| Entrada | Algoritmo | Original (s) | Compactado (s) | Tempo compactado | macOS original / compactado (s) |
| --- | --- | ---: | ---: | ---: | ---: |
| synthetic64_128 | single-linkage | 1.7659 | 1.5964 | -9.6% | 0.7162 / 0.7353 |
| synthetic64_128 | complete-linkage | 1.7795 | 1.5665 | -12.0% | 0.7165 / 0.7210 |
| synthetic64_128 | uclust | 0.4157 | 0.3853 | -7.3% | 0.1825 / 0.1894 |
| synthetic64_128 | set-cover | 1.7913 | 1.5623 | -12.8% | 0.7142 / 0.7224 |
| synthetic64_128 | cd-hit | 0.0856 | 0.0850 | -0.7% | 0.0370 / 0.0419 |
| synthetic64_128 | leiden | 1.8201 | 1.6548 | -9.1% | 0.8331 / 0.8162 |
| vclust_prefix1000 | single-linkage | 3.4993 | 3.1225 | -10.8% | 1.4156 / 1.4186 |
| vclust_prefix1000 | complete-linkage | 3.4811 | 3.0180 | -13.3% | 1.4150 / 1.3937 |
| vclust_prefix1000 | uclust | 3.5033 | 3.2002 | -8.7% | 1.5007 / 1.5704 |
| vclust_prefix1000 | set-cover | 3.3396 | 2.9972 | -10.3% | 1.4118 / 1.3904 |
| vclust_prefix1000 | cd-hit | 1.1747 | 1.0784 | -8.2% | 0.5132 / 0.5638 |
| vclust_prefix1000 | leiden | 3.4183 | 3.0688 | -10.2% | 1.7644 / 1.6136 |
| canu_short8 | single-linkage | 12.8430 | 10.6014 | -17.5% | 4.9153 / 4.8972 |
| canu_short8 | uclust | 12.7272 | 11.3253 | -11.0% | 5.2458 / 5.5388 |
| canu_short8 | cd-hit | 10.7885 | 10.1763 | -5.7% | 4.7382 / 5.0576 |
| wtdbg2_short8 | single-linkage | 41.5289 | 35.8895 | -13.6% | 16.6624 / 16.5649 |
| vclust_prefix1000 (reverso) | single-linkage | 6.7050 | 5.8673 | -12.5% | 2.785 / 2.793 |
| vclust_prefix1000 (reverso) | cd-hit | 2.6124 | 2.3815 | -8.8% | 1.124 / 1.239 |
| storage1024_2048 | load-only | 0.4060 | 0.4958 | +22.1% | 0.264 / 0.346 |
