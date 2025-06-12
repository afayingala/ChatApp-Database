-- PostgreSQL Update Queries for Custom Chat App Schema

-- 1. Mark Messages as Read/Seen for a specific user in a chat
UPDATE "Message" 
SET "IsRead" = true,
    "MessageStatus" = 'Seen'
WHERE "ChatID" = $1 
  AND "MessageID" = ANY(
    SELECT unnest("Messages") 
    FROM "Chat" 
    WHERE "ChatID" = $1
  )
  AND "SenderID" != $2  -- Don't mark own messages as read
  AND "IsRead" = false
RETURNING "MessageID", "TimeStamp", "MessageStatus";

-- Alternative: Mark specific message as seen
UPDATE "Message" 
SET "IsRead" = true,
    "MessageStatus" = 'Seen'
WHERE "MessageID" = $1 
  AND "SenderID" != $2
RETURNING "MessageID", "Content", "MessageStatus";

-- 2. Update User's Online Status and Last Seen
UPDATE "User" 
SET "OnlineStatus" = true,
    "LastSeen" = NOW()
WHERE "UserID" = $1
RETURNING "UserID", "Username", "OnlineStatus", "LastSeen";

-- Also update device last active time
UPDATE "Device" 
SET "LastActive" = NOW(),
    "IsAuthenticated" = true
WHERE "UserID" = $1 
  AND "DeviceID" = $2
RETURNING "DeviceID", "DeviceType", "LastActive";

-- 3. Edit Message Content and Mark as Edited
UPDATE "Message" 
SET "Content" = $1,
    "IsEdited" = true
WHERE "MessageID" = $2 
  AND "SenderID" = $3
  AND "TimeStamp" > (NOW() - INTERVAL '1 hour')  -- Only allow editing within 1 hour
  AND "MessageType" = 'Text'  -- Only text messages can be edited
RETURNING "MessageID", "Content", "IsEdited", "TimeStamp";

-- 4. Archive/Unarchive Chat for a User
UPDATE "Chat" 
SET "IsArchived" = $1,  -- true to archive, false to unarchive
    "LastUpdated" = NOW()
WHERE "ChatID" = $2 
  AND $3 = ANY("Participants")  -- Ensure user is participant
RETURNING "ChatID", "ChatType", "IsArchived", "LastUpdated";

-- Alternative: Remove user from chat participants (soft leave)
UPDATE "Chat" 
SET "Participants" = array_remove("Participants", $1),
    "LastUpdated" = NOW()
WHERE "ChatID" = $2 
  AND $1 = ANY("Participants")
RETURNING "ChatID", "Participants", "LastUpdated";

-- 5. Update Chat Metadata (add new message to chat)
UPDATE "Chat" 
SET "Messages" = array_append("Messages", $1),  -- Add new message ID
    "LastUpdated" = NOW()
WHERE "ChatID" = $2
RETURNING "ChatID", array_length("Messages", 1) as MessageCount, "LastUpdated";

-- Update message delivery status
UPDATE "Message" 
SET "MessageStatus" = 'Delivered'
WHERE "ChatID" = $1 
  AND "MessageStatus" = 'Sent'
  AND "SenderID" != $2  -- Don't update sender's own messages
RETURNING "MessageID", "MessageStatus", "TimeStamp";

-- 6. Batch Update: Mark Users as Offline After Timeout
UPDATE "User" 
SET "OnlineStatus" = false
WHERE "LastSeen" < (NOW() - INTERVAL '15 minutes')
  AND "OnlineStatus" = true
RETURNING "UserID", "Username", "LastSeen", "OnlineStatus";

-- Mark devices as inactive
UPDATE "Device" 
SET "IsAuthenticated" = false
WHERE "LastActive" < (NOW() - INTERVAL '30 minutes')
  AND "IsAuthenticated" = true
RETURNING "DeviceID", "UserID", "LastActive";

-- 7. Update Group Information
UPDATE "Group" 
SET "GroupName" = $1,
    "GroupDescription" = $2
WHERE "GroupID" = $3 
  AND "AdminID" = $4  -- Only admin can update group info
RETURNING "GroupID", "GroupName", "GroupDescription";

-- Add member to group
UPDATE "Group" 
SET "MemberIDs" = array_append("MemberIDs", $1)
WHERE "GroupID" = $2 
  AND "AdminID" = $3
  AND NOT ($1 = ANY("MemberIDs"))  -- Don't add if already member
RETURNING "GroupID", "MemberIDs";

-- Remove member from group
UPDATE "Group" 
SET "MemberIDs" = array_remove("MemberIDs", $1)
WHERE "GroupID" = $2 
  AND ("AdminID" = $3 OR $1 = $3)  -- Admin can remove anyone, users can remove themselves
RETURNING "GroupID", "MemberIDs";

-- 8. Update User Profile Information
UPDATE "User" 
SET "StatusMessage" = $1,
    "ProfilePicture" = $2
WHERE "UserID" = $3
RETURNING "UserID", "Username", "StatusMessage", "ProfilePicture";

-- Add/Remove contacts
UPDATE "User" 
SET "Contacts" = array_append("Contacts", $1)
WHERE "UserID" = $2 
  AND NOT ($1 = ANY("Contacts"))  -- Don't add duplicate contacts
RETURNING "UserID", "Contacts";

-- Block/Unblock user
UPDATE "User" 
SET "BlockedUsers" = 
    CASE 
        WHEN $1 = ANY("BlockedUsers") THEN array_remove("BlockedUsers", $1)  -- Unblock
        ELSE array_append("BlockedUsers", $1)  -- Block
    END
WHERE "UserID" = $2
RETURNING "UserID", "BlockedUsers";

-- 9. Update Settings and Privacy
UPDATE "Settings" 
SET "Theme" = $1,
    "NotificationsEnabled" = $2,
    "Language" = $3
WHERE "UserID" = $4
RETURNING "UserID", "Theme", "NotificationsEnabled", "Language";

UPDATE "PrivacySettings" 
SET "LastSeenEnabled" = $1,
    "ProfilePhotoVisibility" = $2
WHERE "UserID" = $3
RETURNING "UserID", "LastSeenEnabled", "ProfilePhotoVisibility";

-- 10. Mark Notifications as Read
UPDATE "Notification" 
SET "IsRead" = true
WHERE "RecipientID" = $1 
  AND "IsRead" = false
RETURNING "NotificationID", "Type", "Content", "TimeStamp";

-- Update specific notification
UPDATE "Notification" 
SET "IsRead" = true
WHERE "NotificationID" = $1 
  AND "RecipientID" = $2
RETURNING "NotificationID", "Content", "IsRead";

-- 11. Update Call Status
UPDATE "Call" 
SET "CallStatus" = $1,  -- 'Completed', 'Missed', 'Rejected'
    "EndTime" = NOW(),
    "Duration" = NOW() - "StartTime"
WHERE "CallID" = $2
RETURNING "CallID", "CallStatus", "Duration", "EndTime";

-- 12. Complex Query: Update Chat with New Message and Participants
WITH new_message AS (
    INSERT INTO "Message" (
        "MessageID", "SenderID", "ChatID", "MessageType", 
        "Content", "MessageStatus"
    ) 
    VALUES ($1, $2, $3, 'Text', $4, 'Sent')
    RETURNING "MessageID"
)
UPDATE "Chat" 
SET "Messages" = array_append("Messages", (SELECT "MessageID" FROM new_message)),
    "LastUpdated" = NOW()
WHERE "ChatID" = $3
RETURNING "ChatID", "LastUpdated", array_length("Messages", 1) as TotalMessages;