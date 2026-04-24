# 📚 Smart Grid Backend Documentation

This folder contains all backend documentation for the Smart Grid Fault Detection System.

---

## 📁 FILES IN THIS FOLDER

### 1. **API-Documentation.md** ⭐ MAIN REFERENCE
**What:** Complete API documentation (50+ pages)  
**When to use:** 
- Building mobile app
- Integrating ESP32
- Creating web dashboard
- Reference for all endpoints

**Contents:**
- Database schema
- All API endpoints
- Edge Functions
- Workflow examples
- Error handling
- Testing guide

---

### 2. **Quick-Reference.md** ⚡ CHEAT SHEET
**What:** One-page quick reference  
**When to use:**
- Quick lookup while coding
- Testing API calls
- Remembering endpoint URLs

**Contents:**
- Common API calls
- Table structures
- RLS policies summary
- Quick test commands

---

### 3. **supabase-credentials-TEMPLATE.txt** 🔐 SECRETS
**What:** Template for storing your API keys and passwords  
**⚠️ IMPORTANT:** 
- Fill in YOUR actual credentials
- Keep this file SECURE
- Do NOT commit to Git
- Add to .gitignore

**What to fill in:**
- Anon key (from Supabase Dashboard)
- Service role key (KEEP SECRET!)
- Database password
- Test account credentials

---

## 🚀 HOW TO USE THESE DOCS

### For Mobile App Development:
1. Open **API-Documentation.md**
2. Go to section: "API Endpoints"
3. Find: "GET LINEMAN'S ASSIGNED FAULTS"
4. Copy the endpoint and headers
5. Implement in your Flutter code

### For IoT Integration:
1. Open **Quick-Reference.md**
2. Find: "Insert Fault (IoT)"
3. Copy the curl command
4. Adapt to ESP32 HTTP library
5. Use credentials from credentials file

### For Web Dashboard:
1. Open **API-Documentation.md**
2. Go to: "GET ALL POLES"
3. Use to display map markers
4. Check "Workflow Examples" for complete flows

---

## 📖 READING ORDER

**If you're new to the project:**

1. Start with **Quick-Reference.md** (5 min read)
   - Get overview of all endpoints
   - Understand table structure

2. Then **API-Documentation.md** (30 min read)
   - Deep dive into each endpoint
   - Understand workflows
   - Learn error handling

3. Fill in **supabase-credentials-TEMPLATE.txt**
   - Add your actual keys
   - Save as `supabase-credentials.txt`
   - Keep it safe!

---

## 🔍 FINDING WHAT YOU NEED

### "How do I insert a fault from ESP32?"
→ Quick-Reference.md → "Insert Fault (IoT)"

### "How does auto-dispatch work?"
→ API-Documentation.md → "Edge Functions" → "assign-nearest-lineman"

### "What's my API key?"
→ supabase-credentials.txt (you'll create this)

### "How do I test if it's working?"
→ API-Documentation.md → "Testing Guide"

### "What tables exist?"
→ API-Documentation.md → "Database Schema"

### "How do I update lineman GPS?"
→ Quick-Reference.md → "Update Lineman GPS"

---

## 🎯 QUICK START GUIDE

### 1. Fill in Your Credentials (5 minutes)
```bash
# Copy the template
cp supabase-credentials-TEMPLATE.txt supabase-credentials.txt

# Edit with your actual keys
code supabase-credentials.txt

# Get your keys from:
# https://supabase.com/dashboard/project/zjgorwwogcanatbacecm/settings/api
```

### 2. Test Your First API Call (2 minutes)
```bash
# Open Quick-Reference.md
# Copy the "Get All Poles" curl command
# Replace KEY with your anon key
# Run in terminal

curl 'https://zjgorwwogcanatbacecm.supabase.co/rest/v1/poles?select=*' \
-H "apikey: YOUR-ANON-KEY" \
-H "Authorization: Bearer YOUR-ANON-KEY"

# Should return 5 poles ✅
```

### 3. Read Workflow Example (10 minutes)
```
Open: API-Documentation.md
Go to: "Complete Fault Detection & Resolution Flow"
Understand: How the entire system works end-to-end
```

---

## 📱 NEXT DEVELOPMENT STEPS

**Backend: ✅ COMPLETE**

**Now build:**

### Option A: Mobile App (Flutter)
- Read: API-Documentation.md → "GET LINEMAN'S ASSIGNED FAULTS"
- Read: API-Documentation.md → "UPDATE LINEMAN GPS LOCATION"
- Implement: Login, Fault list, GPS tracking, Mark resolved

### Option B: Web Dashboard
- Read: API-Documentation.md → "GET ALL POLES"
- Read: API-Documentation.md → "GET ACTIVE FAULTS"
- Implement: Map view, Fault table, Analytics

### Option C: IoT Code (ESP32)
- Read: Quick-Reference.md → "Insert Fault (IoT)"
- Implement: Sensor reading → HTTP POST to Supabase
- Test: Simulate faults

---

## ⚠️ IMPORTANT NOTES

### Security
- ✅ Anon key: Safe to use in mobile/web apps
- ❌ Service role key: NEVER expose publicly
- 🔒 Add `supabase-credentials.txt` to `.gitignore`

### Rate Limits
- Free tier: 500K API calls/month
- 2M Edge Function calls/month
- Your project won't exceed these during development

### Support
- Supabase Docs: https://supabase.com/docs
- Project Dashboard: https://supabase.com/dashboard/project/zjgorwwogcanatbacecm
- SQL Editor: For direct database access

---

## 📊 PROJECT STATUS

**Backend Components:**

| Component | Status | Documentation |
|-----------|--------|---------------|
| Database Schema | ✅ Complete | API-Documentation.md → "Database Schema" |
| Sample Data | ✅ Inserted | 5 poles, 3 linemen, 3 faults |
| Edge Functions | ✅ Deployed | API-Documentation.md → "Edge Functions" |
| RLS Policies | ✅ Configured | API-Documentation.md → "Authentication & Security" |
| API Endpoints | ✅ Tested | Quick-Reference.md |

**What's Left:**
- Mobile App (Flutter)
- Web Dashboard (React)
- ESP32 Integration
- Push Notifications

---

## 🆘 TROUBLESHOOTING

### "I can't find my API key"
1. Go to: https://supabase.com/dashboard/project/zjgorwwogcanatbacecm/settings/api
2. Copy "anon public" key
3. Paste in `supabase-credentials.txt`

### "API returns 401 Unauthorized"
- Check: Authorization header has correct format
- Format: `Authorization: Bearer YOUR-ANON-KEY`
- Not: `Authorization: YOUR-ANON-KEY` (missing "Bearer")

### "RLS blocks my request"
- Check: Are you using anon key? (RLS applies)
- Or: Are you using service role key? (Bypasses RLS)
- See: API-Documentation.md → "Row Level Security"

### "Edge Function not working"
- Check: Function URL correct?
- Check: Request body has all required fields?
- Check: Authorization header present?
- Debug: Check Supabase logs in Dashboard

---

## 📞 GETTING HELP

1. **Check API-Documentation.md first** (most questions answered there)
2. **Check Supabase Dashboard logs** (real error messages)
3. **Test with curl** (isolate if it's your code or API)
4. **Verify credentials** (wrong key = errors)

---

**Created:** February 6, 2026  
**Last Updated:** February 6, 2026  
**Version:** 1.0  
**Maintained By:** Smart Grid Development Team

---

## ✨ YOU'RE ALL SET!

Your backend is complete and documented. Start building your mobile app or web dashboard using these docs as reference!

**Happy Coding! 🚀**
