@RTK.md

## Gradle / JVM Dependencies

Avoid directly accessing `.gradle` files or directories. Instead, proactively use the `ksrc` bash tool to inspect source code of dependencies and learn API shapes or implementations. Start with `ksrc --help`.
