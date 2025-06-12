-- Get churned orgs with their churn dates
WITH churned_orgs AS (
  SELECT 
    s.org_id,
    s.canceled_at AS churn_date
  FROM subscriptions s
  WHERE s.status = 'canceled' AND s.canceled_at IS NOT NULL
),

-- All support tickets tied to those orgs
tickets_with_churn AS (
  SELECT 
    t.*,
    c.churn_date
  FROM support_tickets t
  JOIN churned_orgs c ON t.org_id = c.org_id
),

-- Filter tickets to those opened within 90 days before churn
filtered_tickets AS (
  SELECT 
    *,
    DATE_PART('day', churn_date - opened_at) AS days_before_churn
  FROM tickets_with_churn
  WHERE opened_at < churn_date
),

-- Only those within a 90-day window
tickets_90_days AS (
  SELECT *
  FROM filtered_tickets
  WHERE days_before_churn BETWEEN 0 AND 90
),

-- Compute average response time (opened to closed duration)
ticket_response_metrics AS (
  SELECT 
    org_id,
    COUNT(*) AS ticket_count,
    AVG(EXTRACT(EPOCH FROM (closed_at - opened_at))/3600) AS avg_hours_to_close
  FROM tickets_90_days
  WHERE closed_at IS NOT NULL
  GROUP BY org_id
)

-- Final output with org name
SELECT 
  o.name AS organization_name,
  m.ticket_count,
  ROUND(m.avg_hours_to_close, 2) AS avg_hours_to_close
FROM ticket_response_metrics m
JOIN organizations o ON o.id = m.org_id
ORDER BY m.ticket_count DESC;
