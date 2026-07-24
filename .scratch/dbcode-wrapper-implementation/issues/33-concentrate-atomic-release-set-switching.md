# 33 — Concentrate atomic release-set switching

**What to build:** Replace the duplicated promotion and rollback five-member filesystem swap loops with one atomic switch implementation behind the Approved Release Set seam. Promotion and rollback keep their distinct policy and journal states but share move, failure, reverse recovery, and cleanup behaviour.

**Blocked by:** 32

**Type:** task

**Status:** open

- [ ] One module switches the app, manifest, user data, extension root, and shared data as one validated transaction.
- [ ] Promotion and rollback supply explicit incoming, outgoing, target, identity, and journal records without implementing their own move loops.
- [ ] Failure at every outgoing move, incoming move, recovery move, and cleanup point either restores the complete prior set or preserves an explicit recovery-incomplete journal.
- [ ] No mixed host, manifest, extension, user-data, or shared-data set can be reported as active.
- [ ] Existing promotion, health, rollback, and four-pair compatibility behaviour remains unchanged.
- [ ] Focused transaction tests and the complete controlled-upgrade gate pass.
