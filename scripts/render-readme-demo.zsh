#!/bin/zsh

emulate -L zsh
setopt errexit nounset pipefail

project_root=${0:A:h:h}
frame_dir=$(command mktemp -d "${TMPDIR:-/tmp}/monkey-readme.XXXXXX")
builtin cd -- "$project_root"

function cleanup() {
  command rm -rf -- "$frame_dir"
}
trap cleanup EXIT

if ! command -v npx >/dev/null 2>&1; then
  print -u2 -r -- 'render-readme-demo: npx is required'
  return 127
fi

if ! command -v magick >/dev/null 2>&1; then
  print -u2 -r -- 'render-readme-demo: ImageMagick is required'
  return 127
fi

command mkdir -p -- "$project_root/assets"

typeset source_file frame_name
for source_file in "$project_root"/snippets/readme-demo/*.txt; do
  frame_name=${source_file:t:r}
  command cp -- "$source_file" "$frame_dir/monkey"
  command npx --yes snipgrapher@0.1.0 render "$frame_dir/monkey" \
    --profile readme \
    --language bash \
    --format png \
    --scale 2 \
    --output "$frame_dir/$frame_name.raw.png"
  command magick "$frame_dir/$frame_name.raw.png" \
    -background '#0d1117' \
    -gravity northwest \
    -extent 1100x650 \
    "$frame_dir/$frame_name.png"
done

command magick \
  -delay 90 "$frame_dir/01-start.png" \
  -delay 150 "$frame_dir/02-created.png" \
  -delay 120 "$frame_dir/03-entered.png" \
  -delay 170 "$frame_dir/04-copy.png" \
  -loop 0 \
  -layers Optimize \
  "$project_root/assets/monkey-demo.gif"

print -r -- "$project_root/assets/monkey-demo.gif"
