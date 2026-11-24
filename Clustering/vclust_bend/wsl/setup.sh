#!/usr/bin/env bash
# One-time setup of the Bend-vs-Vclust benchmark inside WSL2 (Ubuntu 22.04/24.04)
# on a Windows PC with an NVIDIA GPU. Run from anywhere inside the repo clone:
#   bash Clustering/vclust_bend/wsl/setup.sh
# It asks for sudo only for apt. Re-running is safe (each step is skipped when done).
set -euo pipefail

BEND_COMMIT=6b806192284fc9c64404d9b0b59c937f568d87ec   # bendlang/bend revision the port was verified on
CUDA_PKG=${CUDA_PKG:-cuda-toolkit-12-8}               # Bend accepts CUDA 12 or 13
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
CLU="$REPO/Clustering"
BEND_DIR=${BEND_DIR:-$HOME/bend}
ENV_FILE="$HOME/.bend-vclust-env.sh"

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die() { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

say "Checking WSL and the NVIDIA driver"
grep -qi microsoft /proc/version || echo "warning: this does not look like WSL; continuing anyway"
if ! command -v nvidia-smi >/dev/null && [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
  export PATH="/usr/lib/wsl/lib:$PATH"
fi
command -v nvidia-smi >/dev/null || die "nvidia-smi not found. Install/update the NVIDIA driver on WINDOWS (not inside WSL), then run 'wsl --update' in PowerShell."
nvidia-smi --query-gpu=name,driver_version,power.limit,memory.total --format=csv

say "Installing apt packages (sudo)"
sudo apt-get update -y
sudo apt-get install -y git curl wget unzip build-essential python3 python3-venv python3-pip ca-certificates

say "Checking clang (Bend needs clang 19+ for GPU builds)"
have_clang=""
for c in clang clang-21 clang-20 clang-19; do
  if command -v "$c" >/dev/null; then
    v=$("$c" --version | grep -oE 'version [0-9]+' | grep -oE '[0-9]+' | head -1)
    if [ "${v:-0}" -ge 19 ]; then have_clang="$c ($v)"; break; fi
  fi
done
if [ -z "$have_clang" ]; then
  sudo apt-get install -y clang-19 2>/dev/null || {
    echo "clang-19 not in this Ubuntu's archive; using apt.llvm.org"
    wget -qO /tmp/llvm.sh https://apt.llvm.org/llvm.sh && sudo bash /tmp/llvm.sh 19
  }
  have_clang="clang-19"
fi
echo "using $have_clang (Bend picks the newest clang-NN on PATH automatically)"

say "Checking the CUDA toolkit (NVRTC headers)"
if [ ! -f /usr/local/cuda/include/nvrtc.h ]; then
  # NVIDIA's WSL-Ubuntu repository ships the toolkit WITHOUT a Linux driver (the
  # Windows driver is used). Never install a 'cuda-drivers' or 'nvidia-driver' package in WSL.
  wget -qO /tmp/cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i /tmp/cuda-keyring.deb
  sudo apt-get update -y
  sudo apt-get install -y "$CUDA_PKG"
fi
ls /usr/local/cuda/include/nvrtc.h

say "Installing Bun (runs the Bend compiler from source)"
if [ ! -x "$HOME/.bun/bin/bun" ]; then
  curl -fsSL https://bun.sh/install | bash
fi
"$HOME/.bun/bin/bun" --version

say "Fetching the Bend source at $BEND_COMMIT"
if [ ! -d "$BEND_DIR/.git" ]; then
  git clone https://github.com/bendlang/bend "$BEND_DIR"
fi
git -C "$BEND_DIR" fetch -q origin
git -C "$BEND_DIR" checkout -q "$BEND_COMMIT"
git -C "$BEND_DIR" log -1 --format='%h %s'

say "Installing Vclust 1.3.1 (the reference) into Clustering/.tools/"
PYTHON=python3 "$CLU/benchmark/install_vclust.sh" | tail -4

say "Writing $ENV_FILE"
mkdir -p "$CLU/vclust_bend/.work"
cat > "$ENV_FILE" <<EOF
# Bend vs Vclust benchmark environment (written by Clustering/vclust_bend/wsl/setup.sh)
export BEND_REPO="$BEND_DIR"
export BEND_NO_TELEMETRY=1
export PATH="\$HOME/.bun/bin:/usr/lib/wsl/lib:/usr/local/cuda/bin:\$PATH"
export CUDA_HOME=/usr/local/cuda
export BENCH_LOCK="$CLU/vclust_bend/.work/bench.lock"
bend() { bun "\$BEND_REPO/bend2/main.ts" "\$@"; }
EOF
# shellcheck disable=SC1090
. "$ENV_FILE"

say "Smoke test: CPU build and GPU build of a tiny Bend program"
T=$(mktemp -d)
cat > "$T/pow2.bend" <<'EOF'
import Base

def pow2(+n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      a b = pow2(p) pow2(p)
      (a + b : U32)

def main() -> IO(Unit):
  IO.print(U32.show(pow2!(20n)))
EOF
bun "$BEND_REPO/bend2/main.ts" "$T/pow2.bend" -o "$T/pow2"
ls -la "$T"/pow2*
echo -n "GPU run (expects 1048576): "; "$T/pow2"
echo -n "CPU run (expects 1048576): "; "$T/pow2" +RTS --gpu off -RTS
[ -f "$T/pow2.gpu" ] && echo "GPU program built: OK" || echo "WARNING: no .gpu file was produced; check CUDA/clang above"
rm -rf "$T"

say "Done. Next:  bash Clustering/vclust_bend/wsl/run_bench.sh [path/to/all_clean_contigs.fasta]"
