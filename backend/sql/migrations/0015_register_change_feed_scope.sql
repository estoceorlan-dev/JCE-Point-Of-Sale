-- Registers belong to one branch. Older command processing incorrectly wrote
-- their change-feed entries at organization scope, which exposed them to every
-- branch and left clients without the branch required to apply the change.
UPDATE change_feed AS feed
SET branch_id = register_row.branch_id
FROM registers AS register_row
WHERE feed.aggregate_type = 'register'
  AND feed.aggregate_id = register_row.id
  AND feed.organization_id = register_row.organization_id
  AND feed.branch_id IS NULL;
