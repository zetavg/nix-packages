{ coreutils, findutils, bash, lsof, procps, beep, ... }:

''
--- ./src/agent/Core/SpawningKit/Exceptions.h
+++ ./src/agent/Core/SpawningKit/Exceptions.h
@@ -738,7 +738,7 @@ private:

 	static string gatherUlimits() {
 		// On Linux, ulimit is a shell builtin and not a command.
-		const char *command[] = { "/bin/sh", "-c", "ulimit -a", NULL };
+		const char *command[] = { "${bash}/bin/sh", "-c", "ulimit -a", NULL };
 		try {
 			SubprocessInfo info;
 			SubprocessOutput output;
@@ -754,7 +754,7 @@ private:
 	}

 	static string gatherUserInfo() {
-		const char *command[] = { "id", "-a", NULL };
+		const char *command[] = { "${coreutils}/bin/id", "-a", NULL };
 		try {
 			SubprocessInfo info;
 			SubprocessOutput output;

--- ./src/agent/Shared/Fundamentals/AbortHandler.cpp
+++ ./src/agent/Shared/Fundamentals/AbortHandler.cpp
@@ -395,7 +395,7 @@ dumpFileDescriptorInfoWithLsof(AbortHandlerWorkingState &state, void *userData)

 	execlp("lsof", "lsof", "-p", state.messageBuf, "-nP", (char *) 0);

-	const char *command[] = { "lsof", NULL };
+	const char *command[] = { "${lsof}/bin/lsof", NULL };
 	printExecError2(command, errno, state.messageBuf, sizeof(state.messageBuf));
 	_exit(1);
 }
@@ -434,7 +434,7 @@ dumpFileDescriptorInfoWithLs(AbortHandlerWorkingState &state, const char *path)
 		// The '-v' is for natural sorting on Linux. On BSD -v means something else but it's harmless.
 		execlp("ls", "ls", "-lv", path, (char *) 0);

-		const char *command[] = { "ls", NULL };
+		const char *command[] = { "${coreutils}/bin/ls", NULL };
 		printExecError2(command, errno, state.messageBuf, sizeof(state.messageBuf));
 		_exit(1);
 	} else if (pid == -1) {
@@ -522,7 +522,7 @@ dumpWithCrashWatch(AbortHandlerWorkingState &state) {
 			state.messageBuf, // PID string
 			(char *) 0);

-		const char *command[] = { "crash-watch", NULL };
+		const char *command[] = { "crash-watch", NULL };
 		printExecError2(command, errno, state.messageBuf, sizeof(state.messageBuf));
 		_exit(1);

@@ -1034,7 +1034,7 @@ abortHandler(int signo, siginfo_t *info, void *_unused) {
 				execlp("osascript", "osascript", "-e", "beep 2", (char *) 0);
 				printExecError2(command, errno, state.messageBuf, sizeof(state.messageBuf));
 			#else
-				const char *command[] = { "beep", NULL };
+				const char *command[] = { "${beep}/bin/beep", NULL };
 				execlp("beep", "beep", (char *) 0);
 				printExecError2(command, errno, state.messageBuf, sizeof(state.messageBuf));
 			#endif

--- ./src/agent/SpawnEnvSetupper/SpawnEnvSetupperMain.cpp
+++ ./src/agent/SpawnEnvSetupper/SpawnEnvSetupperMain.cpp
@@ -215,7 +215,7 @@ dumpEnvvars(const string &workDir) {
 	}

 	const char *command[] = {
-		"env",
+		"${coreutils}/bin/env",
 		NULL
 	};
 	SubprocessInfo info;
@@ -234,7 +234,7 @@ dumpUserInfo(const string &workDir) {
 	}

 	const char *command[] = {
-		"id",
+		"${coreutils}/bin/id",
 		NULL
 	};
 	SubprocessInfo info;
@@ -254,7 +254,7 @@ dumpUlimits(const string &workDir) {

 	// On Linux, ulimit is a shell builtin and not a command.
 	const char *command[] = {
-		"/bin/sh",
+		"${bash}/bin/sh",
 		"-c",
 		"ulimit -a",
 		NULL

--- ./src/agent/Watchdog/InstanceDirToucher.cpp
+++ ./src/agent/Watchdog/InstanceDirToucher.cpp
@@ -122,9 +122,9 @@ private:

 			try {
 				const char *command[] = {
-					"/bin/sh",
+					"${bash}/bin/sh",
 					"-c",
-					"find . | xargs touch",
+					"${findutils}/bin/find . | ${findutils}/bin/xargs touch",
 					NULL
 				};
 				SubprocessInfo info;

--- ./src/cxx_supportlib/FileTools/FileManip.cpp
+++ ./src/cxx_supportlib/FileTools/FileManip.cpp
@@ -301,7 +301,7 @@ void
 removeDirTree(const string &path) {
 	{
 		const char *command[] = {
-			"chmod",
+			"${coreutils}/bin/chmod",
 			"-R",
 			"u+rwx",
 			path.c_str(),
@@ -312,7 +312,7 @@ removeDirTree(const string &path) {
 	}
 	{
 		const char *command[] = {
-			"rm",
+			"${coreutils}/bin/rm",
 			"-rf",
 			path.c_str(),
 			NULL

--- ./src/cxx_supportlib/SystemTools/ProcessMetricsCollector.h
+++ ./src/cxx_supportlib/SystemTools/ProcessMetricsCollector.h
@@ -314,7 +314,7 @@ public:
 		#endif

 		const char *command[] = {
-			"ps", fmtArg.c_str(),
+			"${procps}/bin/ps", fmtArg.c_str(),
 			#ifdef PS_SUPPORTS_MULTIPLE_PIDS
 				pidsArg.c_str(),
 			#endif

''
