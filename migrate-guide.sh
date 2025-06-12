#!/bin/bash

# Docusaurus to Mintlify Migration Script
# Usage: ./migrate-guide.sh <source_guide_name> <target_guide_name> [root]
# Example: ./migrate-guide.sh identity identity
# Example: ./migrate-guide.sh developer developer root (for root-level migration)

set -e

# Configuration
SOURCE_BASE="/Users/cameronfleet/dev/docs/content"
TARGET_BASE="/Users/cameronfleet/dev/new-docs"
DOCS_JSON="/Users/cameronfleet/dev/new-docs/docs.json"

# Input validation
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <source_guide_name> <target_guide_name> [root]"
    echo "Example: $0 identity identity"
    echo "Example: $0 developer developer root (for root-level migration)"
    exit 1
fi

SOURCE_GUIDE="$1"
TARGET_GUIDE="$2"
IS_ROOT_MIGRATION="${3:-}"

SOURCE_DIR="$SOURCE_BASE/$SOURCE_GUIDE"

# Set target directory based on whether it's a root migration
if [ "$IS_ROOT_MIGRATION" = "root" ]; then
    TARGET_DIR="$TARGET_BASE"
    echo "🚀 Starting root-level migration: $SOURCE_GUIDE -> root directory"
else
    TARGET_DIR="$TARGET_BASE/guides/$TARGET_GUIDE"
    echo "🚀 Starting migration: $SOURCE_GUIDE -> $TARGET_GUIDE"
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Create target directory if not root migration
if [ "$IS_ROOT_MIGRATION" != "root" ]; then
    mkdir -p "$TARGET_DIR"
fi

# Function to convert frontmatter
convert_frontmatter() {
    local file="$1"
    local temp_file="/tmp/migrate_temp.mdx"
    
    # Extract original frontmatter
    local title=$(grep "^title:" "$file" | sed 's/title: *//' | sed 's/^"//' | sed 's/"$//')
    local description=$(grep "^description:" "$file" | sed 's/description: *//')
    
    # Generate new frontmatter
    echo "---" > "$temp_file"
    echo "title: '$title'" >> "$temp_file"
    if [ -n "$description" ]; then
        echo "description: $description" >> "$temp_file"
    fi
    echo "---" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Extract content after frontmatter (skip lines between --- markers)
    awk '/^---$/{p++} p>=2' "$file" | tail -n +2 >> "$temp_file"
    
    mv "$temp_file" "$file"
}

# Function to clean up Docusaurus-specific content
clean_docusaurus_content() {
    local file="$1"
    
    # Remove Docusaurus imports
    sed -i '' '/^import.*@site/d' "$file"
    sed -i '' '/^import.*@theme/d' "$file"
    
    # Remove NoIndex component
    sed -i '' '/<NoIndex \/>/d' "$file"
    
    # Replace Description component with simple text
    sed -i '' 's/<Description description={frontMatter\.description} \/>//' "$file"
    
    # Convert Docusaurus components to Mintlify equivalents
    # Tabs -> Accordion (approximate)
    sed -i '' 's/<Tabs groupId="[^"]*">//' "$file"
    sed -i '' 's/<\/Tabs>//' "$file"
    sed -i '' 's/<TabItem value="[^"]*" label="\([^"]*\)"[^>]*>/### \1/' "$file"
    sed -i '' 's/<\/TabItem>//' "$file"
    
    # Convert FeatureCard components to simple links
    sed -i '' 's/<FeatureContainer>//' "$file"
    sed -i '' 's/<\/FeatureContainer>//' "$file"
    sed -i '' 's/<FeatureCard[^>]*href="\([^"]*\)"[^>]*title="\([^"]*\)"[^>]*>/[**\2**](\1)/' "$file"
    sed -i '' 's/<\/FeatureCard>//' "$file"
    
    # Remove link reference definitions (safer approach)
    sed -i '' '/^\[[^\]]*\]: /d' "$file"
    
    # Convert Docusaurus admonitions to Mintlify format with proper matching
    # Handle specific admonition types with their proper closing tags
    sed -i '' 's/:::note/<Tip>/g' "$file"
    sed -i '' 's/:::caution/<Warning>/g' "$file"
    sed -i '' 's/:::info/<Info>/g' "$file"
    sed -i '' 's/:::tip/<Tip>/g' "$file"
    sed -i '' 's/:::warning/<Warning>/g' "$file"
    
    # Now handle closing tags - need to be more intelligent about this
    # First mark what we're dealing with by creating temporary markers
    python3 -c "
import re
import sys

def fix_admonitions(content):
    # Track opening tags and match them with proper closing tags
    lines = content.split('\n')
    result_lines = []
    admonition_stack = []
    
    for line in lines:
        # Check for opening admonition tags
        if '<Tip>' in line:
            admonition_stack.append('Tip')
            result_lines.append(line)
        elif '<Warning>' in line:
            admonition_stack.append('Warning')
            result_lines.append(line)
        elif '<Info>' in line:
            admonition_stack.append('Info')
            result_lines.append(line)
        elif line.strip() == ':::':
            # This should close the most recent admonition
            if admonition_stack:
                tag_type = admonition_stack.pop()
                result_lines.append(f'</{tag_type}>')
            else:
                # If no stack, default to closing tip
                result_lines.append('</Tip>')
        else:
            result_lines.append(line)
    
    return '\n'.join(result_lines)

with open('$file', 'r') as f:
    content = f.read()

fixed_content = fix_admonitions(content)

with open('$file', 'w') as f:
    f.write(fixed_content)
"
}

# Function to fix shell variable expressions and other parsing issues
fix_parsing_issues() {
    local file="$1"
    
    # Fix shell variables that cause acorn parsing errors
    sed -i '' 's/\${/\\${/g' "$file"
    
    # Fix anchor/heading ID patterns that cause acorn parsing errors
    sed -i '' 's/ {#[^}]*}//g' "$file"
    
    # Fix specific parsing issues that commonly occur
    sed -i '' 's|// \.\.\.|// ...|g' "$file"
    
    # Fix malformed admonition tags - remove colons from start of tags
    sed -i '' 's/:<Tip>/<Tip>/g' "$file"
    sed -i '' 's/:<Warning>/<Warning>/g' "$file"
    sed -i '' 's/:<Info>/<Info>/g' "$file"
    sed -i '' 's/:<Note>/<Note>/g' "$file"
    
    # Fix quadruple colons to proper closing tags
    sed -i '' '/^::::$/N;s/^::::\n/<\/Tip>/g' "$file"
    sed -i '' 's/^::::$/<\/Tip>/g' "$file"
    
    # Fix malformed tabs - ensure proper closing tags
    # This is a bit tricky - we need to find <Tabs> without closing tags
    python3 -c "
import re

def fix_tabs_and_admonitions(content):
    lines = content.split('\n')
    result_lines = []
    open_tabs = []
    open_admonitions = []
    
    for i, line in enumerate(lines):
        # Track opening tags
        if '<Tabs>' in line:
            open_tabs.append(i)
        elif '</Tabs>' in line and open_tabs:
            open_tabs.pop()
        
        # Track admonitions
        for tag in ['Tip', 'Warning', 'Info', 'Note']:
            if f'<{tag}>' in line:
                open_admonitions.append(tag)
            elif f'</{tag}>' in line and open_admonitions and open_admonitions[-1] == tag:
                open_admonitions.pop()
        
        # Handle quadruple colons - convert to appropriate closing tag
        if line.strip() == '::::':
            if open_admonitions:
                tag = open_admonitions.pop()
                result_lines.append(f'</{tag}>')
            else:
                result_lines.append('</Tip>')  # Default fallback
        else:
            result_lines.append(line)
    
    # Add missing closing tags at the end
    for tag in reversed(open_admonitions):
        result_lines.append(f'</{tag}>')
    
    for _ in open_tabs:
        result_lines.append('</Tabs>')
    
    return '\n'.join(result_lines)

with open('$file', 'r') as f:
    content = f.read()

fixed_content = fix_tabs_and_admonitions(content)

with open('$file', 'w') as f:
    f.write(fixed_content)
"
}

# Function to determine target filename for root migration
get_target_filename() {
    local source_filename="$1"
    
    # Map common developer files to appropriate names for Get Started section
    case "$source_filename" in
        "authenticate.mdx")
            echo "authenticate.mdx"
            ;;
        "sandbox.mdx")
            echo "sandbox.mdx"
            ;;
        "request-signing.mdx")
            echo "request-signing.mdx"
            ;;
        "credentials.mdx")
            echo "credentials.mdx"
            ;;
        *)
            # For other files, keep original name but consider if they belong in developer section
            echo "$source_filename"
            ;;
    esac
}

# Process each .mdx file in source directory
echo "📁 Processing files from $SOURCE_DIR"
for file in "$SOURCE_DIR"/*.mdx; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        
        if [ "$IS_ROOT_MIGRATION" = "root" ]; then
            target_filename=$(get_target_filename "$filename")
            target_file="$TARGET_DIR/$target_filename"
        else
            target_file="$TARGET_DIR/$filename"
        fi
        
        echo "  📄 Processing: $filename -> $(basename "$target_file")"
        
        # Copy file to target
        cp "$file" "$target_file"
        
        # Convert frontmatter
        convert_frontmatter "$target_file"
        
        # Clean up Docusaurus content
        clean_docusaurus_content "$target_file"
        
        # Fix parsing issues (shell variables and other acorn issues)
        fix_parsing_issues "$target_file"
        
        echo "  ✅ Converted: $filename"
    fi
done

# Apply final cleanup across all files to ensure consistency
echo "🔧 Applying final cleanup..."
if [ "$IS_ROOT_MIGRATION" = "root" ]; then
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/\${/\\${/g' {} \;
else
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/\${/\\${/g' {} \;
fi

# Fix the specific JSON pattern that causes acorn errors
# Replace "'"${var}"'" with "`${var}`" then fix the backticks to quotes
python3 << 'EOF'
import os
import re
import glob

def fix_json_patterns(content):
    # Fix the problematic pattern: "'"${var}"'" -> "`${var}`"
    content = re.sub(r'"\'"([^"]*)"\'', r'`\1`', content)
    return content

target_dir = os.environ.get('TARGET_DIR')
is_root = os.environ.get('IS_ROOT_MIGRATION') == 'root'

if is_root:
    # For root migration, only process .mdx files in the root directory
    file_pattern = f"{target_dir}/*.mdx"
else:
    file_pattern = f"{target_dir}/*.mdx"

for file_path in glob.glob(file_pattern):
    with open(file_path, 'r') as f:
        content = f.read()
    
    fixed_content = fix_json_patterns(content)
    
    with open(file_path, 'w') as f:
        f.write(fixed_content)
EOF

# Fix backticks to proper quotes in JSON
if [ "$IS_ROOT_MIGRATION" = "root" ]; then
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/`\\\\\\${/\\"\\\\\\${/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/`"/\\"/g' {} \;
else
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/`\\\\\\${/\\"\\\\\\${/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/`"/\\"/g' {} \;
fi

if [ "$IS_ROOT_MIGRATION" = "root" ]; then
    echo "🎯 Files migrated to root directory: $TARGET_DIR"
else
    echo "🎯 Files migrated to: $TARGET_DIR"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Update docs.json navigation"
echo "2. Review converted files for:"
echo "   - Link references that need manual fixing"
echo "   - Component conversions that need adjustment"
echo "   - Formatting issues"
echo "3. Test the migrated content"
echo ""

if [ "$IS_ROOT_MIGRATION" = "root" ]; then
    echo "📝 Root migration completed. Update the 'Get Started' section in docs.json with:"
    echo "Developer files have been added to the root directory."
    echo "Consider which files should be included in the 'Get Started' navigation."
else
    echo "📝 Suggested docs.json entry:"
    echo "{"
    echo "  \"group\": \"$(echo $TARGET_GUIDE | sed 's/.*/\u&/')\","
    echo "  \"pages\": ["

    # Generate page list for docs.json
    for file in "$TARGET_DIR"/*.mdx; do
        if [ -f "$file" ]; then
            filename=$(basename "$file" .mdx)
            if [ "$filename" = "index" ]; then
                echo "    \"guides/$TARGET_GUIDE/overview\","
            else
                echo "    \"guides/$TARGET_GUIDE/$filename\","
            fi
        fi
    done | sed '$ s/,$//'

    echo "  ]"
    echo "}"
fi 