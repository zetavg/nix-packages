{ bash, coreutils, gawk, filebeat7, adoptopenjdk-hotspot-bin-11, ... }:

''
--- ./bin/app-search
+++ ./bin/app-search
@@ -1,7 +1,7 @@
-#!/bin/bash
+#!${bash}/bin/bash

 function realpath {
-  echo "$(cd "$(dirname "$1")"; pwd)"/"$(basename "$1")";
+  echo "$(cd "$(${coreutils}/bin/dirname "$1")"; pwd)"/"$(${coreutils}/bin/basename "$1")";
 }

 #---------------------------------------------------------------------------------------------------
@@ -38,12 +38,16 @@ unset GEM_PATH
 unset RUBYLIB
 unset RUBYOPT

-BIN_DIR=$(dirname "$0")
+BIN_DIR=$(${coreutils}/bin/dirname "$0")
 BIN_DIR=$(realpath "$BIN_DIR")
 APP_ROOT="$(cd "$BIN_DIR/.."; pwd)"
 export APP_ROOT

-CONFIG_DIR="$APP_ROOT/config"
+if [ -z "''${APP_SEARCH_CONFIG_DIR:-}" ]; then
+  CONFIG_DIR="$APP_ROOT/config"
+else
+  CONFIG_DIR="$APP_SEARCH_CONFIG_DIR"
+fi
 LIB_DIR="$APP_ROOT/lib"

 # Need this for Filebeat config
@@ -56,8 +60,8 @@ export BUNDLE_GEMFILE=Gemfile-LocoTogo
 export WAR_FILE="$APP_ROOT/lib/app-search.war"

 # Detect the platform
-PLATFORM=$(uname -s | awk '{print tolower($0)}')
-ARCH=$(uname -m)
+PLATFORM=$(${coreutils}/bin/uname -s | ${gawk}/bin/awk '{print tolower($0)}')
+ARCH=$(${coreutils}/bin/uname -m)
 PLATFORM_FULL="$PLATFORM-$ARCH"

 # Make sure the platform is supported
@@ -69,8 +73,13 @@ if [ "$PLATFORM_FULL" != "linux-x86_64" ] && [ "$PLATFORM_FULL" != "darwin-x86_6
 fi

 # Filebeat locations
-export FILEBEAT_BIN="$BIN_DIR/vendor/filebeat/filebeat-$PLATFORM_FULL"
-export FILEBEAT_DIR="$APP_ROOT/filebeat"
+export FILEBEAT_BIN="${filebeat7}/bin/filebeat"
+if [ -z "''${APP_SEARCH_FILEBEAT_DIR:-}" ]; then
+  export FILEBEAT_DIR="/tmp/app-search-filebeat"
+else
+  export FILEBEAT_DIR="$APP_SEARCH_FILEBEAT_DIR"
+fi
+

 #---------------------------------------------------------------------------------------------------
 # shellcheck source=../lib/require_java_version.sh
--- ./lib/require_java_version.sh
+++ ./lib/require_java_version.sh
@@ -2,18 +2,19 @@

 set -e

-if type -p java >/dev/null; then
-    echo "Found java executable in PATH"
-    export _JAVA=java
+java_from_nix=${adoptopenjdk-hotspot-bin-11}/bin/java
+if type -p $java_from_nix >/dev/null; then
+    echo "Using java executable: $java_from_nix"
+    export _JAVA=$java_from_nix
 else
     echo "Could not find java in PATH"
     exit 1
 fi

-version=$("$_JAVA" -version 2>&1 | awk -F '"' '/version/ {print $2}')
+version=$("$_JAVA" -version 2>&1 | ${gawk}/bin/awk -F '"' '/version/ {print $2}')
 echo "Java version: $version"

-numeric_version=$(echo "$version" | awk -F. '{printf("%03d%03d",$1,$2);}')
+numeric_version=$(echo "$version" | ${gawk}/bin/awk -F. '{printf("%03d%03d",$1,$2);}')
 if [ "$numeric_version" -lt "001008" ] ; then
     echo "Elastic App Search requires Java version 1.8 or higher, current version is $version"
     exit 1
''
