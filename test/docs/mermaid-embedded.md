# Mermaid Diagrams - Embedded

This page demonstrates embedded Mermaid diagrams for the Multi-User Todo App workflows and state machines.

## User Registration Flow

```mermaid
flowchart TD
    Start([User visits registration page]) --> Form[Fill registration form]
    Form --> Validate{Valid input?}
    Validate -->|No| Error[Show validation errors]
    Error --> Form
    Validate -->|Yes| Submit[Submit to API]
    Submit --> CheckEmail{Email exists?}
    CheckEmail -->|Yes| EmailError[Show 'email already registered']
    EmailError --> Form
    CheckEmail -->|No| CreateUser[Create user account]
    CreateUser --> SendEmail[Send verification email]
    SendEmail --> Success[Show success message]
    Success --> End([Redirect to login])
```

## Task State Machine

```mermaid
stateDiagram-v2
    [*] --> Todo

    Todo --> InProgress : Start task
    InProgress --> Todo : Pause/Reopen
    InProgress --> Done : Complete
    Done --> InProgress : Reopen
    Done --> [*]

    Todo --> Cancelled : Cancel
    InProgress --> Cancelled : Cancel
    Cancelled --> [*]

    note right of Todo
        Initial state when
        task is created
    end note

    note right of Done
        Task completed
        successfully
    end note
```

## Team Collaboration Sequence

```mermaid
sequenceDiagram
    actor Alice
    actor Bob
    participant App as Todo App
    participant API as Backend API
    participant DB as Database
    participant WS as WebSocket

    Alice->>App: Create new task
    App->>API: POST /api/tasks
    API->>DB: Insert task
    DB-->>API: Task created
    API-->>App: Return task
    App-->>Alice: Show task

    API->>WS: Broadcast task.created
    WS-->>Bob: Notify new task
    Bob->>App: View task list
    App->>API: GET /api/tasks
    API->>DB: Query tasks
    DB-->>API: Task list
    API-->>App: Return tasks
    App-->>Bob: Display updated list

    Bob->>App: Add comment
    App->>API: POST /api/tasks/:id/comments
    API->>DB: Insert comment
    DB-->>API: Comment created
    API-->>App: Return comment
    App-->>Bob: Show comment

    API->>WS: Broadcast comment.added
    WS-->>Alice: Notify new comment
    Alice->>App: View comment
    App-->>Alice: Display comment
```

## Application Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        Browser[Web Browser]
        Mobile[Mobile App]
    end

    subgraph "API Gateway"
        Gateway[Load Balancer]
    end

    subgraph "Application Layer"
        Auth[Auth Service]
        Task[Task Service]
        User[User Service]
        Notif[Notification Service]
    end

    subgraph "Data Layer"
        PG[(PostgreSQL)]
        Redis[(Redis Cache)]
        S3[S3 Storage]
    end

    Browser --> Gateway
    Mobile --> Gateway
    Gateway --> Auth
    Gateway --> Task
    Gateway --> User
    Gateway --> Notif

    Auth --> PG
    Auth --> Redis
    Task --> PG
    Task --> Redis
    User --> PG
    Notif --> PG
    Task --> S3

    style Browser fill:#E1F5FE
    style Mobile fill:#E1F5FE
    style Gateway fill:#FFF3E0
    style Auth fill:#C8E6C9
    style Task fill:#C8E6C9
    style User fill:#C8E6C9
    style Notif fill:#C8E6C9
    style PG fill:#F8BBD0
    style Redis fill:#F8BBD0
    style S3 fill:#F8BBD0
```

## Task Priority Distribution

```mermaid
pie title Task Priority Distribution
    "High Priority" : 25
    "Medium Priority" : 50
    "Low Priority" : 25
```

## User Journey Map

```mermaid
journey
    title User Journey: Creating and Completing a Task
    section Registration
      Sign up: 5: User
      Verify email: 3: User
      Set up profile: 4: User
    section Task Creation
      Navigate to dashboard: 5: User
      Click 'New Task': 5: User
      Fill task details: 4: User
      Assign to team member: 4: User
      Set due date: 4: User
      Save task: 5: User
    section Collaboration
      Receive notification: 5: Team Member
      Add comment: 4: Team Member
      Update status: 5: Team Member
    section Completion
      Mark as done: 5: Team Member
      Review completion: 5: User
      Archive task: 4: User
```
