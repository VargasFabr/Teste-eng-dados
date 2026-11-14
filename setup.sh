#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

python3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)"
if [[ ! -x .venv/bin/python ]]; then
  python3 -m venv .venv
fi
.venv/bin/python -m pip install -r requirements.txt

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Ambiente pronto. Nesta janela, rode: source setup.sh"
  echo "Depois: dbt seed, dbt run e dbt test."
  exit 0
fi

# shellcheck disable=SC1091
source .venv/bin/activate
