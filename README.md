# Paxos Documentation

The official documentation for Paxos APIs and developer resources, built with [Mintlify](https://mintlify.com).

## Overview

This repository contains the comprehensive documentation for Paxos APIs, including:

- **API Reference** - Complete REST API documentation with OpenAPI specifications
- **Developer Guides** - Getting started tutorials, authentication, and integration guides  
- **Product Guides** - Documentation for Crypto Brokerage, Stablecoin, Payments, and Settlements
- **Webhooks** - Event-driven integration documentation
- **Identity & KYC** - Customer onboarding and compliance guides

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- Git

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/paxos/paxos-docs.git
   cd paxos-docs/new-docs
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Install Mintlify CLI globally**
   ```bash
   npm install -g mintlify
   ```

4. **Start the development server**
   ```bash
   mintlify dev
   ```

   The documentation will be available at `http://localhost:3000`

### Making Changes

1. **Create a new branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Documentation files are in Markdown (`.mdx`) format
   - Configuration is in `docs.json`
   - Images go in the `images/` directory

3. **Preview your changes**
   ```bash
   mintlify dev
   ```

4. **Check for broken links**
   ```bash
   mintlify broken-links
   ```

5. **Commit and push**
   ```bash
   git add .
   git commit -m "Description of your changes"
   git push origin feature/your-feature-name
   ```

6. **Create a pull request**

## Project Structure

```
├── api-reference/          # OpenAPI-generated API documentation
├── guides/                 # Developer and product guides
│   ├── developer/         # Developer-focused guides
│   ├── identity/          # Identity and KYC guides
│   ├── stablecoin/        # Stablecoin operation guides
│   └── ...
├── images/                # Static images and assets
├── snippets/              # Reusable content snippets
├── docs.json              # Mintlify configuration
└── README.md              # This file
```

## Contributing

### Content Guidelines

- Use clear, concise language
- Include code examples where relevant
- Follow the existing style and structure
- Test all code samples before submitting
- Add screenshots for UI-related documentation

### Review Process

1. All changes require a pull request
2. Documentation is automatically deployed after merge to main
3. Check that links work and examples are accurate
4. Ensure proper formatting and spelling

### Troubleshooting

- **Mintlify dev not running**: Run `mintlify install` to reinstall dependencies
- **Page loads as 404**: Ensure you're in the directory with `docs.json`
- **Build fails**: Check `docs.json` syntax and file paths
- **Links broken**: Run `mintlify broken-links` to identify issues

## Resources

- [Mintlify Documentation](https://mintlify.com/docs)
- [Paxos Developer Portal](https://developer.paxos.com)
- [API Status Page](https://status.paxos.com)

## Support

For documentation issues, please create an issue in this repository. For API support, contact [Paxos Support](https://support.paxos.com).