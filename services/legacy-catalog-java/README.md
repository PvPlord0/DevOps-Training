# Legacy catalog service (Java / Spring Boot / MySQL)

This service is written the way a lot of real inherited codebases look:
config baked into the app, older dependency versions, and no `/health`
endpoint at all. That's not an oversight -- part of this project is treating
it like a legacy system you have to modernize in a later phase of this project, not rewrite from scratch.

## Run natively

```bash
mvn spring-boot:run
```

Requires a running MySQL instance and the credentials in
`src/main/resources/application.properties` to match it (or edit that file
locally -- but think about whether that's really the right long-term fix).

Requires Maven and a Maven Central-reachable network to build (this
service was not build-tested in the environment this repo was generated
in -- smoke test it before handing it out).
