"""Run the NHANES analysis and build the research report."""
import argparse
import os
from pathlib import Path
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true", help="Download or validate official source files")
    parser.add_argument("--no-report", action="store_true", help="Run the statistical analysis without building PDFs")
    args = parser.parse_args()
    os.chdir(root)
    for folder in ("data/raw", "data/derived", "outputs/tables", "outputs/figures", "logs", "report"):
        (root / folder).mkdir(parents=True, exist_ok=True)

    def run(*command):
        subprocess.run(command, check=True, cwd=root)

    if args.download:
        run(sys.executable, "analysis/download_data.py")
    run(sys.executable, "analysis/verify_manifest.py")
    run("Rscript", "run_all.R")
    if not args.no_report:
        python = os.environ.get("BIOSTAT_REPORT_PYTHON", sys.executable)
        run(python, "analysis/build_report.py")
    run(sys.executable, "analysis/verify_manifest.py")
    print("Analysis completed. Results are in outputs/ and report/.")


if __name__ == "__main__":
    main()
