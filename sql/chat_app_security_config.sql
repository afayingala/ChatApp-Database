

-- 1. USERS
CREATE TABLE "User" (
    UserID UUID PRIMARY KEY,
    Username TEXT NOT NULL,
    PhoneNumber TEXT UNIQUE NOT NULL,
    ProfilePicture TEXT,
    StatusMessage TEXT,
    OnlineStatus BOOLEAN DEFAULT FALSE,
    LastSeen TIMESTAMP,
    BlockedUsers UUID[],
    Contacts UUID[]
);

-- 2. DEVICE
CREATE TABLE "Device" (
    DeviceID UUID PRIMARY KEY,
    UserID UUID REFERENCES "User"(UserID),
    DeviceType TEXT,
    LastActive TIMESTAMP,
    IsAuthenticated BOOLEAN
);

-- 3. CHAT
CREATE TABLE "Chat" (
    ChatID UUID PRIMARY KEY,
    ChatType TEXT CHECK (ChatType IN ('one-to-one', 'group')),
    Participants UUID[],
    Messages UUID[],
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastUpdated TIMESTAMP,
    IsArchived BOOLEAN DEFAULT FALSE
);

-- 4. MESSAGE
CREATE TABLE "Message" (
    MessageID UUID PRIMARY KEY,
    SenderID UUID REFERENCES "User"(UserID),
    ChatID UUID REFERENCES "Chat"(ChatID),
    MessageType TEXT CHECK (MessageType IN ('Text', 'Image', 'Video', 'File', 'VoiceNote')),
    Content TEXT,
    TimeStamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsRead BOOLEAN DEFAULT FALSE,
    MessageStatus TEXT CHECK (MessageStatus IN ('Sent', 'Delivered', 'Seen')),
    IsEdited BOOLEAN DEFAULT FALSE,
    ReplyToMessageID UUID
);

-- 5. MEDIA
CREATE TABLE "Media" (
    MediaID UUID PRIMARY KEY,
    UploaderID UUID REFERENCES "User"(UserID),
    MediaType TEXT CHECK (MediaType IN ('Image', 'Video', 'Audio', 'File')),
    FileURL TEXT,
    ThumbnailURL TEXT,
    UploadTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    AssociatedMessageID UUID REFERENCES "Message"(MessageID)
);

-- 6. GROUP
CREATE TABLE "Group" (
    GroupID UUID PRIMARY KEY,
    GroupName TEXT,
    GroupPicture TEXT,
    GroupDescription TEXT,
    AdminID UUID REFERENCES "User"(UserID),
    MemberIDs UUID[],
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    InviteLink TEXT
);

-- 7. CALL
CREATE TABLE "Call" (
    CallID UUID PRIMARY KEY,
    CallerID UUID REFERENCES "User"(UserID),
    Participants UUID[],
    CallType TEXT CHECK (CallType IN ('Voice', 'Video')),
    CallStatus TEXT CHECK (CallStatus IN ('Missed', 'Completed', 'Rejected')),
    StartTime TIMESTAMP,
    EndTime TIMESTAMP,
    Duration INTERVAL,
    IsGroupCall BOOLEAN DEFAULT FALSE
);

-- 8. STATUS
CREATE TABLE "Status" (
    StatusID UUID PRIMARY KEY,
    UserID UUID REFERENCES "User"(UserID),
    MediaType TEXT,
    MediaURL TEXT,
    Caption TEXT,
    TimeStamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Viewers UUID[]
);

-- 9. NOTIFICATION
CREATE TABLE "Notification" (
    NotificationID UUID PRIMARY KEY,
    RecipientID UUID REFERENCES "User"(UserID),
    Type TEXT CHECK (Type IN ('Message', 'Call', 'GroupEvent')),
    Content TEXT,
    TimeStamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsRead BOOLEAN DEFAULT FALSE
);

-- 10. SETTINGS
CREATE TABLE "Settings" (
    UserID UUID PRIMARY KEY REFERENCES "User"(UserID),
    Theme TEXT,
    NotificationsEnabled BOOLEAN,
    LastBackup TIMESTAMP,
    Language TEXT
);

-- 11. PRIVACY SETTINGS
CREATE TABLE "PrivacySettings" (
    UserID UUID PRIMARY KEY REFERENCES "User"(UserID),
    LastSeenEnabled BOOLEAN,
    ProfilePhotoVisibility TEXT,
    Attribute1 TEXT
);

-- 12. ROLES & PRIVILEGES
CREATE ROLE chat_admin WITH LOGIN PASSWORD 'AdminPass';
ALTER ROLE chat_admin WITH SUPERUSER;

CREATE ROLE chat_user WITH LOGIN PASSWORD 'UserPass';
CREATE ROLE chat_auditor WITH LOGIN PASSWORD 'AuditorPass';

GRANT CONNECT ON DATABASE chat_app TO chat_user, chat_auditor;
GRANT USAGE ON SCHEMA public TO chat_user, chat_auditor;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO chat_admin;

GRANT SELECT, INSERT, UPDATE ON
    "User", "Chat", "Message", "Call", "Group", "Notification"
TO chat_user;

GRANT SELECT ON
    "User", "Chat", "Message", "Call", "Group", "Notification",
    "Status", "Settings", "Device", "Media"
TO chat_auditor;

REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM chat_auditor;

-- 13. AUDIT LOG TABLE
CREATE TABLE audit_log (
    AuditID SERIAL PRIMARY KEY,
    TableName TEXT,
    Operation TEXT,
    ChangedBy TEXT,
    ChangedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    OldData JSONB,
    NewData JSONB
);

-- 14. AUDIT FUNCTION
CREATE OR REPLACE FUNCTION audit_trigger_fn() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(TableName, Operation, ChangedBy, OldData, NewData)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD), row_to_json(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log(TableName, Operation, ChangedBy, OldData)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD));
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(TableName, Operation, ChangedBy, NewData)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(NEW));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 15. TRIGGERS (example for Message and User)
CREATE TRIGGER message_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON "Message"
FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();

CREATE TRIGGER user_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON "User"
FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();


-- 16. Function to generate daily audit report for ALL table changes
CREATE OR REPLACE FUNCTION generate_full_daily_audit_report()
RETURNS VOID AS $$
DECLARE
    report TEXT;
BEGIN
    SELECT string_agg(
        'Table: ' || TableName || ', Operation: ' || Operation ||
        ', Time: ' || ChangedAt || ', By: ' || ChangedBy ||
        ', Old: ' || COALESCE(OldData::TEXT, 'NULL') ||
        ', New: ' || COALESCE(NewData::TEXT, 'NULL'),
        E'

'
    )
    INTO report
    FROM audit_log
    WHERE ChangedAt >= NOW() - INTERVAL '1 day';

    IF report IS NOT NULL THEN
        INSERT INTO daily_reports (report_content, generated_at)
        VALUES (report, CURRENT_TIMESTAMP);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Table to store daily reports (if not already created)
CREATE TABLE IF NOT EXISTS daily_reports (
    report_id SERIAL PRIMARY KEY,
    report_content TEXT,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


