#!/usr/bin/env python3
"""Produce a readable report from the saved measurements, without rerunning."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESULTS = HERE / 'results'


def table(rows):
    lines = ['| Entrada | Algoritmo | Original (s) | Compactado (s) | Tempo compactado | RSS original / compactado (MiB) |',
             '| --- | --- | ---: | ---: | ---: | ---: |']
    for row in rows:
        delta = (row['packed_seconds'] / row['baseline_seconds'] - 1) * 100
        lines.append(f'| {row["dataset"]} | {row["algorithm"]} | {row["baseline_seconds"]:.4f} | {row["packed_seconds"]:.4f} | {delta:+.1f}% | {row["baseline_rss_mib"]:.2f} / {row["packed_rss_mib"]:.2f} |')
    return '\n'.join(lines)


def main():
    reports = {name: json.loads((RESULTS / (name + '.json')).read_text())
               for name in ('main', 'canu', 'wtdbg2', 'load', 'reverse')}
    validation = json.loads((RESULTS/'validation.json').read_text())
    report = reports['main']
    text = f'''# Resultados da comparação

Data: 2026-10-15. Compilador Bend `{report['compiler_revision']}`.
Sistema: `{report['platform']}`, arquitetura `{report['machine']}`.
Clang: `{report['clang']}`. Bun: `{report['bun']}`.

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
- {validation['roundtrip_records']} registros de roundtrip cobrem limites de palavras,
  comprimentos até 30.000 bases, RNA e ambiguidades IUPAC.
- {validation['score_pairs_per_backend_and_strand']} pares de sequências foram comparados
  com a referência Python em cada backend, variante e opção de orientação.
- Todos os TSVs e FASTAs de representantes das repetições medidas coincidiram
  byte a byte entre as variantes.

## Seis algoritmos — cinco repetições após aquecimento

{table(report['summary'])}

O conjunto sintético tem 64 registros de 128 bases, com oito famílias e
duplicatas/mutações. O exemplo Vclust tem 12 fragmentos de 1.000 bases; nessa
configuração de 95% não há redução para menos de 12 representantes.

## Contigs reais inteiros — três repetições após aquecimento

{table(reports['canu']['summary'] + reports['wtdbg2']['summary'])}

Canu: oito contigs de 1.909–3.162 bases. wtdbg2: oito contigs de 4.913–5.966
bases. Nenhum foi truncado. Eles são subconjuntos das coleções de viroma
baixadas anteriormente; os dados já passaram por dereplicação na publicação.

## Reverso complementar — três repetições após aquecimento

{table(reports['reverse']['summary'])}

## Leitura e escrita sem clustering — cinco repetições após aquecimento

{table(reports['load']['summary'])}

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
'''
    (HERE/'RESULTADOS.md').write_text(text)
    print(text)


if __name__ == '__main__':
    main()
