# ⚡ Smart Grid API - Quick Reference

**Base URL:** `https://zjgorwwogcanatbacecm.supabase.co`

---

## 🔑 AUTHENTICATION

```http
apikey: YOUR-ANON-KEY
Authorization: Bearer YOUR-ANON-KEY
Content-Type: application/json
```

---

## 📊 COMMON ENDPOINTS

### Insert Fault (IoT)
```http
POST /rest/v1/faults
{
  "pole_id": "uuid",
  "fault_type": "voltage_drop",
  "priority_score": 8,
  "voltage_drop": 25.5,
  "status": "open"
}
```

### Auto-Dispatch
```http
POST /functions/v1/assign-nearest-lineman
{
  "faultId": "uuid",
  "faultLatitude": 13.0878,
  "faultLongitude": 80.2088,
  "priority": 8
}
```

### Get All Poles
```http
GET /rest/v1/poles?select=*
```

### Get Active Faults
```http
GET /rest/v1/faults?select=*,poles(*)&status=in.(open,assigned)
```

### Update Lineman GPS
```http
PATCH /rest/v1/linemen?id=eq.LINEMAN-ID
{
  "current_latitude": 13.05,
  "current_longitude": 80.23
}
```

### Mark Fault Resolved
```http
PATCH /rest/v1/faults?id=eq.FAULT-ID
{
  "status": "resolved",
  "resolved_at": "2026-02-06T11:00:00Z",
  "resolution_notes": "Fixed!"
}
```

---

## 📁 DATABASE TABLES

### poles
- pole_number (text, unique)
- location_name (text)
- latitude, longitude (float8)
- device_id (text, unique)
- status (active/maintenance/offline)

### faults
- pole_id (uuid → poles)
- fault_type (text)
- priority_score (1-10)
- voltage_drop, current_spike (float8)
- status (open/assigned/resolved)
- assigned_to (uuid → linemen)

### linemen
- auth_id (uuid → auth.users)
- name, phone, employee_id (text, unique)
- current_latitude, current_longitude (float8)
- availability_status (available/busy/offline)

### maintenance_logs
- pole_id (uuid → poles)
- alert_type (predictive/scheduled)
- risk_level (low/medium/high/critical)
- predicted_failure_date (date)

---

## 🔐 RLS POLICIES

| Table | Anonymous | Authenticated | Service Role |
|-------|-----------|---------------|--------------|
| poles | ✅ Read | ✅ Read | ✅ Full |
| faults | ✅ Insert | ✅ Read/Update Own | ✅ Full |
| linemen | ❌ | ✅ Read/Update Own | ✅ Full |
| maintenance_logs | ✅ Read | ✅ Read | ✅ Full |

---

## ⚡ FAULT WORKFLOW

```
1. ESP32 → POST /rest/v1/faults
2. Backend → POST /functions/v1/assign-nearest-lineman
3. App → GET /rest/v1/faults (lineman sees assignment)
4. App → PATCH /rest/v1/linemen (update GPS)
5. App → PATCH /rest/v1/faults (mark resolved)
6. App → PATCH /rest/v1/linemen (mark available)
```

---

## 🎯 FAULT TYPES

- `voltage_drop` - Voltage below threshold
- `current_leakage` - Abnormal current
- `wire_break` - Physical damage
- `overload` - Excessive current
- `transformer_fault` - Transformer issue

---

## 📊 PRIORITY LEVELS

| Score | Severity | Response Time |
|-------|----------|---------------|
| 10 | Critical | < 15 min |
| 8-9 | High | < 30 min |
| 5-7 | Medium | < 2 hours |
| 1-4 | Low | < 24 hours |

---

## ⚠️ ERROR CODES

| Code | Meaning | Solution |
|------|---------|----------|
| 401 | Unauthorized | Check API key |
| 403 | Forbidden | RLS blocked - check auth |
| 404 | Not Found | Verify UUID |
| 409 | Conflict | Duplicate unique field |
| 500 | Server Error | Check Supabase logs |

---

## 🧪 QUICK TESTS

### Test Fault Insert
```bash
curl -X POST 'https://zjgorwwogcanatbacecm.supabase.co/rest/v1/faults' \
-H "apikey: KEY" -H "Authorization: Bearer KEY" \
-H "Content-Type: application/json" \
-d '{"pole_id":"uuid","fault_type":"voltage_drop","priority_score":7}'
```

### Test Auto-Dispatch
```bash
curl -X POST 'https://zjgorwwogcanatbacecm.supabase.co/functions/v1/assign-nearest-lineman' \
-H "Authorization: Bearer KEY" \
-H "Content-Type: application/json" \
-d '{"faultId":"uuid","faultLatitude":13.08,"faultLongitude":80.20,"priority":7}'
```

---

**Last Updated:** Feb 6, 2026
