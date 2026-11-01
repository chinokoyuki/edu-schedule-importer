# Contributing

Bug reports and pull requests are welcome.

## Reporting a problem

Include the adapter id, the payload that reaches `adapter.parse`, and the result you expected. Strip names, student ids, room numbers and anything else that points at a real person or a real school. Hand-written payloads work better than recorded ones.

## Adding an adapter

An adapter is two pieces of work:

1. A script string that runs inside the page and returns JSON.
2. A parser that turns that JSON into `ImportResult`.

Keep the two apart. The script touches the DOM; the parser touches nothing but strings and numbers. That split is what makes the parser testable without a device.

Then:

- Register the id in `EduImporters` and in `EduImporters.ids()`.
- Add a test in `library/src/test` with a synthetic payload.
- Note the layout in the README, including what will break when the vendor changes its pages.

## Pull requests

- Keep the module free of runtime dependencies. ArkWeb is the only import the library expects.
- ArkTS strict mode applies. Avoid `any`, `unknown` and type assertions.
- Never add code that collects, stores or transmits credentials. The library reads a page the user already opened; it does not sign in on their behalf.
- No school list. Which adapter an app uses is the app's decision.
- Update `CHANGELOG.md` under an "Unreleased" heading.

## Style

Two-space indentation, single quotes, explicit types on exported functions. Comments explain decisions, not syntax.

## License

Contributions are accepted under the Apache-2.0 license used by this project.
