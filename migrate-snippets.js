#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Convert kebab-case filename to PascalCase component name
 * @param {string} filename - The filename (without extension)
 * @returns {string} PascalCase component name
 */
function toPascalCase(filename) {
  return filename
    .replace(/^[^a-zA-Z]*/, '') // Remove leading non-letters
    .replace(/[^a-zA-Z0-9-_/]/g, '') // Keep only letters, numbers, hyphens, underscores, and slashes
    .split(/[-_/]/) // Split on hyphens, underscores, and slashes
    .filter(part => part.length > 0) // Remove empty parts
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join('');
}

/**
 * Extract frontmatter and content from MDX file
 * @param {string} content - The MDX file content
 * @returns {object} Object with frontmatter and content
 */
function extractFrontmatter(content) {
  const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  
  if (frontmatterMatch) {
    return {
      frontmatter: frontmatterMatch[1],
      content: frontmatterMatch[2]
    };
  }
  
  return {
    frontmatter: '',
    content: content
  };
}

/**
 * Process a single MDX file to migrate snippet usage
 * @param {string} filePath - Path to the MDX file
 * @param {boolean} dryRun - Whether to only preview changes
 */
function processFile(filePath, dryRun = false) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const { frontmatter, content: fileContent } = extractFrontmatter(content);
  
  // Find all snippet usages
  const snippetRegex = /<Snippet\s+file="([^"]+)"\s*\/>/g;
  const snippets = [];
  let match;
  
  while ((match = snippetRegex.exec(fileContent)) !== null) {
    const filename = match[1];
    const filenameWithoutExt = filename.replace(/\.mdx$/, '');
    const componentName = toPascalCase(filenameWithoutExt);
    
    snippets.push({
      original: match[0],
      filename: filename,
      componentName: componentName
    });
  }
  
  if (snippets.length === 0) {
    if (!dryRun) console.log(`No snippets found in ${filePath}`);
    return;
  }
  
  console.log(`${dryRun ? '[DRY RUN] ' : ''}Processing ${filePath}:`);
  console.log(`  Found ${snippets.length} snippet(s)`);
  
  // Generate import statements
  const imports = snippets.map(snippet => {
    return `import ${snippet.componentName} from '/snippets/${snippet.filename}';`;
  });
  
  // Show what would be changed
  snippets.forEach(snippet => {
    console.log(`  - ${snippet.original} → <${snippet.componentName} />`);
  });
  
  if (imports.length > 0) {
    console.log(`  Imports to add:`);
    imports.forEach(imp => console.log(`    ${imp}`));
  }
  
  if (dryRun) {
    console.log(`  [DRY RUN] Would update ${filePath}\n`);
    return;
  }
  
  // Replace snippet tags with component usage
  let newContent = fileContent;
  snippets.forEach(snippet => {
    newContent = newContent.replace(snippet.original, `<${snippet.componentName} />`);
  });
  
  // Find existing imports to insert new ones properly
  const existingImports = [];
  const importRegex = /^import\s+.*?;$/gm;
  const importMatches = newContent.match(importRegex);
  
  if (importMatches) {
    existingImports.push(...importMatches);
  }
  
  // Remove existing imports from content
  newContent = newContent.replace(importRegex, '');
  
  // Combine all imports (existing + new) and deduplicate
  const allImports = [...existingImports, ...imports];
  const uniqueImports = [...new Set(allImports)];
  
  // Reconstruct the file
  let newFileContent = '';
  
  if (frontmatter) {
    newFileContent += `---\n${frontmatter}\n---\n\n`;
  }
  
  if (uniqueImports.length > 0) {
    newFileContent += uniqueImports.join('\n') + '\n\n';
  }
  
  newFileContent += newContent.trim();
  
  // Write the file back
  fs.writeFileSync(filePath, newFileContent);
  console.log(`  ✅ Updated ${filePath}\n`);
}

/**
 * Recursively find all MDX files in a directory
 * @param {string} dir - Directory to search
 * @returns {string[]} Array of file paths
 */
function findMdxFiles(dir) {
  const files = [];
  
  const items = fs.readdirSync(dir);
  
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    
    if (stat.isDirectory()) {
      files.push(...findMdxFiles(fullPath));
    } else if (item.endsWith('.mdx')) {
      files.push(fullPath);
    }
  }
  
  return files;
}

/**
 * Main function to run the migration
 */
function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run') || args.includes('-d');
  
  const guidesDir = path.join(__dirname, 'guides');
  
  if (!fs.existsSync(guidesDir)) {
    console.error('Guides directory not found!');
    process.exit(1);
  }
  
  console.log(`🚀 ${dryRun ? 'Previewing' : 'Starting'} snippet migration...\n`);
  
  const mdxFiles = findMdxFiles(guidesDir);
  console.log(`Found ${mdxFiles.length} MDX files to process\n`);
  
  let processedCount = 0;
  let filesWithSnippets = 0;
  
  for (const file of mdxFiles) {
    try {
      const content = fs.readFileSync(file, 'utf-8');
      const hasSnippets = /<Snippet\s+file="([^"]+)"\s*\/>/g.test(content);
      
      if (hasSnippets) {
        filesWithSnippets++;
        processFile(file, dryRun);
      }
      processedCount++;
    } catch (error) {
      console.error(`❌ Error processing ${file}:`, error.message);
    }
  }
  
  console.log(`\n${dryRun ? '📋 Preview complete!' : '✅ Migration complete!'} Processed ${processedCount}/${mdxFiles.length} files.`);
  console.log(`Found ${filesWithSnippets} files with snippet usage.`);
  
  if (dryRun) {
    console.log('\nTo apply these changes, run: node migrate-snippets.js');
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = { toPascalCase, processFile, findMdxFiles }; 