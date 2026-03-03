# Quality Standards

## Artifact Quality

- Complete: all required sections are present.
- Correct: facts and references are accurate.
- Coherent: no internal contradictions.
- Traceable: links from requirements to implementation and tests.
- Actionable: next decisions or actions are explicit.

## Delivery Quality

- Implementation aligns with architecture and design constraints.
- Test strategy covers happy path, edge cases, and regressions.
- Critical risks have owners and mitigation plans.

## Deployment Quality Contract

- Compose manifest exists at `infra/deploy/docker-compose.yml`.
- `docker compose up --build -d` evidence is documented for release.
- Services define explicit ports and environment contract references.
- Container health assumptions and checks are documented.

## Review Expectations

- Reviews prioritize defects, risks, and missing evidence.
- Approvals require explicit rationale.
- Rejections include concrete correction instructions.
