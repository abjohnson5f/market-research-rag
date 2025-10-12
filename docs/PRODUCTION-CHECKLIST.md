# Production Deployment Checklist

Final validation checklist before deploying the Market Research RAG system to production.

**Use this checklist when:**
- All testing (Issue #5) has passed
- System has been validated end-to-end
- Ready to switch from manual testing to production use

---

## Prerequisites

Before starting this checklist, ensure:

- [ ] All GitHub Issues #1-4 completed
- [ ] Testing suite (Issue #5) passed with 95%+ success rate
- [ ] System has been used for at least 1 week in testing mode
- [ ] Stakeholders have reviewed sample outputs

---

## 1. Database Readiness

### 1.1 Schema Validation

- [ ] All tables exist and have correct structure
  ```sql
  \d market_executions
  \d businesses
  \d business_reviews
  ```

- [ ] All indexes created and functional
  ```bash
  psql "YOUR_URL" -f schema/run-tests.sql
  # All index tests should pass
  ```

- [ ] Generated columns working correctly
  ```sql
  SELECT COUNT(*) FROM businesses
  WHERE city IS NULL AND business_data->'overview'->>'city' IS NOT NULL;
  # Should return 0
  ```

### 1.2 Performance Benchmarks

- [ ] Index usage verified with EXPLAIN ANALYZE
  ```sql
  EXPLAIN ANALYZE
  SELECT * FROM businesses WHERE city = 'Phoenix' AND rating > 4.5;
  -- Should show "Index Scan using idx_businesses_city_rating"
  ```

- [ ] Query execution times meet targets:
  - [ ] Simple queries (< 10 rows): < 100ms
  - [ ] JSONB queries: < 200ms
  - [ ] Full-text search: < 500ms
  - [ ] Aggregations: < 1 second

### 1.3 Data Integrity

- [ ] No orphaned records
  ```sql
  -- Check for businesses without executions
  SELECT COUNT(*) FROM businesses b
  WHERE NOT EXISTS (SELECT 1 FROM market_executions WHERE id = b.execution_id);
  -- Should return 0

  -- Check for reviews without businesses
  SELECT COUNT(*) FROM business_reviews r
  WHERE NOT EXISTS (SELECT 1 FROM businesses WHERE id = r.business_id);
  -- Should return 0
  ```

- [ ] Unique constraints enforced (no duplicate apify_place_ids)
  ```sql
  SELECT apify_place_id, COUNT(*)
  FROM businesses
  WHERE apify_place_id IS NOT NULL
  GROUP BY apify_place_id
  HAVING COUNT(*) > 1;
  -- Should return 0 rows
  ```

### 1.4 Backup Strategy

- [ ] **Automated backups configured**
  - Frequency: Daily minimum (recommended: every 6 hours)
  - Retention: 30 days minimum
  - Backup location: Off-site or separate region

- [ ] **Backup tested successfully**
  ```bash
  # Test backup creation
  pg_dump "YOUR_URL" > backup_test.sql

  # Test restore on separate database
  psql "TEST_DB_URL" < backup_test.sql

  # Verify data integrity after restore
  psql "TEST_DB_URL" -c "SELECT COUNT(*) FROM businesses;"
  ```

- [ ] **Point-in-time recovery available** (for critical production systems)
  - Supabase: Verify PITR enabled in project settings
  - Self-hosted: WAL archiving configured

### 1.5 Monitoring Setup

- [ ] **Database monitoring enabled**
  - Query performance tracking
  - Connection pool monitoring
  - Disk space alerts (alert at 70% full)
  - Slow query logging (> 1 second)

- [ ] **Supabase Dashboard configured** (if using Supabase)
  - Query performance panel reviewed
  - Database size trends monitored
  - Connection count tracked

---

## 2. n8n Workflow Readiness

### 2.1 Data Collection Workflow

- [ ] **Workflow tested end-to-end**
  - Completed at least 3 successful runs
  - Processed 100+ businesses without errors
  - All data correctly inserted into database

- [ ] **Production URLs configured**
  - [ ] Apify Actor run URL updated (remove `maxCrawledPlacesPerSearch` limit)
  - [ ] Production search query configured (e.g., "home services in Phoenix")
  - [ ] Apify dataset access verified

- [ ] **Error handling implemented**
  - [ ] Error Trigger node added
  - [ ] Notification sent on failure (Slack/Email)
  - [ ] Failed executions marked clearly in database
  - [ ] Retry logic for transient failures (optional but recommended)

- [ ] **Scheduled execution configured**
  - Frequency: Weekly recommended (adjust based on needs)
  - Day/time: Off-peak hours (e.g., Sunday 2 AM)
  - Schedule tested and working

- [ ] **Execution logging enabled**
  - Execution IDs tracked in market_executions table
  - Execution duration monitored
  - Error messages captured

### 2.2 RAG Chat Workflow

- [ ] **Chat interface tested thoroughly**
  - [ ] 20+ test conversations completed
  - [ ] All AI tools execute successfully
  - [ ] Memory persists across messages
  - [ ] Error handling prevents crashes

- [ ] **Production webhook secured**
  - [ ] Authentication enabled (if public-facing)
  - [ ] HTTPS enforced (not HTTP)
  - [ ] CORS configured properly
  - [ ] Rate limiting considered (for public APIs)

- [ ] **AI Agent optimized**
  - [ ] System prompt finalized and tested
  - [ ] Tool descriptions clear and comprehensive
  - [ ] Model selection finalized (GPT-4o-mini recommended for cost)
  - [ ] Token limits configured (prevent runaway costs)

- [ ] **Memory management configured**
  - [ ] Postgres Chat Memory connected
  - [ ] Memory table indexed (idx on session_id)
  - [ ] Old conversations archived (optional: add cleanup job)

---

## 3. Credentials & Security

### 3.1 Credential Management

- [ ] **All credentials stored securely in n8n**
  - [ ] Postgres connection (never hardcoded)
  - [ ] OpenAI API key (never in git)
  - [ ] Apify API token (never in git)

- [ ] **Credentials tested and valid**
  - [ ] Postgres: Test connection button works
  - [ ] OpenAI: API key has credits and rate limits
  - [ ] Apify: Token has access to required Actors

- [ ] **No credentials in git repository**
  ```bash
  git log --all --full-history -- '*.json' | grep -i "api_key\|password\|token"
  # Should return nothing
  ```

### 3.2 Access Control

- [ ] **Database access restricted**
  - Postgres user has minimal required permissions
  - Read-only access for reporting tools (if applicable)
  - Superuser access limited to admins

- [ ] **n8n access controlled**
  - User accounts created (not using default admin)
  - Two-factor authentication enabled (if available)
  - Workflow edit permissions limited to authorized users

- [ ] **Webhook URLs protected** (if public)
  - Authentication required
  - API key validation
  - Rate limiting configured

### 3.3 Data Privacy

- [ ] **GDPR/Privacy compliance reviewed** (if applicable)
  - Customer review data handling documented
  - Data retention policy defined
  - Data deletion process documented

- [ ] **PII handling** (if collecting personal info)
  - PII encrypted at rest
  - PII access logged
  - Data anonymization considered

---

## 4. Performance & Scalability

### 4.1 Load Testing

- [ ] **Chat interface load tested**
  - [ ] 10 concurrent users tested
  - [ ] Response times under load measured
  - [ ] No degradation in quality at scale

- [ ] **Database load tested**
  - [ ] 1000+ businesses inserted successfully
  - [ ] 10,000+ reviews handled without slowdown
  - [ ] Query performance maintained with large datasets

### 4.2 Resource Limits

- [ ] **OpenAI rate limits understood**
  - Current tier: ___________
  - RPM limit: ___________
  - TPM limit: ___________
  - Monthly budget set (recommended: $50-100 for testing, scale as needed)

- [ ] **Database limits understood**
  - Connection limit: ___________
  - Storage limit: ___________
  - Storage growth rate estimated: ___________ GB/month

- [ ] **n8n execution limits**
  - Max workflow execution time: 10 minutes (default)
  - Concurrent workflow executions: Depends on plan
  - Workflow timeout configured appropriately

### 4.3 Cost Optimization

- [ ] **OpenAI costs monitored**
  - Usage alerts configured (alert at 80% of monthly budget)
  - Token usage optimized (LIMIT queries, truncate long outputs)
  - Model selection cost-effective (GPT-4o-mini for most queries)

- [ ] **Database costs optimized**
  - Appropriate plan selected
  - Auto-scaling configured (if available)
  - Unnecessary data archived

- [ ] **n8n costs optimized**
  - Workflow executions minimized (batch operations where possible)
  - Inactive workflows deactivated
  - Execution history retention configured (keep 30 days, archive older)

---

## 5. Monitoring & Alerting

### 5.1 System Health Monitoring

- [ ] **Uptime monitoring configured**
  - Chat webhook monitored (e.g., UptimeRobot, Pingdom)
  - Alert if webhook returns errors
  - Alert if response time > 30 seconds

- [ ] **Database monitoring configured**
  - Connection count alerts
  - Query performance alerts
  - Disk space alerts
  - Backup success/failure alerts

- [ ] **n8n execution monitoring**
  - Failed workflow alerts
  - Long-running execution alerts (> 10 minutes)
  - Execution frequency tracked

### 5.2 Application Metrics

- [ ] **Usage metrics tracked**
  - Chat conversations per day
  - Most common queries identified
  - Average response time measured
  - Tool usage frequency (which tools used most)

- [ ] **Data collection metrics tracked**
  - Workflows executed per week
  - Businesses collected per execution
  - Average reviews per business
  - Execution duration trends

- [ ] **Error rate tracked**
  - Failed executions / total executions < 1%
  - SQL errors / total queries < 1%
  - AI hallucinations flagged and reviewed

### 5.3 Alert Channels

- [ ] **Critical alerts configured**
  - Database connection failures → Immediate notification
  - Workflow failures → Notification within 15 minutes
  - OpenAI API errors → Notification
  - Backup failures → Immediate notification

- [ ] **Notification channels configured**
  - [ ] Email notifications (for critical alerts)
  - [ ] Slack/Teams notifications (for all alerts)
  - [ ] SMS notifications (for critical only - optional)

---

## 6. Documentation & Training

### 6.1 Technical Documentation

- [ ] **System architecture documented**
  - [ ] README.md complete and accurate
  - [ ] docs/SETUP.md reflects current setup
  - [ ] docs/TESTING.md matches actual tests
  - [ ] docs/TROUBLESHOOTING.md includes all known issues

- [ ] **Workflow documentation complete**
  - Data collection workflow explained
  - RAG chat workflow explained
  - Node configurations documented
  - Credential setup documented

- [ ] **Database schema documented**
  - [ ] schema/01-tables.sql has inline comments
  - [ ] schema/02-indexes.sql explains each index
  - [ ] Generated columns explained
  - [ ] JSONB structure documented

### 6.2 Operational Documentation

- [ ] **Runbook created** (how to operate the system)
  - [ ] How to run data collection manually
  - [ ] How to update Apify search query
  - [ ] How to access chat interface
  - [ ] How to restart workflows

- [ ] **Troubleshooting guide updated**
  - [ ] Common errors documented
  - [ ] Solutions verified and tested
  - [ ] Contact information for escalation

- [ ] **Change management process defined**
  - How to request changes
  - How to test changes
  - How to deploy changes
  - Rollback procedure

### 6.3 User Training

- [ ] **End-user documentation created**
  - [ ] How to access chat interface
  - [ ] Example questions and use cases
  - [ ] How to interpret results
  - [ ] What to do if system is down

- [ ] **Stakeholders trained**
  - [ ] Demo session completed
  - [ ] Q&A session held
  - [ ] Feedback incorporated
  - [ ] Contact for support established

---

## 7. Testing & Validation

### 7.1 Pre-Production Testing

- [ ] **Full test suite passed**
  ```bash
  psql "YOUR_URL" -f schema/run-tests.sql
  # All tests should pass
  ```

- [ ] **End-to-end scenarios tested**
  - [ ] Scenario 1: New market research (Issue #5)
  - [ ] Scenario 2: Newsletter creation (Issue #5)
  - [ ] Scenario 3: Competitive analysis (Issue #5)

- [ ] **Performance benchmarks met**
  - All query times within targets (see section 1.2)
  - Chat response times < 5 seconds for 90% of queries
  - No query timeouts

### 7.2 User Acceptance Testing (UAT)

- [ ] **UAT completed with stakeholders**
  - [ ] 5+ real-world queries tested
  - [ ] Results validated against expectations
  - [ ] Feedback documented and addressed

- [ ] **Edge cases tested**
  - Empty results handled gracefully
  - Invalid inputs don't crash system
  - Concurrent users work correctly

### 7.3 Disaster Recovery Testing

- [ ] **Backup restoration tested**
  - Backup created and restored successfully
  - Data integrity verified after restore
  - Time to restore measured (should be < 1 hour)

- [ ] **Failure scenarios tested**
  - Database connection lost → Graceful degradation
  - OpenAI API down → Clear error message
  - Apify rate limit → Workflow fails with clear error

---

## 8. Go-Live Planning

### 8.1 Deployment Schedule

- [ ] **Go-live date set:** _______________
- [ ] **Rollback plan documented**
  - How to revert to old system
  - Data migration reversal (if applicable)
  - Communication plan for rollback

- [ ] **Go-live team identified**
  - Technical lead: _______________
  - Stakeholder contact: _______________
  - On-call support: _______________

### 8.2 Launch Checklist

**Day before launch:**
- [ ] Final backup created
- [ ] All tests re-run and passing
- [ ] Team notified of go-live time
- [ ] Monitoring dashboards open and ready

**Launch day:**
- [ ] Remove test data (if applicable)
  ```bash
  psql "YOUR_URL" -f schema/test-data.sql --variable=CLEANUP=true
  ```
- [ ] Run final production data collection
- [ ] Verify data in database
- [ ] Test chat interface with production data
- [ ] Share chat URL with stakeholders
- [ ] Monitor for first 2 hours

**Day after launch:**
- [ ] Review usage metrics
- [ ] Check for errors
- [ ] Gather initial feedback
- [ ] Document any issues

### 8.3 Stakeholder Communication

- [ ] **Launch announcement sent**
  - Chat interface URL shared
  - Quick start guide included
  - Support contact information provided

- [ ] **Feedback mechanism established**
  - How to report issues
  - How to request features
  - Regular check-ins scheduled

---

## 9. Post-Launch Monitoring

### 9.1 First Week (Critical Monitoring)

- [ ] **Daily health checks**
  - [ ] Check workflow execution success rate
  - [ ] Review chat conversation logs
  - [ ] Monitor database size growth
  - [ ] Check OpenAI costs

- [ ] **Issue tracking**
  - [ ] All reported issues logged
  - [ ] Critical issues resolved within 24 hours
  - [ ] User feedback collected and categorized

### 9.2 Ongoing Operations

- [ ] **Weekly reviews**
  - Usage trends analyzed
  - Performance metrics reviewed
  - Cost tracking updated
  - Optimization opportunities identified

- [ ] **Monthly maintenance**
  - Database vacuuming (if self-hosted)
  - Old chat histories archived (optional)
  - Unused data cleaned up
  - Security patches applied

- [ ] **Quarterly improvements**
  - Feature requests prioritized
  - System optimizations implemented
  - Documentation updates
  - User training refreshers

---

## 10. Sign-Off

### Final Approval

By checking the boxes below, I certify that:

- [ ] All items in this checklist have been completed or explicitly marked as not applicable
- [ ] Testing results show 95%+ success rate
- [ ] All stakeholders have been trained and provided with documentation
- [ ] Monitoring and alerting are configured and tested
- [ ] Backup and disaster recovery procedures are documented and tested
- [ ] The system is ready for production use

**Approved by:**

- Technical Lead: _______________ Date: _______________
- Stakeholder: _______________ Date: _______________

---

## Appendix: Quick Reference Commands

### Database Health Check
```bash
psql "YOUR_URL" -f schema/run-tests.sql
```

### Insert Test Data
```bash
psql "YOUR_URL" -f schema/test-data.sql
```

### Clean Up Test Data
```bash
psql "YOUR_URL" -f schema/test-data.sql --variable=CLEANUP=true
```

### Create Backup
```bash
pg_dump "YOUR_URL" > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Check System Status
```sql
-- Total businesses
SELECT COUNT(*) FROM businesses;

-- Recent executions
SELECT * FROM recent_executions LIMIT 5;

-- Database size
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Active connections
SELECT COUNT(*) FROM pg_stat_activity;
```

### Monitor OpenAI Usage
Visit: https://platform.openai.com/usage

### Check n8n Executions
n8n UI → Executions → Filter by date range

---

**Congratulations!** If you've completed this checklist, your Market Research RAG system is production-ready.

**Next steps:**
1. Share chat interface URL with stakeholders
2. Schedule first real data collection
3. Monitor usage and gather feedback
4. Iterate and improve based on real-world usage
