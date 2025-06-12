#!/bin/bash

# Docusaurus to Mintlify Migration Script
# Usage: 
# - Migrate a directory: ./migrate-guide.sh <source_guide_name> <target_guide_name> [root]
# - Migrate specific files: ./migrate-guide.sh --files <source_file1,source_file2,...> <target_guide_name>
# Examples:
# ./migrate-guide.sh identity identity
# ./migrate-guide.sh developer developer root (for root-level migration)
# ./migrate-guide.sh --files developer/mint.mdx,developer/convert.mdx,developer/redeem.mdx stablecoin-operations

set -e

# Configuration
SOURCE_BASE="/Users/cameronfleet/dev/docs/content"
TARGET_BASE="/Users/cameronfleet/dev/new-docs"
DOCS_JSON="/Users/cameronfleet/dev/new-docs/docs.json"
SOURCE_IMAGES="/Users/cameronfleet/dev/docs/static/img"
TARGET_IMAGES="/Users/cameronfleet/dev/new-docs/images"

# Parse arguments
if [ "$1" = "--files" ]; then
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

# Set target directory based on whether it's a root migration
if [ "$IS_ROOT_MIGRATION" = "root" ]; then
    TARGET_DIR="$TARGET_BASE"
else
    TARGET_DIR="$TARGET_BASE/guides/$TARGET_GUIDE"
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
    sed -E -i '' 's/<Tabs[^>]*>//g' "$file"
    sed -i '' 's/<\/Tabs>//g' "$file"
    sed -E -i '' 's/<TabItem[^>]*label="([^"]*)"[^>]*>/### \1\n\n/g' "$file"
    sed -i '' 's/<\/TabItem>//g' "$file"
    
    # Convert FeatureContainer to CardGroup
    sed -i '' 's/<FeatureContainer>/<CardGroup cols={2}>/g' "$file"
    sed -i '' 's/<\/FeatureContainer>/<\/CardGroup>/g' "$file"
    
    # Convert FeatureCard to Card (more sophisticated conversion)
    # Handle FeatureCard with href and title attributes
    sed -E -i '' 's/<FeatureCard[^>]*href="([^"]*)"[^>]*title="([^"]*)"[^>]*>/<Card title="\2" href="\1">/g' "$file"
    sed -i '' 's/<\/FeatureCard>/<\/Card>/g' "$file"
    
    # Handle FeatureCard with only title
    sed -E -i '' 's/<FeatureCard[^>]*title="([^"]*)"[^>]*>/<Card title="\1">/g' "$file"
    
    # Handle basic FeatureCard without attributes
    sed -i '' 's/<FeatureCard>/<Card>/g' "$file"
    
    # Convert <Image /> tags to Markdown images
    # Basic conversion: <Image src="SRC" alt="ALT" ... /> -> ![ALT](SRC)
    sed -E -i '' 's/<Image[^>]*src="([^"]*)"[^>]*alt="([^"]*)"[^>]*\/>/![\2](\1)/g' "$file"
    # Fallback when alt is missing: <Image src="SRC" ... /> -> ![](SRC)
    sed -E -i '' 's/<Image[^>]*src="([^"]*)"[^>]*\/>/![](\1)/g' "$file"
    
    # Remove link reference definitions (safer approach)
    sed -i '' '/^\[[^\]]*\]: /d' "$file"
    
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
    
    # Convert API reference links to new Mintlify format
    
    # Stablecoin Conversion endpoints
    sed -i '' 's|/api/v2#tag/Stablecoin-Conversion/operation/CreateStablecoinConversion|/api-reference/stablecoin-conversion/create-stablecoin-conversion|g' "$file"
    sed -i '' 's|/api/v2#tag/Stablecoin-Conversion/operation/ListStablecoinConversions|/api-reference/stablecoin-conversion/list-stablecoin-conversions|g' "$file"
    sed -i '' 's|/api/v2#tag/Stablecoin-Conversion/operation/GetStablecoinConversion|/api-reference/stablecoin-conversion/get-stablecoin-conversion|g' "$file"
    sed -i '' 's|/api/v2#tag/Stablecoin-Conversion|/api-reference/stablecoin-conversion|g' "$file"
    
    # Identity endpoints
    sed -i '' 's|/api/v2#tag/Identity/operation/CreateIdentity|/api-reference/identity/create-identity|g' "$file"
    sed -i '' 's|/api/v2#tag/Identity/operation/GetIdentity|/api-reference/identity/get-identity|g' "$file"
    sed -i '' 's|/api/v2#tag/Identity/operation/ListIdentities|/api-reference/identity/list-identities|g' "$file"
    sed -i '' 's|/api/v2#tag/Identity/operation/UpdateIdentity|/api-reference/identity/update-identity|g' "$file"
    sed -i '' 's|/api/v2#tag/Identity|/api-reference/identity|g' "$file"
    
    # Fiat Transfers endpoints
    sed -i '' 's|/api/v2#tag/Fiat-Transfers/operation/CreateFiatDepositInstructions|/api-reference/fiat-transfers/create-fiat-deposit-instructions|g' "$file"
    sed -i '' 's|/api/v2#tag/Fiat-Transfers/operation/ListFiatDepositInstructions|/api-reference/fiat-transfers/list-fiat-deposit-instructions|g' "$file"
    sed -i '' 's|/api/v2#tag/Fiat-Transfers/operation/GetFiatDepositInstructions|/api-reference/fiat-transfers/get-fiat-deposit-instructions|g' "$file"
    sed -i '' 's|/api/v2#tag/Fiat-Transfers|/api-reference/fiat-transfers|g' "$file"
    
    # Crypto Withdrawals endpoints
    sed -i '' 's|/api/v2#tag/Crypto-Withdrawals/operation/CreateCryptoWithdrawal|/api-reference/crypto-withdrawals/create-crypto-withdrawal|g' "$file"
    sed -i '' 's|/api/v2#tag/Crypto-Withdrawals/operation/ListCryptoWithdrawals|/api-reference/crypto-withdrawals/list-crypto-withdrawals|g' "$file"
    sed -i '' 's|/api/v2#tag/Crypto-Withdrawals/operation/GetCryptoWithdrawal|/api-reference/crypto-withdrawals/get-crypto-withdrawal|g' "$file"
    sed -i '' 's|/api/v2#tag/Crypto-Withdrawals|/api-reference/crypto-withdrawals|g' "$file"
    
    # Profiles endpoints
    sed -i '' 's|/api/v2#tag/Profiles/operation/CreateProfile|/api-reference/profiles/create-profile|g' "$file"
    sed -i '' 's|/api/v2#tag/Profiles/operation/ListProfiles|/api-reference/profiles/list-profiles|g' "$file"
    sed -i '' 's|/api/v2#tag/Profiles/operation/GetProfile|/api-reference/profiles/get-profile|g' "$file"
    sed -i '' 's|/api/v2#tag/Profiles/operation/ListProfileBalances|/api-reference/profiles/list-profile-balances|g' "$file"
    sed -i '' 's|/api/v2#tag/Profiles|/api-reference/profiles|g' "$file"
    
    # Transfers endpoints
    sed -i '' 's|/api/v2#tag/Transfers/operation/ListTransfers|/api-reference/transfers/list-transfers|g' "$file"
    sed -i '' 's|/api/v2#tag/Transfers/operation/GetTransfer|/api-reference/transfers/get-transfer|g' "$file"
    sed -i '' 's|/api/v2#tag/Transfers|/api-reference/transfers|g' "$file"
    
    # Sandbox endpoints
    sed -i '' 's|/api/v2#tag/Sandbox-Deposits/operation/CreateSandboxDeposit|/api-reference/sandbox/create-sandbox-deposit|g' "$file"
    sed -i '' 's|/api/v2#tag/Sandbox-Deposits|/api-reference/sandbox|g' "$file"
    
    # Webhooks endpoints
    sed -i '' 's|/api/v2#tag/Webhooks/operation/CreateWebhook|/api-reference/webhooks/create-webhook|g' "$file"
    sed -i '' 's|/api/v2#tag/Webhooks/operation/ListWebhooks|/api-reference/webhooks/list-webhooks|g' "$file"
    sed -i '' 's|/api/v2#tag/Webhooks/operation/GetWebhook|/api-reference/webhooks/get-webhook|g' "$file"
    sed -i '' 's|/api/v2#tag/Webhooks/operation/UpdateWebhook|/api-reference/webhooks/update-webhook|g' "$file"
    sed -i '' 's|/api/v2#tag/Webhooks/operation/DeleteWebhook|/api-reference/webhooks/delete-webhook|g' "$file"
    sed -i '' 's|/api/v2#tag/Webhooks|/api-reference/webhooks|g' "$file"
    
    # Institution Members endpoints
    sed -i '' 's|/api/v2#tag/Institution-Members/operation/CreateInstitutionMember|/api-reference/institution-members/create-institution-member|g' "$file"
    sed -i '' 's|/api/v2#tag/Institution-Members/operation/ListInstitutionMembers|/api-reference/institution-members/list-institution-members|g' "$file"
    sed -i '' 's|/api/v2#tag/Institution-Members/operation/GetInstitutionMember|/api-reference/institution-members/get-institution-member|g' "$file"
    sed -i '' 's|/api/v2#tag/Institution-Members/operation/UpdateInstitutionMember|/api-reference/institution-members/update-institution-member|g' "$file"
    sed -i '' 's|/api/v2#tag/Institution-Members/operation/DeleteInstitutionMember|/api-reference/institution-members/delete-institution-member|g' "$file"
    sed -i '' 's|/api/v2#tag/Institution-Members|/api-reference/institution-members|g' "$file"
    
    # Assets endpoints
    sed -i '' 's|/api/v2#tag/Assets/operation/ListAssets|/api-reference/assets/list-assets|g' "$file"
    sed -i '' 's|/api/v2#tag/Assets/operation/GetAsset|/api-reference/assets/get-asset|g' "$file"
    sed -i '' 's|/api/v2#tag/Assets|/api-reference/assets|g' "$file"
    
    # Networks endpoints
    sed -i '' 's|/api/v2#tag/Networks/operation/ListNetworks|/api-reference/networks/list-networks|g' "$file"
    sed -i '' 's|/api/v2#tag/Networks/operation/GetNetwork|/api-reference/networks/get-network|g' "$file"
    sed -i '' 's|/api/v2#tag/Networks|/api-reference/networks|g' "$file"
    
    # Generic fallback for any remaining /api/v2 references
    sed -i '' 's|/api/v2#tag/\([^/]*\)/operation/\([^]]*\)|/api-reference/\1/\2|g' "$file"
    sed -i '' 's|/api/v2#tag/\([^]]*\)|/api-reference/\1|g' "$file"
    
    # Convert tag names to lowercase and replace hyphens appropriately
    sed -i '' 's|/api-reference/Stablecoin-Conversion|/api-reference/stablecoin-conversion|g' "$file"
    sed -i '' 's|/api-reference/Fiat-Transfers|/api-reference/fiat-transfers|g' "$file"
    sed -i '' 's|/api-reference/Crypto-Withdrawals|/api-reference/crypto-withdrawals|g' "$file"
    sed -i '' 's|/api-reference/Institution-Members|/api-reference/institution-members|g' "$file"
    sed -i '' 's|/api-reference/Sandbox-Deposits|/api-reference/sandbox|g' "$file"
    
    # Convert operation names from PascalCase to kebab-case
    python3 -c "
import re
import sys

def convert_operation_name(match):
    operation = match.group(1)
    # Convert PascalCase to kebab-case
    operation = re.sub(r'([a-z0-9])([A-Z])', r'\1-\2', operation)
    operation = operation.lower()
    return f'/api-reference/{match.group(0).split(\"/\")[2]}/{operation}'

with open('$file', 'r') as f:
    content = f.read()

# Pattern to match remaining operation conversions that need kebab-case
pattern = r'/api-reference/([^/]+)/([A-Z][a-zA-Z0-9]*)'
content = re.sub(pattern, convert_operation_name, content)

with open('$file', 'w') as f:
    f.write(content)
"
}

# Process files based on migration mode
if [ "$IS_FILE_MIGRATION" = "true" ]; then
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
        
        echo "  ✅ Converted: $filename"
    done
else
    # Process all files in directory
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
            
            # Migrate images
            migrate_images "$target_file"
            
            # Convert API references
            convert_api_references "$target_file"
            
            # Fix parsing issues
            fix_parsing_issues "$target_file"
            
            echo "  ✅ Converted: $filename"
        fi
    done
fi

# Apply final cleanup across all files to ensure consistency
echo "🔧 Applying final cleanup..."
if [ "$IS_ROOT_MIGRATION" = "root" ]; then
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

# Additional fixes for specific parsing errors
if [ "$IS_ROOT_MIGRATION" = "root" ]; then
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/<\/\\Tip>/<\/Tip>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/<\/\\Warning>/<\/Warning>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/<\/\\Info>/<\/Info>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -maxdepth 1 -exec sed -i '' 's/<\/\\Note>/<\/Note>/g' {} \;
else
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Tip>/<\/Tip>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Warning>/<\/Warning>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Info>/<\/Info>/g' {} \;
    find "$TARGET_DIR" -name "*.mdx" -exec sed -i '' 's/<\/\\Note>/<\/Note>/g' {} \;
fi

if [ "$IS_FILE_MIGRATION" = "true" ]; then
    echo "🎯 Specific files migrated to: $TARGET_DIR"
elif [ "$IS_ROOT_MIGRATION" = "root" ]; then
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
echo "   - Image references (now using @images/)"
echo "   - API references (now using /api-reference/)"
echo "3. Test the migrated content"
echo ""

if [ "$IS_FILE_MIGRATION" = "true" ]; then
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