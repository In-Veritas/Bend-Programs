# Agrupando genomas virais em Bend

Apresentação local de 37 slides, recuperada do trabalho do Claude e revisada em
23/11/2026. O design e a ordem dos slides foram preservados. Os slides finais
distinguem referências históricas do estado atual de implementação e validação.

Esta versão incorpora os certificados integrados, 98/98 comparações de cluster,
42/42 de prefiltro e 15/15 de align. O benchmark completo foi interrompido por
concorrência; apenas as amostras de 1.000 genomas foram concluídas. Seus tempos
comparam o CLI Python oficial do Vclust aos executáveis nativos Bend; build,
run.py e verificador Python ficam fora dos tempos Bend. O custo do launcher
certificado não foi medido. Consulte o registro em `CLAUDE_HANDOFF.md`.

Abra `index.html` em um navegador: funciona sem servidor e sem rede. Use as setas,
PageUp/PageDown, Home/End, o seletor de slides ou `F` para tela cheia. O PDF
`agrupando-genomas-virais-em-bend.pdf` contém os mesmos 37 slides.

## Editar e gerar

Edite `slides/*.html` e, quando necessário, `refinements.css`. O arquivo `deck.css`
é o tema original preservado. `deck.json` define a ordem dos slides.

```bash
cd /home/veritas/Bend-Programs/Clustering/presentation
/home/veritas/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node tools/build.mjs
sh tools/render-capped.sh --pdf
```

O segundo comando usa Playwright/Chromium do runtime local do Codex e limita o
navegador a 2 GiB, sem swap, na slice compartilhada `bendwork.slice` de 10 GiB.
Precisa de acesso ao bus do systemd do usuário. Não remova o limite para contornar
erros do sandbox. `PRESENTATION_NODE` e `CODEX_NODE_MODULES` permitem informar outro
Node e outro diretório de módulos. As capturas e o relatório vão para
`/tmp/bend-presentation-qa`; mude com `PRESENTATION_QA`.

## Continuação

O código da entrega está em `../vclust_bend_codex_verified/`, a versão validada
isolada após alterações concorrentes na pasta original. A apresentação registra
equivalência nos casos testados, sem afirmar equivalência universal com o Vclust.
As medições novas concluídas cobrem a amostra de 1.000 genomas.
Leia `CLAUDE_HANDOFF.md` para o histórico preciso, os resultados de revisão, as
fontes das medições e os passos restantes. `evidence/` preserva a apresentação
original, as alterações e os registros recuperados.
