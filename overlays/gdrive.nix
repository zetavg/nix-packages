/*
 * Allow gdrive to use custom client credentials passed via environment variables
 * (GDRIVE_CLIENT_ID, GDRIVE_CLIENT_SECRET) to avoid rate limit errors.
 */

let
  gdrive-overlay = self: super:
  {
    gdrive = super.gdrive.overrideAttrs (oldAttrs: {
      patches = [
        (builtins.toFile "patch" ''
        --- ./handlers_drive.go
        +++ ./handlers_drive.go
        @@ -13,8 +13,15 @@
          "time"
         )

        -const ClientId = "367116221053-7n0vf5akeru7on6o2fjinrecpdoe99eg.apps.googleusercontent.com"
        -const ClientSecret = "1qsNodXNaWq1mQuBjUjmvhoO"
        +func getEnv(key, fallback string) string {
        +  if value, ok := os.LookupEnv(key); ok {
        +    return value
        +  }
        +  return fallback
        +}
        +
        +var ClientId = getEnv("GDRIVE_CLIENT_ID", "367116221053-7n0vf5akeru7on6o2fjinrecpdoe99eg.apps.googleusercontent.com")
        +var ClientSecret = getEnv("GDRIVE_CLIENT_SECRET", "1qsNodXNaWq1mQuBjUjmvhoO")
         const TokenFilename = "token_v2.json"
         const DefaultCacheFileName = "file_cache.json"
        '')
      ];
    });
  };
in gdrive-overlay
