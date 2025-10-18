# GitHub Actions Workflows

## Neon Branch Preview (Database per PR)

**File:** `neon-branch-preview.yml`

### What It Does

Automatically creates an **ephemeral database branch** for every pull request, runs all migrations, and posts a schema diff comment to the PR discussion.

### Workflow Triggers

| Event | Action | What Happens |
|-------|--------|--------------|
| PR opened | `opened` | Creates Neon branch + runs migrations |
| PR reopened | `reopened` | Creates Neon branch + runs migrations |
| New commits | `synchronize` | Recreates branch + reruns migrations |
| PR closed | `closed` | **Deletes** Neon branch (cleanup) |

### Migration Execution Order

When a PR is created or updated, the workflow automatically runs:

1. **`schema/01-tables.sql`** - Creates `market_executions`, `businesses`, `business_reviews` tables
2. **`schema/02-indexes.sql`** - Adds GIN indexes, B-tree indexes, full-text search
3. **`schema/03-strategic-views.sql`** - Creates 8 strategic analysis views (if exists in branch)
4. **`schema/test-data.sql`** - Loads 10 test businesses + 30 reviews (optional, non-blocking)

### Schema Diff Comments

The workflow uses `neondatabase/schema-diff-action@v1` to automatically post a comment to your PR showing:

- **New tables** added
- **New columns** in existing tables
- **New views** created
- **Index changes**
- **Constraint modifications**

**Example comment:**
```
📊 Schema Diff Report

Comparing: main → preview/pr-15-issue-12-strategic-views

✨ New Views (8):
  + niche_opportunities
  + competitive_positioning
  + customer_sentiment
  + market_overview
  + operational_intelligence
  + pricing_intelligence
  + growth_trends
  + expansion_opportunities

No breaking changes detected ✅
```

### How to Use

#### For Reviewers

When reviewing a PR, check the **schema diff comment** to understand database changes:

1. Look for the bot comment (appears within ~2 minutes of PR creation)
2. Review new tables/columns/views
3. Verify no breaking changes (dropped columns, renamed tables)
4. Approve if schema changes match PR description

#### For PR Authors

**Before creating a PR:**
```bash
# Test migrations locally first
psql "$DATABASE_URL" -f schema/01-tables.sql
psql "$DATABASE_URL" -f schema/02-indexes.sql
psql "$DATABASE_URL" -f schema/03-strategic-views.sql

# Verify no errors
echo $?  # Should be 0
```

**After creating a PR:**
1. Wait for GitHub Actions to complete (~2 minutes)
2. Check for green checkmark on PR
3. Review schema diff comment
4. If migrations fail, check **Actions** tab for logs

### Troubleshooting

#### Migration Fails on Step 1 (Tables)

**Symptom:** Red X on "Create Neon Branch & Run Migrations" job

**Cause:** SQL syntax error in `01-tables.sql`

**Fix:**
```bash
# Test locally
psql "$DATABASE_URL" -f schema/01-tables.sql -v ON_ERROR_STOP=1

# Check for error on specific line
```

#### Migration Fails on Step 3 (Views)

**Symptom:** Error "relation 'businesses' does not exist"

**Cause:** View references a table that wasn't created in Step 1

**Fix:** Verify `03-strategic-views.sql` references correct table names

#### Schema Diff Comment Not Appearing

**Symptom:** No bot comment on PR after 5+ minutes

**Cause:** Missing `permissions` in workflow or invalid `NEON_API_KEY`

**Fix:**
1. Verify workflow has `pull-requests: write` permission (line 11)
2. Check GitHub Settings → Secrets → `NEON_API_KEY` is set
3. Re-run workflow from Actions tab

### Preview Database Details

Each PR gets a unique database branch:

**Branch naming:** `preview/pr-<NUMBER>-<BRANCH-NAME>`

**Example:**
- PR #15 from branch `issue-12-strategic-views`
- Branch name: `preview/pr-15-issue-12-strategic-views`

**Connection string:** Available in GitHub Actions logs as:
```
${{ steps.create_neon_branch.outputs.db_url }}
```

**⚠️ Security:** Connection strings contain credentials - never log them!

**Expiration:** Branches auto-delete after:
1. PR is closed/merged, OR
2. 14 days from creation (whichever comes first)

### Cost Optimization

**Neon Free Tier:**
- 10 concurrent branches (plenty for solo dev)
- 3 GB storage per branch
- Branches auto-sleep after 5 minutes of inactivity

**Best Practices:**
1. Close PRs when done (triggers immediate cleanup)
2. Don't create draft PRs until ready (avoids wasted branches)
3. Squash commits to reduce `synchronize` triggers

### Integration with n8n Workflows

**Important:** n8n workflows should use **production database**, not preview branches.

Preview branches are for:
- ✅ Testing schema changes
- ✅ Running automated tests
- ✅ Validating migrations before merge

Preview branches are NOT for:
- ❌ n8n workflow execution (use main branch database)
- ❌ Production data collection
- ❌ Live RAG chat queries

### Advanced: Testing n8n Workflows Against Preview DB

If you want to test n8n workflows against a preview database:

1. Get preview DB connection string from GitHub Actions logs
2. Temporarily update n8n credentials to point to preview DB
3. Run workflow tests
4. Revert credentials to production DB

**⚠️ Warning:** Never commit preview DB credentials to git!

### Monitoring

**Check workflow status:**
```bash
gh run list --workflow=neon-branch-preview.yml
```

**View logs for specific run:**
```bash
gh run view <RUN-ID> --log
```

**Re-run failed workflow:**
```bash
gh run rerun <RUN-ID>
```

### Future Enhancements

Potential improvements to add later:

- [ ] Run `schema/run-tests.sql` automated test suite
- [ ] Post test results as PR comment
- [ ] Deploy n8n workflows to preview environment
- [ ] Run E2E tests against preview database
- [ ] Benchmark query performance (compare to main)

---

## Workflow Maintenance

**When to update this workflow:**

1. **New migration files:** Add to "Run Database Migrations" step
2. **New test suites:** Add validation steps after migrations
3. **Performance tests:** Add benchmark steps before schema diff
4. **Breaking changes:** Add migration compatibility checks

**Testing workflow changes:**

1. Create a test PR from a feature branch
2. Watch Actions tab for execution
3. Verify all steps pass and schema diff appears
4. Close PR (triggers cleanup job)
5. Verify branch deleted in Neon Console

---

**Generated:** 2025-10-18
**Maintainer:** @abjohnson5f
**Documentation:** [Neon Branching Guide](https://neon.tech/docs/guides/branching)
