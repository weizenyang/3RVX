#!/usr/bin/env sh
# Export print-ready STLs for 3- and 4-segment versions, plus preview images.
# Needs OpenSCAD (2021.01+). Preview PNGs need a display (or xvfb-run).
set -e
cd "$(dirname "$0")"
SCAD=threshold_slope.scad

for n in 3 4; do
  out="stl/${n}-segments"
  mkdir -p "$out"
  i=0
  while [ "$i" -lt "$n" ]; do
    openscad -q -o "$out/segment_$((i + 1))_of_${n}.stl" \
      -D "segments=$n" -D 'part="segment"' -D "segment_index=$i" "$SCAD"
    i=$((i + 1))
  done
  openscad -q -o "$out/keys_and_pins.stl" -D "segments=$n" -D 'part="hardware_plate"' "$SCAD"
done

mkdir -p images
RUN=""
[ -z "$DISPLAY" ] && command -v xvfb-run >/dev/null && RUN="xvfb-run -a"
$RUN openscad -q -o images/assembly_exploded.png --render --imgsize=1600,900 \
  --camera=400,40,-10,58,0,345,1500 --colorscheme=Tomorrow \
  -D explode=40 -D show_walls=false "$SCAD"
$RUN openscad -q -o images/segment_end.png --render --imgsize=1200,800 \
  --camera=0,0,0,60,0,325,0 --viewall --autocenter --colorscheme=Tomorrow \
  -D 'part="segment"' -D segment_index=0 "$SCAD"
$RUN openscad -q -o images/segment_underside.png --render --imgsize=1200,800 \
  --camera=0,0,0,235,0,35,0 --viewall --autocenter --colorscheme=Tomorrow \
  -D 'part="segment"' -D segment_index=1 "$SCAD"
$RUN openscad -q -o images/end_lip_section.png --preview --imgsize=1200,800 \
  --camera=15,60,20,72,0,12,260 --colorscheme=Tomorrow \
  -D 'part="end_section"' "$SCAD"
