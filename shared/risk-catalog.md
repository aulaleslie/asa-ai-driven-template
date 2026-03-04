# Risk Catalog

Use this baseline taxonomy and extend per project.

| Risk ID | Category | Description | Probability | Impact | Owner | Mitigation | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-001 | Scope | Scope creep from uncontrolled changes | Medium | High | Project Manager | Lock scope and enforce change log | Open |
| R-002 | Requirements | Ambiguous requirements cause rework | Medium | High | Business Analyst | Add acceptance criteria and examples | Open |
| R-003 | Architecture | Early design decisions do not scale | Low | High | Solution Architect | Capture ADRs and run design review | Open |
| R-004 | Data | Data quality gaps affect delivery | Medium | Medium | Data Engineer | Define validation rules and ownership | Open |
| R-005 | Quality | Incomplete test coverage allows defects | Medium | High | SDET | Risk-based test strategy and regression checks | Open |
| R-006 | Stack Governance | Unauthorized stack changes after lock | Medium | High | Project Manager | Enforce stack-lock + override approval protocol | Open |
| R-007 | Deployment | Compose deployment fails at release | Medium | High | Solution Architect | Validate deployability evidence before release gate | Open |
| R-008 | Command Consistency | Command registry, docs, and scripts drift | Medium | Medium | Project Manager | Run framework validation checks regularly | Open |
| R-009 | Engineering Method Drift | Delivery skips test-first/domain-model discipline for chosen stack | Medium | High | Software Developer + SDET | Enforce stack-aware TDD/DDD evidence in delivery and quality gates | Open |

Risk status values: `Open`, `Monitoring`, `Mitigated`, `Closed`.
