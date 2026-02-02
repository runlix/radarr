# Renovate Configuration TODOs

## ⚠️ Temporary Testing Changes

### Schedule Setting (CHANGE BACK AFTER TESTING)

**Current:** `"schedule": ["at any time"]`
**Reason:** Testing - allows Renovate to create PRs immediately for verification
**TODO:** Change back to `"schedule": ["before 3am"]` after confirming PRs are created successfully

**Location:** `renovate.json` → `packageRules[0].schedule`

**Why we want "before 3am":**
- Reduces noise during work hours
- Groups updates into daily batches
- Creates PRs early morning so they're ready for review

**When to change back:**
After you see at least one successful PR created automatically by Renovate with:
- ✅ Distroless runtime digest updates
- ✅ PR created without manual approval
- ✅ All 4 variants updated in single PR

---

## Recommended Final Configuration

```json
{
  "packageRules": [
    {
      "description": "Group all docker-matrix.json updates into daily PRs",
      "matchFileNames": ["**/.ci/docker-matrix.json"],
      "groupName": "Docker base images",
      "schedule": ["before 3am"]  // ← Change back to this
    }
  ]
}
```

---

## Testing Checklist

- [ ] See PR created automatically by Renovate
- [ ] Verify PR includes distroless digest updates
- [ ] Verify no "Pending Approval" status
- [ ] Verify PR passes CI/smoke tests
- [ ] **THEN** change schedule back to "before 3am"

---

## How to Trigger Renovate Manually (for testing)

If you want to test immediately without waiting for the hourly run:

1. Go to Dependency Dashboard issue in your repo
2. Check the box: "Check this box to trigger a request for Renovate to run again"
3. Renovate will run within a few minutes

OR use Mend Developer Portal:
- https://developer.mend.io/github/runlix/radarr
- Click "Run Renovate Now"
