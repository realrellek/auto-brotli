#!/bin/bash

# ==============================================================================
# AUTO-BROTLI STATIC COMPRESSOR
# ==============================================================================
# Scans wp-content/cache directories for static assets (CSS, JS, HTML, XML)
# and creates pre-compressed .br files (Brotli Level 11).
#
# Features:
# - Incremental: Only processes new or modified files.
# - Self-Healing: Syncs timestamps to avoid re-processing.
# - Permissions: Preserves ownership and permissions of source files.
#
# Usage:
#   Normal (Cron):  ./auto-brotli.sh
#   Full Scan:      ./auto-brotli.sh --first-run
#
# Cronjob Recommendation (every 10 min):
#   */10 * * * * /usr/bin/flock -n /tmp/auto-brotli.lock /usr/bin/nice -n 19 /usr/bin/ionice -c 3 /usr/local/bin/auto-brotli.sh
#                                                                                                 ^ Adjust path
# ==============================================================================

# ---------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------
WEB_ROOT="/var/customers/webs"
CACHE_PATH_PATTERN="*/wp-content/cache/*"

# Default Lookback window in minutes (for incremental runs)
# 360 min = 6 hours (safe overlap for 10min cronjobs)
DEFAULT_LOOKBACK="360"

BROTLI_CMD="brotli"

# ---------------------------------------------------------
# YOU SHALL NOT CHANGE ANYTHING FROM HERE
# ---------------------------------------------------------
TIME_FILTER="-mmin -$DEFAULT_LOOKBACK"

if [[ "$1" == "--first-run" ]]; then
    TIME_FILTER=""
fi

if ! command -v $BROTLI_CMD &> /dev/null; then
    echo "Error: '$BROTLI_CMD' could not be found. Please install brotli."
    exit 1
fi

find "$WEB_ROOT" \
    -path "$CACHE_PATH_PATTERN" \
    -type f \
    \( \
        -name "*.css" \
        -o -name "*.js" \
        -o -name "*.html" \
        -o -name "*.htm" \
        -o -name "*.xml" \
        -o -name "*.rss-xml" \
        -o -name "*.json" \
        -o -name "*.svg" \
        -o -name "*.map" \
        -o -name "*.ttf" \
        -o -name "*.eot" \
        -o -name "*.otf" \
        -o -name "*.txt" \
    \) \
    $TIME_FILTER \
    ! -name "*.br" \
    ! -name "*.gz" \
    ! -name "*.html_gz" \
    ! -name "*.svgz" \
    ! -name "*.woff" \
    ! -name "*.woff2" \
    -print0 | while IFS= read -r -d '' file; do

    br_file="${file}.br"
    do_compress=false

    # if no .br exist, we have to make one
    if [ ! -f "$br_file" ]; then
        do_compress=true
    else
        # if our source is newer than .br, we compress too
        if [ "$file" -nt "$br_file" ]; then
            do_compress=true
        fi
    fi

    if [ "$do_compress" = true ]; then
        $BROTLI_CMD --best -f -k "$file" > /dev/null 2>&1

        if [ -f "$br_file" ]; then
            # Set ownership and modes and mtime to the original file
            chown --reference="$file" "$br_file"
            chmod --reference="$file" "$br_file"
            touch -r "$file" "$br_file"
        fi
    fi

done
