#!/usr/bin/env bash
# pandoc-convert helper script
# Usage: convert.sh <input-file> <output-file> [extra pandoc options...]
#
# Auto-detects formats from file extensions, applies sensible defaults,
# and selects the appropriate PDF engine when needed.

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <input-file> <output-file> [pandoc options...]"
    echo ""
    echo "Examples:"
    echo "  $0 report.md report.pdf"
    echo "  $0 page.html output.docx"
    echo "  $0 notes.md notes.html --css=style.css --toc"
    echo "  $0 paper.md paper.pdf --toc -V geometry:margin=1in"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"
shift 2

# Validate input file exists
if [[ ! -f "$INPUT" ]]; then
    echo "Error: Input file '$INPUT' not found."
    exit 1
fi

# Extract output extension (lowercase)
OUT_EXT="${OUTPUT##*.}"
OUT_EXT="$(echo "$OUT_EXT" | tr '[:upper:]' '[:lower:]')"

# Extract input extension (lowercase)
IN_EXT="${INPUT##*.}"
IN_EXT="$(echo "$IN_EXT" | tr '[:upper:]' '[:lower:]')"

# Build pandoc arguments
PANDOC_ARGS=()

# Always produce standalone output for formats that support it
case "$OUT_EXT" in
    html|html5|htm|epub|epub3)
        PANDOC_ARGS+=("-s")
        ;;
    pdf|docx|odt|pptx|rtf)
        PANDOC_ARGS+=("-s")
        ;;
esac

# PDF engine selection
if [[ "$OUT_EXT" == "pdf" ]]; then
    # Check if user already specified a --pdf-engine
    PDF_ENGINE_SET=false
    for arg in "$@"; do
        if [[ "$arg" == --pdf-engine=* ]] || [[ "$arg" == "--pdf-engine" ]]; then
            PDF_ENGINE_SET=true
            break
        fi
    done

    if [[ "$PDF_ENGINE_SET" == false ]]; then
        # Default to xelatex for best Unicode support
        if command -v xelatex &>/dev/null; then
            PANDOC_ARGS+=("--pdf-engine=xelatex")
        elif command -v pdflatex &>/dev/null; then
            PANDOC_ARGS+=("--pdf-engine=pdflatex")
        elif command -v wkhtmltopdf &>/dev/null; then
            PANDOC_ARGS+=("--pdf-engine=wkhtmltopdf")
        else
            echo "Error: No PDF engine found. Install texlive-xetex or wkhtmltopdf."
            exit 1
        fi
    fi

    # Set sensible default margins if not specified
    GEOMETRY_SET=false
    for arg in "$@"; do
        if [[ "$arg" == *geometry* ]]; then
            GEOMETRY_SET=true
            break
        fi
    done
    if [[ "$GEOMETRY_SET" == false ]]; then
        PANDOC_ARGS+=("-V" "geometry:margin=1in")
    fi
fi

# For HTML input going to PDF, hint the input format explicitly
# (pandoc sometimes misdetects HTML fragments)
if [[ "$IN_EXT" == "html" || "$IN_EXT" == "htm" ]]; then
    PANDOC_ARGS+=("-f" "html")
fi

# Run pandoc
echo "Converting: $INPUT → $OUTPUT"
echo "Command: pandoc \"$INPUT\" -o \"$OUTPUT\" ${PANDOC_ARGS[*]} $*"

pandoc "$INPUT" -o "$OUTPUT" "${PANDOC_ARGS[@]}" "$@"

# Verify output was created
if [[ -f "$OUTPUT" ]]; then
    SIZE=$(stat --printf="%s" "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null || echo "unknown")
    echo "Success: Created $OUTPUT ($SIZE bytes)"
else
    echo "Error: Output file was not created."
    exit 1
fi
