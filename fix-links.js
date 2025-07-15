#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Patterns to fix
const linkPatterns = [
  // API reference links missing /endpoints/
  {
    pattern: /\/api-reference\/([^\/\s\)]+)\/([^\/\s\)]+)(?!\/endpoints)/g,
    replacement: (match, group1, group2) => {
      // Don't add endpoints if it's already there or if it's a top-level section
      const topLevelSections = ['introduction', 'events', 'webhooks', 'websockets'];
      if (topLevelSections.includes(group1)) {
        return match; // Return unchanged
      }
      return `/api-reference/endpoints/${group1}/${group2}`;
    },
    description: 'Fix API reference links missing /endpoints/'
  },
  // Guide links missing /guides/
  {
    pattern: /(?<![\/"])(developer|identity|payments|settlements|webhooks|dashboard|stablecoin|crypto-brokerage)\/([^\/\s\)]+)/g,
    replacement: '/guides/$1/$2',
    description: 'Fix guide links missing /guides/'
  }
];

// Additional specific fixes
const specificFixes = [
  {
    pattern: /\[fiat withdrawal guide\]:\s*developer\/fiat-transfers\/quickstart#withdrawal/g,
    replacement: '[fiat withdrawal guide]: /guides/developer/fiat-transfers/quickstart#withdrawal',
    description: 'Fix fiat withdrawal guide link'
  },
  {
    pattern: /\[token\]:\s*developer\/authenticate/g,
    replacement: '[token]: /guides/developer/authenticate',
    description: 'Fix token authentication link'
  }
];

function getAllMdxFiles(dir) {
  const files = [];
  
  function scan(currentDir) {
    const items = fs.readdirSync(currentDir);
    
    for (const item of items) {
      const fullPath = path.join(currentDir, item);
      const stat = fs.statSync(fullPath);
      
      if (stat.isDirectory()) {
        // Skip node_modules and other build directories
        if (!['node_modules', '.git', 'build', 'dist'].includes(item)) {
          scan(fullPath);
        }
      } else if (item.endsWith('.mdx')) {
        files.push(fullPath);
      }
    }
  }
  
  scan(dir);
  return files;
}

function fixLinksInFile(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');
  let modified = false;
  const changes = [];

  // Apply specific fixes first
  for (const fix of specificFixes) {
    const before = content;
    content = content.replace(fix.pattern, fix.replacement);
    if (content !== before) {
      modified = true;
      changes.push(fix.description);
    }
  }

  // Apply pattern fixes
  for (const pattern of linkPatterns) {
    const before = content;
    if (typeof pattern.replacement === 'function') {
      content = content.replace(pattern.pattern, pattern.replacement);
    } else {
      content = content.replace(pattern.pattern, pattern.replacement);
    }
    if (content !== before) {
      modified = true;
      changes.push(pattern.description);
    }
  }

  if (modified) {
    fs.writeFileSync(filePath, content);
    console.log(`Fixed ${filePath}:`);
    changes.forEach(change => console.log(`  - ${change}`));
    return true;
  }
  
  return false;
}

function main() {
  const docsDir = process.cwd();
  console.log(`Scanning for .mdx files in ${docsDir}...`);
  
  const mdxFiles = getAllMdxFiles(docsDir);
  console.log(`Found ${mdxFiles.length} .mdx files`);
  
  let totalFixed = 0;
  
  for (const file of mdxFiles) {
    if (fixLinksInFile(file)) {
      totalFixed++;
    }
  }
  
  console.log(`\nFixed links in ${totalFixed} files`);
}

if (require.main === module) {
  main();
}