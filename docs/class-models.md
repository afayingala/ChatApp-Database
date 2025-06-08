This section describes the implementation of classes based on the object diagram designed for the Central Africa Chat App. The application leverages Prisma ORM for modeling and managing the PostgreSQL database, ensuring consistency between object-oriented logic and relational structures.

The Prisma models below were created to represent each object and relationship in the UML diagram. Each class maps directly to a database table, with fields representing attributes and relationships represented via Prisma’s relation syntax.

Prisma Models
prisma
Copy
Edit
model User {
  id          String         @id @default(uuid())
  name        String
  phoneNum    String
  language    String
  messages    Message[]      @relation("UserMessages")
  orders      Order[]
  sessions    ChatSession[]  @relation("SessionParticipants", references: [id])
}

model Message {
  messageId   String         @id @default(uuid())
  content     String
  timestamp   DateTime
  senderId    String
  sender      User           @relation("UserMessages", fields: [senderId], references: [id])
  sessionId   String
  session     ChatSession    @relation(fields: [sessionId], references: [sessionId])
  factCheck   FactCheckPrompt?
}

model Order {
  orderId     String   @id @default(uuid())
  item        String
  price       Int
  status      String
  userId      String
  user        User     @relation(fields: [userId], references: [id])
}

model BusinessAccount {
  id          String    @id @default(uuid())
  name        String
  phoneNum    String
  language    String
  orders      Order[]
}

model ChatSession {
  sessionId     String     @id @default(uuid())
  type          String
  isLowBandwidth Boolean
  messages      Message[]
  participants  User[]     @relation("SessionParticipants")
  group         Group?
}

model Group {
  groupId     String      @id @default(uuid())
  name        String
  maxMembers  Int
  sessionId   String
  session     ChatSession @relation(fields: [sessionId], references: [sessionId])
}

model FactCheckPrompt {
  promptId     String     @id @default(uuid())
  messageRef   String     @unique
  message      Message    @relation(fields: [messageRef], references: [messageId])
  status       String
  suggestion   String
}
Mapping to the UML Diagram
Prisma Model	Mapped UML Class	Details
User	User	Attributes like name, phone number, language, with relationships to messages and sessions.
Message	Message	Stores message content, sender info, session context, and links to fact-checking.
Order	Order	Connected to both User and BusinessAccount, representing transactions.
BusinessAccount	BusinessAccount	Simplified business entity with relationships to orders.
ChatSession	ChatSession	Central communication entity connecting multiple users and messages.
Group	Group	Represents group chats with a defined maximum member count and session link.
FactCheckPrompt	FactCheckPrompt	Optional layer for verifying or tagging messages, attached to a specific message.

