{ ... }:

''
--- ./bin/passenger
+++ ./bin/passenger
@@ -26,6 +26,8 @@
 ## Magic comment: begin bootstrap ##
 source_root = File.expand_path("..", File.dirname(__FILE__))
 $LOAD_PATH.unshift("#{source_root}/src/ruby_supportlib")
+out_path = $out
+$LOAD_PATH.unshift("#{out_path}/src/ruby_supportlib")
 begin
   require 'rubygems'
 rescue LoadError

--- ./bin/passenger-config
+++ ./bin/passenger-config
@@ -26,6 +26,8 @@
 ## Magic comment: begin bootstrap ##
 source_root = File.expand_path("..", File.dirname(__FILE__))
 $LOAD_PATH.unshift("#{source_root}/src/ruby_supportlib")
+out_path = $out
+$LOAD_PATH.unshift("#{out_path}/src/ruby_supportlib")
 begin
   require 'rubygems'
 rescue LoadError

--- ./bin/passenger-install-apache2-module
+++ ./bin/passenger-install-apache2-module
@@ -27,6 +27,8 @@
 ## Magic comment: begin bootstrap ##
 source_root = File.expand_path("..", File.dirname(__FILE__))
 $LOAD_PATH.unshift("#{source_root}/src/ruby_supportlib")
+out_path = $out
+$LOAD_PATH.unshift("#{out_path}/src/ruby_supportlib")
 begin
   require 'rubygems'
 rescue LoadError

--- ./bin/passenger-install-nginx-module
+++ ./bin/passenger-install-nginx-module
@@ -26,6 +26,8 @@
 ## Magic comment: begin bootstrap ##
 source_root = File.expand_path("..", File.dirname(__FILE__))
 $LOAD_PATH.unshift("#{source_root}/src/ruby_supportlib")
+out_path = $out
+$LOAD_PATH.unshift("#{out_path}/src/ruby_supportlib")
 begin
   require 'rubygems'

--- ./bin/passenger-memory-stats
+++ ./bin/passenger-memory-stats
@@ -26,6 +26,8 @@
 ## Magic comment: begin bootstrap ##
 source_root = File.expand_path("..", File.dirname(__FILE__))
 $LOAD_PATH.unshift("#{source_root}/src/ruby_supportlib")
+out_path = $out
+$LOAD_PATH.unshift("#{out_path}/src/ruby_supportlib")
 begin
   require 'rubygems'
 rescue LoadError

--- ./bin/passenger-status
+++ ./bin/passenger-status
@@ -26,6 +26,8 @@
 ## Magic comment: begin bootstrap ##
 source_root = File.expand_path("..", File.dirname(__FILE__))
 $LOAD_PATH.unshift("#{source_root}/src/ruby_supportlib")
+out_path = $out
+$LOAD_PATH.unshift("#{out_path}/src/ruby_supportlib")
 begin
   require 'rubygems'
 rescue LoadError
''
