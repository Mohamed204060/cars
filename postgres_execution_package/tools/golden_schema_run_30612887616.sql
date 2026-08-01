--
-- PostgreSQL database dump
--

\restrict uuiKQBiciRImrT578ZYZPizub0alQuZQJVeOuaJNVQGO3aygpRwAlm2dOHhzs4F

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: aud; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA aud;


--
-- Name: cmp; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA cmp;


--
-- Name: cnt; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA cnt;


--
-- Name: com; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA com;


--
-- Name: iam; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA iam;


--
-- Name: ntf; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ntf;


--
-- Name: pct; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pct;


--
-- Name: pur; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pur;


--
-- Name: ref; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ref;


--
-- Name: str; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA str;


--
-- Name: sub; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sub;


--
-- Name: sup; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sup;


--
-- Name: sys; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sys;


--
-- Name: trm; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA trm;


--
-- Name: vct; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vct;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: reject_template_version_mutation(); Type: FUNCTION; Schema: ntf; Owner: -
--

CREATE FUNCTION ntf.reject_template_version_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'ntf.template_versions is append-only; UPDATE and DELETE are forbidden'
        USING ERRCODE = 'insufficient_privilege';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: events; Type: TABLE; Schema: aud; Owner: -
--

CREATE TABLE aud.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    log_type character varying(16) NOT NULL,
    correlation_id uuid NOT NULL,
    actor_ref_id uuid,
    event_name character varying(128) NOT NULL,
    occurred_at_utc timestamp with time zone DEFAULT now() NOT NULL,
    before_value jsonb,
    after_value jsonb,
    reason text,
    metadata jsonb,
    CONSTRAINT chk_events_log_type CHECK (((log_type)::text = ANY ((ARRAY['general'::character varying, 'security'::character varying, 'administrative'::character varying])::text[])))
);


--
-- Name: TABLE events; Type: COMMENT; Schema: aud; Owner: -
--

COMMENT ON TABLE aud.events IS 'REQ-AUD-001..012: سجل تدقيق موحّد (Append-Only)؛ لا تعديل ولا حذف مسموح (REQ-AUD-002)';


--
-- Name: compatibility_records; Type: TABLE; Schema: cmp; Owner: -
--

CREATE TABLE cmp.compatibility_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    catalog_part_ref_id uuid NOT NULL,
    trim_ref_id uuid NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_compatibility_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE compatibility_records; Type: COMMENT; Schema: cmp; Owner: -
--

COMMENT ON TABLE cmp.compatibility_records IS 'REQ-CMP-001..003: سجل التوافق بين قطعة الكتالوج وفئة السيارة';


--
-- Name: articles; Type: TABLE; Schema: cnt; Owner: -
--

CREATE TABLE cnt.articles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    author_ref_id uuid NOT NULL,
    title character varying(256) NOT NULL,
    body text NOT NULL,
    status character varying(16) DEFAULT 'unpublished'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_articles_status CHECK (((status)::text = ANY ((ARRAY['unpublished'::character varying, 'published'::character varying])::text[])))
);


--
-- Name: TABLE articles; Type: COMMENT; Schema: cnt; Owner: -
--

COMMENT ON TABLE cnt.articles IS 'REQ-CNT-001, 002: المقالة/الخبر';


--
-- Name: attachments; Type: TABLE; Schema: com; Owner: -
--

CREATE TABLE com.attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    message_id uuid NOT NULL,
    file_name character varying(255) NOT NULL,
    mime_type character varying(64) NOT NULL,
    size_bytes bigint NOT NULL,
    CONSTRAINT chk_attachments_size CHECK (((size_bytes > 0) AND (size_bytes <= 10485760)))
);


--
-- Name: TABLE attachments; Type: COMMENT; Schema: com; Owner: -
--

COMMENT ON TABLE com.attachments IS 'REQ-COM-016: حد أدنى أمني (نوع/حجم) مطبَّق أيضًا في طبقة منطق الأعمال قبل الوصول هنا';


--
-- Name: conversation_user_settings; Type: TABLE; Schema: com; Owner: -
--

CREATE TABLE com.conversation_user_settings (
    conversation_id uuid NOT NULL,
    user_ref_id uuid NOT NULL,
    is_muted boolean DEFAULT false NOT NULL,
    is_archived boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE conversation_user_settings; Type: COMMENT; Schema: com; Owner: -
--

COMMENT ON TABLE com.conversation_user_settings IS 'REQ-COM-021, 023: كتم/أرشفة مستقلَّان لكل مستخدم على حدة، لا يؤثران على الطرف الآخر';


--
-- Name: conversations; Type: TABLE; Schema: com; Owner: -
--

CREATE TABLE com.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    context_type character varying(24) NOT NULL,
    context_ref_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_conversations_context_type CHECK (((context_type)::text = ANY ((ARRAY['purchase_request'::character varying, 'inventory_item'::character varying])::text[])))
);


--
-- Name: TABLE conversations; Type: COMMENT; Schema: com; Owner: -
--

COMMENT ON TABLE com.conversations IS 'REQ-COM-001, 002, 010: محادثة مرتبطة بسياق محدد، تبقى مفتوحة بعد إغلاق الطلب';


--
-- Name: forward_records; Type: TABLE; Schema: com; Owner: -
--

CREATE TABLE com.forward_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_message_id uuid NOT NULL,
    forwarded_message_id uuid NOT NULL,
    forwarded_to_conversation_id uuid NOT NULL
);


--
-- Name: TABLE forward_records; Type: COMMENT; Schema: com; Owner: -
--

COMMENT ON TABLE com.forward_records IS 'REQ-COM-025: إعادة توجيه رسالة لمحادثة أخرى';


--
-- Name: message_delivery_tracking; Type: TABLE; Schema: com; Owner: -
--

CREATE TABLE com.message_delivery_tracking (
    message_id uuid NOT NULL,
    sent_at timestamp with time zone NOT NULL,
    delivered_at timestamp with time zone,
    read_at timestamp with time zone
);


--
-- Name: TABLE message_delivery_tracking; Type: COMMENT; Schema: com; Owner: -
--

COMMENT ON TABLE com.message_delivery_tracking IS 'REQ-COM-015, 031: طوابع زمنية للتسليم والقراءة؛ سجل مرتبط لا حقل مباشر على الرسالة';


--
-- Name: message_thread_links; Type: TABLE; Schema: com; Owner: -
--

CREATE TABLE com.message_thread_links (
    message_id uuid NOT NULL,
    reply_to_message_id uuid NOT NULL
);


--
-- Name: TABLE message_thread_links; Type: COMMENT; Schema: com; Owner: -
--

COMMENT ON TABLE com.message_thread_links IS 'REQ-COM-024: الرد على رسالة سابقة';


--
-- Name: messages; Type: TABLE; Schema: com; Owner: -
--

CREATE TABLE com.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    sender_user_ref_id uuid NOT NULL,
    body text NOT NULL,
    is_deleted_by_sender boolean DEFAULT false NOT NULL,
    is_deleted_by_recipient boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE messages; Type: COMMENT; Schema: com; Owner: -
--

COMMENT ON TABLE com.messages IS 'REQ-COM-001, 007: الرسالة، بحذف منطقي نسبي لكل طرف';


--
-- Name: user_presence; Type: TABLE; Schema: com; Owner: -
--

CREATE TABLE com.user_presence (
    user_ref_id uuid NOT NULL,
    is_online boolean DEFAULT false NOT NULL,
    last_seen_at timestamp with time zone
);


--
-- Name: TABLE user_presence; Type: COMMENT; Schema: com; Owner: -
--

COMMENT ON TABLE com.user_presence IS 'REQ-COM-028, 029: آخر ظهور وحالة الاتصال';


--
-- Name: favorites; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.favorites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    inventory_item_ref_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE favorites; Type: COMMENT; Schema: iam; Owner: -
--

COMMENT ON TABLE iam.favorites IS 'REQ-IAM-008: قائمة عناصر المخزون المفضَّلة لدى المستخدم';


--
-- Name: identity_providers; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.identity_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(32) NOT NULL,
    display_name character varying(64) NOT NULL,
    provider_category character varying(16) NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_identity_providers_category CHECK (((provider_category)::text = ANY ((ARRAY['password'::character varying, 'otp'::character varying, 'oauth'::character varying])::text[]))),
    CONSTRAINT chk_identity_providers_code CHECK (((code)::text = ANY ((ARRAY['email_password'::character varying, 'google'::character varying, 'facebook'::character varying, 'x'::character varying, 'phone_otp'::character varying])::text[])))
);


--
-- Name: TABLE identity_providers; Type: COMMENT; Schema: iam; Owner: -
--

COMMENT ON TABLE iam.identity_providers IS 'REQ-IAM-010, 013: المرجع الرسمي الوحيد لأنواع وسائل الهوية؛ يُوسَّع بإضافة قيمة جديدة للقيد فقط دون تغيير بنيوي؛ display_name وprovider_category يدعمان المرونة الإدارية المستقبلية';


--
-- Name: user_identities; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.user_identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    provider_type_id uuid NOT NULL,
    external_identifier character varying(256) NOT NULL,
    credential_secret_hash text,
    verified_at timestamp with time zone,
    is_primary boolean DEFAULT false NOT NULL,
    last_authenticated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE user_identities; Type: COMMENT; Schema: iam; Owner: -
--

COMMENT ON TABLE iam.user_identities IS 'REQ-IAM-010, 014, 015, 016: وسائل الهوية المرتبطة بكل حساب، بقيد تفرّد صارم يمنع ربط نفس الهوية بأكثر من حساب';


--
-- Name: users; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_code character varying(32) NOT NULL,
    primary_role character varying(32) NOT NULL,
    account_type character varying(16) NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    is_verified_seller boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_users_account_type CHECK (((account_type)::text = ANY ((ARRAY['individual'::character varying, 'business'::character varying])::text[]))),
    CONSTRAINT chk_users_primary_role CHECK (((primary_role)::text = ANY ((ARRAY['super_admin'::character varying, 'admin'::character varying, 'moderator'::character varying, 'individual_seller'::character varying, 'business_seller'::character varying, 'individual_buyer'::character varying, 'business_buyer'::character varying, 'news_editor'::character varying, 'support_moderator'::character varying])::text[]))),
    CONSTRAINT chk_users_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying, 'banned'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: iam; Owner: -
--

COMMENT ON TABLE iam.users IS 'REQ-IAM-001..009: حساب المستخدم؛ بيانات الاعتماد بالكامل أصبحت في iam.user_identities (CR-005)، لا عمود مباشر هنا';


--
-- Name: campaigns; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_by_user_ref_id uuid NOT NULL,
    title character varying(200) NOT NULL,
    body text NOT NULL,
    audience_type character varying(16) NOT NULL,
    status character varying(16) DEFAULT 'draft'::character varying NOT NULL,
    priority character varying(16) DEFAULT 'normal'::character varying NOT NULL,
    campaign_version integer DEFAULT 1 NOT NULL,
    template_version_id uuid,
    scheduled_at timestamp with time zone,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_campaigns_audience_type CHECK (((audience_type)::text = ANY ((ARRAY['static'::character varying, 'dynamic'::character varying])::text[]))),
    CONSTRAINT chk_campaigns_priority CHECK (((priority)::text = ANY ((ARRAY['critical'::character varying, 'high'::character varying, 'normal'::character varying, 'low'::character varying])::text[]))),
    CONSTRAINT chk_campaigns_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'scheduled'::character varying, 'running'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'paused'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE campaigns; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.campaigns IS 'REQ-NTF-001..004, 029: الحملة، مع رقم إصدار (Campaign Versioning)';


--
-- Name: channel_providers; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.channel_providers (
    code character varying(32) NOT NULL,
    display_name character varying(64) NOT NULL,
    health_status character varying(16) DEFAULT 'healthy'::character varying NOT NULL,
    last_success_at timestamp with time zone,
    last_failure_at timestamp with time zone,
    success_rate_pct numeric(5,2),
    is_enabled boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_channel_providers_health CHECK (((health_status)::text = ANY ((ARRAY['healthy'::character varying, 'degraded'::character varying, 'offline'::character varying])::text[])))
);


--
-- Name: TABLE channel_providers; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.channel_providers IS 'REQ-NTF-018, 044: سجل صحة كل مزوِّد قناة';


--
-- Name: deliveries; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.deliveries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    campaign_version_snapshot integer NOT NULL,
    correlation_id uuid NOT NULL,
    execution_status character varying(16) DEFAULT 'running'::character varying NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    total_recipients integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_deliveries_status CHECK (((execution_status)::text = ANY ((ARRAY['running'::character varying, 'paused'::character varying, 'resumed'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: TABLE deliveries; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.deliveries IS 'REQ-NTF-020, 022: تنفيذ فعلي واحد لحملة؛ يثبِّت إصدار الحملة وقت التنفيذ';


--
-- Name: notification_center_entries; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.notification_center_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipient_id uuid NOT NULL,
    user_ref_id uuid NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    is_archived_by_user boolean DEFAULT false NOT NULL,
    is_deleted_by_user boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE notification_center_entries; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.notification_center_entries IS 'REQ-NTF-036: حذف نسبي بالمستخدم فقط؛ لا حذف فعلي';


--
-- Name: notification_preferences; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.notification_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_ref_id uuid NOT NULL,
    channel_provider_code character varying(32) NOT NULL,
    notification_type character varying(32) NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE notification_preferences; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.notification_preferences IS 'REQ-NTF-033, 034: تفضيلات لكل مستخدم ولكل قناة ولكل نوع إشعار';


--
-- Name: outbox; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.outbox (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    delivery_id uuid NOT NULL,
    recipient_id uuid NOT NULL,
    correlation_id uuid NOT NULL,
    dispatched boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE outbox; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.outbox IS 'نمط Transactional Outbox: تُكتَب ضمن نفس معاملة إنشاء Recipient؛ Outbox Worker يستطلعها لاحقًا';


--
-- Name: recipients; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.recipients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    delivery_id uuid NOT NULL,
    user_ref_id uuid NOT NULL,
    channel_provider_code character varying(32) NOT NULL,
    status character varying(16) DEFAULT 'pending'::character varying NOT NULL,
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    read_at timestamp with time zone,
    failure_reason_code character varying(32),
    retry_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT chk_recipients_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'queued'::character varying, 'sent'::character varying, 'delivered'::character varying, 'read'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: TABLE recipients; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.recipients IS 'REQ-NTF-012, 021: سجل مستلِم واحد فقط لكل مستخدم لكل Delivery (Dedup مضمونة بقيد DB)';


--
-- Name: template_versions; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.template_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_id uuid NOT NULL,
    version_number integer NOT NULL,
    title character varying(200) NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE template_versions; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.template_versions IS 'BR-NTF-006: جدول Append-Only بالكامل؛ لا UPDATE ولا DELETE على صف قائم أبدًا';


--
-- Name: templates; Type: TABLE; Schema: ntf; Owner: -
--

CREATE TABLE ntf.templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(64) NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    current_version_number integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_templates_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE templates; Type: COMMENT; Schema: ntf; Owner: -
--

COMMENT ON TABLE ntf.templates IS 'BR-NTF-006: لا حذف فعلي؛ الأرشفة فقط';


--
-- Name: aftermarket_numbers; Type: TABLE; Schema: pct; Owner: -
--

CREATE TABLE pct.aftermarket_numbers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    catalog_part_id uuid NOT NULL,
    aftermarket_number character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE aftermarket_numbers; Type: COMMENT; Schema: pct; Owner: -
--

COMMENT ON TABLE pct.aftermarket_numbers IS 'REQ-PCT-006: رقم القطعة البديلة، مرجع بديل لرقم OEM';


--
-- Name: catalog_parts; Type: TABLE; Schema: pct; Owner: -
--

CREATE TABLE pct.catalog_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
    status character varying(16) DEFAULT 'proposed'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_catalog_parts_status CHECK (((status)::text = ANY ((ARRAY['proposed'::character varying, 'approved'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE catalog_parts; Type: COMMENT; Schema: pct; Owner: -
--

COMMENT ON TABLE pct.catalog_parts IS 'REQ-PCT-001، 002، 007: قطعة الكتالوج المرجعية، مستقلة عن أي بائع';


--
-- Name: categories; Type: TABLE; Schema: pct; Owner: -
--

CREATE TABLE pct.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE categories; Type: COMMENT; Schema: pct; Owner: -
--

COMMENT ON TABLE pct.categories IS 'REQ-PCT-007: تصنيف قطعة الكتالوج';


--
-- Name: localized_names; Type: TABLE; Schema: pct; Owner: -
--

CREATE TABLE pct.localized_names (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    catalog_part_id uuid NOT NULL,
    locale character varying(16),
    name_value character varying(256) NOT NULL,
    name_kind character varying(16) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_pct_localized_names_kind CHECK (((name_kind)::text = ANY ((ARRAY['canonical'::character varying, 'local'::character varying, 'english'::character varying, 'synonym'::character varying])::text[])))
);


--
-- Name: TABLE localized_names; Type: COMMENT; Schema: pct; Owner: -
--

COMMENT ON TABLE pct.localized_names IS 'REQ-PCT-003: الاسم القياسي والمحلي والإنجليزي والمرادفات';


--
-- Name: oem_numbers; Type: TABLE; Schema: pct; Owner: -
--

CREATE TABLE pct.oem_numbers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    catalog_part_id uuid NOT NULL,
    manufacturer_ref_id uuid NOT NULL,
    oem_number character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE oem_numbers; Type: COMMENT; Schema: pct; Owner: -
--

COMMENT ON TABLE pct.oem_numbers IS 'REQ-PCT-004، 005: رقم أو أرقام OEM لكل قطعة، بلا تكرار ضمن نفس الشركة';


--
-- Name: offers; Type: TABLE; Schema: pur; Owner: -
--

CREATE TABLE pur.offers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_code character varying(32) NOT NULL,
    purchase_request_id uuid NOT NULL,
    seller_store_ref_id uuid NOT NULL,
    amount numeric(12,2) NOT NULL,
    currency character(3) NOT NULL,
    provides_shipping boolean NOT NULL,
    notes text,
    status character varying(16) DEFAULT 'submitted'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_offers_status CHECK (((status)::text = ANY ((ARRAY['submitted'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'withdrawn'::character varying, 'expired'::character varying])::text[])))
);


--
-- Name: TABLE offers; Type: COMMENT; Schema: pur; Owner: -
--

COMMENT ON TABLE pur.offers IS 'REQ-PUR-011..018: عرض السعر، قابل للتعديل قبل القبول فقط (CR-002)';


--
-- Name: purchase_requests; Type: TABLE; Schema: pur; Owner: -
--

CREATE TABLE pur.purchase_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_code character varying(32) NOT NULL,
    buyer_user_ref_id uuid NOT NULL,
    catalog_part_ref_id uuid NOT NULL,
    trim_ref_id uuid NOT NULL,
    status character varying(24) DEFAULT 'open'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_purchase_requests_status CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'under_review'::character varying, 'fulfilled'::character varying, 'expired'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: TABLE purchase_requests; Type: COMMENT; Schema: pur; Owner: -
--

COMMENT ON TABLE pur.purchase_requests IS 'REQ-PUR-001..010: طلب الشراء بدورة حياته الخماسية';


--
-- Name: bulk_import_job_rows; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.bulk_import_job_rows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    row_number integer NOT NULL,
    outcome character varying(16) NOT NULL,
    rejection_reason text,
    raw_row_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_bulk_import_job_rows_outcome CHECK (((outcome)::text = ANY ((ARRAY['new'::character varying, 'updated'::character varying, 'rejected'::character varying])::text[])))
);


--
-- Name: TABLE bulk_import_job_rows; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON TABLE ref.bulk_import_job_rows IS 'CR-003 — REQ-REF-006: نتيجة كل صف في عملية الاستيراد';


--
-- Name: bulk_import_jobs; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.bulk_import_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ref_type character varying(32) NOT NULL,
    imported_by_ref_id uuid NOT NULL,
    file_name character varying(256) NOT NULL,
    source_file_ref text,
    status character varying(24) DEFAULT 'validating'::character varying NOT NULL,
    new_count integer DEFAULT 0 NOT NULL,
    updated_count integer DEFAULT 0 NOT NULL,
    rejected_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_bulk_import_jobs_status CHECK (((status)::text = ANY ((ARRAY['validating'::character varying, 'preview_ready'::character varying, 'committed'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT chk_bulk_import_jobs_type CHECK (((ref_type)::text = ANY ((ARRAY['country'::character varying, 'city'::character varying, 'language'::character varying, 'fuel_type'::character varying, 'transmission_type'::character varying, 'engine_type'::character varying, 'part_condition'::character varying, 'subscription_type'::character varying])::text[])))
);


--
-- Name: TABLE bulk_import_jobs; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON TABLE ref.bulk_import_jobs IS 'CR-003 — REQ-REF-004..008: رأس عملية الاستيراد الجماعي';


--
-- Name: ref_values; Type: TABLE; Schema: ref; Owner: -
--

CREATE TABLE ref.ref_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ref_type character varying(32) NOT NULL,
    code character varying(64) NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_ref_values_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'archived'::character varying])::text[]))),
    CONSTRAINT chk_ref_values_type CHECK (((ref_type)::text = ANY ((ARRAY['country'::character varying, 'city'::character varying, 'language'::character varying, 'fuel_type'::character varying, 'transmission_type'::character varying, 'engine_type'::character varying, 'part_condition'::character varying, 'subscription_type'::character varying])::text[])))
);


--
-- Name: TABLE ref_values; Type: COMMENT; Schema: ref; Owner: -
--

COMMENT ON TABLE ref.ref_values IS 'REQ-REF-001..002: جدول موحّد لجميع أنواع القيم المرجعية الثمانية';


--
-- Name: inventory_items; Type: TABLE; Schema: str; Owner: -
--

CREATE TABLE str.inventory_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_code character varying(32) NOT NULL,
    store_id uuid NOT NULL,
    catalog_part_ref_id uuid NOT NULL,
    condition_ref_id uuid NOT NULL,
    pricing_mode character varying(32) NOT NULL,
    price_amount numeric(12,2),
    price_currency character(3),
    quantity integer DEFAULT 0 NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    primary_photo_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_inventory_items_price_mode CHECK (((((pricing_mode)::text = 'fixed_price'::text) AND (price_amount IS NOT NULL) AND (price_currency IS NOT NULL)) OR (((pricing_mode)::text = 'contact_for_price'::text) AND (price_amount IS NULL)))),
    CONSTRAINT chk_inventory_items_pricing_mode CHECK (((pricing_mode)::text = ANY ((ARRAY['fixed_price'::character varying, 'contact_for_price'::character varying])::text[]))),
    CONSTRAINT chk_inventory_items_quantity CHECK ((quantity >= 0)),
    CONSTRAINT chk_inventory_items_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'out_of_stock'::character varying, 'hidden'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE inventory_items; Type: COMMENT; Schema: str; Owner: -
--

COMMENT ON TABLE str.inventory_items IS 'REQ-STR-009..019: عنصر مخزون البائع، بالإشارة لقطعة الكتالوج لا بنسخها';


--
-- Name: inventory_photos; Type: TABLE; Schema: str; Owner: -
--

CREATE TABLE str.inventory_photos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    inventory_item_id uuid NOT NULL,
    original_asset_ref text NOT NULL,
    display_asset_ref text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE inventory_photos; Type: COMMENT; Schema: str; Owner: -
--

COMMENT ON TABLE str.inventory_photos IS 'REQ-STR-020..024-B: صور عنصر المخزون (أصلية + نسخة عرض)';


--
-- Name: stores; Type: TABLE; Schema: str; Owner: -
--

CREATE TABLE str.stores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_user_ref_id uuid NOT NULL,
    status character varying(16) DEFAULT 'creating'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    country_ref_id uuid,
    city_ref_id uuid,
    CONSTRAINT chk_stores_status CHECK (((status)::text = ANY ((ARRAY['creating'::character varying, 'active'::character varying, 'suspended'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE stores; Type: COMMENT; Schema: str; Owner: -
--

COMMENT ON TABLE str.stores IS 'REQ-STR-001..008: المتجر؛ لا فروع في الإصدار الأول (CR-001)';


--
-- Name: COLUMN stores.country_ref_id; Type: COMMENT; Schema: str; Owner: -
--

COMMENT ON COLUMN str.stores.country_ref_id IS 'REQ-SRC-006: دولة البائع، أساس تصفية البحث الجغرافية';


--
-- Name: COLUMN stores.city_ref_id; Type: COMMENT; Schema: str; Owner: -
--

COMMENT ON COLUMN str.stores.city_ref_id IS 'REQ-SRC-006: مدينة البائع';


--
-- Name: plans; Type: TABLE; Schema: sub; Owner: -
--

CREATE TABLE sub.plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_type_ref_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE plans; Type: COMMENT; Schema: sub; Owner: -
--

COMMENT ON TABLE sub.plans IS 'REQ-SUB-001: خطط الاشتراك المعرَّفة من الإدارة';


--
-- Name: seller_subscriptions; Type: TABLE; Schema: sub; Owner: -
--

CREATE TABLE sub.seller_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_ref_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_seller_subscriptions_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'expired'::character varying])::text[])))
);


--
-- Name: TABLE seller_subscriptions; Type: COMMENT; Schema: sub; Owner: -
--

COMMENT ON TABLE sub.seller_subscriptions IS 'REQ-SUB-002..005: اشتراك البائع في خطة، مع انتهاء تلقائي';


--
-- Name: replies; Type: TABLE; Schema: sup; Owner: -
--

CREATE TABLE sup.replies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_id uuid NOT NULL,
    author_ref_id uuid NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE replies; Type: COMMENT; Schema: sup; Owner: -
--

COMMENT ON TABLE sup.replies IS 'REQ-SUP-005: تبادل ردود متعددة ضمن الطلب نفسه';


--
-- Name: tickets; Type: TABLE; Schema: sup; Owner: -
--

CREATE TABLE sup.tickets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requester_ref_id uuid NOT NULL,
    assigned_moderator_ref_id uuid,
    subject character varying(256) NOT NULL,
    status character varying(16) DEFAULT 'open'::character varying NOT NULL,
    reopen_window_expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_tickets_status CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'in_progress'::character varying, 'resolved'::character varying, 'closed'::character varying])::text[])))
);


--
-- Name: TABLE tickets; Type: COMMENT; Schema: sup; Owner: -
--

COMMENT ON TABLE sup.tickets IS 'REQ-SUP-001..006: طلب الدعم الفني، مع إعادة فتح خلال مهلة';


--
-- Name: scheduled_jobs; Type: TABLE; Schema: sys; Owner: -
--

CREATE TABLE sys.scheduled_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_type character varying(64) NOT NULL,
    target_ref_id uuid NOT NULL,
    scheduled_at timestamp with time zone NOT NULL,
    recurrence_rule character varying(16),
    status character varying(16) DEFAULT 'pending'::character varying NOT NULL,
    last_run_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_scheduled_jobs_recurrence CHECK (((recurrence_rule IS NULL) OR ((recurrence_rule)::text = ANY ((ARRAY['daily'::character varying, 'weekly'::character varying, 'monthly'::character varying])::text[])))),
    CONSTRAINT chk_scheduled_jobs_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'executing'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: TABLE scheduled_jobs; Type: COMMENT; Schema: sys; Owner: -
--

COMMENT ON TABLE sys.scheduled_jobs IS 'ADR-035: مُجدوِل عام قابل لإعادة الاستخدام من أي مجال (PUR، NTF، وأي مجال مستقبلي)؛ لا حذف فعلي — الإزالة عبر status=cancelled فقط';


--
-- Name: settings; Type: TABLE; Schema: sys; Owner: -
--

CREATE TABLE sys.settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    setting_key character varying(128) NOT NULL,
    setting_value text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE settings; Type: COMMENT; Schema: sys; Owner: -
--

COMMENT ON TABLE sys.settings IS 'REQ-SYS-001، 002: قيم كائنات السياسة والإعدادات التشغيلية العامة';


--
-- Name: disputes; Type: TABLE; Schema: trm; Owner: -
--

CREATE TABLE trm.disputes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    buyer_ref_id uuid NOT NULL,
    seller_ref_id uuid NOT NULL,
    status character varying(16) DEFAULT 'open'::character varying NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_disputes_status CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'closed'::character varying])::text[])))
);


--
-- Name: TABLE disputes; Type: COMMENT; Schema: trm; Owner: -
--

COMMENT ON TABLE trm.disputes IS 'REQ-TRM-007: أداة توثيق نزاع تنظيمية، غير ملزمة';


--
-- Name: ratings; Type: TABLE; Schema: trm; Owner: -
--

CREATE TABLE trm.ratings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rated_by_user_ref_id uuid NOT NULL,
    target_type character varying(24) NOT NULL,
    target_ref_id uuid NOT NULL,
    source_purchase_request_ref_id uuid NOT NULL,
    score smallint NOT NULL,
    comment text,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_ratings_score CHECK (((score >= 1) AND (score <= 5))),
    CONSTRAINT chk_ratings_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'archived'::character varying])::text[]))),
    CONSTRAINT chk_ratings_target_type CHECK (((target_type)::text = ANY ((ARRAY['seller'::character varying, 'store'::character varying, 'purchase_experience'::character varying])::text[])))
);


--
-- Name: TABLE ratings; Type: COMMENT; Schema: trm; Owner: -
--

COMMENT ON TABLE trm.ratings IS 'النموذج الموحَّد المعتمَد رسميًا (CR-009)؛ يحل محل trm.ratings_legacy_seller_only_v1 بالكامل من هذا الترحيل فصاعدًا';


--
-- Name: ratings_legacy_seller_only_v1; Type: TABLE; Schema: trm; Owner: -
--

CREATE TABLE trm.ratings_legacy_seller_only_v1 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rated_seller_ref_id uuid NOT NULL,
    rater_buyer_ref_id uuid NOT NULL,
    score smallint NOT NULL,
    comment_text text,
    edit_window_expires_at timestamp with time zone NOT NULL,
    is_removed_by_moderator boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_ratings_score CHECK (((score >= 1) AND (score <= 5)))
);


--
-- Name: TABLE ratings_legacy_seller_only_v1; Type: COMMENT; Schema: trm; Owner: -
--

COMMENT ON TABLE trm.ratings_legacy_seller_only_v1 IS 'Superseded by CR-009 (نموذج التقييم الموحَّد، 021_trm_unified_ratings.sql). محفوظ تاريخيًا فقط؛ لا كتابة جديدة إليه إطلاقًا بعد هذا الترحيل.';


--
-- Name: reports; Type: TABLE; Schema: trm; Owner: -
--

CREATE TABLE trm.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    target_type character varying(24) NOT NULL,
    target_ref_id uuid NOT NULL,
    reporter_ref_id uuid NOT NULL,
    status character varying(16) DEFAULT 'under_review'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_reports_status CHECK (((status)::text = ANY ((ARRAY['under_review'::character varying, 'accepted'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT chk_reports_target_type CHECK (((target_type)::text = ANY ((ARRAY['store'::character varying, 'user'::character varying, 'message'::character varying, 'inventory_item'::character varying])::text[])))
);


--
-- Name: TABLE reports; Type: COMMENT; Schema: trm; Owner: -
--

COMMENT ON TABLE trm.reports IS 'REQ-TRM-005, 006: البلاغات، تشمل عناصر المخزون';


--
-- Name: generations; Type: TABLE; Schema: vct; Owner: -
--

CREATE TABLE vct.generations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    model_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE generations; Type: COMMENT; Schema: vct; Owner: -
--

COMMENT ON TABLE vct.generations IS 'REQ-VCT-004: الجيل، جزء تابع لتجميع الموديل';


--
-- Name: localized_names; Type: TABLE; Schema: vct; Owner: -
--

CREATE TABLE vct.localized_names (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_ref_id uuid NOT NULL,
    owner_type character varying(16) NOT NULL,
    locale character varying(16) NOT NULL,
    name_value character varying(256) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_localized_names_owner_type CHECK (((owner_type)::text = ANY ((ARRAY['manufacturer'::character varying, 'model'::character varying])::text[])))
);


--
-- Name: TABLE localized_names; Type: COMMENT; Schema: vct; Owner: -
--

COMMENT ON TABLE vct.localized_names IS 'REQ-VCT-006: كائن القيمة المشترك "الاسم متعدد اللغات"';


--
-- Name: manufacturers; Type: TABLE; Schema: vct; Owner: -
--

CREATE TABLE vct.manufacturers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status character varying(16) DEFAULT 'proposed'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_manufacturers_status CHECK (((status)::text = ANY ((ARRAY['proposed'::character varying, 'approved'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE manufacturers; Type: COMMENT; Schema: vct; Owner: -
--

COMMENT ON TABLE vct.manufacturers IS 'REQ-VCT-001، 002: الشركة المصنّعة مع دورة حوكمتها';


--
-- Name: models; Type: TABLE; Schema: vct; Owner: -
--

CREATE TABLE vct.models (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    manufacturer_id uuid NOT NULL,
    status character varying(16) DEFAULT 'proposed'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_models_status CHECK (((status)::text = ANY ((ARRAY['proposed'::character varying, 'approved'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE models; Type: COMMENT; Schema: vct; Owner: -
--

COMMENT ON TABLE vct.models IS 'REQ-VCT-003: الموديل، عضو في تجميع الشركة المصنّعة';


--
-- Name: trims; Type: TABLE; Schema: vct; Owner: -
--

CREATE TABLE vct.trims (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    generation_id uuid NOT NULL,
    fuel_type_ref_id uuid NOT NULL,
    transmission_type_ref_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trims; Type: COMMENT; Schema: vct; Owner: -
--

COMMENT ON TABLE vct.trims IS 'REQ-VCT-005: فئة السيارة، تشير لنوع الوقود وناقل الحركة كقيم مرجعية';


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: aud; Owner: -
--

ALTER TABLE ONLY aud.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: compatibility_records compatibility_records_pkey; Type: CONSTRAINT; Schema: cmp; Owner: -
--

ALTER TABLE ONLY cmp.compatibility_records
    ADD CONSTRAINT compatibility_records_pkey PRIMARY KEY (id);


--
-- Name: compatibility_records uq_compatibility_part_trim; Type: CONSTRAINT; Schema: cmp; Owner: -
--

ALTER TABLE ONLY cmp.compatibility_records
    ADD CONSTRAINT uq_compatibility_part_trim UNIQUE (catalog_part_ref_id, trim_ref_id);


--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: cnt; Owner: -
--

ALTER TABLE ONLY cnt.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);


--
-- Name: conversation_user_settings conversation_user_settings_pkey; Type: CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.conversation_user_settings
    ADD CONSTRAINT conversation_user_settings_pkey PRIMARY KEY (conversation_id, user_ref_id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: forward_records forward_records_pkey; Type: CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.forward_records
    ADD CONSTRAINT forward_records_pkey PRIMARY KEY (id);


--
-- Name: message_delivery_tracking message_delivery_tracking_pkey; Type: CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.message_delivery_tracking
    ADD CONSTRAINT message_delivery_tracking_pkey PRIMARY KEY (message_id);


--
-- Name: message_thread_links message_thread_links_pkey; Type: CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.message_thread_links
    ADD CONSTRAINT message_thread_links_pkey PRIMARY KEY (message_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: user_presence user_presence_pkey; Type: CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.user_presence
    ADD CONSTRAINT user_presence_pkey PRIMARY KEY (user_ref_id);


--
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: identity_providers identity_providers_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.identity_providers
    ADD CONSTRAINT identity_providers_pkey PRIMARY KEY (id);


--
-- Name: favorites uq_favorites_user_item; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.favorites
    ADD CONSTRAINT uq_favorites_user_item UNIQUE (user_id, inventory_item_ref_id);


--
-- Name: identity_providers uq_identity_providers_code; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.identity_providers
    ADD CONSTRAINT uq_identity_providers_code UNIQUE (code);


--
-- Name: user_identities uq_user_identities_provider_identifier; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.user_identities
    ADD CONSTRAINT uq_user_identities_provider_identifier UNIQUE (provider_type_id, external_identifier);


--
-- Name: user_identities uq_user_identities_user_provider; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.user_identities
    ADD CONSTRAINT uq_user_identities_user_provider UNIQUE (user_id, provider_type_id);


--
-- Name: users uq_users_business_code; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.users
    ADD CONSTRAINT uq_users_business_code UNIQUE (business_code);


--
-- Name: user_identities user_identities_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.user_identities
    ADD CONSTRAINT user_identities_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);


--
-- Name: channel_providers channel_providers_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.channel_providers
    ADD CONSTRAINT channel_providers_pkey PRIMARY KEY (code);


--
-- Name: deliveries deliveries_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.deliveries
    ADD CONSTRAINT deliveries_pkey PRIMARY KEY (id);


--
-- Name: notification_center_entries notification_center_entries_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.notification_center_entries
    ADD CONSTRAINT notification_center_entries_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (id);


--
-- Name: outbox outbox_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.outbox
    ADD CONSTRAINT outbox_pkey PRIMARY KEY (id);


--
-- Name: recipients recipients_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.recipients
    ADD CONSTRAINT recipients_pkey PRIMARY KEY (id);


--
-- Name: template_versions template_versions_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.template_versions
    ADD CONSTRAINT template_versions_pkey PRIMARY KEY (id);


--
-- Name: templates templates_code_key; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.templates
    ADD CONSTRAINT templates_code_key UNIQUE (code);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences uq_notification_preferences; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.notification_preferences
    ADD CONSTRAINT uq_notification_preferences UNIQUE (user_ref_id, channel_provider_code, notification_type);


--
-- Name: recipients uq_recipients_delivery_user; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.recipients
    ADD CONSTRAINT uq_recipients_delivery_user UNIQUE (delivery_id, user_ref_id);


--
-- Name: template_versions uq_template_versions_template_version; Type: CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.template_versions
    ADD CONSTRAINT uq_template_versions_template_version UNIQUE (template_id, version_number);


--
-- Name: aftermarket_numbers aftermarket_numbers_pkey; Type: CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.aftermarket_numbers
    ADD CONSTRAINT aftermarket_numbers_pkey PRIMARY KEY (id);


--
-- Name: catalog_parts catalog_parts_pkey; Type: CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.catalog_parts
    ADD CONSTRAINT catalog_parts_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: localized_names localized_names_pkey; Type: CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.localized_names
    ADD CONSTRAINT localized_names_pkey PRIMARY KEY (id);


--
-- Name: oem_numbers oem_numbers_pkey; Type: CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.oem_numbers
    ADD CONSTRAINT oem_numbers_pkey PRIMARY KEY (id);


--
-- Name: oem_numbers uq_oem_numbers_manufacturer_number; Type: CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.oem_numbers
    ADD CONSTRAINT uq_oem_numbers_manufacturer_number UNIQUE (manufacturer_ref_id, oem_number);


--
-- Name: offers offers_pkey; Type: CONSTRAINT; Schema: pur; Owner: -
--

ALTER TABLE ONLY pur.offers
    ADD CONSTRAINT offers_pkey PRIMARY KEY (id);


--
-- Name: purchase_requests purchase_requests_pkey; Type: CONSTRAINT; Schema: pur; Owner: -
--

ALTER TABLE ONLY pur.purchase_requests
    ADD CONSTRAINT purchase_requests_pkey PRIMARY KEY (id);


--
-- Name: offers uq_offers_business_code; Type: CONSTRAINT; Schema: pur; Owner: -
--

ALTER TABLE ONLY pur.offers
    ADD CONSTRAINT uq_offers_business_code UNIQUE (business_code);


--
-- Name: purchase_requests uq_purchase_requests_business_code; Type: CONSTRAINT; Schema: pur; Owner: -
--

ALTER TABLE ONLY pur.purchase_requests
    ADD CONSTRAINT uq_purchase_requests_business_code UNIQUE (business_code);


--
-- Name: bulk_import_job_rows bulk_import_job_rows_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.bulk_import_job_rows
    ADD CONSTRAINT bulk_import_job_rows_pkey PRIMARY KEY (id);


--
-- Name: bulk_import_jobs bulk_import_jobs_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.bulk_import_jobs
    ADD CONSTRAINT bulk_import_jobs_pkey PRIMARY KEY (id);


--
-- Name: ref_values ref_values_pkey; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.ref_values
    ADD CONSTRAINT ref_values_pkey PRIMARY KEY (id);


--
-- Name: ref_values uq_ref_values_type_code; Type: CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.ref_values
    ADD CONSTRAINT uq_ref_values_type_code UNIQUE (ref_type, code);


--
-- Name: inventory_items inventory_items_pkey; Type: CONSTRAINT; Schema: str; Owner: -
--

ALTER TABLE ONLY str.inventory_items
    ADD CONSTRAINT inventory_items_pkey PRIMARY KEY (id);


--
-- Name: inventory_photos inventory_photos_pkey; Type: CONSTRAINT; Schema: str; Owner: -
--

ALTER TABLE ONLY str.inventory_photos
    ADD CONSTRAINT inventory_photos_pkey PRIMARY KEY (id);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: str; Owner: -
--

ALTER TABLE ONLY str.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: inventory_items uq_inventory_items_business_code; Type: CONSTRAINT; Schema: str; Owner: -
--

ALTER TABLE ONLY str.inventory_items
    ADD CONSTRAINT uq_inventory_items_business_code UNIQUE (business_code);


--
-- Name: plans plans_pkey; Type: CONSTRAINT; Schema: sub; Owner: -
--

ALTER TABLE ONLY sub.plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: seller_subscriptions seller_subscriptions_pkey; Type: CONSTRAINT; Schema: sub; Owner: -
--

ALTER TABLE ONLY sub.seller_subscriptions
    ADD CONSTRAINT seller_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: replies replies_pkey; Type: CONSTRAINT; Schema: sup; Owner: -
--

ALTER TABLE ONLY sup.replies
    ADD CONSTRAINT replies_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: sup; Owner: -
--

ALTER TABLE ONLY sup.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: scheduled_jobs scheduled_jobs_pkey; Type: CONSTRAINT; Schema: sys; Owner: -
--

ALTER TABLE ONLY sys.scheduled_jobs
    ADD CONSTRAINT scheduled_jobs_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: sys; Owner: -
--

ALTER TABLE ONLY sys.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: settings uq_settings_key; Type: CONSTRAINT; Schema: sys; Owner: -
--

ALTER TABLE ONLY sys.settings
    ADD CONSTRAINT uq_settings_key UNIQUE (setting_key);


--
-- Name: disputes disputes_pkey; Type: CONSTRAINT; Schema: trm; Owner: -
--

ALTER TABLE ONLY trm.disputes
    ADD CONSTRAINT disputes_pkey PRIMARY KEY (id);


--
-- Name: ratings_legacy_seller_only_v1 ratings_pkey; Type: CONSTRAINT; Schema: trm; Owner: -
--

ALTER TABLE ONLY trm.ratings_legacy_seller_only_v1
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (id);


--
-- Name: ratings ratings_pkey1; Type: CONSTRAINT; Schema: trm; Owner: -
--

ALTER TABLE ONLY trm.ratings
    ADD CONSTRAINT ratings_pkey1 PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: trm; Owner: -
--

ALTER TABLE ONLY trm.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: ratings uq_ratings_rater_target_source; Type: CONSTRAINT; Schema: trm; Owner: -
--

ALTER TABLE ONLY trm.ratings
    ADD CONSTRAINT uq_ratings_rater_target_source UNIQUE (rated_by_user_ref_id, target_type, target_ref_id, source_purchase_request_ref_id);


--
-- Name: generations generations_pkey; Type: CONSTRAINT; Schema: vct; Owner: -
--

ALTER TABLE ONLY vct.generations
    ADD CONSTRAINT generations_pkey PRIMARY KEY (id);


--
-- Name: localized_names localized_names_pkey; Type: CONSTRAINT; Schema: vct; Owner: -
--

ALTER TABLE ONLY vct.localized_names
    ADD CONSTRAINT localized_names_pkey PRIMARY KEY (id);


--
-- Name: manufacturers manufacturers_pkey; Type: CONSTRAINT; Schema: vct; Owner: -
--

ALTER TABLE ONLY vct.manufacturers
    ADD CONSTRAINT manufacturers_pkey PRIMARY KEY (id);


--
-- Name: models models_pkey; Type: CONSTRAINT; Schema: vct; Owner: -
--

ALTER TABLE ONLY vct.models
    ADD CONSTRAINT models_pkey PRIMARY KEY (id);


--
-- Name: trims trims_pkey; Type: CONSTRAINT; Schema: vct; Owner: -
--

ALTER TABLE ONLY vct.trims
    ADD CONSTRAINT trims_pkey PRIMARY KEY (id);


--
-- Name: idx_events_actor; Type: INDEX; Schema: aud; Owner: -
--

CREATE INDEX idx_events_actor ON aud.events USING btree (actor_ref_id);


--
-- Name: idx_events_correlation; Type: INDEX; Schema: aud; Owner: -
--

CREATE INDEX idx_events_correlation ON aud.events USING btree (correlation_id);


--
-- Name: idx_events_type_time; Type: INDEX; Schema: aud; Owner: -
--

CREATE INDEX idx_events_type_time ON aud.events USING btree (log_type, occurred_at_utc);


--
-- Name: idx_compatibility_part; Type: INDEX; Schema: cmp; Owner: -
--

CREATE INDEX idx_compatibility_part ON cmp.compatibility_records USING btree (catalog_part_ref_id);


--
-- Name: idx_compatibility_trim; Type: INDEX; Schema: cmp; Owner: -
--

CREATE INDEX idx_compatibility_trim ON cmp.compatibility_records USING btree (trim_ref_id);


--
-- Name: idx_articles_status; Type: INDEX; Schema: cnt; Owner: -
--

CREATE INDEX idx_articles_status ON cnt.articles USING btree (status);


--
-- Name: idx_attachments_message_id; Type: INDEX; Schema: com; Owner: -
--

CREATE INDEX idx_attachments_message_id ON com.attachments USING btree (message_id);


--
-- Name: idx_conversations_context; Type: INDEX; Schema: com; Owner: -
--

CREATE INDEX idx_conversations_context ON com.conversations USING btree (context_type, context_ref_id);


--
-- Name: idx_messages_conversation_id; Type: INDEX; Schema: com; Owner: -
--

CREATE INDEX idx_messages_conversation_id ON com.messages USING btree (conversation_id);


--
-- Name: idx_favorites_user_id; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX idx_favorites_user_id ON iam.favorites USING btree (user_id);


--
-- Name: idx_user_identities_provider; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX idx_user_identities_provider ON iam.user_identities USING btree (provider_type_id);


--
-- Name: idx_user_identities_user_id; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX idx_user_identities_user_id ON iam.user_identities USING btree (user_id);


--
-- Name: idx_users_primary_role; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX idx_users_primary_role ON iam.users USING btree (primary_role);


--
-- Name: idx_users_status; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX idx_users_status ON iam.users USING btree (status);


--
-- Name: idx_campaigns_scheduled_at; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_campaigns_scheduled_at ON ntf.campaigns USING btree (scheduled_at);


--
-- Name: idx_campaigns_status; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_campaigns_status ON ntf.campaigns USING btree (status);


--
-- Name: idx_channel_providers_health; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_channel_providers_health ON ntf.channel_providers USING btree (health_status);


--
-- Name: idx_deliveries_campaign_id; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_deliveries_campaign_id ON ntf.deliveries USING btree (campaign_id);


--
-- Name: idx_deliveries_execution_status; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_deliveries_execution_status ON ntf.deliveries USING btree (execution_status);


--
-- Name: idx_notification_center_is_read; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_notification_center_is_read ON ntf.notification_center_entries USING btree (is_read);


--
-- Name: idx_notification_center_user_ref_id; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_notification_center_user_ref_id ON ntf.notification_center_entries USING btree (user_ref_id);


--
-- Name: idx_notification_preferences_user; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_notification_preferences_user ON ntf.notification_preferences USING btree (user_ref_id);


--
-- Name: idx_outbox_pending; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_outbox_pending ON ntf.outbox USING btree (created_at) WHERE (dispatched = false);


--
-- Name: idx_recipients_status; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_recipients_status ON ntf.recipients USING btree (status);


--
-- Name: idx_recipients_user_ref_id; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_recipients_user_ref_id ON ntf.recipients USING btree (user_ref_id);


--
-- Name: idx_template_versions_template_id; Type: INDEX; Schema: ntf; Owner: -
--

CREATE INDEX idx_template_versions_template_id ON ntf.template_versions USING btree (template_id);


--
-- Name: idx_aftermarket_numbers_part_id; Type: INDEX; Schema: pct; Owner: -
--

CREATE INDEX idx_aftermarket_numbers_part_id ON pct.aftermarket_numbers USING btree (catalog_part_id);


--
-- Name: idx_catalog_parts_category_id; Type: INDEX; Schema: pct; Owner: -
--

CREATE INDEX idx_catalog_parts_category_id ON pct.catalog_parts USING btree (category_id);


--
-- Name: idx_catalog_parts_status; Type: INDEX; Schema: pct; Owner: -
--

CREATE INDEX idx_catalog_parts_status ON pct.catalog_parts USING btree (status);


--
-- Name: idx_oem_numbers_part_id; Type: INDEX; Schema: pct; Owner: -
--

CREATE INDEX idx_oem_numbers_part_id ON pct.oem_numbers USING btree (catalog_part_id);


--
-- Name: idx_pct_localized_names_part_id; Type: INDEX; Schema: pct; Owner: -
--

CREATE INDEX idx_pct_localized_names_part_id ON pct.localized_names USING btree (catalog_part_id);


--
-- Name: idx_pct_localized_names_value; Type: INDEX; Schema: pct; Owner: -
--

CREATE INDEX idx_pct_localized_names_value ON pct.localized_names USING btree (name_value);


--
-- Name: idx_offers_purchase_request_id; Type: INDEX; Schema: pur; Owner: -
--

CREATE INDEX idx_offers_purchase_request_id ON pur.offers USING btree (purchase_request_id);


--
-- Name: idx_offers_status; Type: INDEX; Schema: pur; Owner: -
--

CREATE INDEX idx_offers_status ON pur.offers USING btree (status);


--
-- Name: idx_purchase_requests_buyer; Type: INDEX; Schema: pur; Owner: -
--

CREATE INDEX idx_purchase_requests_buyer ON pur.purchase_requests USING btree (buyer_user_ref_id);


--
-- Name: idx_purchase_requests_status; Type: INDEX; Schema: pur; Owner: -
--

CREATE INDEX idx_purchase_requests_status ON pur.purchase_requests USING btree (status);


--
-- Name: uq_offers_one_active_per_seller; Type: INDEX; Schema: pur; Owner: -
--

CREATE UNIQUE INDEX uq_offers_one_active_per_seller ON pur.offers USING btree (purchase_request_id, seller_store_ref_id) WHERE ((status)::text = 'submitted'::text);


--
-- Name: idx_bulk_import_job_rows_job_id; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX idx_bulk_import_job_rows_job_id ON ref.bulk_import_job_rows USING btree (job_id);


--
-- Name: idx_bulk_import_jobs_status; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX idx_bulk_import_jobs_status ON ref.bulk_import_jobs USING btree (status);


--
-- Name: idx_bulk_import_jobs_type; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX idx_bulk_import_jobs_type ON ref.bulk_import_jobs USING btree (ref_type);


--
-- Name: idx_ref_values_type; Type: INDEX; Schema: ref; Owner: -
--

CREATE INDEX idx_ref_values_type ON ref.ref_values USING btree (ref_type);


--
-- Name: idx_inventory_items_part; Type: INDEX; Schema: str; Owner: -
--

CREATE INDEX idx_inventory_items_part ON str.inventory_items USING btree (catalog_part_ref_id);


--
-- Name: idx_inventory_items_status; Type: INDEX; Schema: str; Owner: -
--

CREATE INDEX idx_inventory_items_status ON str.inventory_items USING btree (status);


--
-- Name: idx_inventory_items_store_id; Type: INDEX; Schema: str; Owner: -
--

CREATE INDEX idx_inventory_items_store_id ON str.inventory_items USING btree (store_id);


--
-- Name: idx_inventory_photos_item_id; Type: INDEX; Schema: str; Owner: -
--

CREATE INDEX idx_inventory_photos_item_id ON str.inventory_photos USING btree (inventory_item_id);


--
-- Name: idx_stores_city; Type: INDEX; Schema: str; Owner: -
--

CREATE INDEX idx_stores_city ON str.stores USING btree (city_ref_id);


--
-- Name: idx_stores_country; Type: INDEX; Schema: str; Owner: -
--

CREATE INDEX idx_stores_country ON str.stores USING btree (country_ref_id);


--
-- Name: idx_stores_owner; Type: INDEX; Schema: str; Owner: -
--

CREATE INDEX idx_stores_owner ON str.stores USING btree (owner_user_ref_id);


--
-- Name: idx_stores_status; Type: INDEX; Schema: str; Owner: -
--

CREATE INDEX idx_stores_status ON str.stores USING btree (status);


--
-- Name: idx_seller_subscriptions_seller; Type: INDEX; Schema: sub; Owner: -
--

CREATE INDEX idx_seller_subscriptions_seller ON sub.seller_subscriptions USING btree (seller_ref_id);


--
-- Name: idx_seller_subscriptions_status; Type: INDEX; Schema: sub; Owner: -
--

CREATE INDEX idx_seller_subscriptions_status ON sub.seller_subscriptions USING btree (status);


--
-- Name: idx_replies_ticket_id; Type: INDEX; Schema: sup; Owner: -
--

CREATE INDEX idx_replies_ticket_id ON sup.replies USING btree (ticket_id);


--
-- Name: idx_tickets_requester; Type: INDEX; Schema: sup; Owner: -
--

CREATE INDEX idx_tickets_requester ON sup.tickets USING btree (requester_ref_id);


--
-- Name: idx_tickets_status; Type: INDEX; Schema: sup; Owner: -
--

CREATE INDEX idx_tickets_status ON sup.tickets USING btree (status);


--
-- Name: idx_scheduled_jobs_job_type; Type: INDEX; Schema: sys; Owner: -
--

CREATE INDEX idx_scheduled_jobs_job_type ON sys.scheduled_jobs USING btree (job_type);


--
-- Name: idx_scheduled_jobs_status_scheduled_at; Type: INDEX; Schema: sys; Owner: -
--

CREATE INDEX idx_scheduled_jobs_status_scheduled_at ON sys.scheduled_jobs USING btree (status, scheduled_at) WHERE ((status)::text = 'pending'::text);


--
-- Name: idx_ratings_seller; Type: INDEX; Schema: trm; Owner: -
--

CREATE INDEX idx_ratings_seller ON trm.ratings_legacy_seller_only_v1 USING btree (rated_seller_ref_id) WHERE (is_removed_by_moderator = false);


--
-- Name: idx_ratings_source; Type: INDEX; Schema: trm; Owner: -
--

CREATE INDEX idx_ratings_source ON trm.ratings USING btree (source_purchase_request_ref_id);


--
-- Name: idx_ratings_target; Type: INDEX; Schema: trm; Owner: -
--

CREATE INDEX idx_ratings_target ON trm.ratings USING btree (target_type, target_ref_id);


--
-- Name: idx_reports_status; Type: INDEX; Schema: trm; Owner: -
--

CREATE INDEX idx_reports_status ON trm.reports USING btree (status);


--
-- Name: idx_reports_target; Type: INDEX; Schema: trm; Owner: -
--

CREATE INDEX idx_reports_target ON trm.reports USING btree (target_type, target_ref_id);


--
-- Name: idx_generations_model_id; Type: INDEX; Schema: vct; Owner: -
--

CREATE INDEX idx_generations_model_id ON vct.generations USING btree (model_id);


--
-- Name: idx_manufacturers_status; Type: INDEX; Schema: vct; Owner: -
--

CREATE INDEX idx_manufacturers_status ON vct.manufacturers USING btree (status);


--
-- Name: idx_models_manufacturer_id; Type: INDEX; Schema: vct; Owner: -
--

CREATE INDEX idx_models_manufacturer_id ON vct.models USING btree (manufacturer_id);


--
-- Name: idx_models_status; Type: INDEX; Schema: vct; Owner: -
--

CREATE INDEX idx_models_status ON vct.models USING btree (status);


--
-- Name: idx_trims_generation_id; Type: INDEX; Schema: vct; Owner: -
--

CREATE INDEX idx_trims_generation_id ON vct.trims USING btree (generation_id);


--
-- Name: idx_vct_localized_names_owner; Type: INDEX; Schema: vct; Owner: -
--

CREATE INDEX idx_vct_localized_names_owner ON vct.localized_names USING btree (owner_ref_id, owner_type);


--
-- Name: template_versions trg_template_versions_append_only; Type: TRIGGER; Schema: ntf; Owner: -
--

CREATE TRIGGER trg_template_versions_append_only BEFORE DELETE OR UPDATE ON ntf.template_versions FOR EACH ROW EXECUTE FUNCTION ntf.reject_template_version_mutation();


--
-- Name: attachments attachments_message_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.attachments
    ADD CONSTRAINT attachments_message_id_fkey FOREIGN KEY (message_id) REFERENCES com.messages(id);


--
-- Name: conversation_user_settings conversation_user_settings_conversation_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.conversation_user_settings
    ADD CONSTRAINT conversation_user_settings_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES com.conversations(id);


--
-- Name: forward_records forward_records_forwarded_message_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.forward_records
    ADD CONSTRAINT forward_records_forwarded_message_id_fkey FOREIGN KEY (forwarded_message_id) REFERENCES com.messages(id);


--
-- Name: forward_records forward_records_forwarded_to_conversation_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.forward_records
    ADD CONSTRAINT forward_records_forwarded_to_conversation_id_fkey FOREIGN KEY (forwarded_to_conversation_id) REFERENCES com.conversations(id);


--
-- Name: forward_records forward_records_original_message_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.forward_records
    ADD CONSTRAINT forward_records_original_message_id_fkey FOREIGN KEY (original_message_id) REFERENCES com.messages(id);


--
-- Name: message_delivery_tracking message_delivery_tracking_message_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.message_delivery_tracking
    ADD CONSTRAINT message_delivery_tracking_message_id_fkey FOREIGN KEY (message_id) REFERENCES com.messages(id);


--
-- Name: message_thread_links message_thread_links_message_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.message_thread_links
    ADD CONSTRAINT message_thread_links_message_id_fkey FOREIGN KEY (message_id) REFERENCES com.messages(id);


--
-- Name: message_thread_links message_thread_links_reply_to_message_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.message_thread_links
    ADD CONSTRAINT message_thread_links_reply_to_message_id_fkey FOREIGN KEY (reply_to_message_id) REFERENCES com.messages(id);


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: com; Owner: -
--

ALTER TABLE ONLY com.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES com.conversations(id);


--
-- Name: favorites favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.favorites
    ADD CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES iam.users(id);


--
-- Name: user_identities user_identities_provider_type_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.user_identities
    ADD CONSTRAINT user_identities_provider_type_id_fkey FOREIGN KEY (provider_type_id) REFERENCES iam.identity_providers(id);


--
-- Name: user_identities user_identities_user_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.user_identities
    ADD CONSTRAINT user_identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES iam.users(id);


--
-- Name: deliveries deliveries_campaign_id_fkey; Type: FK CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.deliveries
    ADD CONSTRAINT deliveries_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES ntf.campaigns(id);


--
-- Name: notification_center_entries notification_center_entries_recipient_id_fkey; Type: FK CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.notification_center_entries
    ADD CONSTRAINT notification_center_entries_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES ntf.recipients(id);


--
-- Name: notification_preferences notification_preferences_channel_provider_code_fkey; Type: FK CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.notification_preferences
    ADD CONSTRAINT notification_preferences_channel_provider_code_fkey FOREIGN KEY (channel_provider_code) REFERENCES ntf.channel_providers(code);


--
-- Name: outbox outbox_delivery_id_fkey; Type: FK CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.outbox
    ADD CONSTRAINT outbox_delivery_id_fkey FOREIGN KEY (delivery_id) REFERENCES ntf.deliveries(id);


--
-- Name: outbox outbox_recipient_id_fkey; Type: FK CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.outbox
    ADD CONSTRAINT outbox_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES ntf.recipients(id);


--
-- Name: recipients recipients_delivery_id_fkey; Type: FK CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.recipients
    ADD CONSTRAINT recipients_delivery_id_fkey FOREIGN KEY (delivery_id) REFERENCES ntf.deliveries(id);


--
-- Name: template_versions template_versions_template_id_fkey; Type: FK CONSTRAINT; Schema: ntf; Owner: -
--

ALTER TABLE ONLY ntf.template_versions
    ADD CONSTRAINT template_versions_template_id_fkey FOREIGN KEY (template_id) REFERENCES ntf.templates(id);


--
-- Name: aftermarket_numbers aftermarket_numbers_catalog_part_id_fkey; Type: FK CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.aftermarket_numbers
    ADD CONSTRAINT aftermarket_numbers_catalog_part_id_fkey FOREIGN KEY (catalog_part_id) REFERENCES pct.catalog_parts(id);


--
-- Name: catalog_parts catalog_parts_category_id_fkey; Type: FK CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.catalog_parts
    ADD CONSTRAINT catalog_parts_category_id_fkey FOREIGN KEY (category_id) REFERENCES pct.categories(id);


--
-- Name: localized_names localized_names_catalog_part_id_fkey; Type: FK CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.localized_names
    ADD CONSTRAINT localized_names_catalog_part_id_fkey FOREIGN KEY (catalog_part_id) REFERENCES pct.catalog_parts(id);


--
-- Name: oem_numbers oem_numbers_catalog_part_id_fkey; Type: FK CONSTRAINT; Schema: pct; Owner: -
--

ALTER TABLE ONLY pct.oem_numbers
    ADD CONSTRAINT oem_numbers_catalog_part_id_fkey FOREIGN KEY (catalog_part_id) REFERENCES pct.catalog_parts(id);


--
-- Name: offers offers_purchase_request_id_fkey; Type: FK CONSTRAINT; Schema: pur; Owner: -
--

ALTER TABLE ONLY pur.offers
    ADD CONSTRAINT offers_purchase_request_id_fkey FOREIGN KEY (purchase_request_id) REFERENCES pur.purchase_requests(id);


--
-- Name: bulk_import_job_rows bulk_import_job_rows_job_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: -
--

ALTER TABLE ONLY ref.bulk_import_job_rows
    ADD CONSTRAINT bulk_import_job_rows_job_id_fkey FOREIGN KEY (job_id) REFERENCES ref.bulk_import_jobs(id);


--
-- Name: inventory_items fk_inventory_items_primary_photo; Type: FK CONSTRAINT; Schema: str; Owner: -
--

ALTER TABLE ONLY str.inventory_items
    ADD CONSTRAINT fk_inventory_items_primary_photo FOREIGN KEY (primary_photo_id) REFERENCES str.inventory_photos(id);


--
-- Name: inventory_items inventory_items_store_id_fkey; Type: FK CONSTRAINT; Schema: str; Owner: -
--

ALTER TABLE ONLY str.inventory_items
    ADD CONSTRAINT inventory_items_store_id_fkey FOREIGN KEY (store_id) REFERENCES str.stores(id);


--
-- Name: inventory_photos inventory_photos_inventory_item_id_fkey; Type: FK CONSTRAINT; Schema: str; Owner: -
--

ALTER TABLE ONLY str.inventory_photos
    ADD CONSTRAINT inventory_photos_inventory_item_id_fkey FOREIGN KEY (inventory_item_id) REFERENCES str.inventory_items(id);


--
-- Name: seller_subscriptions seller_subscriptions_plan_id_fkey; Type: FK CONSTRAINT; Schema: sub; Owner: -
--

ALTER TABLE ONLY sub.seller_subscriptions
    ADD CONSTRAINT seller_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES sub.plans(id);


--
-- Name: replies replies_ticket_id_fkey; Type: FK CONSTRAINT; Schema: sup; Owner: -
--

ALTER TABLE ONLY sup.replies
    ADD CONSTRAINT replies_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES sup.tickets(id);


--
-- Name: generations generations_model_id_fkey; Type: FK CONSTRAINT; Schema: vct; Owner: -
--

ALTER TABLE ONLY vct.generations
    ADD CONSTRAINT generations_model_id_fkey FOREIGN KEY (model_id) REFERENCES vct.models(id);


--
-- Name: models models_manufacturer_id_fkey; Type: FK CONSTRAINT; Schema: vct; Owner: -
--

ALTER TABLE ONLY vct.models
    ADD CONSTRAINT models_manufacturer_id_fkey FOREIGN KEY (manufacturer_id) REFERENCES vct.manufacturers(id);


--
-- Name: trims trims_generation_id_fkey; Type: FK CONSTRAINT; Schema: vct; Owner: -
--

ALTER TABLE ONLY vct.trims
    ADD CONSTRAINT trims_generation_id_fkey FOREIGN KEY (generation_id) REFERENCES vct.generations(id);


--
-- PostgreSQL database dump complete
--

\unrestrict uuiKQBiciRImrT578ZYZPizub0alQuZQJVeOuaJNVQGO3aygpRwAlm2dOHhzs4F

