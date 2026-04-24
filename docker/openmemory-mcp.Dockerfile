# Build a patched version of mem0/openmemory-mcp with the categorization fix
# Bug: https://github.com/mem0ai/mem0/issues/3834
# The original image uses unsupported with_response_format() method

FROM mem0/openmemory-mcp:latest

# Copy patch script that fixes the with_response_format bug
COPY <<EOF /tmp/patch_categorization.py
import re

# Read the problematic file
with open('/usr/src/openmemory/app/utils/categorization.py', 'r') as f:
    content = f.read()

# Replace the buggy with_response_format call with beta.chat.completions.parse
# The original code has:
#   completion = openai_client.chat.completions.with_response_format(
#       response_format=MemoryCategories
#   ).create(
#       model="gpt-4o-mini",
#       messages=messages,
#       temperature=0
#   )
# Replace with:
#   completion = openai_client.beta.chat.completions.parse(
#       model="gpt-4o-mini",
#       response_format=MemoryCategories,
#       messages=messages,
#       temperature=0
#   )

# Find and replace the method chain
old_code = '''completion = openai_client.chat.completions.with_response_format(
            response_format=MemoryCategories
        ).create(
            model="gpt-4o-mini",
            messages=messages,
            temperature=0
        )'''

new_code = '''completion = openai_client.beta.chat.completions.parse(
            model="gpt-4o-mini",
            response_format=MemoryCategories,
            messages=messages,
            temperature=0
        )'''

if old_code in content:
    content = content.replace(old_code, new_code)
    print("✓ Patched categorization.py: replaced with_response_format with beta.chat.completions.parse")
else:
    print("✗ ERROR: Could not find the with_response_format code in categorization.py")
    print("File may have already been patched or code structure changed")
    exit(1)

# Write back
with open('/usr/src/openmemory/app/utils/categorization.py', 'w') as f:
    f.write(content)

# Verify the patch
if 'beta.chat.completions.parse' in content:
    print("✓ Verification successful: beta.chat.completions.parse found in patched file")
else:
    print("✗ Verification failed: beta.chat.completions.parse not found after patching")
    exit(1)
EOF

RUN python3 /tmp/patch_categorization.py && rm /tmp/patch_categorization.py

# Create an entrypoint wrapper that reads Docker secrets and exports them as env vars
# This allows secrets mounted at /run/secrets/* to be injected into the application
COPY <<EOF /entrypoint.sh
#!/bin/bash
set -e

# Read all files under /run/secrets and export as env vars
if [ -d /run/secrets ]; then
    for secret_file in /run/secrets/*; do
        if [ -f "\$secret_file" ]; then
            # Convert filename to UPPER_SNAKE_CASE env var name
            secret_name=\$(basename "\$secret_file" | sed 's/-/_/g' | tr '[:lower:]' '[:upper:]')
            export "\$secret_name"="\$(cat \$secret_file)"
            echo "✓ Loaded secret: \$secret_name"
        fi
    done
fi

# If we have adesso-ai-hub_api_key but not OPENAI_API_KEY, use it
if [ -z "\$OPENAI_API_KEY" ] && [ -n "\$ADESSO_AI_HUB_API_KEY" ]; then
    export OPENAI_API_KEY="\$ADESSO_AI_HUB_API_KEY"
    echo "✓ Using Adesso AI Hub API key as OPENAI_API_KEY"
fi

# Launch the original entrypoint (uvicorn)
exec uvicorn main:app --host 0.0.0.0 --port 8765
EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]




