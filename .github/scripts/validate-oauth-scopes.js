#!/usr/bin/env node

const fs = require('fs').promises;
const path = require('path');

async function fetchOpenAPISpec() {
  const response = await fetch('https://developer.paxos.com/docs/paxos-v2.openapi.json');
  if (!response.ok) {
    throw new Error(`Failed to fetch OpenAPI spec: ${response.status} ${response.statusText}`);
  }
  return response.json();
}

async function findMdxFiles(dir) {
  const files = [];
  const entries = await fs.readdir(dir, { withFileTypes: true });
  
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await findMdxFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.mdx') && entry.name !== 'overview.mdx') {
      files.push(fullPath);
    }
  }
  return files;
}

function extractOpenAPIFromFrontmatter(content) {
  const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---/);
  if (!frontmatterMatch) return null;
  
  const frontmatter = frontmatterMatch[1];
  const openApiMatch = frontmatter.match(/^openapi:\s*(.+)$/m);
  
  if (openApiMatch) {
    const [method, path] = openApiMatch[1].trim().split(' ', 2);
    return { method: method.toLowerCase(), path };
  }
  return null;
}

function findOAuthScope(openApiSpec, method, path) {
  const paths = openApiSpec.paths;
  if (!paths[path] || !paths[path][method]) {
    return null;
  }
  
  const operation = paths[path][method];
  const security = operation.security || openApiSpec.security || [];
  
  // Look for OAuth2 security with scopes
  for (const securityRequirement of security) {
    for (const [schemeName, scopes] of Object.entries(securityRequirement)) {
      const securityScheme = openApiSpec.components?.securitySchemes?.[schemeName];
      if (securityScheme?.type === 'oauth2' && scopes.length > 0) {
        return scopes[0]; // Return the first scope
      }
    }
  }
  
  return null;
}

function hasOAuthScopeSection(content) {
  return content.includes('```bash OAuth Scope');
}

function extractOAuthScopeFromContent(content) {
  const scopeMatch = content.match(/```bash OAuth Scope\n([^\n]+)\n```/);
  return scopeMatch ? scopeMatch[1].trim() : null;
}

async function validateFile(filePath, openApiSpec) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    
    const openApiInfo = extractOpenAPIFromFrontmatter(content);
    if (!openApiInfo) {
      // Skip files without OpenAPI frontmatter - they're not API endpoints
      return { valid: true };
    }
    
    const expectedScope = findOAuthScope(openApiSpec, openApiInfo.method, openApiInfo.path);
    const hasScope = hasOAuthScopeSection(content);
    
    // If the endpoint requires a scope but file doesn't have one
    if (expectedScope && !hasScope) {
      return {
        valid: false,
        error: `Missing OAuth scope section. Expected scope: ${expectedScope}`,
        endpoint: `${openApiInfo.method.toUpperCase()} ${openApiInfo.path}`,
        expectedScope
      };
    }
    
    // If the endpoint requires a scope and file has one, check if it matches
    if (expectedScope && hasScope) {
      const actualScope = extractOAuthScopeFromContent(content);
      if (actualScope !== expectedScope) {
        return {
          valid: false,
          error: `OAuth scope mismatch. Expected: ${expectedScope}, Found: ${actualScope}`,
          endpoint: `${openApiInfo.method.toUpperCase()} ${openApiInfo.path}`,
          expectedScope,
          actualScope
        };
      }
    }
    
    // If the endpoint doesn't require a scope but file has one
    if (!expectedScope && hasScope) {
      const actualScope = extractOAuthScopeFromContent(content);
      return {
        valid: false,
        error: `Unexpected OAuth scope section found. This endpoint doesn't require OAuth. Found scope: ${actualScope}`,
        endpoint: `${openApiInfo.method.toUpperCase()} ${openApiInfo.path}`,
        actualScope
      };
    }
    
    return { valid: true };
    
  } catch (error) {
    return {
      valid: false,
      error: `Failed to process file: ${error.message}`
    };
  }
}

async function main() {
  try {
    console.log('🔄 Fetching OpenAPI specification...');
    const openApiSpec = await fetchOpenAPISpec();
    console.log('✅ OpenAPI specification fetched successfully');
    
    console.log('🔍 Finding MDX files in api-reference/endpoints...');
    const endpointsDir = path.join(process.cwd(), 'api-reference', 'endpoints');
    const mdxFiles = await findMdxFiles(endpointsDir);
    console.log(`📁 Found ${mdxFiles.length} MDX files to validate`);
    
    console.log('🔄 Validating OAuth scopes...');
    const errors = [];
    
    for (const filePath of mdxFiles) {
      const result = await validateFile(filePath, openApiSpec);
      if (!result.valid) {
        const relativePath = path.relative(process.cwd(), filePath);
        errors.push({
          file: relativePath,
          ...result
        });
      }
    }
    
    if (errors.length === 0) {
      console.log('🎉 All OAuth scopes are valid!');
      process.exit(0);
    } else {
      console.log(`❌ Found ${errors.length} OAuth scope validation error(s):\n`);
      
      for (const error of errors) {
        console.log(`📄 ${error.file}`);
        if (error.endpoint) {
          console.log(`   Endpoint: ${error.endpoint}`);
        }
        console.log(`   Error: ${error.error}`);
        if (error.expectedScope && error.actualScope) {
          console.log(`   Expected: ${error.expectedScope}`);
          console.log(`   Actual: ${error.actualScope}`);
        } else if (error.expectedScope) {
          console.log(`   Expected: ${error.expectedScope}`);
        } else if (error.actualScope) {
          console.log(`   Found: ${error.actualScope}`);
        }
        console.log('');
      }
      
      console.log(`💡 To fix these issues, run: node add-oauth-scopes.js`);
      process.exit(1);
    }
    
  } catch (error) {
    console.error('❌ Validation failed:', error.message);
    process.exit(1);
  }
}

// Run the script
main();