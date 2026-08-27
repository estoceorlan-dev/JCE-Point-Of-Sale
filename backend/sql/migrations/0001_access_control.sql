CREATE TABLE IF NOT EXISTS organizations (
  id text PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  timezone text NOT NULL DEFAULT 'Asia/Manila',
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS branches (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  code text NOT NULL,
  name text NOT NULL,
  timezone text NOT NULL DEFAULT 'Asia/Manila',
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, code),
  UNIQUE (id, organization_id)
);

CREATE TABLE IF NOT EXISTS app_users (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  firebase_uid text,
  email text NOT NULL,
  display_name text NOT NULL,
  status text NOT NULL CHECK (
    status IN ('invited', 'active', 'suspended', 'disabled')
  ),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, email),
  UNIQUE (organization_id, firebase_uid),
  UNIQUE (id, organization_id)
);

CREATE TABLE IF NOT EXISTS roles (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, code),
  UNIQUE (id, organization_id)
);

CREATE TABLE IF NOT EXISTS permissions (
  code text PRIMARY KEY,
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id text NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_code text NOT NULL REFERENCES permissions(code) ON DELETE CASCADE,
  granted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_code)
);

CREATE TABLE IF NOT EXISTS user_role_assignments (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text REFERENCES branches(id) ON DELETE RESTRICT,
  user_id text NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  role_id text NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  CONSTRAINT user_role_assignments_branch_organization_fk
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT user_role_assignments_user_organization_fk
    FOREIGN KEY (user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE CASCADE,
  CONSTRAINT user_role_assignments_role_organization_fk
    FOREIGN KEY (role_id, organization_id)
    REFERENCES roles(id, organization_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS user_role_assignments_user_scope_idx
  ON user_role_assignments (user_id, organization_id, branch_id)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS devices (
  id text NOT NULL,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text REFERENCES branches(id) ON DELETE RESTRICT,
  user_id text NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  platform text NOT NULL,
  display_name text,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  registered_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  disabled_at timestamptz,
  PRIMARY KEY (organization_id, id),
  CONSTRAINT devices_branch_organization_fk
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT devices_user_organization_fk
    FOREIGN KEY (user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE CASCADE
);
