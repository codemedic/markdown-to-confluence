# PlantUML Diagrams - Embedded

This page demonstrates embedded PlantUML diagrams for the Multi-User Todo App architecture.

## System Architecture

```plantuml
@startuml
!define RECTANGLE_COLOR #E1F5FE

package "Frontend" {
  [React SPA] <<RECTANGLE_COLOR>>
  [Redux Store] <<RECTANGLE_COLOR>>
}

package "Backend API" {
  [Auth Service] <<RECTANGLE_COLOR>>
  [Task Service] <<RECTANGLE_COLOR>>
  [User Service] <<RECTANGLE_COLOR>>
  [Notification Service] <<RECTANGLE_COLOR>>
}

package "Data Layer" {
  database "PostgreSQL" {
    [Users]
    [Tasks]
    [Comments]
  }
  database "Redis" {
    [Sessions]
    [Cache]
  }
}

[React SPA] --> [Auth Service] : API Requests
[React SPA] --> [Task Service] : API Requests
[React SPA] --> [User Service] : API Requests

[Auth Service] --> [Users]
[Auth Service] --> [Sessions]
[Task Service] --> [Tasks]
[Task Service] --> [Cache]
[User Service] --> [Users]
[Notification Service] --> [Tasks]
@enduml
```

## User Authentication Sequence

```plantuml
@startuml
actor User
participant "React SPA" as Frontend
participant "Auth Service" as Auth
participant "PostgreSQL" as DB
participant "Redis" as Cache

User -> Frontend: Login (email, password)
Frontend -> Auth: POST /api/auth/login
Auth -> DB: Verify credentials
DB --> Auth: User data
Auth -> Cache: Store session
Cache --> Auth: Session ID
Auth --> Frontend: JWT + Session ID
Frontend --> User: Redirect to dashboard
@enduml
```

## Task Creation Flow

```plantuml
@startuml
actor User
participant "React SPA" as Frontend
participant "Task Service" as TaskSvc
participant "PostgreSQL" as DB
participant "Notification Service" as NotifSvc

User -> Frontend: Create new task
Frontend -> TaskSvc: POST /api/tasks
TaskSvc -> DB: Insert task record
DB --> TaskSvc: Task ID
TaskSvc -> NotifSvc: Notify team members
NotifSvc --> Frontend: WebSocket event
Frontend --> User: Show success + update UI
@enduml
```

## Component Relationships

```plantuml
@startuml
class User {
  +id: UUID
  +email: String
  +name: String
  +role: Role
  +createdAt: DateTime
}

class Task {
  +id: UUID
  +title: String
  +description: String
  +priority: Priority
  +status: Status
  +dueDate: DateTime
  +assigneeId: UUID
  +creatorId: UUID
}

class Comment {
  +id: UUID
  +taskId: UUID
  +authorId: UUID
  +content: String
  +createdAt: DateTime
}

enum Priority {
  HIGH
  MEDIUM
  LOW
}

enum Status {
  TODO
  IN_PROGRESS
  DONE
}

enum Role {
  ADMIN
  MEMBER
  VIEWER
}

User "1" -- "*" Task : creates
User "1" -- "*" Task : assigned to
User "1" -- "*" Comment : writes
Task "1" -- "*" Comment : has
@enduml
```
