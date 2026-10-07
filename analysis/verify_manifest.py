"""Verify public originals, publication files, and reference result tables."""

from pathlib import Path
import csv
import hashlib
import json
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SHA256 = re.compile(r"[0-9a-f]{64}")


class VerificationError(Exception):
    """A missing, malformed, or changed reproducibility artifact."""


def project_path(root, relative):
    if not isinstance(relative, str) or not relative:
        raise VerificationError("A manifest entry has an empty or invalid path.")
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise VerificationError(f"Manifest path must stay within the project: {relative}")
    resolved = (root / path).resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise VerificationError(f"Manifest path leaves the project: {relative}")
    return resolved


def digest(path):
    checksum = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(chunk)
    return checksum.hexdigest()


def expected_hash(value, label):
    if not isinstance(value, str) or SHA256.fullmatch(value) is None:
        raise VerificationError(f"Invalid SHA-256 value for {label}.")
    return value


def verify_originals(root):
    manifest = root / "data/download_manifest.csv"
    download_hint = "Run python3 run_project.py --download to fetch missing originals."
    if not manifest.is_file():
        raise VerificationError(f"Missing data/download_manifest.csv. {download_hint}")
    with manifest.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        if not {"path", "bytes", "sha256"}.issubset(reader.fieldnames or []):
            raise VerificationError("Download manifest requires path, bytes, and sha256 columns.")
        rows = list(reader)
    if not rows:
        raise VerificationError("Download manifest has no source-file entries.")
    seen = set()
    missing = []
    for row in rows:
        relative = row["path"]
        path = project_path(root, relative)
        if relative in seen:
            raise VerificationError(f"Duplicate download manifest path: {relative}")
        seen.add(relative)
        expected = expected_hash(row["sha256"], relative)
        try:
            size = int(row["bytes"])
        except (TypeError, ValueError):
            raise VerificationError(f"Invalid byte length for {relative}.") from None
        if size < 0:
            raise VerificationError(f"Invalid byte length for {relative}.")
        if not path.is_file():
            missing.append(relative)
            continue
        actual_size = path.stat().st_size
        if actual_size != size:
            raise VerificationError(
                f"Source-file length mismatch: {relative}; expected {size}, found {actual_size} bytes."
            )
        actual = digest(path)
        if actual != expected:
            raise VerificationError(
                f"Source-file SHA-256 mismatch: {relative}; expected {expected}, found {actual}."
            )
    if missing:
        raise VerificationError("Missing source files: " + ", ".join(missing) + ". " + download_hint)
    return len(rows)


def verify_hashes(root, entries, label):
    if not isinstance(entries, dict) or not entries:
        raise VerificationError(f"Publication record has no valid {label} map.")
    for relative, value in entries.items():
        path = project_path(root, relative)
        expected = expected_hash(value, relative)
        if not path.is_file():
            raise VerificationError(f"Missing {label} file: {relative}")
        actual = digest(path)
        if actual != expected:
            raise VerificationError(
                f"{label} SHA-256 mismatch: {relative}; expected {expected}, found {actual}."
            )
    return len(entries)


def verify_publication(root):
    marker = root / "docs/DESIGN_FROZEN.json"
    if not marker.is_file():
        raise VerificationError("Missing publication integrity record: docs/DESIGN_FROZEN.json")
    try:
        record = json.loads(marker.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise VerificationError(f"Cannot read publication integrity record: {error}") from None
    if not isinstance(record, dict) or record.get("record_type") != "publication_copy":
        raise VerificationError("docs/DESIGN_FROZEN.json must identify a publication_copy record.")
    files = verify_hashes(root, record.get("publication_files"), "publication file")
    references = record.get("reference_tables")
    if not isinstance(references, dict) or len(references) != 27:
        raise VerificationError("Publication integrity record must contain 27 reference result tables.")
    if any(not isinstance(path, str) or not path.startswith("outputs/tables/") or not path.endswith(".csv") for path in references):
        raise VerificationError("Reference result tables must be CSV files within outputs/tables/.")
    tables = verify_hashes(root, references, "reference result table")
    return files, tables


def main():
    try:
        originals = verify_originals(ROOT)
        files, tables = verify_publication(ROOT)
    except (VerificationError, OSError, csv.Error) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(
        f"PASS: {originals} public originals match their lengths and SHA-256; "
        f"{files} publication files and {tables} reference result tables match SHA-256."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
