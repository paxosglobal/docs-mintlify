# Paxos Documentation Guidelines

## Documentation Platform

This documentation uses **Mintlify** as configured in `docs.json`. Content is written in MDX format.

## Voice and Style

**Professional yet accessible**: Technical precision without unnecessary jargon
**Action-oriented**: Use imperative verbs and step-by-step instructions
**User-focused**: Always address the reader as "you"
**Helpful and supportive**: Include pointers to support and additional context

### Person and Voice

- **Address readers as "you"** (second person) for instructions and guidance
- **Use "Paxos" in third person** when referring to the company or platform: "Paxos provides...", "The Paxos API supports..."
- **Avoid first person** ("I", "we", "us", "our") in technical documentation
- **Exception**: Use "we" sparingly in support contexts: "If you need help, we're here to assist"

### Writing Patterns

- Use numbered step progression with ➊ ➋ ➌ ➍ for multi-step processes
- Write direct, instructional statements: "Use Create Sandbox Deposit to add USD"
- Include contextual guidance with blockquotes: `> If you've already authenticated, skip ahead to...`
- Add verification steps: "Confirm response includes the requisite scopes"
- Never include real PII or Production IDs in examples

### Contextual Information

- **Support references**: `> Questions? Contact [Support](https://support.paxos.com).`
- **Cross-references**: `> Scopes for each endpoint are listed in the [API Reference docs](/api-reference).`
- **Important clarifications**: Use blockquotes to highlight key information without disrupting flow
- **Prerequisites**: Clearly state what's needed before starting: "Before you can complete onboarding..."

### Status and State Communication

- Use consistent language for system states: `"PENDING"`, `"COMPLETED"`, `"APPROVED"`
- Explain state implications: `While on "PENDING", Paxos is processing your request`
- Use backticks for specific values: `"conversion_target_asset": "USD"`

### Expectation Setting

- **Timing guidance**: "This guide should take less than one hour to complete"
- **Processing expectations**: "It can take a minute to process the deposit on the backend"
- **Business context**: Connect technical steps to business outcomes
- **Complexity indicators**: Set appropriate expectations for review processes and timelines

### Error Prevention and Recovery

- **Proactive guidance**: "To avoid common errors with the ID verification process:"
- **Recovery paths**: "Contact Support if you run into any issues using this scope"
- **Retry behavior**: Explain system retry logic and failure handling

## File Organization

```
new-docs/
├── guides/              # User-facing guides and tutorials
├── api-reference/       # API Reference docs for REST, Webhooks & Websockets APIs
├── snippets/            # Reusable MDX components
├── cookbook/            # Step-by-step integration recipes
└── images/              # Screenshots, diagrams, videos
```

### File Naming

- Use **kebab-case** for all files and directories
- Mirror API operations: `create-crypto-withdrawal.mdx` → POST /crypto-withdrawals
- Use descriptive names: `fiat-transfers-quickstart.mdx`

## Content Structure

### Frontmatter

**For guides:**

```yaml
---
title: 'Descriptive Title'
description: Brief, actionable description.
---
```

**For API reference:**

```yaml
---
openapi: post /identity/accounts
---
```

### Heading Hierarchy

- **H1**: Reserved for titles (from frontmatter)
- **H2**: Major sections (`## ➊ Authenticate`, `## Key Features`)
- **H3**: Subsections (`### Sandbox`, `### Production`)

## Code Examples

### Structure

- Provide **complete, executable examples**
- Use realistic placeholders: `{profile_id}`, `{access_token}`
- Include response examples with realistic data
- Use `highlight={line_numbers}` for key lines

### Example Format

```bash {3}
curl -X POST https://api.paxos.com/v2/profiles \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json"
```

## Content Guidelines

### Progressive Structure

1. **Overview** - What and why
2. **Prerequisites** - What you need first
3. **Step-by-step** - How to do it with ➊ ➋ ➌
4. **Verification** - How to confirm success
5. **Next steps** - Where to go from here

### Cross-referencing

- Link between related guides and API endpoints
- Reference specific sections: `guides/developer/authenticate.mdx`
- Include support contact: "Questions? Contact Support."

### Environment Handling

- Clearly distinguish Sandbox vs Production
- Use environment-specific URLs and examples
- Include testnet warnings where appropriate

## How Tos

### Add a New Developer Guide

1. Create file in `guides/developer/` using kebab-case naming
2. Add frontmatter with `title` and `description`
3. Structure with Progressive format: Overview → Prerequisites → Step-by-step → Verification → Next steps
4. Include code examples with realistic placeholders
5. Cross-reference related API endpoints

### Add a New Dashboard Guide

1. Create file in `guides/dashboard/` following kebab-case naming
2. Include screenshots and videos in `images/` directory with descriptive names
3. Use numbered step progression with ➊ ➋ ➌ format
4. Write action-oriented instructions: "Click Add", "Select Profile"
5. Include verification steps with expected UI states
6. Add contextual tips with blockquotes where helpful

### Add a New Stablecoin Guide

1. Create file in `guides/stablecoin/` with token-specific naming
2. Structure by network: mainnet and testnet sections
3. Include contract addresses and network-specific details
4. Add `<MainnetWarning />` component for mainnet content
5. Include cross-chain transfer guidance where applicable
6. Reference relevant API endpoints for programmatic access

### Add New WebSocket Reference

1. Create file in `api-reference/websockets/`
2. Update `websocket-asyncapi.json` with new event specification
3. Use frontmatter: `openapi: websocket /path`
4. Document subscription patterns and message formats
5. Include realistic JSON message examples
6. Add authentication requirements and scope information
7. Cross-reference related REST endpoints

### Add New Webhook Reference

1. Create file in `api-reference/webhooks/`
2. Update `webhooks-openapi.json` with new webhook specification
3. Use frontmatter: `openapi: webhook event-name`
4. Document event trigger conditions and payload structure
5. Include complete JSON payload examples
6. Add retry behavior and delivery information
7. Reference related event objects in `/events/`

### Add New REST API Reference

1. Create file in `api-reference/endpoints/[category]/`
2. Use frontmatter: `openapi: [method] /endpoint-path`
3. Let OpenAPI spec drive the content (minimal additional text needed)
4. Ensure endpoint category has `overview.mdx` file
5. Add any business context or usage notes if needed
6. Cross-reference related webhooks or websocket events