BEGIN;

ALTER TABLE registers
  ADD COLUMN IF NOT EXISTS scanner_type text NOT NULL DEFAULT 'keyboard_wedge',
  ADD COLUMN IF NOT EXISTS scanner_inter_character_timeout_ms integer NOT NULL DEFAULT 80,
  ADD COLUMN IF NOT EXISTS scanner_duplicate_suppression_ms integer NOT NULL DEFAULT 350,
  ADD COLUMN IF NOT EXISTS printer_type text NOT NULL DEFAULT 'screen',
  ADD COLUMN IF NOT EXISTS printer_address text,
  ADD COLUMN IF NOT EXISTS printer_port integer NOT NULL DEFAULT 9100,
  ADD COLUMN IF NOT EXISTS printer_paper_width_mm integer NOT NULL DEFAULT 80,
  ADD COLUMN IF NOT EXISTS cash_drawer_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS cash_drawer_pin integer NOT NULL DEFAULT 0;

ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_scanner_type_check;
ALTER TABLE registers ADD CONSTRAINT registers_scanner_type_check
  CHECK (scanner_type IN ('disabled', 'keyboard_wedge', 'camera'));
ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_scanner_timeout_check;
ALTER TABLE registers ADD CONSTRAINT registers_scanner_timeout_check
  CHECK (scanner_inter_character_timeout_ms BETWEEN 20 AND 1000);
ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_scanner_suppression_check;
ALTER TABLE registers ADD CONSTRAINT registers_scanner_suppression_check
  CHECK (scanner_duplicate_suppression_ms BETWEEN 0 AND 5000);
ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_printer_type_check;
ALTER TABLE registers ADD CONSTRAINT registers_printer_type_check
  CHECK (printer_type IN ('screen', 'network_esc_pos'));
ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_printer_address_check;
ALTER TABLE registers ADD CONSTRAINT registers_printer_address_check
  CHECK (printer_type <> 'network_esc_pos' OR
    (printer_address IS NOT NULL AND length(trim(printer_address)) > 0));
ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_printer_port_check;
ALTER TABLE registers ADD CONSTRAINT registers_printer_port_check
  CHECK (printer_port BETWEEN 1 AND 65535);
ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_printer_width_check;
ALTER TABLE registers ADD CONSTRAINT registers_printer_width_check
  CHECK (printer_paper_width_mm IN (58, 80));
ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_cash_drawer_pin_check;
ALTER TABLE registers ADD CONSTRAINT registers_cash_drawer_pin_check
  CHECK (cash_drawer_pin IN (0, 1));
ALTER TABLE registers DROP CONSTRAINT IF EXISTS registers_cash_drawer_printer_check;
ALTER TABLE registers ADD CONSTRAINT registers_cash_drawer_printer_check
  CHECK (NOT cash_drawer_enabled OR printer_type = 'network_esc_pos');

CREATE TABLE IF NOT EXISTS receipt_reprint_events (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  register_id text NOT NULL,
  sale_id text NOT NULL,
  requested_by_user_id text NOT NULL,
  requested_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (register_id, organization_id, branch_id)
    REFERENCES registers(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (sale_id, organization_id, branch_id)
    REFERENCES sales(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (requested_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS receipt_reprint_events_sale_idx
  ON receipt_reprint_events (organization_id, branch_id, sale_id, requested_at);

COMMIT;
