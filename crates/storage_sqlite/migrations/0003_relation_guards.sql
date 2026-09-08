-- SQLite foreign keys cannot express that a child folder/request must belong to
-- the same collection as its optional parent folder. Keep that invariant at the
-- database boundary too, so imports and future callers cannot bypass the API.
CREATE TRIGGER folders_parent_must_share_collection_insert
BEFORE INSERT ON folders
WHEN NEW.parent_folder_id IS NOT NULL
 AND NOT EXISTS (
    SELECT 1 FROM folders parent
    WHERE parent.id = NEW.parent_folder_id
      AND parent.collection_id = NEW.collection_id
 )
BEGIN
    SELECT RAISE(ABORT, 'folder parent must belong to the same collection');
END;

CREATE TRIGGER folders_parent_must_share_collection_update
BEFORE UPDATE OF parent_folder_id, collection_id ON folders
WHEN NEW.parent_folder_id IS NOT NULL
 AND NOT EXISTS (
    SELECT 1 FROM folders parent
    WHERE parent.id = NEW.parent_folder_id
      AND parent.collection_id = NEW.collection_id
 )
BEGIN
    SELECT RAISE(ABORT, 'folder parent must belong to the same collection');
END;

CREATE TRIGGER requests_folder_must_share_collection_insert
BEFORE INSERT ON requests
WHEN NEW.folder_id IS NOT NULL
 AND NOT EXISTS (
    SELECT 1 FROM folders folder
    WHERE folder.id = NEW.folder_id
      AND folder.collection_id = NEW.collection_id
 )
BEGIN
    SELECT RAISE(ABORT, 'request folder must belong to the same collection');
END;

CREATE TRIGGER requests_folder_must_share_collection_update
BEFORE UPDATE OF folder_id, collection_id ON requests
WHEN NEW.folder_id IS NOT NULL
 AND NOT EXISTS (
    SELECT 1 FROM folders folder
    WHERE folder.id = NEW.folder_id
      AND folder.collection_id = NEW.collection_id
 )
BEGIN
    SELECT RAISE(ABORT, 'request folder must belong to the same collection');
END;
