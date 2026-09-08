-- Authentication is stored alongside the request definition. Existing requests
-- are deliberately assigned the explicit no-auth variant on upgrade.
ALTER TABLE requests ADD COLUMN auth_json TEXT NOT NULL DEFAULT '{"kind":"none"}';
