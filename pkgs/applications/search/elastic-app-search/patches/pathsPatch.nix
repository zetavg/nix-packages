{ bash, filebeat7, adoptopenjdk-hotspot-bin-11, ... }:

''
--- ./bin/app-search
+++ ./bin/app-search
@@ -1,4 +1,4 @@
-#!/bin/bash
+#!${bash}/bin/bash

 function realpath {
   echo "$(cd "$(dirname "$1")"; pwd)"/"$(basename "$1")";
@@ -43,7 +43,11 @@ BIN_DIR=$(realpath "$BIN_DIR")
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
@@ -2,9 +2,10 @@

 set -e

-if type -p java >/dev/null; then
-    echo "Found java executable in PATH"
-    export _JAVA=java
+java_from_nix=${adoptopenjdk-hotspot-bin-11}/bin/java
+if type -p $java_from_nix >/dev/null; then
+    echo "Using java executable: $java_from_nix"
+    export _JAVA="$java_from_nix"
 else
     echo "Could not find java: $java_from_nix"
     exit 1

''
