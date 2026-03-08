# Release Readiness

## Readiness Checklist

- [ ] Stage gates complete
- [ ] Quality gate approved
- [ ] Manual-test gate approved (`manual_test_gate_status=approved`)
- [ ] Open manual-test issues are zero (`open_manual_issues=0`)
- [ ] Known issues documented
- [ ] Release notes drafted
- [ ] Deployment evidence exists in `Deployment_Readiness_Evidence.md`
- [ ] Compose manifest exists at `project/infra/deploy/docker-compose.yml`
- [ ] Manual-test issues reviewed in `08-quality/Manual_Test_Issues.md`

## Compose Deployment Verification

- Command: `docker compose up --build -d`
- Verification reference:
- Verifier:
- Record reference:

## Final Decision

- Status:
- Approver:
- Record reference:
