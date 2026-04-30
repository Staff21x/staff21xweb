#!/usr/bin/env bash
# Usage: ./apollo_test.sh <YOUR_APOLLO_API_KEY> [company_name]
# Verifies that the Apollo People Search API returns results for a Chilean company.
# If this works, the issue is in the n8n credential header config, not the API itself.

API_KEY="${1:-}"
COMPANY="${2:-Sodimac}"

if [[ -z "$API_KEY" ]]; then
  echo "ERROR: API key required."
  echo "Usage: $0 <api_key> [company_name]"
  exit 1
fi

echo "==> Testing Apollo API"
echo "    Company  : $COMPANY"
echo "    Endpoint : https://api.apollo.io/api/v1/mixed_people/search"
echo ""

BODY=$(cat <<EOF
{
  "organization_names": ["$COMPANY"],
  "person_titles": [
    "Jefe de Capacitación",
    "Gerente RRHH",
    "Subgerente de Personas",
    "Gerente Desarrollo Organizacional",
    "Gerente Formación",
    "HR Manager",
    "Training Manager",
    "People Manager",
    "Learning and Development Manager"
  ],
  "page": 1,
  "per_page": 5,
  "person_locations": ["Chile"]
}
EOF
)

RESPONSE=$(curl -s -w "\n__HTTP_STATUS__:%{http_code}" \
  -X POST "https://api.apollo.io/api/v1/mixed_people/search" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "$BODY")

HTTP_STATUS=$(echo "$RESPONSE" | grep "__HTTP_STATUS__:" | cut -d: -f2)
BODY_RESPONSE=$(echo "$RESPONSE" | grep -v "__HTTP_STATUS__:")

echo "==> HTTP Status: $HTTP_STATUS"
echo ""

if [[ "$HTTP_STATUS" == "200" ]]; then
  python3 - <<PYEOF
import sys, json

raw = '''$BODY_RESPONSE'''
try:
    data = json.loads(raw)
except Exception as e:
    print("Could not parse JSON:", e)
    sys.exit(1)

people = data.get('people', data.get('contacts', []))
total  = data.get('pagination', {}).get('total_entries', '?')
print(f"People returned : {len(people)}  (total in Apollo: {total})")
print()
for p in people[:5]:
    name  = ' '.join(filter(None, [p.get('first_name',''), p.get('last_name','')]))
    email = p.get('email', 'no-email')
    title = p.get('title', '')
    org   = p.get('organization_name', '')
    print(f"  {name} | {title} | {email} | {org}")
print()
if people:
    print("SUCCESS: API key is valid. Check n8n credential header config (see below).")
else:
    print("WARNING: API key is valid but 0 results. Try a broader company name or remove person_locations filter.")
PYEOF

elif [[ "$HTTP_STATUS" == "401" || "$HTTP_STATUS" == "403" ]]; then
  echo "FAIL: Invalid or missing API key."
  echo ""
  echo "Fix in n8n > Credentials > 'Header Auth account 2':"
  echo "  Name  (header name) : x-api-key"
  echo "  Value               : <your Apollo API key>"
  echo ""
  echo "Raw response: $BODY_RESPONSE"
elif [[ "$HTTP_STATUS" == "422" ]]; then
  echo "FAIL: Unprocessable request (bad JSON body)."
  echo "Raw response: $BODY_RESPONSE"
else
  echo "FAIL: Unexpected HTTP $HTTP_STATUS"
  echo "Raw response: $BODY_RESPONSE"
fi
