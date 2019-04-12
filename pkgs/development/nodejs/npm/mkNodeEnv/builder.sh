source $stdenv/setup

mkdir -p $out

# Link modules
mkdir "$out/node_modules"
for packageNameAndSrc in $nodeModuleNameAndSrcs; do
  IFS='|' read -r -a arr <<< "$packageNameAndSrc"
  packageName=${arr[0]}
  src=${arr[1]}
  path="$out/node_modules/$packageName"
  mkdir -p "$(dirname $path)"
  ln -sf $src $path
done

# Link bins
for binNameAndPath in $binNameAndPaths; do
  mkdir -p "$out/node_modules/.bin"
  IFS='|' read -r -a arr <<< "$binNameAndPath"
  binName=${arr[0]}
  sourcePath=${arr[1]}
  ln -sf "$sourcePath" "$out/node_modules/.bin/$binName"
done

path="$systemPaths:$out/node_modules/.bin"
nodePath="$out/node_modules"

echo "$path" > "$out/PATH"
echo "$nodePath" > "$out/NODE_PATH"
echo "$environmentVariables" > "$out/ENV"

{
  echo "# This script is used to setup the node environment, source this script in"
  echo "# a shell to load the environment."
  echo ""
  echo "export PATH=$path\${PATH:+:}\$PATH"
  echo "export NODE_PATH=$nodePath\${NODE_PATH:+:}\$NODE_PATH"
  echo "$exportEnvironmentVariables"
} > "$out/setup.sh"
