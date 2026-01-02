# Multi-User Todo App Documentation

Welcome to the Multi-User Todo App documentation. This application allows teams to collaboratively manage tasks with role-based access control.

## Architecture Overview

Our todo app is built with a modern microservices architecture:

- **Frontend**: React SPA with real-time updates
- **Backend**: Node.js REST API with authentication
- **Database**: PostgreSQL for persistent storage
- **Cache**: Redis for session management and real-time features

## Documentation Structure

- [PlantUML Diagrams - Embedded](plantuml-embedded.md) - System architecture and sequence diagrams
- [PlantUML Diagrams - Linked](plantuml-linked.md) - Entity relationships and deployment
- [Mermaid Diagrams - Embedded](mermaid-embedded.md) - User flows and state machines
- [Mermaid Diagrams - Linked](mermaid-linked.md) - Gantt charts and timelines

## Quick Start

```bash
# Clone the repository
git clone https://github.com/example/todo-app.git

# Install dependencies
npm install

# Configure environment
cp .env.example .env

# Start development server
npm run dev
```

## Key Features

- **Task Management**: Create, edit, and organize tasks
- **Team Collaboration**: Share lists and assign tasks
- **Priority Levels**: High, medium, and low priority tags
- **Due Dates**: Set deadlines with notifications
- **Comments**: Discuss tasks with team members
- **Search & Filter**: Find tasks quickly with advanced filters

## Support

For issues and feature requests, please visit our [GitHub repository](https://github.com/example/todo-app).
