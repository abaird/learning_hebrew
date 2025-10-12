#!/bin/bash
# Test if CSS is properly deployed and serving

set -e

APP_URL="${APP_URL:-http://localhost:3000}"
PASSED=0
FAILED=0

echo "Testing CSS deployment on $APP_URL"
echo "=========================================="

# Test 1: Check if homepage loads
echo -n "Test 1: Homepage loads... "
if curl -sf "$APP_URL/" > /dev/null; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL - Homepage not accessible"
    ((FAILED++))
    exit 1
fi

# Test 2: Extract stylesheet URLs from HTML
echo -n "Test 2: Stylesheet links present in HTML... "
STYLESHEETS=$(curl -sL "$APP_URL/" | grep -o 'href="/assets/[^"]*\.css"' | sed 's/href="//;s/"//' || true)
if [ -n "$STYLESHEETS" ]; then
    echo "✓ PASS"
    ((PASSED++))
    echo "   Found: $(echo "$STYLESHEETS" | wc -l | tr -d ' ') stylesheet(s)"
else
    echo "✗ FAIL - No stylesheet links found"
    ((FAILED++))
fi

# Test 3: Verify each stylesheet returns valid CSS and reasonable size
echo "Test 3: Stylesheets serve valid CSS..."
for sheet in $STYLESHEETS; do
    echo -n "   Testing $sheet... "
    CONTENT=$(curl -s "$APP_URL$sheet")
    SIZE=$(echo "$CONTENT" | wc -c | tr -d ' ')

    if echo "$CONTENT" | grep -q "Not found"; then
        echo "✗ FAIL - Returns 404"
        ((FAILED++))
    elif [ -z "$CONTENT" ]; then
        echo "✗ FAIL - Empty response"
        ((FAILED++))
    elif [ "$SIZE" -lt 500 ]; then
        echo "✗ FAIL - Too small ($SIZE bytes, likely incomplete)"
        ((FAILED++))
    else
        echo "✓ PASS ($SIZE bytes)"
        ((PASSED++))
    fi
done

# Test 4: Check for Tailwind CSS utility class DEFINITIONS (not just references)
echo -n "Test 4: Tailwind utility classes are DEFINED... "
# Collect all CSS content
ALL_CSS=""
for sheet in $STYLESHEETS; do
    ALL_CSS="$ALL_CSS $(curl -s "$APP_URL$sheet")"
done

# Check for @import statements and fetch those too
IMPORTS=$(echo "$ALL_CSS" | grep -o '@import url("[^"]*")' | sed 's/@import url("//;s/")//' || true)
for import_url in $IMPORTS; do
    # Handle relative URLs
    if [[ "$import_url" == //* ]]; then
        import_url="http:$import_url"
    elif [[ "$import_url" == /* ]]; then
        import_url="$APP_URL$import_url"
    fi

    if [[ "$import_url" == http* ]]; then
        IMPORTED=$(curl -s "$import_url" 2>/dev/null || echo "")
        ALL_CSS="$ALL_CSS $IMPORTED"
    fi
done

# Check for actual Tailwind utility definitions (not just @import statements)
if echo "$ALL_CSS" | grep -q "\.bg-blue-600{" || echo "$ALL_CSS" | grep -q "\.bg-blue-600\s*{" || echo "$ALL_CSS" | grep -q "bg-blue-600" && echo "$ALL_CSS" | grep -q "background-color"; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL - Tailwind utility class definitions not found in served CSS"
    echo "   (CSS may contain @import but imported files aren't accessible or processed)"
    ((FAILED++))
fi

# Test 5: Verify Tailwind CSS file size is reasonable
echo -n "Test 5: Tailwind CSS file is substantial... "
TAILWIND_SIZE=$(echo "$ALL_CSS" | grep -E "(tailwindcss|@layer)" | wc -c | tr -d ' ')
if [ "$TAILWIND_SIZE" -gt 10000 ]; then
    echo "✓ PASS ($TAILWIND_SIZE bytes of Tailwind content)"
    ((PASSED++))
else
    echo "✗ FAIL - Tailwind CSS too small or missing ($TAILWIND_SIZE bytes)"
    echo "   Expected 10KB+, got $TAILWIND_SIZE bytes"
    ((FAILED++))
fi

# Test 6: Check for font definitions
echo -n "Test 6: Hebrew font defined... "
if echo "$ALL_CSS" | grep -q "font-hebrew" && echo "$ALL_CSS" | grep -q "font-family"; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL - font-hebrew class not properly defined"
    ((FAILED++))
fi

# Test 7: Verify specific utility classes used in HTML are defined in CSS
echo -n "Test 7: HTML utility classes have CSS definitions... "
HTML=$(curl -sL "$APP_URL/")
# Extract a few common classes from HTML
SAMPLE_CLASSES=$(echo "$HTML" | grep -o 'class="[^"]*"' | head -5 | sed 's/class="//;s/"//;s/ /\n/g' | grep -E '^(bg-|text-|px-|py-)' | head -3)

MISSING_DEFS=0
for cls in $SAMPLE_CLASSES; do
    # Check if this class is defined in the CSS (look for the class name and a property)
    if ! echo "$ALL_CSS" | grep -q "$cls" || ! echo "$ALL_CSS" | grep -A2 "$cls" | grep -q ":"; then
        MISSING_DEFS=$((MISSING_DEFS + 1))
    fi
done

if [ "$MISSING_DEFS" -eq 0 ] && [ -n "$SAMPLE_CLASSES" ]; then
    echo "✓ PASS"
    ((PASSED++))
elif [ -z "$SAMPLE_CLASSES" ]; then
    echo "⚠ SKIP - No utility classes found in HTML"
else
    echo "✗ FAIL - $MISSING_DEFS HTML classes lack CSS definitions"
    echo "   Sample missing: $SAMPLE_CLASSES"
    ((FAILED++))
fi

# Summary
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ CSS is properly deployed and serving"
    exit 0
else
    echo "✗ CSS deployment has issues"
    exit 1
fi
