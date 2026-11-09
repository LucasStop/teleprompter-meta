#!/usr/bin/env bash
# Verifica se a cobertura de testes no núcleo do Teleprompter atinge o limiar mínimo.
# Uso: tools/coverage-gate.sh [caminho/para/Test.xcresult]
# Variáveis de ambiente:
#   COVERAGE_MIN: percentual mínimo ponderado por grupo (padrão: 80)
set -euo pipefail

RESULT_BUNDLE="${1:-${RESULT_BUNDLE:-}}"

if [ -z "$RESULT_BUNDLE" ]; then
    if [ -d "build/Test.xcresult" ]; then
        RESULT_BUNDLE="build/Test.xcresult"
    elif [ -d "build.noindex/Test.xcresult" ]; then
        RESULT_BUNDLE="build.noindex/Test.xcresult"
    else
        echo "Erro: nenhum bundle .xcresult encontrado. Especifique o caminho como argumento ou gere com xcodebuild test -enableCodeCoverage YES -resultBundlePath build/Test.xcresult" >&2
        exit 1
    fi
fi

if [ ! -d "$RESULT_BUNDLE" ]; then
    echo "Erro: bundle '$RESULT_BUNDLE' não encontrado." >&2
    exit 1
fi

COVERAGE_MIN="${COVERAGE_MIN:-80}"

python3 - "$RESULT_BUNDLE" "$COVERAGE_MIN" << 'EOF'
import json
import os
import subprocess
import sys

bundle_path = sys.argv[1]
coverage_min = float(sys.argv[2])

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..")) if "__file__" in globals() else os.getcwd()

# Obter relatório de cobertura em JSON via xcrun xccov
cmd = ["xcrun", "xccov", "view", "--report", "--json", bundle_path]
try:
    raw_output = subprocess.check_output(cmd)
    report = json.loads(raw_output)
except Exception as e:
    print(f"Erro ao ler relatório xcresult: {e}", file=sys.stderr)
    sys.exit(1)

# Encontrar o alvo do aplicativo (Teleprompter.app)
app_target = None
for target in report.get("targets", []):
    name = target.get("name", "")
    if not name.endswith(".xctest") and "Teleprompter" in name:
        app_target = target
        break

if not app_target and report.get("targets"):
    app_target = report["targets"][0]

if not app_target:
    print("Erro: nenhum target encontrado no relatório de cobertura.", file=sys.stderr)
    sys.exit(1)

# Mapear arquivos do target por nome de arquivo
files_in_report = {}
for f in app_target.get("files", []):
    fname = f.get("name")
    if fname:
        files_in_report[fname] = f

# Definir grupos do núcleo
# 1. detector: QuestionDetector.swift, PauseQuestionDetector.swift
# 2. retrieval: todos os arquivos em Teleprompter/Retrieval/
# 3. formatter: ResponseFormatter.swift, LensFormatter.swift
retrieval_dir = os.path.join(repo_root, "Teleprompter", "Retrieval")
retrieval_files = []
if os.path.isdir(retrieval_dir):
    retrieval_files = sorted([f for f in os.listdir(retrieval_dir) if f.endswith(".swift")])
if not retrieval_files:
    retrieval_files = ["Embedder.swift", "IndexedChunk.swift", "LocalRetriever.swift", "MaterialFileSource.swift", "MaterialImporter.swift", "MaterialIndexable.swift", "Retriever.swift"]

GROUPS = {
    "detector": ["QuestionDetector.swift", "PauseQuestionDetector.swift"],
    "retrieval": retrieval_files,
    "formatter": ["ResponseFormatter.swift", "LensFormatter.swift"]
}

col_grp = 12
col_file = 32
col_cov = 10
col_exec = 12
col_pct = 11

sep_line = "-" * (col_grp + col_file + col_cov + col_exec + col_pct + 12)

print("\n=== GATE DE COBERTURA (Núcleo Teleprompter) ===")
print(f"Limiar mínimo configurado (COVERAGE_MIN): {coverage_min:.1f}%\n")
print(f"{'Grupo':<{col_grp}} | {'Arquivo':<{col_file}} | {'Cobertas':>{col_cov}} | {'Executáveis':>{col_exec}} | {'Cobertura':>{col_pct}}")
print(sep_line)

any_failed = False
group_results = {}

for group_name, expected_files in GROUPS.items():
    total_covered = 0
    total_exec = 0

    for fname in expected_files:
        finfo = files_in_report.get(fname)
        if finfo:
            cov_lines = finfo.get("coveredLines", 0)
            exec_lines = finfo.get("executableLines", 0)
            pct_str = f"{(cov_lines / exec_lines * 100.0):.2f}%" if exec_lines > 0 else "N/A"
        else:
            cov_lines = 0
            exec_lines = 0
            pct_str = "N/A"

        total_covered += cov_lines
        total_exec += exec_lines
        print(f"{group_name:<{col_grp}} | {fname:<{col_file}} | {cov_lines:>{col_cov}} | {exec_lines:>{col_exec}} | {pct_str:>{col_pct}}")

    group_pct = (total_covered / total_exec * 100.0) if total_exec > 0 else 100.0
    passed = group_pct >= coverage_min
    status = "APROVADO" if passed else "REPROVADO"
    if not passed:
        any_failed = True

    group_results[group_name] = {
        "covered": total_covered,
        "executable": total_exec,
        "percentage": group_pct,
        "passed": passed
    }

    subtotal_label = f"TOTAL ({group_name})"
    pct_formatted = f"{group_pct:.2f}% [{status}]"
    print(f"{group_name:<{col_grp}} | {subtotal_label:<{col_file}} | {total_covered:>{col_cov}} | {total_exec:>{col_exec}} | {pct_formatted:>{col_pct}}")
    print(sep_line)

print("\nResumo por grupo:")
for group_name, res in group_results.items():
    status_icon = "✓" if res["passed"] else "✗"
    print(f"  [{status_icon}] {group_name:<10}: {res['percentage']:6.2f}% ({res['covered']}/{res['executable']} linhas) (mínimo: {coverage_min:.1f}%)")

if any_failed:
    print(f"\nERRO: Um ou mais grupos ficaram abaixo do limiar de {coverage_min:.1f}%!\n", file=sys.stderr)
    sys.exit(1)
else:
    print(f"\nSUCESSO: Todos os grupos do núcleo atingiram o limiar mínimo de {coverage_min:.1f}%!\n")
    sys.exit(0)
EOF
