source $stdenv/setup

# Copy the package to $out
cp -rf $package $out
chmod +w $out

# Bundle private dependencies into node_modules
mkdir $out/node_modules
for packageNameAndSrc in $bundlePackageNameAndSrcs; do
  IFS='|' read -r -a arr <<< "$packageNameAndSrc"
  packageName=${arr[0]}
  src=${arr[1]}
  path="$out/node_modules/$packageName"
  mkdir -p "$(dirname $path)"
  cp -r $src $path
done
