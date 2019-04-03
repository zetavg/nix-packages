# Required vars:
#
#  - buildInputs
#  - package
#  - nodeEnv
#
# shellcheck disable=SC2154
# shellcheck disable=SC2148

set -e

unset PATH
for p in $buildInputs; do
  export PATH=$p/bin''${PATH:+:}$PATH
done

mkdir -p "$out"
cd "$out"

cp -rf "$package/"* .

mkdir node_modules
cd node_modules
IFS=':' read -r -a nodePath <<< "$(cat "$nodeEnv/NODE_PATH")"
for pkg in $nodePath; do
  cp -rf "$pkg/"* .
  if [[ -d bin ]]; then
    mkdir -p .bin
    cp -rf "bin/"* .bin/
  fi
  rm -rf bin
done
rm -rf package-name
