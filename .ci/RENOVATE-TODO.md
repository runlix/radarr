# Renovate Configuration TODOs

## ⚠️ Temporary Testing Changes

### 1. Schedule Setting (CHANGE BACK AFTER TESTING)

**Current:** `"schedule": ["at any time"]`
**Production:** `"schedule": ["before 3am"]`
**Reason:** Testing - allows Renovate to create PRs immediately for verification
**TODO:** Change back to `"schedule": ["before 3am"]` after confirming PRs are created successfully

**Location:** `renovate.json` → `packageRules[0].schedule`

**Why we want "before 3am":**
- Reduces noise during work hours
- Groups updates into daily batches
- Creates PRs early morning so they're ready for review

---

### 2. PR Hourly Limit (CONSIDER INCREASING FOR TESTING)

**Current:** `"prHourlyLimit": 1`
**Recommended for Testing:** `"prHourlyLimit": 10` (or remove entirely)
**Production:** `"prHourlyLimit": 1`

**Location:** `renovate.json` → root level

**What it does:**
- Limits how many PRs Renovate can create per hour
- Prevents flooding the repo with too many PRs at once
- Current setting: Only 1 PR created per hour maximum

**Why this might block testing:**
- If multiple updates are ready (Debian, Radarr version, etc.), only 1 PR will be created per hour
- Other updates will wait for the next hour
- During testing, you might want to see all PRs immediately

**For testing, consider:**
```json
{
  "prHourlyLimit": 10  // Allow up to 10 PRs per hour during testing
}
```

**For production, keep:**
```json
{
  "prHourlyLimit": 1  // Limit to 1 PR per hour to avoid noise
}
```

**When to change back:**
After you see at least one successful PR created automatically by Renovate with:
- ✅ Distroless runtime digest updates
- ✅ PR created without manual approval
- ✅ All 4 variants updated in single PR

---

## Recommended Final Production Configuration

After testing is complete, restore these settings:

```json
{
  "packageRules": [
    {
      "description": "Group all docker-matrix.json updates into daily PRs",
      "matchFileNames": ["**/.ci/docker-matrix.json"],
      "groupName": "Docker base images",
      "schedule": ["before 3am"]  // ← Restore this for production
    }
  ],
  "prHourlyLimit": 1,  // ← Keep at 1 for production to limit noise
  "prConcurrentLimit": 3
}
```

---

## Testing Checklist

### Phase 1: Verify PRs Are Created
- [ ] See PR created automatically by Renovate
- [ ] Verify PR includes distroless digest updates
- [ ] Verify no "Pending Approval" status
- [ ] Verify PR passes CI/smoke tests
- [ ] Test auto-merge (if configured)

### Phase 2: Optional - Test Multiple PRs
- [ ] Increase `prHourlyLimit` to 10 temporarily
- [ ] Trigger Renovate again
- [ ] Verify all pending updates create PRs (not just 1)

### Phase 3: Restore Production Settings
- [ ] **Change schedule back to:** `"schedule": ["before 3am"]`
- [ ] **Change prHourlyLimit back to:** `"prHourlyLimit": 1`
- [ ] Commit and push changes
- [ ] Monitor first scheduled run (next day before 3am UTC)

---

## Understanding Rate Limits

### Why These Limits Exist

**Schedule (`"before 3am"`):**
- Prevents PRs from appearing during work hours
- Batches all updates into one time window per day
- You review PRs in the morning when you're ready

**prHourlyLimit (`1`):**
- Prevents Renovate from flooding your repo with many PRs at once
- Spreads out updates if there are many pending
- Reduces notification fatigue

**prConcurrentLimit (`3`):**
- Maximum open PRs at any time
- Once a PR is merged/closed, Renovate creates the next one
- Keeps PR list manageable

### When to Adjust

**Testing Phase:**
- Schedule: `"at any time"` - See PRs immediately
- prHourlyLimit: `10` - See all pending PRs quickly

**Production Phase:**
- Schedule: `"before 3am"` - Daily batch window
- prHourlyLimit: `1` - Controlled rollout

**High-Activity Repos:**
- May want `prHourlyLimit: 2-3` to handle more updates
- May want `prConcurrentLimit: 5` if you can review quickly

---

## How to Trigger Renovate Manually (for testing)

If you want to test immediately without waiting for the hourly run:

1. Go to Dependency Dashboard issue in your repo
2. Check the box: "Check this box to trigger a request for Renovate to run again"
3. Renovate will run within a few minutes

OR use Mend Developer Portal:
- https://developer.mend.io/github/runlix/radarr
- Click "Run Renovate Now"

**Note:** Manual triggers still respect `prHourlyLimit` and `schedule` settings!
