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
