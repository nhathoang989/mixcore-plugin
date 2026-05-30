#!/usr/bin/env bash
# Validate the mixcore plugin skill-suite invariants.
# Run from anywhere: bash scripts/validate.sh
cd "$(dirname "$0")/.." || exit 2
fail=0
old='guide|dev|cms|db|ai|rag|spa|build-site|module|dotnet-code|dotnet-cli|migration|tests|blazor-app|blazor-blueprint'

echo "==> 1. each skill dir name must equal its 'name:' frontmatter"
for d in skills/*/; do
  n=$(basename "$d")
  fm=$(grep -m1 '^name:' "$d/SKILL.md" 2>/dev/null | sed 's/name:[[:space:]]*//; s/[[:space:]]*$//')
  if [ "$n" != "$fm" ]; then echo "   MISMATCH: dir=$n name='$fm'"; fail=1; fi
done

echo "==> 2. no leftover old short skill tokens (mixcore:<short> without prefix)"
if grep -rnE "mixcore:(${old})([^a-z-]|\$)" skills README.md .claude-plugin 2>/dev/null; then
  echo "   ^ stale short tokens"; fail=1
fi

echo "==> 3. no stale skills/<old-name>/ path refs"
if grep -rnE "skills/(${old})/" skills 2>/dev/null; then
  echo "   ^ stale path refs"; fail=1
fi

echo "==> 4. no machine-absolute paths in skills (C:\\... , /Users/, /home/<user>)"
if grep -rnE '[A-Za-z]:\\|/Users/|/home/[a-z]' skills 2>/dev/null; then
  echo "   ^ machine-absolute path leak"; fail=1
fi

echo "==> (warn) skills with no 'allowed-tools:' declared"
for d in skills/*/; do
  grep -q '^allowed-tools:' "$d/SKILL.md" 2>/dev/null || echo "   - ${d}SKILL.md"
done

if [ "$fail" = 0 ]; then echo "OK: all checks passed"; else echo "FAILED: see above"; fi
exit "$fail"
