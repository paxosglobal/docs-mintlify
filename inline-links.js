#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function inlineLinks(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n');
  
  // Find the links block (starts after frontmatter and ends at first empty line)
  let frontmatterEnd = -1;
  let linksStart = -1;
  let linksEnd = -1;
  
  // Find end of frontmatter
  let inFrontmatter = false;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      if (!inFrontmatter) {
        inFrontmatter = true;
      } else {
        frontmatterEnd = i;
        break;
      }
    }
  }
  
  // Find links block after frontmatter
  if (frontmatterEnd !== -1) {
    for (let i = frontmatterEnd + 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line === '') {
        if (linksStart !== -1) {
          linksEnd = i;
          break;
        }
        continue;
      }
      if (line.match(/^\[.+\]:\s*.+$/)) {
        if (linksStart === -1) {
          linksStart = i;
        }
      } else if (linksStart !== -1) {
        linksEnd = i;
        break;
      }
    }
  }
  
  // Extract link definitions
  const linkDefs = {};
  if (linksStart !== -1 && linksEnd !== -1) {
    for (let i = linksStart; i < linksEnd; i++) {
      const line = lines[i].trim();
      const match = line.match(/^\[(.+)\]:\s*(.+)$/);
      if (match) {
        linkDefs[match[1]] = match[2];
      }
    }
  }
  
  // Remove links block
  let processedLines = [];
  if (linksStart !== -1 && linksEnd !== -1) {
    processedLines = [
      ...lines.slice(0, linksStart),
      ...lines.slice(linksEnd)
    ];
  } else {
    processedLines = lines;
  }
  
  // Replace link references with inline links
  const processedContent = processedLines.map(line => {
    return line.replace(/\[([^\]]+)\]\[([^\]]+)\]/g, (match, text, key) => {
      if (linkDefs[key]) {
        return `[${text}](${linkDefs[key]})`;
      }
      return match; // Keep original if no matching definition found
    });
  }).join('\n');
  
  return processedContent;
}

// Command line usage
if (require.main === module) {
  const filePath = process.argv[2];
  
  if (!filePath) {
    console.error('Usage: node inline-links.js <file-path>');
    process.exit(1);
  }
  
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }
  
  try {
    const result = inlineLinks(filePath);
    fs.writeFileSync(filePath, result);
    console.log(`Successfully inlined links in ${filePath}`);
  } catch (error) {
    console.error(`Error processing file: ${error.message}`);
    process.exit(1);
  }
}

module.exports = { inlineLinks };