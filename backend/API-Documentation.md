# 🔌 Smart Grid Fault Detection System - API Documentation

**Project:** Smart Grid Fault Detection System  
**Backend:** Supabase (PostgreSQL + Edge Functions)  
**Date Created:** February 6, 2026  
**Version:** 1.0

---

## 📋 TABLE OF CONTENTS

1. [Project Overview](#project-overview)
2. [Authentication & Security](#authentication--security)
3. [Database Schema](#database-schema)
4. [API Endpoints](#api-endpoints)
5. [Edge Functions](#edge-functions)
6. [Workflow Examples](#workflow-examples)
7. [Error Handling](#error-handling)
8. [Testing Guide](#testing-guide)

---

## 🎯 PROJECT OVERVIEW

### What This System Does

The Smart Grid Fault Detection System automatically:
- Detects electrical faults using IoT sensors on poles
- Calculates fault priority based on location, time, and severity
- Auto-assigns faults to the nearest available lineman
- Tracks linemen GPS locations in real-time
- Provides predictive maintenance alerts
- Manages fault resolution workflow

### Unique Features

1. **Low-cost IoT monitoring** (₹3,500/pole vs ₹50,000+ competitors)
2. **Multi-sensor AI fusion** (voltage + current + vibration)
3. **Proximity-based auto-dispatch** (Uber-like algorithm)
4. **Predictive maintenance** (prevents 30-40% of failures)
5. **Public safety integration** (alerts nearby residents)
6. **Context-aware priority** (school hours = critical)

---

## 🔐 AUTHENTICATION & SECURITY

### Project Credentials

```
Project URL: https://zjgorwwogcanatbacecm.supabase.co
Region: Southeast Asia (Singapore)
Database: PostgreSQL 15
```

### API Keys

**Anon (Public) Key:**
- Use in: IoT devices, Mobile apps, Web dashboard
- Permissions: Limited by Row Level Security policies
- Safe to expose in client-side code

**Service Role Key:**
- Use in: Server-side code, Edge Functions only
- Permissions: Full database access (bypasses RLS)
- **NEVER expose publicly!**

### Row Level Security (RLS) Policies

#### Poles Table
- ✅ **Public:** Can read all poles (for map display)
- ✅ **Service Role:** Full access

#### Faults Table
- ✅ **Anonymous:** Can insert faults (IoT devices)
- ✅ **Authenticated Linemen:** Can read/update assigned faults only
- ✅ **Service Role:** Full access

#### Linemen Table
- ✅ **Authenticated Linemen:** Can read/update own profile only
- ❌ **Anonymous:** No access
- ✅ **Service Role:** Full access

#### Maintenance Logs Table
- ✅ **Public:** Can read maintenance alerts
- ✅ **Service Role:** Full access

---

## 📊 DATABASE SCHEMA

### Table: `poles`
Stores IoT device information and pole locations.

| Column | Type | Description | Required |
|--------|------|-------------|----------|
| id | uuid | Primary key | Auto |
| pole_number | text | Unique pole identifier (e.g., POLE-001) | Yes |
| location_name | text | Human-readable location | Yes |
| latitude | float8 | GPS latitude | Yes |
| longitude | float8 | GPS longitude | Yes |
| device_id | text | ESP32 device ID | Yes |
| status | text | active/maintenance/offline | Default: 'active' |
| installed_date | timestamp | Installation date | Auto |
| last_heartbeat | timestamp | Last communication from device | Auto |
| created_at | timestamp | Record creation time | Auto |

**Indexes:**
- Primary: id
- Unique: pole_number, device_id

---

### Table: `faults`
Records all detected electrical faults.

| Column | Type | Description | Required |
|--------|------|-------------|----------|
| id | uuid | Primary key | Auto |
| pole_id | uuid | Foreign key → poles.id | Yes |
| fault_type | text | voltage_drop/current_leakage/wire_break | Yes |
| priority_score | int2 | 1-10 (10 = critical) | Default: 5 |
| voltage_drop | float8 | Voltage drop in volts | No |
| current_spike | float8 | Current spike in amperes | No |
| vibration_detected | bool | Wire movement detected | Default: false |
| status | text | open/assigned/resolved | Default: 'open' |
| detected_at | timestamp | Fault detection time | Auto |
| assigned_to | uuid | Foreign key → linemen.id | No |
| resolved_at | timestamp | Resolution time | No |
| resolution_notes | text | Lineman's repair notes | No |
| created_at | timestamp | Record creation time | Auto |

**Indexes:**
- Primary: id
- Foreign Keys: pole_id, assigned_to
- Common Queries: status, priority_score

---

### Table: `linemen`
Stores lineman profiles and real-time GPS locations.

| Column | Type | Description | Required |
|--------|------|-------------|----------|
| id | uuid | Primary key | Auto |
| auth_id | uuid | Foreign key → auth.users.id | Yes |
| name | text | Lineman's full name | Yes |
| phone | text | Contact number | Yes |
| employee_id | text | Company employee ID | Yes |
| current_latitude | float8 | Real-time GPS latitude | No |
| current_longitude | float8 | Real-time GPS longitude | No |
| availability_status | text | available/busy/offline | Default: 'available' |
| total_faults_resolved | int4 | Performance metric | Default: 0 |
| avg_response_time | int4 | Average minutes to reach site | No |
| last_location_update | timestamp | Last GPS update time | Auto |
| created_at | timestamp | Record creation time | Auto |

**Indexes:**
- Primary: id
- Unique: auth_id, phone, employee_id
- Common Queries: availability_status

---

### Table: `maintenance_logs`
Predictive maintenance alerts generated by AI.

| Column | Type | Description | Required |
|--------|------|-------------|----------|
| id | uuid | Primary key | Auto |
| pole_id | uuid | Foreign key → poles.id | Yes |
| alert_type | text | predictive/scheduled/emergency | Yes |
| risk_level | text | low/medium/high/critical | Default: 'medium' |
| predicted_failure_date | date | AI-predicted failure date | No |
| maintenance_scheduled | bool | Scheduled for repair | Default: false |
| maintenance_completed | bool | Repair completed | Default: false |
| notes | text | Additional details | No |
| created_at | timestamp | Alert creation time | Auto |

**Indexes:**
- Primary: id
- Foreign Key: pole_id

---

## 🌐 API ENDPOINTS

### Base URL
```
https://zjgorwwogcanatbacecm.supabase.co
```

### Common Headers
```http
apikey: YOUR-ANON-KEY
Authorization: Bearer YOUR-ANON-KEY
Content-Type: application/json
```

---

### 1. INSERT FAULT (IoT Device)

**Endpoint:** `POST /rest/v1/faults`

**Use Case:** When ESP32 sensor detects an electrical fault

**Request:**
```http
POST /rest/v1/faults
apikey: YOUR-ANON-KEY
Authorization: Bearer YOUR-ANON-KEY
Content-Type: application/json

{
  "pole_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "fault_type": "voltage_drop",
  "priority_score": 8,
  "voltage_drop": 25.5,
  "current_spike": 0.0,
  "vibration_detected": false,
  "status": "open"
}
```

**Response:** `201 Created`
```json
{
  "id": "fault-uuid-here",
  "pole_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "fault_type": "voltage_drop",
  "priority_score": 8,
  "status": "open",
  "detected_at": "2026-02-06T10:30:00Z"
}
```

**Fault Types:**
- `voltage_drop` - Voltage below threshold
- `current_leakage` - Abnormal current flow
- `wire_break` - Physical wire damage
- `overload` - Excessive current draw
- `transformer_fault` - Transformer issues

---

### 2. GET ALL POLES

**Endpoint:** `GET /rest/v1/poles`

**Use Case:** Display all poles on web dashboard map

**Request:**
```http
GET /rest/v1/poles?select=*
apikey: YOUR-ANON-KEY
Authorization: Bearer YOUR-ANON-KEY
```

**Response:** `200 OK`
```json
[
  {
    "id": "pole-uuid-1",
    "pole_number": "POLE-001",
    "location_name": "Anna Nagar Main Road",
    "latitude": 13.0878,
    "longitude": 80.2088,
    "device_id": "ESP32-001",
    "status": "active",
    "last_heartbeat": "2026-02-06T10:25:00Z"
  },
  {
    "id": "pole-uuid-2",
    "pole_number": "POLE-002",
    "location_name": "T Nagar Bus Stand",
    "latitude": 13.0418,
    "longitude": 80.2341,
    "device_id": "ESP32-002",
    "status": "active",
    "last_heartbeat": "2026-02-06T10:26:00Z"
  }
]
```

**Query Parameters:**
- `select=*` - All columns
- `select=pole_number,latitude,longitude` - Specific columns only
- `status=eq.active` - Filter by status
- `order=pole_number.asc` - Sort results

---

### 3. GET ACTIVE FAULTS

**Endpoint:** `GET /rest/v1/faults`

**Use Case:** Dashboard displays all open/assigned faults

**Request:**
```http
GET /rest/v1/faults?select=*,poles(pole_number,location_name,latitude,longitude)&status=in.(open,assigned)&order=priority_score.desc
apikey: YOUR-ANON-KEY
Authorization: Bearer YOUR-ANON-KEY
```

**Response:** `200 OK`
```json
[
  {
    "id": "fault-uuid-1",
    "pole_id": "pole-uuid-1",
    "fault_type": "wire_break",
    "priority_score": 10,
    "status": "assigned",
    "assigned_to": "lineman-uuid-1",
    "detected_at": "2026-02-06T09:00:00Z",
    "poles": {
      "pole_number": "POLE-002",
      "location_name": "T Nagar Bus Stand",
      "latitude": 13.0418,
      "longitude": 80.2341
    }
  }
]
```

---

### 4. GET LINEMAN'S ASSIGNED FAULTS

**Endpoint:** `GET /rest/v1/faults`

**Use Case:** Mobile app shows lineman's work queue

**Authentication:** Requires lineman JWT token

**Request:**
```http
GET /rest/v1/faults?select=*,poles(*)&assigned_to=eq.LINEMAN-ID&status=neq.resolved&order=priority_score.desc
apikey: YOUR-ANON-KEY
Authorization: Bearer USER-JWT-TOKEN
```

**Response:** `200 OK`
```json
[
  {
    "id": "fault-uuid-1",
    "fault_type": "voltage_drop",
    "priority_score": 8,
    "status": "assigned",
    "detected_at": "2026-02-06T09:30:00Z",
    "poles": {
      "pole_number": "POLE-001",
      "location_name": "Anna Nagar Main Road",
      "latitude": 13.0878,
      "longitude": 80.2088
    }
  }
]
```

---

### 5. UPDATE LINEMAN GPS LOCATION

**Endpoint:** `PATCH /rest/v1/linemen`

**Use Case:** Mobile app updates GPS every 30 seconds

**Authentication:** Requires lineman JWT token

**Request:**
```http
PATCH /rest/v1/linemen?id=eq.LINEMAN-ID
apikey: YOUR-ANON-KEY
Authorization: Bearer USER-JWT-TOKEN
Content-Type: application/json

{
  "current_latitude": 13.0500,
  "current_longitude": 80.2300,
  "last_location_update": "2026-02-06T10:30:00Z"
}
```

**Response:** `204 No Content` (Success)

---

### 6. MARK FAULT AS RESOLVED

**Endpoint:** `PATCH /rest/v1/faults`

**Use Case:** Lineman completes repair and updates status

**Authentication:** Requires lineman JWT token

**Request:**
```http
PATCH /rest/v1/faults?id=eq.FAULT-ID
apikey: YOUR-ANON-KEY
Authorization: Bearer USER-JWT-TOKEN
Content-Type: application/json

{
  "status": "resolved",
  "resolved_at": "2026-02-06T11:00:00Z",
  "resolution_notes": "Replaced damaged wire section. Tested voltage - normal at 230V. No further issues."
}
```

**Response:** `204 No Content` (Success)

**Follow-up Action:** Update lineman availability

```http
PATCH /rest/v1/linemen?id=eq.LINEMAN-ID
{
  "availability_status": "available",
  "total_faults_resolved": "total_faults_resolved + 1"
}
```

---

### 7. UPDATE LINEMAN AVAILABILITY

**Endpoint:** `PATCH /rest/v1/linemen`

**Use Case:** Lineman marks themselves available/busy/offline

**Request:**
```http
PATCH /rest/v1/linemen?id=eq.LINEMAN-ID
apikey: YOUR-ANON-KEY
Authorization: Bearer USER-JWT-TOKEN
Content-Type: application/json

{
  "availability_status": "available"
}
```

**Availability Status Values:**
- `available` - Ready for new assignments
- `busy` - Currently working on a fault
- `offline` - Off-duty or unavailable

**Response:** `204 No Content` (Success)

---

### 8. GET MAINTENANCE ALERTS

**Endpoint:** `GET /rest/v1/maintenance_logs`

**Use Case:** Dashboard shows predictive maintenance warnings

**Request:**
```http
GET /rest/v1/maintenance_logs?select=*,poles(pole_number,location_name)&maintenance_completed=eq.false&order=risk_level.desc,predicted_failure_date.asc
apikey: YOUR-ANON-KEY
Authorization: Bearer YOUR-ANON-KEY
```

**Response:** `200 OK`
```json
[
  {
    "id": "log-uuid-1",
    "pole_id": "pole-uuid-4",
    "alert_type": "predictive",
    "risk_level": "high",
    "predicted_failure_date": "2026-02-15",
    "maintenance_scheduled": false,
    "notes": "Voltage fluctuations increasing. Inspect transformer connection.",
    "created_at": "2026-02-05T08:00:00Z",
    "poles": {
      "pole_number": "POLE-004",
      "location_name": "Velachery Junction"
    }
  }
]
```

---

## ⚡ EDGE FUNCTIONS

### Function: `assign-nearest-lineman`

**Endpoint:** `POST /functions/v1/assign-nearest-lineman`

**Purpose:** Automatically assigns fault to nearest available lineman using GPS coordinates

**Algorithm:**
1. Receives fault location (latitude, longitude)
2. Queries all linemen with `availability_status = 'available'`
3. Calculates distance using Haversine formula
4. Selects lineman with shortest distance
5. Updates fault: `assigned_to`, `status = 'assigned'`
6. Updates lineman: `availability_status = 'busy'`
7. Returns assignment details

**Request:**
```http
POST /functions/v1/assign-nearest-lineman
Authorization: Bearer YOUR-ANON-KEY
Content-Type: application/json

{
  "faultId": "fault-uuid-here",
  "faultLatitude": 13.0878,
  "faultLongitude": 80.2088,
  "priority": 8
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "assigned_to": "Rajesh Kumar",
  "lineman_id": "lineman-uuid-1",
  "distance": 2.45,
  "message": "Fault assigned to Rajesh Kumar (2.45 km away)"
}
```

**Error Responses:**

`404 Not Found` - No available linemen
```json
{
  "error": "No linemen available"
}
```

`500 Internal Server Error` - Database error
```json
{
  "error": "Database update failed: [error details]"
}
```

**Trigger Timing:**
- Automatically called after fault insertion
- Can be manually triggered from dashboard
- Retry on failure with exponential backoff

---

## 🔄 WORKFLOW EXAMPLES

### Complete Fault Detection & Resolution Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. FAULT DETECTION (ESP32)                              │
└─────────────────────────────────────────────────────────┘
   ↓
   POST /rest/v1/faults
   {
     "pole_id": "...",
     "fault_type": "voltage_drop",
     "priority_score": 8,
     "voltage_drop": 25.5
   }
   ↓
┌─────────────────────────────────────────────────────────┐
│ 2. AUTO-DISPATCH (Edge Function)                        │
└─────────────────────────────────────────────────────────┘
   ↓
   POST /functions/v1/assign-nearest-lineman
   {
     "faultId": "fault-uuid",
     "faultLatitude": 13.0878,
     "faultLongitude": 80.2088,
     "priority": 8
   }
   ↓
   Returns: "Assigned to Rajesh Kumar (2.45 km away)"
   ↓
┌─────────────────────────────────────────────────────────┐
│ 3. LINEMAN RECEIVES NOTIFICATION (Mobile App)           │
└─────────────────────────────────────────────────────────┘
   ↓
   GET /rest/v1/faults?assigned_to=eq.lineman-id
   ↓
   Displays: Fault details, location, priority
   ↓
┌─────────────────────────────────────────────────────────┐
│ 4. LINEMAN NAVIGATES (Mobile App GPS)                   │
└─────────────────────────────────────────────────────────┘
   ↓
   Every 30 seconds:
   PATCH /rest/v1/linemen?id=eq.lineman-id
   {
     "current_latitude": 13.0500,
     "current_longitude": 80.2300
   }
   ↓
┌─────────────────────────────────────────────────────────┐
│ 5. FAULT RESOLUTION (On-Site)                           │
└─────────────────────────────────────────────────────────┘
   ↓
   PATCH /rest/v1/faults?id=eq.fault-id
   {
     "status": "resolved",
     "resolved_at": "2026-02-06T11:00:00Z",
     "resolution_notes": "Replaced wire"
   }
   ↓
┌─────────────────────────────────────────────────────────┐
│ 6. LINEMAN MARKS AVAILABLE                              │
└─────────────────────────────────────────────────────────┘
   ↓
   PATCH /rest/v1/linemen?id=eq.lineman-id
   {
     "availability_status": "available"
   }
   ↓
   Ready for next assignment!
```

---

### Priority Calculation Logic

**Base Priority (1-10):**

```javascript
// Pseudo-code for ESP32/Edge Function
let priority = 5; // Default

// Voltage severity
if (voltage_drop > 50) priority += 3;
else if (voltage_drop > 20) priority += 2;
else if (voltage_drop > 10) priority += 1;

// Wire break (critical)
if (vibration_detected && voltage_drop > 100) priority = 10;

// Current spike (fire risk)
if (current_spike > 10) priority += 2;

// Time of day
const hour = new Date().getHours();
if (hour >= 6 && hour <= 22) priority += 1; // Daytime

// Location context (future enhancement)
if (near_school || near_hospital) priority = 10;

return Math.min(priority, 10); // Cap at 10
```

---

## ⚠️ ERROR HANDLING

### Common HTTP Status Codes

| Code | Meaning | Common Cause | Solution |
|------|---------|--------------|----------|
| 200 | OK | Successful GET request | - |
| 201 | Created | Successful POST request | - |
| 204 | No Content | Successful PATCH/DELETE | - |
| 400 | Bad Request | Invalid JSON or missing fields | Check request body |
| 401 | Unauthorized | Missing/invalid API key | Verify Authorization header |
| 403 | Forbidden | RLS policy blocked access | Check user permissions |
| 404 | Not Found | Resource doesn't exist | Verify UUID/endpoint |
| 409 | Conflict | Duplicate unique field | Change pole_number/employee_id |
| 500 | Server Error | Database/function error | Check Supabase logs |

### RLS Policy Errors

**Error:** "new row violates row-level security policy"
- **Cause:** Trying to insert/update data blocked by RLS
- **Solution:** Use correct authentication or service role key

**Error:** "permission denied for table"
- **Cause:** RLS enabled but no policies allow access
- **Solution:** Create appropriate policy or disable RLS temporarily

### Edge Function Errors

**Error:** "No linemen available"
- **Cause:** All linemen status = 'busy' or 'offline'
- **Solution:** Manual assignment or wait for lineman to become available

**Error:** "Invalid JWT"
- **Cause:** Using wrong API key type
- **Solution:** Use anon key for client calls, service role key only in Edge Functions

---

## 🧪 TESTING GUIDE

### Testing Tools

1. **Supabase SQL Editor** - Database queries
2. **Thunder Client** (VS Code) - API testing
3. **Postman** - Alternative API testing
4. **Browser Console** - Quick JavaScript tests

### Test Scenarios

#### Test 1: Insert Fault from IoT

```bash
# Using curl
curl -X POST 'https://zjgorwwogcanatbacecm.supabase.co/rest/v1/faults' \
-H "apikey: YOUR-ANON-KEY" \
-H "Authorization: Bearer YOUR-ANON-KEY" \
-H "Content-Type: application/json" \
-d '{
  "pole_id": "POLE-UUID-HERE",
  "fault_type": "voltage_drop",
  "priority_score": 7,
  "voltage_drop": 20.0,
  "status": "open"
}'
```

**Expected:** 201 Created with fault UUID

---

#### Test 2: Trigger Auto-Dispatch

```bash
curl -X POST 'https://zjgorwwogcanatbacecm.supabase.co/functions/v1/assign-nearest-lineman' \
-H "Authorization: Bearer YOUR-ANON-KEY" \
-H "Content-Type: application/json" \
-d '{
  "faultId": "FAULT-UUID-FROM-TEST-1",
  "faultLatitude": 13.0878,
  "faultLongitude": 80.2088,
  "priority": 7
}'
```

**Expected:** 200 OK with lineman name and distance

---

#### Test 3: Verify RLS (Should Block)

```bash
# Try to read linemen without auth
curl 'https://zjgorwwogcanatbacecm.supabase.co/rest/v1/linemen?select=*' \
-H "apikey: YOUR-ANON-KEY" \
-H "Authorization: Bearer YOUR-ANON-KEY"
```

**Expected:** `[]` (empty array - blocked by RLS)

---

#### Test 4: Read Poles (Should Allow)

```bash
curl 'https://zjgorwwogcanatbacecm.supabase.co/rest/v1/poles?select=*' \
-H "apikey: YOUR-ANON-KEY" \
-H "Authorization: Bearer YOUR-ANON-KEY"
```

**Expected:** Array of 5 poles

---

### Performance Benchmarks

**Target Metrics:**
- Fault insertion: < 200ms
- Auto-dispatch calculation: < 1 second
- GPS update: < 100ms
- Dashboard refresh: < 500ms

**Current Test Results:**
- Fault insertion: ~150ms ✅
- Auto-dispatch: ~800ms ✅
- GPS update: ~80ms ✅

---

## 📞 SUPPORT & RESOURCES

### Supabase Resources
- Dashboard: https://supabase.com/dashboard
- Documentation: https://supabase.com/docs
- API Reference: https://supabase.com/docs/reference/javascript

### Project-Specific
- Database: PostgreSQL 15
- Region: Southeast Asia (Singapore)
- Project ID: zjgorwwogcanatbacecm

### Troubleshooting
1. Check Supabase project logs
2. Verify RLS policies in SQL Editor
3. Test API endpoints with Thunder Client
4. Review Edge Function logs

---

## 🎯 NEXT STEPS

**Backend: ✅ Complete**

**To Build Next:**
1. Mobile App (Flutter) - Lineman interface
2. Web Dashboard (React) - Admin monitoring
3. IoT Code (ESP32) - Sensor integration
4. Push Notifications - Real-time alerts

---

**Last Updated:** February 6, 2026  
**Maintained By:** Smart Grid Development Team  
**License:** Internal Use - SIH Project

---
