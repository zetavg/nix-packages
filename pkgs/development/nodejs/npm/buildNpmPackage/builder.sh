source $stdenv/setup

# Copy source to build
rm -rf npm-build
if [[ ! -z "${srcs:-}" ]]; then
  mkdir npm-build
  for s in $srcs;do
    cp -r "$s" "npm-build/$(stripHash "$s")"
  done
elif [[ ! -z "${src:-}" ]]; then
  cp -r $src npm-build
else
  echo 'variable $src or $srcs should point to the source'
  exit 1
fi
chmod -R +w npm-build
cd npm-build

# Setup env
source $setupNodeEnvScript

# Pack
tarballFileName=$(npm pack --no-update-notifier | tail -n 1)

if [ $format == "tarball" ]; then
  cp $tarballFileName $out
else
  cd ..

  rm -rf npm-unpacked
  mkdir -p npm-unpacked
  tar -xf "npm-build/$tarballFileName" --directory npm-unpacked --warning=no-unknown-keyword
  for i in npm-unpacked/*; do
    if [ -d "$i" ]; then
      mv -f "$i" $out
      break
    fi
  done

  # Patch shebangs (/usr/bin/env)
  find $out/ -type f -print0 | xargs -0 sed -i "s|/usr/bin/env|$env|g"
fi
