#!/bin/sh
set -eu
cd "$(dirname "$0")"
for test in tb_stabilizer tb_merge tb_sccb tb_text tb_components tb_classifier tb_video tb_engine tb_photos tb_shadows tb_top tb_top_stable; do
    src="$test.v"
    if [ "$test" = "tb_top_stable" ]; then src="tb_top.v"; fi
    iverilog -g2001 -Wall -s "$test" -o "$test.out" ../rtl/*.v text_reference.v "$src"
    vvp "$test.out" > "$test.log"
    cat "$test.log"
    if grep -q 'FAIL' "$test.log"; then exit 1; fi
    grep -q '^PASS:' "$test.log"
done
