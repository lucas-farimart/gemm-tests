#=============================================================================
# Compara relatórios de síntese entre as implementações
# "only_srams" e "sram_dclb", imprime uma tabela com tabulate
# e gera a tabela equivalente em LaTeX (comp_table.tex).
#-----------------------------------------------------------------------------
# Autor: Lucas Farias Martins
# Email: lucas.martins@ee.ufcg.edu.br
# Data:  26-08-2026
#=============================================================================

import re
from pathlib  import Path
from typing   import Dict, Optional, Tuple
from tabulate import tabulate


REPORTS_DIR = Path("reports")
OUTPUT_TEX  = Path("comp_table.tex")

DESIGNS = {
    "only_srams": {
        "area":   REPORTS_DIR / "only_srams_area.rpt",
        "power":  REPORTS_DIR / "only_srams_power.rpt",
        "qor":    REPORTS_DIR / "only_srams_qor.rpt",
        "timing": REPORTS_DIR / "only_srams_timing.rpt",
    },
    "sram_dclb": {
        "area":   REPORTS_DIR / "sram_dclb_area.rpt",
        "power":  REPORTS_DIR / "sram_dclb_power.rpt",
        "qor":    REPORTS_DIR / "sram_dclb_qor.rpt",
        "timing": REPORTS_DIR / "sram_dclb_timing.rpt",
    },
}

#---------------------------------------------------------------------------
# Utilitarios
#---------------------------------------------------------------------------

def read_report(path: Path) -> str:
    if not path.exists():
        print(f"[AVISO] Arquivo não encontrado: {path}")
        return ""
    return path.read_text(errors="ignore")


def normalize_number(value: str) -> Optional[float]:
    """
    Converte strings como:
        123.45
        1,234.56
        -12.3
        1.2e-03
    para float.
    """
    value = value.strip().replace(",", "")
    match = re.search(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?", value)
    return float(match.group()) if match else None


def find_metric(text: str, patterns) -> Optional[float]:
    """
    Tenta vários padrões regex e retorna o primeiro valor encontrado.
    Cada padrão deve possuir um grupo de captura para o número.
    """
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
        if match:
            value = normalize_number(match.group(1))
            if value is not None:
                return value
    return None


def fmt(value: Optional[float], unit: str = "") -> str:
    if value is None:
        return "N/A"
    return f"{value:.4g}{unit}"


def delta(a: Optional[float], b: Optional[float]) -> Optional[float]:
    if a is None or b is None:
        return None
    return b - a


def percent_delta(a: Optional[float], b: Optional[float]) -> Optional[float]:
    if a is None or b is None or a == 0:
        return None
    return 100.0 * (b - a) / abs(a)


#---------------------------------------------------------------------------
# Parsers
#
# Os padrões abaixo cobrem os formatos mais comuns dos relatórios
# Synopsys/Design Compiler. Se seu .rpt usar nomes diferentes, basta adicionar
# um regex à lista correspondente.
#---------------------------------------------------------------------------

def parse_area(text: str) -> Dict[str, Tuple[Optional[float], str]]:
    return {
        "Total cell area": (
            find_metric(text, [r"Total\s+cell\s+area\s*[:=]\s*([0-9.eE+-]+)",r"Total\s+Area\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "Combinational area": (
            find_metric(text, [r"Combinational\s+area\s*[:=]\s*([0-9.eE+-]+)",r"Combinational\s+Area\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "Noncombinational area": (
            find_metric(text, [r"Noncombinational\s+area\s*[:=]\s*([0-9.eE+-]+)",r"Non-combinational\s+area\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "Number of cells": (
            find_metric(text, [r"Number\s+of\s+cells\s*[:=]\s*([0-9.eE+-]+)",r"Number\s+of\s+leaf\s+cells\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
    }


def parse_power(text: str) -> Dict[str, Tuple[Optional[float], str]]:
    return {
        "Total power": (
            find_metric(text, [r"Total\s+Power\s*[:=]\s*([0-9.eE+-]+)",r"Total\s+power\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "Dynamic power": (
            find_metric(text, [r"Dynamic\s+Power\s*[:=]\s*([0-9.eE+-]+)",r"Dynamic\s+power\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "Cell leakage power": (
            find_metric(text, [r"Cell\s+Leakage\s+Power\s*[:=]\s*([0-9.eE+-]+)",r"Leakage\s+Power\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "Net switching power": (
            find_metric(text, [r"Net\s+Switching\s+Power\s*[:=]\s*([0-9.eE+-]+)",r"Switching\s+Power\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
    }


def parse_qor(text: str) -> Dict[str, Tuple[Optional[float], str]]:
    return {
        "Critical path delay": (
            find_metric(text, [r"Critical\s+Path\s+Delay\s*[:=]\s*([0-9.eE+-]+)",r"Critical\s+path\s+delay\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "Area": (
            find_metric(text, [r"Total\s+cell\s+area\s*[:=]\s*([0-9.eE+-]+)",r"Area\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "WNS": (
            find_metric(text, [r"\bWNS\b\s*[:=]\s*([0-9.eE+-]+)",r"worst\s+negative\s+slack\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "TNS": (
            find_metric(text, [r"\bTNS\b\s*[:=]\s*([0-9.eE+-]+)",r"total\s+negative\s+slack\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
    }


def parse_timing(text: str) -> Dict[str, Tuple[Optional[float], str]]:
    return {
        "WNS": (
            find_metric(text, [r"\bWNS\b\s*[:=]\s*([0-9.eE+-]+)",r"slack\s*\(VIOLATED\)\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "TNS": (
            find_metric(text, [r"\bTNS\b\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
        "Clock period": (
            find_metric(text, [r"Clock\s+Period\s*[:=]\s*([0-9.eE+-]+)",r"Period\s*[:=]\s*([0-9.eE+-]+)",]),"",
        ),
    }

PARSERS = {
    "area": parse_area,
    "power": parse_power,
    "qor": parse_qor,
    "timing": parse_timing,
}

#---------------------------------------------------------------------------
# Leitura dos reports
#---------------------------------------------------------------------------

def collect_results():
    results = {}

    for design, reports in DESIGNS.items():
        results[design] = {}

        for report_type, path in reports.items():
            text = read_report(path)
            results[design][report_type] = PARSERS[report_type](text)

    return results


#---------------------------------------------------------------------------
# Construção da tabela
#---------------------------------------------------------------------------

def build_rows(results):
    rows = []

    # Mantemos as métricas agrupadas por tipo de relatório.
    for report_type in ["area", "power", "qor", "timing"]:
        metrics = set(results["only_srams"][report_type])
        metrics.update(results["sram_dclb"][report_type])

        for metric in metrics:
            a, _ = results["only_srams"][report_type].get(metric, (None, ""))
            b, _ = results["sram_dclb"][report_type].get(metric, ("", ""))

            # Ignora métricas que não foram encontradas em nenhum dos reports.
            if a is None and b is None:
                continue

            d = delta(a, b)
            p = percent_delta(a, b)

            rows.append([
                report_type,
                metric,
                fmt(a),
                fmt(b),
                fmt(d),
                "N/A" if p is None else f"{p:+.2f}%",
            ])

    return rows


def print_table(rows):
    headers = [
        "Report",
        "Metric",
        "only_srams",
        "sram_dclb",
        "Delta",
        "Delta (%)",
    ]

    print("\n" + "=" * 90)
    print("COMPARAÇÃO: only_srams vs sram_dclb")
    print("=" * 90)

    print(
        tabulate(
            rows,
            headers=headers,
            tablefmt="fancy_grid",
            stralign="left",
            numalign="right",
        )
    )


#---------------------------------------------------------------------------
# Geração LaTeX
#---------------------------------------------------------------------------

def latex_escape(text: str) -> str:
    replacements = {
        "\\": r"\textbackslash{}",
        "&": r"\&", "%": r"\%", "$": r"\$", "#": r"\#", "_": r"\_", "{": r"\{", "}": r"\}", 
    }

    for old, new in replacements.items():
        text = text.replace(old, new)

    return text


def generate_latex(rows, output_path: Path):
    headers = [
        "Report",
        "Metric",
        "only\\_srams",
        "sram\\_dclb",
        "Delta",
        "Delta (\\%)",
    ]

    # tabulate gera uma tabela LaTeX válida para ser incluída em um documento.
    latex_rows = [
        [latex_escape(str(cell)) for cell in row]
        for row in rows
    ]

    table = tabulate(
        latex_rows,
        headers=headers,
        tablefmt="latex_raw",
        disable_numparse=True,
    )

    document = rf"""% =============================================================================
% Data: 2026-08-26
% Descrição: Tabela comparativa dos resultados de síntese.
% Gerado automaticamente por compare_reports.py
% =============================================================================

\begin{{table}}[htbp]
    \centering
    \caption{{Comparação entre as implementações only\_srams e sram\_dclb.}}
    \label{{tab:comparison_sram}}
    \small
{table}
\end{{table}}
"""

    output_path.write_text(document, encoding="utf-8")
    print(f"\n[OK] Tabela LaTeX salva em: {output_path}")


#---------------------------------------------------------------------------
# Main
#---------------------------------------------------------------------------

def main():
    results = collect_results()
    rows = build_rows(results)

    if not rows:
        print(
            "[ERRO] Nenhuma métrica foi encontrada.\n"
            "Verifique os arquivos .rpt e ajuste os regex dos parsers."
        )
        return

    print_table(rows)
    generate_latex(rows, OUTPUT_TEX)


if __name__ == "__main__":
    main()
