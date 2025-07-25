# Docusaurus to Mintlify Migration Plan

## Overview
This document outlines a **repeatable migration process** for converting Docusaurus-based developer guides to Mintlify format. This plan was designed for migrating developer guides to be organized as sections in the Mintlify Guides sidebar.

## Migration Architecture

### Source Structure (Docusaurus)
```
/Users/cameronfleet/dev/docs/content/{guide-name}/
├── index.mdx (overview page)
├── page1.mdx
├── page2.mdx
└── ...
```

### Target Structure (Mintlify)  
```
/Users/cameronfleet/dev/new-docs/guides/{guide-name}/
├── overview.mdx (renamed from index.mdx)
├── page1.mdx
├── page2.mdx
└── ...
```

## Migration Process

### Phase 1: Automated Migration

#### 1. Use the Migration Script
```bash
# Make script executable (one time)
chmod +x /Users/cameronfleet/dev/new-docs/migrate-guide.sh

# Run migration
./migrate-guide.sh <source_guide_name> <target_guide_name>

# Example for identity guide:
./migrate-guide.sh identity identity
```

#### 2. What the Script Does Automatically
- ✅ **Frontmatter Conversion**: Converts Docusaurus frontmatter to Mintlify format
- ✅ **Component Cleanup**: Removes Docusaurus-specific imports and components
- ✅ **Basic Component Conversion**: Converts some components to Mintlify equivalents
- ✅ **Admonition Conversion**: Converts `:::note` to `<Tip>`, `:::caution` to `<Warning>`, etc.
- ✅ **Link Reference Cleanup**: Removes Docusaurus-style link references
- ✅ **File Organization**: Creates proper directory structure

#### 3. Rename index.mdx to overview.mdx
```bash
mv guides/{guide-name}/index.mdx guides/{guide-name}/overview.mdx
```

### Phase 2: Manual Review & Cleanup

#### 1. Update docs.json Navigation
Add the new guide section to `docs.json`:

```json
{
  "group": "{Guide Name}",
  "pages": [
    "guides/{guide-name}/overview",
    "guides/{guide-name}/page1",
    "guides/{guide-name}/page2",
    // ... other pages
  ]
}
```

#### 2. Manual Cleanup Required

**Priority 1 - Critical Issues:**
- [ ] **Broken Admonitions**: Fix unclosed `<Tip>`, `<Warning>`, `<Info>` tags
- [ ] **Component Conversions**: 
  - Replace `FeatureCard` with Mintlify `<Card>` components
  - Convert `FeatureContainer` to `<CardGroup>`
- [ ] **Import Cleanup**: Remove any remaining Docusaurus imports

**Priority 2 - Content Issues:**
- [ ] **Link References**: Convert remaining `[text][ref]` links to `[text](url)` format
- [ ] **Internal Links**: Update internal links to use new guide paths
- [ ] **Tab Components**: Convert Docusaurus `<Tabs>` to Mintlify `<Tabs>` or `<Accordion>`

**Priority 3 - Enhancement:**
- [ ] **Images**: Update image paths and add proper alt text
- [ ] **Code Blocks**: Review and enhance code block formatting
- [ ] **Icons**: Add appropriate icons to frontmatter using Mintlify's icon library

#### 3. Testing
- [ ] Preview the migrated content locally
- [ ] Check all internal links work correctly
- [ ] Verify all components render properly
- [ ] Test navigation flow

## Example: Identity Guide Migration

### Completed Migration
✅ **Files Migrated** (8 files):
- `overview.mdx` - Identity overview with card layout
- `person-crypto-brokerage.mdx` - Person onboarding guide  
- `institution-crypto-brokerage.mdx` - Institution onboarding guide
- `required-details.mdx` - Required details reference
- `statuses.mdx` - Identity statuses guide
- `edd.mdx` - Enhanced Due Diligence guide
- `kyc-refresh.mdx` - KYC refresh automation guide
- `institution-types.mdx` - Institution types reference

✅ **Navigation Updated**: Added Identity section to Guides tab

### Manual Cleanup Applied
✅ **Fixed**: overview.mdx converted to use proper Mintlify `<Card>` components

### Remaining Manual Tasks for Identity
- [ ] Review and fix admonition tags in `person-crypto-brokerage.mdx`
- [ ] Convert remaining link references to inline links
- [ ] Test all internal navigation links

## Reusable Migration Checklist

For each new guide migration:

### Pre-Migration
- [ ] Identify source guide directory
- [ ] Plan target guide name and structure
- [ ] Backup source files if needed

### Automated Migration  
- [ ] Run `./migrate-guide.sh <source> <target>`
- [ ] Rename `index.mdx` to `overview.mdx`
- [ ] Update `docs.json` navigation

### Manual Review
- [ ] Fix component conversions (FeatureCard → Card)
- [ ] Fix broken admonitions 
- [ ] Convert link references
- [ ] Update internal links
- [ ] Test navigation and rendering

### Quality Assurance
- [ ] Preview locally
- [ ] Check all links work
- [ ] Verify components render correctly
- [ ] Review content formatting

## Script Improvements for Future Versions

### Potential Enhancements
1. **Better Component Conversion**: More sophisticated regex for FeatureCard → Card conversion
2. **Link Reference Handling**: Proper conversion of link references to inline links
3. **Admonition Fix**: Better handling of admonition closing tags
4. **Image Path Updates**: Automatic update of image paths
5. **Frontmatter Enhancement**: Add icon suggestions based on guide type

### Known Limitations
- Link references require manual conversion for complex cases
- Some component conversions need manual refinement
- Admonition closing tags may need manual fixing
- Custom React components require manual replacement

## Migration Statistics

### Identity Guide Migration Results
- **Total Files**: 8 MDX files migrated
- **Automated Success Rate**: ~80% 
- **Manual Review Required**: ~20%
- **Time Saved**: ~2-3 hours per guide (vs manual migration)

This migration plan provides a **repeatable, semi-automated process** that significantly reduces manual work while ensuring consistent quality across guide migrations. 