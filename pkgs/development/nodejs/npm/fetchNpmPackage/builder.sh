source $stdenv/setup

# Unpack archive
rm -rf npm-unpacked
mkdir -p npm-unpacked
tar -xf $src --directory npm-unpacked --warning=no-unknown-keyword
for i in npm-unpacked/*; do
  if [ -d "$i" ]; then
    mv -f "$i" $out
    break
  fi
done

# Make bins executable
for binPath in $binPaths; do
  chmod +x "$out/$binPath"
done

# Patch shebangs (/usr/bin/env)
find $out/ -type f -print0 | xargs -0 sed -i "s|/usr/bin/env|$env|g"

# Apply custom patches
cd $out
if [ ! -z "$patchPhase" ]; then
  eval "$patchPhase"
else
  patchPhase
fi
