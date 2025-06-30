#!/bin/bash

# Docusaurus to Mintlify Migration Script
# Usage: 
# - Migrate a directory: ./migrate-guide.sh <source_guide_name> <target_guide_name> [root]
# - Migrate specific files: ./migrate-guide.sh --files <source_file1,source_file2,...> <target_guide_name>
# - Migrate partials: ./migrate-guide.sh --partials
# Examples:
# ./migrate-guide.sh identity identity
# ./migrate-guide.sh developer developer root (for root-level migration)
# ./migrate-guide.sh --files developer/mint.mdx,developer/convert.mdx,developer/redeem.mdx stablecoin-operations
# ./migrate-guide.sh --partials

set -e

# Configuration
SOURCE_BASE="/Users/cameronfleet/dev/paxos-docs/docs/content"
TARGET_BASE="/Users/cameronfleet/dev/paxos-docs/new-docs"
DOCS_JSON="/Users/cameronfleet/dev/paxos-docs/new-docs/docs.json"
SOURCE_IMAGES="/Users/cameronfleet/dev/paxos-docs/docs/static/img"
TARGET_IMAGES="/Users/cameronfleet/dev/paxos-docs/new-docs/images"

# Partials configuration
SOURCE_PARTIALS="/Users/cameronfleet/dev/paxos-docs/docs/_partials"
TARGET_SNIPPETS="/Users/cameronfleet/dev/paxos-docs/new-docs/snippets"

# Parse arguments
if [ "$1" = "--partials" ]; then
    # Partials migration mode
    if [ $# -ne 1 ]; then
        echo "Usage for partials migration: $0 --partials"
        echo "This will migrate the _partials directory to snippets"
        exit 1
    fi
    
    IS_PARTIALS_MIGRATION="true"
    IS_FILE_MIGRATION="false"
    IS_ROOT_MIGRATION="false"
    
    echo "🚀 Starting partials migration to snippets"
elif [ "$1" = "--files" ]; then
    # File-specific migration mode
    if [ $# -ne 3 ]; then
        echo "Usage for file migration: $0 --files <source_file1,source_file2,...> <target_guide_name>"
        echo "Example: $0 --files developer/mint.mdx,developer/convert.mdx,developer/redeem.mdx stablecoin-operations"
        exit 1
    fi
    
    SOURCE_FILES=$(echo "$2" | tr ',' ' ')
    TARGET_GUIDE="$3"
    IS_FILE_MIGRATION="true"
    IS_ROOT_MIGRATION="false"
    IS_PARTIALS_MIGRATION="false"
    
    echo "🚀 Starting file-specific migration to $TARGET_GUIDE"
else
    # Directory migration mode
    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        echo "Usage for directory migration: $0 <source_guide_name> <target_guide_name> [root]"
        echo "Example: $0 identity identity"
        echo "Example: $0 developer developer root (for root-level migration)"
        exit 1
    fi
    
    SOURCE_GUIDE="$1"
    TARGET_GUIDE="$2"
    IS_ROOT_MIGRATION="${3:-}"
    IS_FILE_MIGRATION="false"
    IS_PARTIALS_MIGRATION="false"
    
    SOURCE_DIR="$SOURCE_BASE/$SOURCE_GUIDE"
    
    # Check if source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "❌ Source directory does not exist: $SOURCE_DIR"
        exit 1
    fi
    
    if [ "$IS_ROOT_MIGRATION" = "root" ]; then
        echo "🚀 Starting root-level migration: $SOURCE_GUIDE -> root directory"
    else
        echo "🚀 Starting migration: $SOURCE_GUIDE -> $TARGET_GUIDE"
    fi
fi

# Set target directory based on migration type
if [ "$IS_PARTIALS_MIGRATION" = "true" ]; then
    TARGET_DIR="$TARGET_SNIPPETS"
    mkdir -p "$TARGET_DIR"
elif [ "$IS_ROOT_MIGRATION" = "root" ]; then
    TARGET_DIR="$TARGET_BASE"
else
    TARGET_DIR="$TARGET_BASE/guides/$TARGET_GUIDE"
    mkdir -p "$TARGET_DIR"
fi

# Function to convert frontmatter
convert_frontmatter() {
    local file="$1"
    local temp_file="/tmp/migrate_temp.mdx"
    
    # Check if file starts with frontmatter
    if head -1 "$file" | grep -q "^---$"; then
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
    else
        # File has no frontmatter, keep it as-is (no frontmatter needed for snippets)
        echo "    📝 No frontmatter found, keeping file as-is (suitable for snippets)"
    fi
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
    
    # Convert HTML details elements to Mintlify Accordions
    echo "    🎯 Converting <details> elements to Mintlify Accordions"
    python3 -c "
import re
import sys

def convert_details_to_accordions(content):
    # Pattern to match details elements with summary/h3 structure
    # Handles both single and multiple details in a file
    
    # First, let's identify all details blocks and convert them
    details_pattern = r'<details>\s*<summary>\s*<h3[^>]*id=\"([^\"]*)\">([^<]*)</h3>\s*</summary>\s*<div>(.*?)</div>\s*</details>'
    
    matches = list(re.finditer(details_pattern, content, re.DOTALL))
    
    if not matches:
        return content
    
    # If we have multiple details elements, we should group them
    if len(matches) > 1:
        # Check if they are consecutive (part of a FAQ section)
        consecutive_groups = []
        current_group = [matches[0]]
        
        for i in range(1, len(matches)):
            # Calculate the gap between end of previous match and start of current
            prev_end = matches[i-1].end()
            curr_start = matches[i].start()
            gap_content = content[prev_end:curr_start].strip()
            
            # If there's minimal content between them (just whitespace), consider them consecutive
            if len(gap_content) <= 10:  # Allow for some whitespace/newlines
                current_group.append(matches[i])
            else:
                # End current group, start new one
                consecutive_groups.append(current_group)
                current_group = [matches[i]]
        
        # Add the last group
        consecutive_groups.append(current_group)
        
        # Process each group
        new_content = content
        offset = 0  # Track position changes as we modify content
        
        for group in consecutive_groups:
            if len(group) > 1:
                # Multiple accordions - wrap in AccordionGroup
                first_match = group[0]
                last_match = group[-1]
                
                # Get the content from start of first to end of last
                group_start = first_match.start() + offset
                group_end = last_match.end() + offset
                group_content = new_content[group_start:group_end]
                
                # Convert each details in the group to accordion
                accordion_content = []
                for match in group:
                    anchor_id = match.group(1)
                    title = match.group(2).strip()
                    body_content = match.group(3).strip()
                    
                    accordion = f'<Accordion title=\"{title}\" id=\"{anchor_id}\">\n\n{body_content}\n\n</Accordion>'
                    accordion_content.append(accordion)
                
                # Wrap in AccordionGroup
                replacement = f'<AccordionGroup>\n\n' + '\n\n'.join(accordion_content) + f'\n\n</AccordionGroup>'
                
                # Replace the group content
                new_content = new_content[:group_start] + replacement + new_content[group_end:]
                
                # Update offset
                offset += len(replacement) - (group_end - group_start)
            else:
                # Single accordion - no group needed
                match = group[0]
                anchor_id = match.group(1)
                title = match.group(2).strip()
                body_content = match.group(3).strip()
                
                replacement = f'<Accordion title=\"{title}\" id=\"{anchor_id}\">\n\n{body_content}\n\n</Accordion>'
                
                match_start = match.start() + offset
                match_end = match.end() + offset
                
                new_content = new_content[:match_start] + replacement + new_content[match_end:]
                offset += len(replacement) - (match_end - match_start)
        
        return new_content
    else:
        # Single details element
        match = matches[0]
        anchor_id = match.group(1)
        title = match.group(2).strip()
        body_content = match.group(3).strip()
        
        replacement = f'<Accordion title=\"{title}\" id=\"{anchor_id}\">\n\n{body_content}\n\n</Accordion>'
        
        return content[:match.start()] + replacement + content[match.end():]

with open('$file', 'r') as f:
    content = f.read()

converted_content = convert_details_to_accordions(content)

with open('$file', 'w') as f:
    f.write(converted_content)
"
    
    # Convert Docusaurus components to Mintlify equivalents
    # Tabs -> Accordion (approximate)
    sed -E -i '' 's/<Tabs[^>]*>//g' "$file"
    sed -i '' 's/<\/Tabs>//g' "$file"
    sed -E -i '' 's/<TabItem[^>]*label="([^"]*)"[^>]*>/### \1\n\n/g' "$file"
    sed -i '' 's/<\/TabItem>//g' "$file"
    
    # Convert FeatureContainer to CardGroup
    sed -i '' 's/<FeatureContainer>/<CardGroup cols={2}>/g' "$file"
    sed -i '' 's/<\/FeatureContainer>/<\/CardGroup>/g' "$file"
    
    # Convert FeatureCard to Card - using a more robust approach
    # First, let's use a Python script to handle the complex multi-line conversion
    python3 -c "
import re

def convert_feature_cards(content):
    # Pattern to match FeatureCard tags including multi-line attributes
    # This handles cases where attributes span multiple lines
    pattern = r'<FeatureCard([^>]*)>(.*?)<\/FeatureCard>'
    
    def replace_feature_card(match):
        attributes = match.group(1)
        content = match.group(2)
        
        # Extract href and title, ignore imgURL
        href_match = re.search(r'href=\"([^\"]+)\"', attributes)
        title_match = re.search(r'title=\"([^\"]+)\"', attributes)
        
        href = href_match.group(1) if href_match else ''
        title = title_match.group(1) if title_match else ''
        
        # Build the Card tag
        card_attrs = []
        if title:
            card_attrs.append(f'title=\"{title}\"')
        if href:
            card_attrs.append(f'href=\"{href}\"')
        
        attrs_str = ' ' + ' '.join(card_attrs) if card_attrs else ''
        
        return f'<Card{attrs_str}>{content}</Card>'
    
    # Use DOTALL flag to handle multi-line matches
    return re.sub(pattern, replace_feature_card, content, flags=re.DOTALL)

with open('$file', 'r') as f:
    content = f.read()

content = convert_feature_cards(content)

with open('$file', 'w') as f:
    f.write(content)
"
    
    # Convert <Image /> tags to Markdown images
    # Basic conversion: <Image src="SRC" alt="ALT" ... /> -> ![ALT](SRC)
    sed -E -i '' 's/<Image[^>]*src="([^"]*)"[^>]*alt="([^"]*)"[^>]*\/>/![\2](\1)/g' "$file"
    # Fallback when alt is missing: <Image src="SRC" ... /> -> ![](SRC)
    sed -E -i '' 's/<Image[^>]*src="([^"]*)"[^>]*\/>/![](\1)/g' "$file"
    
    # Convert Docusaurus admonitions to Mintlify format with proper matching
    # Handle specific admonition types with their proper closing tags
    sed -i '' 's/:::note/<Tip>/g' "$file"
    sed -i '' 's/:::caution/<Warning>/g' "$file"
    sed -i '' 's/:::info/<Info>/g' "$file"
    sed -i '' 's/:::tip/<Tip>/g' "$file"
    sed -i '' 's/:::warning/<Warning>/g' "$file"
    
    # Ensure admonitions have proper newlines after opening tag
    sed -E -i '' 's/<(Tip|Warning|Info|Note)>([^\n])/\<\1\>\n\n\2/g' "$file"
    
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
        elif '<Note>' in line:
            admonition_stack.append('Note')
            result_lines.append(line)
        elif line.strip() == ':::' or line.strip() == '::::':
            # This should close the most recent admonition
            if admonition_stack:
                tag_type = admonition_stack.pop()
                result_lines.append(f'</{tag_type}>')
            else:
                # If no stack, default to closing tip
                result_lines.append('</Tip>')
        else:
            result_lines.append(line)
    
    # Add missing closing tags at the end for any unclosed admonitions
    for tag_type in reversed(admonition_stack):
        result_lines.append(f'</{tag_type}>')
    
    return '\n'.join(result_lines)

with open('$file', 'r') as f:
    content = f.read()

fixed_content = fix_admonitions(content)

with open('$file', 'w') as f:
    f.write(fixed_content)
"

    # Fix specific admonition formatting issues - ensure proper spacing and closing tags
    # For <Tip> Best Practice pattern, ensure proper formatting
    sed -E -i '' 's/<(Tip|Warning|Info|Note)>[ ]*([A-Za-z])/\<\1\>\n\n\2/g' "$file"
    
    # Check for any unclosed admonition tags at the end of the file and close them
    python3 -c "
import re

def ensure_closed_admonitions(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find all opening and closing admonition tags
    open_tags = re.findall(r'<(Tip|Warning|Info|Note)>', content)
    close_tags = re.findall(r'</(Tip|Warning|Info|Note)>', content)
    
    # If there are more opening than closing tags, add closing tags
    if len(open_tags) > len(close_tags):
        for _ in range(len(open_tags) - len(close_tags)):
            # Use the last opened tag type
            content += f'\n\n</{open_tags[-1]}>'
    
    with open(file_path, 'w') as f:
        f.write(content)

ensure_closed_admonitions('$file')
"
}

# Function to convert internal guide links to new Mintlify structure
convert_internal_links() {
    local file="$1"
    
    # COMMENTED OUT: Preserve original Docusaurus links for backwards compatibility
    # The physical files will be in /guides/ but links will remain as /guide-name/
    # This allows setting up redirects in Mintlify configuration
    
    # Convert internal guide links from Docusaurus to Mintlify format
    # Pattern: /guide-name/page-name -> /guides/guide-name/page-name
    
    # Common guide conversions - COMMENTED OUT TO PRESERVE ORIGINAL LINKS
    # sed -i '' 's|href="/identity/|href="/guides/identity/|g' "$file"
    # sed -i '' 's|](/identity/|](guides/identity/|g' "$file"
    # sed -i '' 's|href="/developer/|href="/guides/developer/|g' "$file"
    # sed -i '' 's|](developer/|](guides/developer/|g' "$file"
    # sed -i '' 's|href="/stablecoin-operations/|href="/guides/stablecoin-operations/|g' "$file"
    # sed -i '' 's|](stablecoin-operations/|](guides/stablecoin-operations/|g' "$file"
    # sed -i '' 's|href="/webhooks/|href="/guides/webhooks/|g' "$file"
    # sed -i '' 's|](webhooks/|](guides/webhooks/|g' "$file"
    # sed -i '' 's|href="/transfers/|href="/guides/transfers/|g' "$file"
    # sed -i '' 's|](transfers/|](guides/transfers/|g' "$file"
    # sed -i '' 's|href="/profiles/|href="/guides/profiles/|g' "$file"
    # sed -i '' 's|](profiles/|](guides/profiles/|g' "$file"
    # sed -i '' 's|href="/accounts/|href="/guides/accounts/|g' "$file"
    # sed -i '' 's|](accounts/|](guides/accounts/|g' "$file"
    # sed -i '' 's|href="/orders/|href="/guides/orders/|g' "$file"
    # sed -i '' 's|](orders/|](guides/orders/|g' "$file"
    
    # Handle Card href attributes specifically - COMMENTED OUT
    # sed -E -i '' 's|href="/([a-zA-Z0-9-]+)/([a-zA-Z0-9-]+)"|href="/guides/\1/\2"|g' "$file"
    
    # Generic pattern for any remaining internal guide links - COMMENTED OUT
    # This catches patterns like /guide-name/page-name that weren't handled above
    # python3 -c "
# import re

# def convert_remaining_links(content):
#     # Pattern to match internal links that start with / and have guide structure
#     # but avoid API links, images, and other non-guide links
    
#     def convert_link(match):
#         full_match = match.group(0)
#         link_part = match.group(1)
        
#         # Skip if it's already converted, an API link, image, or other special path
#         if (link_part.startswith('guides/') or 
#             link_part.startswith('api-reference/') or 
#             link_part.startswith('images/') or 
#             link_part.startswith('img/') or
#             link_part.startswith('api/') or
#             '.' in link_part.split('/')[-1]):  # Has file extension
#             return full_match
        
#         # Check if it looks like a guide link (has at least guide/page structure)
#         parts = link_part.split('/')
#         if len(parts) >= 2 and parts[0] and parts[1]:
#             # Convert to /guides/ structure (preserve leading slash)
#             return full_match.replace(f'/{link_part}', f'/guides/{link_part}')
        
#         return full_match
    
#     # Match both href and markdown link patterns
#     content = re.sub(r'href=\"(/[a-zA-Z0-9][a-zA-Z0-9-]*(?:/[a-zA-Z0-9][a-zA-Z0-9-]*)*)\"', convert_link, content)
#     content = re.sub(r'\]\((/[a-zA-Z0-9][a-zA-Z0-9-]*(?:/[a-zA-Z0-9][a-zA-Z0-9-]*)*)\)', convert_link, content)
    
#     return content

# with open('$file', 'r') as f:
#     content = f.read()

# content = convert_remaining_links(content)

# with open('$file', 'w') as f:
#     f.write(content)
# "

    echo "    🔗 Preserving original link format for backwards compatibility"
}

# Function to convert partial references to snippet syntax
convert_partial_references() {
    local file="$1"
    
    echo "    🧩 Converting partial references to snippets"
    
    # Use Python to handle the complex conversion of imports and component usage
    python3 -c "
import re
import os

def convert_partials_to_snippets(content):
    # Dictionary to track imported partials and their component names
    imported_partials = {}
    
    # Pattern to match import statements for partials
    # Examples:
    # import SomePartial from '../_partials/some-partial.mdx';
    # import SomePartial from '@site/content/_partials/some-partial.mdx';
    # import { SomePartial } from '../_partials/some-partial.mdx';
    
    import_patterns = [
        # Default import: import SomePartial from '../_partials/file.mdx'
        r'import\s+(\w+)\s+from\s+[\'\"](\.\.\/)*_partials\/([^\'\"]+)\.mdx[\'\"]\s*;?',
        # Default import: import SomePartial from '@site/content/_partials/file.mdx'
        r'import\s+(\w+)\s+from\s+[\'\"]\@site\/content\/_partials\/([^\'\"]+)\.mdx[\'\"]\s*;?',
        # Named import: import { SomePartial } from '../_partials/file.mdx'
        r'import\s*\{\s*(\w+)\s*\}\s*from\s+[\'\"](\.\.\/)*_partials\/([^\'\"]+)\.mdx[\'\"]\s*;?',
        # Named import: import { SomePartial } from '@site/content/_partials/file.mdx'
        r'import\s*\{\s*(\w+)\s*\}\s*from\s+[\'\"]\@site\/content\/_partials\/([^\'\"]+)\.mdx[\'\"]\s*;?',
    ]
    
    lines = content.split('\n')
    new_lines = []
    
    for line in lines:
        line_modified = False
        
        # Check each import pattern
        for pattern in import_patterns:
            match = re.search(pattern, line)
            if match:
                component_name = match.group(1)
                if len(match.groups()) == 3:
                    # Pattern with relative path (group 2 is path prefix, group 3 is filename)
                    filename = match.group(3)
                else:
                    # Pattern with @site path (group 2 is filename)
                    filename = match.group(2)
                
                # Store the mapping
                imported_partials[component_name] = filename
                
                # Remove the import line
                line_modified = True
                break
        
        if not line_modified:
            new_lines.append(line)
    
    # Now convert component usage to snippet syntax
    content = '\n'.join(new_lines)
    
    for component_name, filename in imported_partials.items():
        # Convert component usage to snippet syntax
        # <ComponentName /> -> <Snippet file=\"filename\" />
        # <ComponentName> -> <Snippet file=\"filename\">
        # Handle both self-closing and opening tags
        
        # Self-closing tags
        content = re.sub(
            f'<{component_name}\\s*\/>',
            f'<Snippet file=\"{filename}\" />',
            content
        )
        
        # Opening tags (rare for partials, but just in case)
        content = re.sub(
            f'<{component_name}\\s*>',
            f'<Snippet file=\"{filename}\">',
            content
        )
        
        # Closing tags
        content = re.sub(
            f'<\/{component_name}>',
            f'</Snippet>',
            content
        )
        
        # Handle cases with props (attributes)
        # <ComponentName prop=\"value\" /> -> <Snippet file=\"filename\" />
        content = re.sub(
            f'<{component_name}\\s+[^>]*\/>',
            f'<Snippet file=\"{filename}\" />',
            content
        )
    
    return content

with open('$file', 'r') as f:
    content = f.read()

converted_content = convert_partials_to_snippets(content)

with open('$file', 'w') as f:
    f.write(converted_content)
"

    # Also handle any remaining generic partial imports that might not match the patterns above
    # Remove any remaining import lines that reference _partials
    sed -i '' '/^import.*_partials.*\.mdx/d' "$file"
    
    # Clean up any empty lines left by removed imports
    sed -i '' '/^$/N;/^\n$/d' "$file"
}

# Function to fix shell variable expressions and other parsing issues
fix_parsing_issues() {
    local file="$1"
    
    # Fix shell variables that cause acorn parsing errors - double escape the $
    sed -i '' 's/\${/\\\\${/g' "$file"
    
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
    
    # Fix code comments that cause parsing errors
    sed -i '' 's|// highlight-next-line|{/* highlight-next-line */}|g' "$file"
    sed -i '' 's|// highlight-start|{/* highlight-start */}|g' "$file"
    sed -i '' 's|// highlight-end|{/* highlight-end */}|g' "$file"
    
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

    # Fix malformed admonition closing tags (e.g., </\Tip> to </Tip>)
    sed -i '' 's/<\/\\\\Tip>/<\/Tip>/g' "$file"
    sed -i '' 's/<\/\\Tip>/<\/Tip>/g' "$file"
    sed -i '' 's/<\/\\Warning>/<\/Warning>/g' "$file"
    sed -i '' 's/<\/\\Info>/<\/Info>/g' "$file"
    sed -i '' 's/<\/\\Note>/<\/Note>/g' "$file"
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

# Function to migrate images
migrate_images() {
    local file="$1"
    
    # Find all image references in the file (both src="/img/ and markdown ![](...)
    grep -o 'src="/img/[^"]*"' "$file" 2>/dev/null | while read -r img_ref; do
        # Extract the image filename from the reference
        img_path=$(echo "$img_ref" | sed 's/src="\/img\///' | sed 's/"//')
        source_img="$SOURCE_IMAGES/$img_path"
        target_img="$TARGET_IMAGES/$img_path"
        
        # Copy image if it exists and hasn't been copied already
        if [ -f "$source_img" ] && [ ! -f "$target_img" ]; then
            echo "    📸 Copying image: $img_path"
            mkdir -p "$(dirname "$target_img")"
            cp "$source_img" "$target_img"
        fi
    done
    
    # Also find markdown images that might reference /img/
    grep -o '!\[[^]]*\](/img/[^)]*' "$file" 2>/dev/null | while read -r img_ref; do
        # Extract the image filename from the markdown reference
        img_path=$(echo "$img_ref" | sed 's/.*\/img\///' | sed 's/)$//')
        source_img="$SOURCE_IMAGES/$img_path"
        target_img="$TARGET_IMAGES/$img_path"
        
        # Copy image if it exists and hasn't been copied already
        if [ -f "$source_img" ] && [ ! -f "$target_img" ]; then
            echo "    📸 Copying image: $img_path"
            mkdir -p "$(dirname "$target_img")"
            cp "$source_img" "$target_img"
        fi
    done
    
    # Update image references from /img/ to /images/ (Mintlify format)
    sed -i '' 's|src="/img/|src="/images/|g' "$file"
    sed -i '' 's|](/img/|](/images/|g' "$file"
    sed -i '' 's|](img/|](images/|g' "$file"
    
    # Also handle any remaining <Image /> or <ImageNoBorder /> components
    sed -E -i '' 's|<Image[^>]*src="/images/([^"]*)"[^>]*alt="([^"]*)"[^>]*/>|![\2](/images/\1)|g' "$file"
    sed -E -i '' 's|<ImageNoBorder[^>]*src="/images/([^"]*)"[^>]*alt="([^"]*)"[^>]*/>|![\2](/images/\1)|g' "$file"
    
    # Handle Image components with additional attributes (align, width, etc.)
    sed -E -i '' 's|<Image[^>]*src="/images/([^"]*)"[^>]*/>|![](/images/\1)|g' "$file"
    sed -E -i '' 's|<ImageNoBorder[^>]*src="/images/([^"]*)"[^>]*/>|![](/images/\1)|g' "$file"
}

# Function to convert API references
convert_api_references() {
    local file="$1"
    
    # Convert API reference links to new Mintlify format using a comprehensive approach
    echo "    🔗 Converting API references to Mintlify format"
    
    # Use Python for more robust regex handling
    python3 -c "
import re
import sys

def convert_api_references(content):
    # Function to convert CamelCase to kebab-case
    def camel_to_kebab(name):
        # First normalize any existing hyphens and underscores
        name = name.replace('_', '-')
        
        # Insert hyphens before capital letters (except the first one)
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1-\2', name)
        # Insert hyphens before capital letters that are followed by lowercase letters
        s2 = re.sub('([a-z0-9])([A-Z])', r'\1-\2', s1)
        
        # Convert to lowercase
        result = s2.lower()
        
        # Clean up any double hyphens that might have been created
        result = re.sub('-+', '-', result)
        
        # Remove leading/trailing hyphens
        result = result.strip('-')
        
        return result
    
    def convert_api_link(match):
        full_url = match.group(0)
        tag = match.group(1) if match.group(1) else ''
        operation = match.group(2) if len(match.groups()) >= 2 and match.group(2) else ''
        
        # Convert tag to kebab-case and lowercase
        if tag:
            tag_converted = camel_to_kebab(tag)
        else:
            tag_converted = ''
        
        # Convert operation to kebab-case and lowercase
        if operation:
            operation_converted = camel_to_kebab(operation)
            return f'/api-reference/{tag_converted}/{operation_converted}'
        else:
            return f'/api-reference/{tag_converted}'
    
    # Pattern 1: /api/v2#tag/TagName/operation/OperationName
    pattern1 = r'/api/v2#tag/([^/]+)/operation/([^)\s\]]+)'
    content = re.sub(pattern1, convert_api_link, content)
    
    # Pattern 2: /api/v2#tag/TagName (without operation)
    pattern2 = r'/api/v2#tag/([^)\s\]#]+)'
    content = re.sub(pattern2, convert_api_link, content)
    
    # Fix any remaining malformed /api-reference/ links
    # Pattern: /api-reference/tag-nameOperationName -> /api-reference/tag-name/operation-name
    def fix_malformed_links(match):
        full_path = match.group(1)
        
        # Look for pattern where tag and operation are concatenated
        # Split on first capital letter that's not at the start
        parts = re.split(r'(?<!^)(?=[A-Z][a-z])', full_path)
        if len(parts) >= 2:
            tag_part = parts[0]
            operation_part = ''.join(parts[1:])
            
            # Convert both to kebab-case
            tag_converted = camel_to_kebab(tag_part)
            operation_converted = camel_to_kebab(operation_part)
            
            return f'/api-reference/{tag_converted}/{operation_converted}'
        else:
            # Just convert to kebab-case
            return f'/api-reference/{camel_to_kebab(full_path)}'
    
    # Fix malformed concatenated links like /api-reference/deposit-addressesCreateDepositAddress
    malformed_pattern = r'/api-reference/([a-z-]+[A-Z][a-zA-Z]*)'
    content = re.sub(malformed_pattern, fix_malformed_links, content)
    
    # Clean up any remaining /operation/ fragments in URLs
    content = re.sub(r'/api-reference/([^/]+)/operation/([^)\s\]]+)', r'/api-reference/\1/\2', content)
    
    # Ensure all API reference URLs use lowercase and kebab-case
    def ensure_kebab_case(match):
        path = match.group(1)
        # Split path and convert each segment
        segments = path.split('/')
        converted_segments = [camel_to_kebab(segment) for segment in segments]
        return '/api-reference/' + '/'.join(converted_segments)
    
    # Apply final kebab-case conversion to any remaining mixed-case API references
    mixed_case_pattern = r'/api-reference/([^)\s\]]*[A-Z][^)\s\]]*)'
    content = re.sub(mixed_case_pattern, ensure_kebab_case, content)
    
    return content

with open('$file', 'r') as f:
    content = f.read()

converted_content = convert_api_references(content)

with open('$file', 'w') as f:
    f.write(converted_content)
"
}

# Process files based on migration mode
if [ "$IS_PARTIALS_MIGRATION" = "true" ]; then
    # Process partials from the root _partials directory
    echo "📁 Processing partials from _partials directory"
    
    # Function to process partials from a directory
    process_partials_directory() {
        local source_partials_dir="$1"
        local dir_name="$2"
        
        if [ ! -d "$source_partials_dir" ]; then
            echo "⚠️  Partials directory does not exist: $source_partials_dir"
            return
        fi
        
        echo "  📂 Processing partials from: $source_partials_dir"
        
        # Find all .mdx files in the partials directory
        find "$source_partials_dir" -name "*.mdx" -type f | while read -r file; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                
                # Create target file path
                target_file="$TARGET_DIR/$filename"
                
                echo "    📄 Processing: $filename"
                
                # Copy file to target
                cp "$file" "$target_file"
                
                # Convert frontmatter
                convert_frontmatter "$target_file"
                
                # Clean up Docusaurus content
                clean_docusaurus_content "$target_file"
                
                # Migrate images
                migrate_images "$target_file"
                
                # Convert API references
                convert_api_references "$target_file"
                
                # Fix parsing issues
                fix_parsing_issues "$target_file"
                
                # Convert internal guide links
                convert_internal_links "$target_file"
                
                # Convert partial references
                convert_partial_references "$target_file"
                
                echo "    ✅ Converted: $filename"
            fi
        done
    }
    
    # Process the root partials directory
    process_partials_directory "$SOURCE_PARTIALS" "_partials"
    
elif [ "$IS_FILE_MIGRATION" = "true" ]; then
    # Process specific files
    echo "📁 Processing specific files"
    
    for file_path in $SOURCE_FILES; do
        # Construct full source path
        source_file="$SOURCE_BASE/$file_path"
        
        if [ ! -f "$source_file" ]; then
            echo "❌ Source file does not exist: $source_file"
            continue
        fi
        
        # Extract filename without path
        filename=$(basename "$file_path")
        
        # Create target file path
        target_file="$TARGET_DIR/$filename"
        
        echo "  📄 Processing: $file_path -> $(basename "$target_file")"
        
        # Copy file to target
        cp "$source_file" "$target_file"
        
        # Convert frontmatter
        convert_frontmatter "$target_file"
        
        # Clean up Docusaurus content
        clean_docusaurus_content "$target_file"
        
        # Migrate images
        migrate_images "$target_file"
        
        # Convert API references
        convert_api_references "$target_file"
        
        # Fix parsing issues
        fix_parsing_issues "$target_file"
        
        # Convert internal guide links
        convert_internal_links "$target_file"
        
        # Convert partial references
        convert_partial_references "$target_file"
        
        echo "  ✅ Converted: $filename"
    done
else
    # Process all files in directory recursively
    echo "📁 Processing files recursively from $SOURCE_DIR"
    
    # Use find to recursively locate all .mdx files
    find "$SOURCE_DIR" -name "*.mdx" -type f | while read -r file; do
        if [ -f "$file" ]; then
            # Get relative path from source directory
            relative_path="${file#$SOURCE_DIR/}"
            filename=$(basename "$file")
            
            # Create target directory structure if needed
            target_subdir=$(dirname "$relative_path")
            if [ "$target_subdir" != "." ]; then
                mkdir -p "$TARGET_DIR/$target_subdir"
                target_file="$TARGET_DIR/$relative_path"
            else
                target_file="$TARGET_DIR/$filename"
            fi
            
            if [ "$IS_ROOT_MIGRATION" = "root" ]; then
                target_filename=$(get_target_filename "$filename")
                target_file="$TARGET_DIR/$target_filename"
            fi
            
            echo "  📄 Processing: $relative_path -> ${target_file#$TARGET_DIR/}"
            
            # Copy file to target
            cp "$file" "$target_file"
            
            # Convert frontmatter
            convert_frontmatter "$target_file"
            
            # Clean up Docusaurus content
            clean_docusaurus_content "$target_file"
            
            # Migrate images
            migrate_images "$target_file"
            
            # Convert API references
            convert_api_references "$target_file"
            
            # Fix parsing issues
            fix_parsing_issues "$target_file"
            
            # Convert internal guide links
            convert_internal_links "$target_file"
            
            # Convert partial references
            convert_partial_references "$target_file"
            
            echo "  ✅ Converted: $relative_path"
        fi
    done
fi

# Apply final cleanup across all files to ensure consistency
echo "🔧 Applying final cleanup..."
if [ "$IS_PARTIALS_MIGRATION" = "true" ]; then
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/\${/\\\\${/g' {} \;
elif [ "$IS_ROOT_MIGRATION" = "root" ]; then
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/\${/\\\\${/g' {} \;
else
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/\${/\\\\${/g' {} \;
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
is_partials = os.environ.get('IS_PARTIALS_MIGRATION') == 'true'

if is_partials:
    # For partials migration, process all .mdx files in snippets directory
    file_pattern = f"{target_dir}/*.mdx"
elif is_root:
    # For root migration, only process .mdx files in the root directory
    file_pattern = f"{target_dir}/*.mdx"
else:
    # For nested migration, process all .mdx files recursively
    file_pattern = f"{target_dir}/**/*.mdx"

for file_path in glob.glob(file_pattern, recursive=True):
    if os.path.isfile(file_path):
        with open(file_path, 'r') as f:
            content = f.read()
        
        fixed_content = fix_json_patterns(content)
        
        with open(file_path, 'w') as f:
            f.write(fixed_content)
EOF

# Fix backticks to proper quotes in JSON
if [ "$IS_PARTIALS_MIGRATION" = "true" ]; then
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/`\\\\\\${/\\"\\\\\\${/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/`"/\\"/g' {} \;
elif [ "$IS_ROOT_MIGRATION" = "root" ]; then
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/`\\\\\\${/\\"\\\\\\${/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/`"/\\"/g' {} \;
else
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/`\\\\\\${/\\"\\\\\\${/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/`"/\\"/g' {} \;
fi

# Additional fixes for specific parsing errors
if [ "$IS_PARTIALS_MIGRATION" = "true" ]; then
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Tip>/<\/Tip>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Warning>/<\/Warning>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Info>/<\/Info>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Note>/<\/Note>/g' {} \;
elif [ "$IS_ROOT_MIGRATION" = "root" ]; then
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/<\/\\Tip>/<\/Tip>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/<\/\\Warning>/<\/Warning>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/<\/\\Info>/<\/Info>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/<\/\\Note>/<\/Note>/g' {} \;
else
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Tip>/<\/Tip>/g' {} \;
    find "$TARGET_DIR" -exec sed -i '' 's/<\/\\Warning>/<\/Warning>/g' {} \;
    find "$TARGET_DIR" -exec sed -i '' 's/<\/\\Info>/<\/Info>/g' {} \;
    find "$TARGET_DIR" -exec sed -i '' 's/<\/\\Note>/<\/Note>/g' {} \;
fi

if [ "$IS_PARTIALS_MIGRATION" = "true" ]; then
    echo "🎯 Partials migrated to snippets: $TARGET_DIR"
elif [ "$IS_FILE_MIGRATION" = "true" ]; then
    echo "🎯 Specific files migrated to: $TARGET_DIR"
elif [ "$IS_ROOT_MIGRATION" = "root" ]; then
    echo "🎯 Files migrated to root directory: $TARGET_DIR"
else
    echo "🎯 Files migrated to: $TARGET_DIR"
fi

echo ""
echo "📋 Next Steps:"
if [ "$IS_PARTIALS_MIGRATION" = "true" ]; then
    echo "1. Review converted snippets for:"
    echo "   - Content that should be reusable across pages"
    echo "   - Component conversions that need adjustment"
    echo "   - Formatting issues"
    echo "   - Link references that need manual fixing"
    echo "2. Update pages to reference snippets using <Snippet file=\"filename\" />"
    echo "3. Test snippet usage in documentation"
else
    echo "1. Update docs.json navigation"
    echo "2. Review converted files for:"
    echo "   - Link references that need manual fixing"
    echo "   - Component conversions that need adjustment"
    echo "   - Formatting issues"
    echo "   - Image references (now using @images/)"
    echo "   - API references (now using /api-reference/)"
    echo "3. Test the migrated content"
fi
echo ""

if [ "$IS_PARTIALS_MIGRATION" = "true" ]; then
    echo "📝 Snippets migrated successfully!"
    echo "All .mdx files from the _partials directory have been converted to snippets."
    echo "Use <Snippet file=\"filename\" /> to include them in your documentation."
elif [ "$IS_FILE_MIGRATION" = "true" ]; then
    echo "📝 Specific files migrated. Update the '$TARGET_GUIDE' section in docs.json with:"
    echo "{"
    echo "  \"group\": \"$(echo $TARGET_GUIDE | sed 's/.*/\u&/')\","
    echo "  \"pages\": ["
    
    # Generate page list for docs.json for migrated files
    for file_path in $SOURCE_FILES; do
        filename=$(basename "$file_path" .mdx)
        echo "    \"guides/$TARGET_GUIDE/$filename\","
    done | sed '$ s/,$//'
    
    echo "  ]"
    echo "}"
elif [ "$IS_ROOT_MIGRATION" = "root" ]; then
    echo "📝 Root migration completed. Update the 'Get Started' section in docs.json with:"
    echo "Developer files have been added to the root directory."
    echo "Consider which files should be included in the 'Get Started' navigation."
else
    echo "📝 Suggested docs.json entry:"
    echo "{"
    echo "  \"group\": \"$(echo $TARGET_GUIDE | sed 's/.*/\u&/')\","
    echo "  \"pages\": ["

    # Generate page list for docs.json recursively
    find "$TARGET_DIR" -name "*.mdx" -type f | while read -r file; do
        if [ -f "$file" ]; then
            # Get relative path from target directory
            relative_path="${file#$TARGET_DIR/}"
            filename_no_ext="${relative_path%.mdx}"
            
            if [ "$filename_no_ext" = "index" ]; then
                echo "    \"guides/$TARGET_GUIDE/overview\","
            else
                echo "    \"guides/$TARGET_GUIDE/$filename_no_ext\","
            fi
        fi
    done | sed '$ s/,$//'

    echo "  ]"
    echo "}"
fi 