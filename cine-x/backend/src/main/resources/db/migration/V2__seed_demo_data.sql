DO $$
DECLARE
    v_hash VARCHAR(255) := '$2a$10$bFSi91sBr8IX9DIZgmO7yuBM59nAsgskCzGotxbLzdoYDj2CcUJ.q';
    v_now TIMESTAMP := CURRENT_TIMESTAMP;
    v_owner_id BIGINT;
    v_writer_id BIGINT;
    v_project_id BIGINT;
    v_act1_id BIGINT;
    v_act2_id BIGINT;
    v_loc1_id BIGINT;
    v_loc2_id BIGINT;
BEGIN
    INSERT INTO users(email, password_hash, display_name, system_role, enabled, created_at, updated_at)
    VALUES ('owner@cinex.local', v_hash, 'CINE-X Owner', 'USER', TRUE, v_now, v_now)
    ON CONFLICT (email) DO NOTHING;

    INSERT INTO users(email, password_hash, display_name, system_role, enabled, created_at, updated_at)
    VALUES ('writer@cinex.local', v_hash, 'Bien kich Demo', 'USER', TRUE, v_now, v_now)
    ON CONFLICT (email) DO NOTHING;

    SELECT id INTO v_owner_id FROM users WHERE email = 'owner@cinex.local';
    SELECT id INTO v_writer_id FROM users WHERE email = 'writer@cinex.local';

    SELECT id INTO v_project_id
    FROM projects
    WHERE title = 'Nguoi Giu Anh Sang' AND owner_id = v_owner_id
    LIMIT 1;

    IF v_project_id IS NULL THEN
        INSERT INTO projects(owner_id, title, genre, description, start_date, poster_url, status, deleted, created_at, updated_at, version)
        VALUES (v_owner_id, 'Nguoi Giu Anh Sang', 'Sci-fi drama', 'Du an demo cho CINE-X.', DATE '2026-07-01', NULL, 'ACTIVE', FALSE, v_now, v_now, 0)
        RETURNING id INTO v_project_id;

        INSERT INTO project_members(project_id, user_id, role, joined_at)
        VALUES (v_project_id, v_owner_id, 'OWNER', v_now), (v_project_id, v_writer_id, 'SCREENWRITER', v_now);

        INSERT INTO acts(project_id, title, description, sequence_order, created_at, updated_at)
        VALUES
          (v_project_id, 'Act 1 - Khoi dau', 'Gioi thieu the gioi va xung dot.', 1, v_now, v_now),
          (v_project_id, 'Act 2 - Doi dau', 'Cac nhan vat bi day vao lua chon kho.', 2, v_now, v_now),
          (v_project_id, 'Act 3 - Anh sang', 'Cao trao va ket thuc.', 3, v_now, v_now);

        INSERT INTO characters(project_id, name, role_type, description, image_url, created_at, updated_at)
        VALUES
          (v_project_id, 'Linh', 'MAIN', 'Ky su anh sang tre tuoi.', NULL, v_now, v_now),
          (v_project_id, 'Minh', 'SUPPORT', 'Tro ly dao dien noi tam.', NULL, v_now, v_now),
          (v_project_id, 'Dam dong nha ga', 'CROWD', 'Nguoi dan trong thanh pho ngam.', NULL, v_now, v_now);

        INSERT INTO locations(project_id, name, setting_type, time_of_day, notes, created_at, updated_at)
        VALUES
          (v_project_id, 'Phong dieu khien ngam', 'INT', 'NIGHT', 'Anh den xanh, nhieu man hinh.', v_now, v_now),
          (v_project_id, 'San ga tren cao', 'EXT', 'DAY', 'Gio manh, bien quang cao khong lo.', v_now, v_now);

        SELECT id INTO v_act1_id FROM acts WHERE project_id = v_project_id AND sequence_order = 1;
        SELECT id INTO v_act2_id FROM acts WHERE project_id = v_project_id AND sequence_order = 2;
        SELECT id INTO v_loc1_id FROM locations WHERE project_id = v_project_id AND name = 'Phong dieu khien ngam';
        SELECT id INTO v_loc2_id FROM locations WHERE project_id = v_project_id AND name = 'San ga tren cao';

        INSERT INTO scenes(project_id, act_id, location_id, scene_number, title, summary, status, estimated_minutes, created_at, updated_at)
        VALUES
          (v_project_id, v_act1_id, v_loc1_id, 1, 'Tin hieu dau tien', 'Linh phat hien mot nguon sang bat thuong duoi long thanh pho.', 'DONE', 8, v_now, v_now),
          (v_project_id, v_act1_id, v_loc2_id, 2, 'Duong ray mat dien', 'Minh dua Linh qua san ga de tranh luc luong truy duoi.', 'IN_PROGRESS', 12, v_now, v_now),
          (v_project_id, v_act2_id, v_loc1_id, 3, 'Cua so bi khoa', 'Nhom phai quyet dinh co kich hoat he thong hay khong.', 'TODO', 15, v_now, v_now);

        INSERT INTO scene_characters(scene_id, character_id)
        SELECT s.id, c.id
        FROM scenes s
        JOIN characters c ON c.project_id = s.project_id
        WHERE s.project_id = v_project_id
          AND (
            (s.scene_number = 1 AND c.name IN ('Linh'))
            OR (s.scene_number = 2 AND c.name IN ('Linh', 'Minh', 'Dam dong nha ga'))
            OR (s.scene_number = 3 AND c.name IN ('Linh', 'Minh'))
          );
    END IF;
END $$;
