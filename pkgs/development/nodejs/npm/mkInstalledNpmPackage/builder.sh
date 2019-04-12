source $stdenv/setup

cp -r $package $out
chmod -R +w $out

cd $out
[[ ! -z "$setupNodeEnvScript" ]] && source $setupNodeEnvScript

npm run preinstall --if-present --no-update-notifier
npm run install --if-present --no-update-notifier
npm run postinstall --if-present --no-update-notifier
