-- PostgreSQL Schema File (initial draft)


CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
	status VARCHAR(20) NOT NULL,
    profile_image BYTEA,
    last_seen TIMESTAMP
);


CREATE TABLE messages (
    message_id SERIAL PRIMARY KEY,
    sender_id INT REFERENCES users(user_id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	media_URL BYTEA,
	is_edited BOOLEAN DEFAULT FALSE,
    is_translated BOOLEAN DEFAULT FALSE
);


CREATE TABLE message_reaction (
    reaction_id SERIAL PRIMARY KEY,
    message_id INT REFERENCES messages(message_id) ON DELETE CASCADE,
    user_id INT REFERENCES users(user_id) ON DELETE CASCADE,
    reaction_type VARCHAR(20) NOT NULL
);


CREATE TABLE chat (
    chat_id SERIAL PRIMARY KEY,
	chat_type VARCHAR(50) NOT NULL, 
    created_by_id INT REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE groupchat (
	chat_id INT REFERENCES chat(chat_id) ON DELETE CASCADE PRIMARY KEY,
    description TEXT,
	group_name VARCHAR(100) NOT NULL,
    group_icon VARCHAR(100) NOT NULL
);


CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id) ON DELETE CASCADE,
    message_id INT REFERENCES messages(message_id) ON DELETE CASCADE,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE
);


CREATE TABLE translation (
    translation_id SERIAL PRIMARY KEY,
    message_id INT REFERENCES messages(message_id) ON DELETE CASCADE,
    translated_text TEXT NOT NULL,
    language_code VARCHAR(10) NOT NULL
);


CREATE TABLE report (
    report_id SERIAL PRIMARY KEY,
    reporter_id INT REFERENCES users(user_id) ON DELETE CASCADE,
    reported_userID INT REFERENCES users(user_id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
	reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE admin (
    admin_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE
);


--These are the SQL codes showing how the ER diagram can be implemented in the physical database (PostgreSQL). Each entity from the ER diagram becomes a table, while all the attributes become the columns of the table with an addition of some constraints such as the:
--Unique constraint: which indicates that an attribute most contain only unique values else it won't be stored. 
--ON DELETE CASCADE means that if a row in the parent table is deleted, all corresponding rows in the child table that reference the deleted row's primary key will also be automatically deleted. This helps maintain referential integrity by ensuring that there are no orphaned records in the child table.
--NOT NULL: Means that attribute can not be left empty. It must always have a value. 
