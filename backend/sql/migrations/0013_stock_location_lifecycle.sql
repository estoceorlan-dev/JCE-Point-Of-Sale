-- Fail preflight if historical normalized codes/defaults conflict. Do not rename
-- records or replace stock history automatically.
CREATE UNIQUE INDEX stock_locations_normalized_code_idx
  ON stock_locations (organization_id, branch_id, upper(btrim(code)));

CREATE UNIQUE INDEX stock_locations_active_default_idx
  ON stock_locations (organization_id, branch_id)
  WHERE is_default = true AND is_active = true AND deleted_at IS NULL;
