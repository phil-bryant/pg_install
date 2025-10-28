create table app.item (
	item_id BIGSERIAL PRIMARY KEY,
	parent_item_id BIGINT REFERENCES app.item(item_id),
	item_seq INT NOT NULL,
	item TEXT NOT NULL,
	UNIQUE (parent_item_id, item_seq)
);

CREATE INDEX idx_item_parent_seq ON app.item(parent_item_id, item_seq);

CREATE FUNCTION app.renumber_items() RETURNS trigger AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		UPDATE app.item SET item_seq = item_seq - 1 
		WHERE parent_item_id = OLD.parent_item_id AND item_seq > OLD.item_seq;
		RETURN OLD;
	ELSIF TG_OP = 'INSERT' THEN
		UPDATE app.item SET item_seq = item_seq + 1 
		WHERE parent_item_id = NEW.parent_item_id AND item_seq >= NEW.item_seq AND item_id != NEW.item_id;
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.parent_item_id = NEW.parent_item_id THEN
			IF NEW.item_seq < OLD.item_seq THEN
				UPDATE app.item SET item_seq = item_seq + 1 
				WHERE parent_item_id = NEW.parent_item_id AND item_seq >= NEW.item_seq AND item_seq < OLD.item_seq AND item_id != NEW.item_id;
			ELSIF NEW.item_seq > OLD.item_seq THEN
				UPDATE app.item SET item_seq = item_seq - 1 
				WHERE parent_item_id = NEW.parent_item_id AND item_seq > OLD.item_seq AND item_seq <= NEW.item_seq AND item_id != NEW.item_id;
			END IF;
		ELSE
			UPDATE app.item SET item_seq = item_seq - 1 
			WHERE parent_item_id = OLD.parent_item_id AND item_seq > OLD.item_seq;
			UPDATE app.item SET item_seq = item_seq + 1 
			WHERE parent_item_id = NEW.parent_item_id AND item_seq >= NEW.item_seq AND item_id != NEW.item_id;
		END IF;
		RETURN NEW;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_item_renumber 
AFTER INSERT OR UPDATE OR DELETE ON app.item 
FOR EACH ROW EXECUTE FUNCTION app.renumber_items();

create table app.tag (
	tag_id SERIAL PRIMARY KEY,
	tag TEXT UNIQUE NOT NULL
);

create table app.item_tag (
	item_id BIGINT REFERENCES app.item(item_id) ON DELETE CASCADE,
	tag_id INT REFERENCES app.tag(tag_id) ON DELETE CASCADE,
	PRIMARY KEY (item_id, tag_id)
);

CREATE INDEX idx_item_tag_tag ON app.item_tag(tag_id);

select * from app.item;