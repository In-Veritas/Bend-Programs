# Rodar o benchmark Bend × Vclust no Windows (WSL2 + GPU NVIDIA)

Mede tempo, memória e energia de três implementações nos mesmos dados:
**Vclust 1.3.1** (referência), **Bend compilado para C** (CPU, 1 thread e todas as
threads) e **Bend na GPU** (CUDA, via chamadas `!`), por etapa (prefilter, align,
cluster) e de ponta a ponta. Toda medição confere que a saída é idêntica, byte a
byte, à do Vclust; uma saída diferente vira `mismatch` e não conta.

## 1. Preparar o Windows (uma vez)

1. Driver NVIDIA atualizado **no Windows** (Game Ready ou Studio). Não instale driver
   NVIDIA dentro do WSL.
2. No PowerShell: `wsl --install -d Ubuntu-24.04` (ou use o Ubuntu que já tem) e
   `wsl --update`.
3. Memória do WSL: por padrão ele usa metade da RAM. Para o dataset grande, crie
   `C:\Users\<você>\.wslconfig` com, por exemplo:

   ```ini
   [wsl2]
   memory=20GB
   processors=16
   ```

   e rode `wsl --shutdown` antes de abrir o Ubuntu de novo. Ajuste aos números do seu PC.

## 2. Baixar a branch e instalar (dentro do Ubuntu/WSL)

Clone dentro do sistema de arquivos do Linux (`~`), **não** em `/mnt/c`: lá o disco é
muito mais lento e distorce os tempos.

```sh
cd ~
git clone -b bend-latest-port https://github.com/In-Veritas/Bend-Programs
cd Bend-Programs
bash Clustering/vclust_bend/wsl/setup.sh
```

O `setup.sh` instala `clang` ≥ 19, o CUDA Toolkit do repositório **WSL-Ubuntu** da
NVIDIA (sem driver), o Bun, o código-fonte do Bend na revisão em que o porte foi
verificado (`6b806192`) e o Vclust 1.3.1. No fim, compila e roda um programa de teste
na CPU e na GPU; as duas linhas devem mostrar `1048576` e aparecer
`GPU program built: OK`.

## 3. Copiar o dataset grande

O `all_clean_contigs.fasta` (299 MB; 91 MB como `.fasta.gz`) não está no repositório,
porque o repositório é público e o arquivo são dados de pesquisa. Baixe-o do Google
Drive no Windows e passe o caminho para o script; ele aceita `.fasta` ou `.fasta.gz`,
descompacta se preciso e copia para `~` se estiver em `/mnt/c` (o disco do Windows é
lento no WSL):

```sh
bash Clustering/vclust_bend/wsl/run_bench.sh /mnt/c/Users/<você>/Downloads/all_clean_contigs.fasta.gz
```

Critério: o script mostra `323556 sequences`.

## 4. Rodar

```sh
cd ~/Bend-Programs
bash Clustering/vclust_bend/wsl/run_bench.sh ~/all_clean_contigs.fasta
```

Sem argumento, roda só o dataset pequeno (`earlyvir_stratified1000`, 1.000 genomas,
3 repetições, ~20–40 min). Com o arquivo grande, o tempo pode ser de horas; o script
mede primeiro a memória do prefilter do Vclust nesse arquivo.

Durante a execução: PC na tomada, feche jogos, navegador com vídeo e qualquer coisa
que use a GPU (a energia da GPU é medida para a placa inteira), e evite usar o PC.

## 5. Devolver os resultados

No fim aparece o caminho de um `bend-vclust-results-<data>.tar.gz` na sua pasta
pessoal do WSL. Mande esse arquivo, ou faça commit de
`Clustering/vclust_bend/evidence/energy/` na branch e dê push. O resumo legível
fica em `Clustering/vclust_bend/evidence/energy/RESULTS.md`.

## Limitações conhecidas no WSL

- **Energia da CPU**: o WSL não expõe o contador RAPL do processador, então essa
  coluna sai como "indisponível" (nunca é estimada).
- **Energia da GPU**: usa o contador de energia da NVIDIA quando o driver o expõe no
  WSL; caso contrário integra a potência medida a cada 100 ms (o registro diz qual
  foi usado em `gpu_energy_source`).
- **Limite de memória por processo**: sem systemd no WSL, o `capped.sh` roda os
  programas sem cgroup e avisa; o limite de memória do próprio WSL (`.wslconfig`)
  protege o Windows.
- "t12" nos nomes das configurações significa "todas as threads da máquina"
  (`nproc`; defina `BENCH_THREADS` para outro valor).
