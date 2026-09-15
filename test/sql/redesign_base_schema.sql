-- Read-only target-table schema snapshot, 2026-09-15. No production rows.
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users(id uuid PRIMARY KEY);
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
DO $$ BEGIN CREATE ROLE authenticated NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE anon NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE TABLE IF NOT EXISTS "public"."species" (
    "id" "text" NOT NULL,
    "category_id" "text",
    "korean_name" "text" NOT NULL,
    "scientific_name" "text" NOT NULL,
    "common_name" "text" NOT NULL,
    "family" "text",
    "registration_required" boolean DEFAULT false,
    "has_care_info" boolean DEFAULT false,
    "has_morph_data" boolean DEFAULT false,
    "tags" "text"[],
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."pets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "species_id" "text",
    "name" "text" NOT NULL,
    "species_name" "text" NOT NULL,
    "morph" "text",
    "sex" "text" DEFAULT 'unknown'::"text",
    "birth_date" "date",
    "adoption_date" "date",
    "weight" double precision,
    "avatar_url" "text",
    "memo" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "enclosure_id" "uuid"
);
CREATE TABLE IF NOT EXISTS "public"."enclosures" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "species" "text",
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);
CREATE TABLE IF NOT EXISTS "public"."devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "device_id" "text" NOT NULL,
    "token_hash" "text" NOT NULL,
    "name" "text" NOT NULL,
    "species" "text",
    "firmware_ver" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_seen_at" timestamp with time zone,
    "is_online" boolean DEFAULT false NOT NULL,
    "enclosure_id" "uuid",
    "capabilities" "jsonb"
);
CREATE TABLE IF NOT EXISTS "public"."cameras" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "enclosure_id" "uuid",
    "camera_id" "text" NOT NULL,
    "token_hash" "text" NOT NULL,
    "name" "text" NOT NULL,
    "model" "text" DEFAULT 'esp32-p4'::"text",
    "firmware_ver" "text",
    "resolution" "text" DEFAULT 'HD'::"text",
    "fps" integer DEFAULT 24,
    "clip_sec" integer DEFAULT 10,
    "stream_mode" "text",
    "stream_until" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_seen_at" timestamp with time zone,
    "is_online" boolean DEFAULT false NOT NULL,
    "rotate_180" boolean DEFAULT false NOT NULL,
    "capabilities" "jsonb"
);
CREATE TABLE IF NOT EXISTS "public"."motion_clips" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "camera_id" "uuid" NOT NULL,
    "enclosure_id" "uuid",
    "owner_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone NOT NULL,
    "duration_sec" double precision NOT NULL,
    "r2_key" "text" NOT NULL,
    "thumbnail_key" "text",
    "file_size" integer,
    "container" "text" DEFAULT 'mp4'::"text",
    "codec" "text" DEFAULT 'h264'::"text",
    "width" integer,
    "height" integer,
    "fps" double precision,
    "motion_score" double precision,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "clip_purpose" "text" NOT NULL,
    CONSTRAINT "motion_clips_purpose_prefix_ck" CHECK (((("clip_purpose" = 'test'::"text") AND ("r2_key" ~~ 'test/%'::"text")) OR (("clip_purpose" = 'production'::"text") AND (("r2_key" ~~ 'terra-clips/clips/%'::"text") OR ("r2_key" ~~ 'research-quarantine/%'::"text") OR ("r2_key" ~~ 'research-excluded/%'::"text") OR ("r2_key" ~~ 'deleted/%'::"text")))))
);
CREATE TABLE IF NOT EXISTS "public"."clip_favorites" (
    "owner_id" "uuid" NOT NULL,
    "clip_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);
CREATE TABLE IF NOT EXISTS "public"."camera_clips" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pet_id" "uuid",
    "started_at" timestamp with time zone NOT NULL,
    "duration_sec" real NOT NULL,
    "has_motion" boolean DEFAULT false NOT NULL,
    "motion_frames" integer,
    "file_path" "text" NOT NULL,
    "file_size" bigint,
    "codec" "text",
    "width" integer,
    "height" integer,
    "fps" real,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "thumbnail_path" "text",
    "camera_id" "uuid",
    "source" "text" DEFAULT 'camera'::"text" NOT NULL,
    "r2_key" "text",
    "thumbnail_r2_key" "text",
    "encoded_file_size" bigint,
    "original_file_size" bigint,
    CONSTRAINT "camera_clips_source_check" CHECK (("source" = ANY (ARRAY['camera'::"text", 'upload'::"text", 'youtube'::"text"])))
);
CREATE TABLE IF NOT EXISTS "public"."pet_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "value" double precision,
    "title" "text",
    "note" "text",
    "metadata" "jsonb",
    "event_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);
CREATE TABLE IF NOT EXISTS "public"."media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "event_id" "uuid",
    "type" "text" NOT NULL,
    "url" "text" NOT NULL,
    "thumbnail_url" "text",
    "caption" "text",
    "file_size" integer,
    "duration" integer,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);
ALTER TABLE ONLY "public"."species"
    ADD CONSTRAINT "species_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."enclosures"
    ADD CONSTRAINT "enclosures_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_device_id_key" UNIQUE ("device_id");
ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."cameras"
    ADD CONSTRAINT "cameras_camera_id_key" UNIQUE ("camera_id");
ALTER TABLE ONLY "public"."cameras"
    ADD CONSTRAINT "cameras_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."motion_clips"
    ADD CONSTRAINT "motion_clips_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."clip_favorites"
    ADD CONSTRAINT "clip_favorites_pkey" PRIMARY KEY ("owner_id", "clip_id");
ALTER TABLE ONLY "public"."camera_clips"
    ADD CONSTRAINT "camera_clips_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."pet_events"
    ADD CONSTRAINT "pet_events_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."media"
    ADD CONSTRAINT "media_pkey" PRIMARY KEY ("id");
ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_enclosure_id_fkey" FOREIGN KEY ("enclosure_id") REFERENCES "public"."enclosures"("id") ON DELETE SET NULL;
ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id");
ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");
ALTER TABLE ONLY "public"."enclosures"
    ADD CONSTRAINT "enclosures_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_enclosure_id_fkey" FOREIGN KEY ("enclosure_id") REFERENCES "public"."enclosures"("id") ON DELETE SET NULL;
ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."cameras"
    ADD CONSTRAINT "cameras_enclosure_id_fkey" FOREIGN KEY ("enclosure_id") REFERENCES "public"."enclosures"("id") ON DELETE SET NULL;
ALTER TABLE ONLY "public"."cameras"
    ADD CONSTRAINT "cameras_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."motion_clips"
    ADD CONSTRAINT "motion_clips_camera_id_fkey" FOREIGN KEY ("camera_id") REFERENCES "public"."cameras"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."motion_clips"
    ADD CONSTRAINT "motion_clips_enclosure_id_fkey" FOREIGN KEY ("enclosure_id") REFERENCES "public"."enclosures"("id") ON DELETE SET NULL;
ALTER TABLE ONLY "public"."motion_clips"
    ADD CONSTRAINT "motion_clips_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."clip_favorites"
    ADD CONSTRAINT "clip_favorites_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."camera_clips"
    ADD CONSTRAINT "camera_clips_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE SET NULL;
ALTER TABLE ONLY "public"."camera_clips"
    ADD CONSTRAINT "camera_clips_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");
ALTER TABLE ONLY "public"."pet_events"
    ADD CONSTRAINT "pet_events_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE CASCADE;
ALTER TABLE ONLY "public"."media"
    ADD CONSTRAINT "media_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."pet_events"("id") ON DELETE SET NULL;
ALTER TABLE ONLY "public"."media"
    ADD CONSTRAINT "media_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE CASCADE;
GRANT USAGE ON SCHEMA auth,public TO authenticated;
GRANT SELECT ON public.motion_clips TO authenticated;
-- Production owner policy is permissive; the new active-profile policy must
-- restrict it rather than replace owner isolation.
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own pets" ON public.pets FOR SELECT USING (auth.uid() = user_id);
GRANT SELECT ON public.pets TO authenticated;
