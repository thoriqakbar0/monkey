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

typeset demo_name source_dir language output canvas delay_one delay_two delay_three delay_four source_file frame_name
for demo_name in monkey rift; do
  if [[ $demo_name == monkey ]]; then
    source_dir="$project_root/snippets/readme-demo"
    language=bash
    output="$project_root/assets/monkey-demo.gif"
    canvas=1100x650
    delay_one=90
    delay_two=150
    delay_three=120
    delay_four=170
  else
    source_dir="$project_root/snippets/rift-demo"
    language=text
    output="$project_root/assets/rift-copy-on-write.gif"
    canvas=1100x760
    delay_one=100
    delay_two=150
    delay_three=170
    delay_four=190
  fi

  for source_file in "$source_dir"/*.txt; do
    frame_name=${source_file:t:r}
    command cp -- "$source_file" "$frame_dir/$demo_name"
    command npx --yes snipgrapher@0.1.0 render "$frame_dir/$demo_name" \
      --profile readme \
      --language "$language" \
      --format png \
      --scale 2 \
      --output "$frame_dir/raw-$demo_name-$frame_name.png"
    command magick "$frame_dir/raw-$demo_name-$frame_name.png" \
      -background '#0d1117' \
      -gravity northwest \
      -extent "$canvas" \
      "$frame_dir/$demo_name-$frame_name.png"
  done

  command magick \
    -delay "$delay_one" "$frame_dir/$demo_name-01-"*.png \
    -delay "$delay_two" "$frame_dir/$demo_name-02-"*.png \
    -delay "$delay_three" "$frame_dir/$demo_name-03-"*.png \
    -delay "$delay_four" "$frame_dir/$demo_name-04-"*.png \
    -loop 0 \
    -layers Optimize \
    "$output"

  print -r -- "$output"
done
