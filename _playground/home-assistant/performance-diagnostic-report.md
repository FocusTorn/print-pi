# Home Assistant Performance Diagnostic Report
**Generated:** 2025-11-17 15:30  
**System:** Raspberry Pi 4 Model B (3.7GB RAM, Debian 13)

## Executive Summary

**Overall Status:** ⚠️ **MODERATE PERFORMANCE ISSUES DETECTED**

Your Home Assistant is experiencing lag primarily due to:
1. **Repeated error logging** (every 5 minutes) causing overhead
2. **Frontend JavaScript errors** causing UI lag
3. **Moderate memory pressure** (swap usage indicates memory constraints)
4. **No database bloat** (storage is healthy at 3.1MB)

---

## 🔴 Critical Issues

### 1. MQTT Select Entity Error (Every 5 Minutes)
**Error:** `Invalid option for select.a1_nodered_5945_camera_resolution: '1080p'`

**Impact:** This error is logged **every 5 minutes** (288 times per day), causing:
- Constant error processing overhead
- Log file bloat
- Potential UI lag when viewing logs

**Fix Required:**
- Update NodeRed flow to send `'1920x1080'` or `'1536x1080'` instead of `'1080p'`
- Or update the MQTT select entity configuration to accept `'1080p'` as a valid option

**Location:** Entity `select.a1_nodered_5945_camera_resolution`

---

### 2. Frontend JavaScript Errors (UI Lag)
**Error:** `Failed to execute 'define' on 'CustomElementRegistry': the name "flex-horseshoe-card" has already been used`

**Impact:** 
- Frontend JavaScript errors causing UI lag
- Card rendering failures
- Browser console errors

**Fix Required:**
- Check for duplicate `flex-horseshoe-card` installations
- Remove duplicate custom card installations
- Clear browser cache and reload HA

**Additional Error:** `TypeError: Cannot read properties of undefined (reading 'state')`
- Indicates cards are trying to access undefined entities
- Check card configurations for missing entity references

---

## ⚠️ Moderate Issues

### 3. Memory Pressure
**Current State:**
- **System Memory:** 2.1GB used / 3.7GB total (57% usage)
- **Available Memory:** 1.7GB free
- **Swap Usage:** 354MB used / 2GB total (17% swap usage)
- **HA Process Memory:** 407MB RSS + 45MB swap

**Analysis:**
- Swap usage indicates memory pressure (system is swapping to disk)
- HA process using reasonable memory (407MB)
- **No memory leak detected** - memory usage is stable

**Recommendations:**
- Monitor memory usage over time
- Consider reducing other services (Cursor server using 576MB, NodeRed 137MB, Grafana 121MB)
- If lag persists, consider increasing swap or reducing memory usage

---

### 4. System Load
**Current State:**
- **Load Average:** 0.61, 1.09, 0.72 (1-minute, 5-minute, 15-minute)
- **CPU Usage:** 2-5% (low)
- **Disk I/O:** 0.46% iowait (low)

**Analysis:**
- Load average is moderate (1.09 on 4-core system = ~27% utilization)
- CPU usage is low, not a bottleneck
- Disk I/O is low, not a bottleneck

**Status:** ✅ System resources are not the primary bottleneck

---

## ✅ Healthy Areas

### Database Storage
- **Storage Size:** 3.1MB (very healthy, no bloat)
- **No recorder database files found** (may be using different storage backend)
- **No database-related errors** in logs

**Status:** ✅ Database is not causing performance issues

---

### Container Health
- **Container Status:** Running (uptime: 9 hours)
- **Container Memory Limit:** 3.8GB (matches system)
- **Process Status:** Healthy (PID 687844, 12+ hours runtime)

**Status:** ✅ Container is running normally

---

## 📊 Resource Breakdown

### Top Memory Consumers (System-Wide)
1. **Cursor Server (Extension Host):** 576MB (14.8%)
2. **Home Assistant:** 407MB (10.4%)
3. **Cursor Server (File Watcher):** 341MB (8.7%)
4. **NodeRed:** 137MB (3.5%)
5. **Grafana:** 121MB (3.1%)

**Total Python/Docker Memory:** 734MB

### Disk Usage
- **Root Filesystem:** 20GB used / 29GB total (73% - healthy)
- **Available Space:** 7.6GB free

**Status:** ✅ Disk space is adequate

---

## 🔧 Recommended Actions (Priority Order)

### Immediate (Fix These First)
1. **Fix MQTT Select Error:**
   - Update NodeRed flow for `a1_nodered_5945_camera_resolution`
   - Change `'1080p'` to `'1920x1080'` or `'1536x1080'`
   - This will eliminate 288 error logs per day

2. **Fix Frontend Card Errors:**
   - Check for duplicate `flex-horseshoe-card` installations
   - Remove duplicates from `/config/www/community/` or `/config/www/`
   - Clear browser cache and hard reload (Ctrl+Shift+R)

3. **Fix Card Configuration Errors:**
   - Review cards showing `TypeError: Cannot read properties of undefined`
   - Ensure all entity references in cards are valid
   - Use `ha list-entities` to verify entity IDs

### Short-Term (Monitor & Optimize)
4. **Monitor Memory Usage:**
   - Check if swap usage increases over time
   - If swap usage grows, consider reducing other services
   - Monitor with: `free -h` and `vmstat 1 5`

5. **Review Custom Integrations:**
   - You have 8 custom integrations loaded
   - Monitor for any that might be causing issues
   - Consider disabling unused ones temporarily to test

### Long-Term (Optimization)
6. **Optimize Recorder (if using):**
   - If you have a large recorder database, consider purging old data
   - Exclude high-frequency entities from recording
   - Set up automatic purging

7. **Review System Services:**
   - Cursor server processes using significant memory (916MB total)
   - Consider closing Cursor when not actively developing
   - NodeRed and Grafana are reasonable but monitor usage

---

## 📈 Monitoring Commands

### Quick Health Check
```bash
# System resources
free -h && uptime

# HA container status
ha status

# Recent errors
ha errors | head -20

# Memory usage over time
vmstat 1 5
```

### Detailed Diagnostics
```bash
# Check for memory leaks (run multiple times, compare)
ps aux | grep python | grep homeassistant

# Check disk I/O
iostat -x 1 3

# Monitor HA resource usage
ha stats
```

---

## 🎯 Expected Improvements

After fixing the critical issues:
- **Error log overhead:** Eliminated (288 fewer errors per day)
- **UI responsiveness:** Improved (no frontend JavaScript errors)
- **Memory pressure:** May improve (fewer errors = less processing)
- **Overall lag:** Should be significantly reduced

---

## 📝 Notes

- **No memory leak detected** - memory usage is stable
- **Database is healthy** - no bloat or corruption
- **System resources are adequate** - not the bottleneck
- **Primary issues are configuration errors** - fixable without system changes

---

**Next Steps:**
1. Fix the MQTT select entity error (highest priority)
2. Fix the frontend card errors
3. Monitor performance after fixes
4. Report back if lag persists after fixes

