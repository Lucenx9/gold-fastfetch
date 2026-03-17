#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

command -v lspci >/dev/null 2>&1 || { echo "N/A (lspci missing)"; exit 0; }
out=()

# NVIDIA
if command -v nvidia-smi >/dev/null 2>&1; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && out+=("$line")
  done < <(
    nvidia-smi --query-gpu=name,memory.total,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null |
    awk -F',' '{
      for(i=1;i<=NF;i++){ gsub(/^[ \t]+|[ \t]+$/, "", $i) }
      if($1!=""){
        temp = ($3 != "" && $3 != "N/A") ? $3"°C" : "N/A"
        printf "%s [%.1f GiB] @ %s\n", $1, $2/1024, temp
      }
    }'
  )
fi

# Other GPUs
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ VMware ]] && continue
  if ((${#out[@]} > 0)); then [[ "$line" =~ NVIDIA ]] && continue; fi

  suffix=""
  if [[ "$line" =~ Intel ]] && [[ ! "$line" =~ Arc ]] && [[ ! "$line" =~ DG2 ]]; then
      suffix=" [Shared]"
  fi
  out+=("$line$suffix")
done < <(lspci 2>/dev/null | awk -F': ' '/(VGA|3D|Display)/{print $2}')

if ((${#out[@]} == 0)); then echo "N/A"; else (IFS=' | '; echo "${out[*]}"); fi
