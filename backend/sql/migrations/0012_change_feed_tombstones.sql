-- Current archive/delete commands publish tombstones. Preserve legacy delete
-- events so older history and clients remain readable; never rewrite the feed.
ALTER TABLE change_feed DROP CONSTRAINT change_feed_change_type_check;
ALTER TABLE change_feed ADD CONSTRAINT change_feed_change_type_check
  CHECK (change_type IN ('upsert', 'delete', 'tombstone'));
