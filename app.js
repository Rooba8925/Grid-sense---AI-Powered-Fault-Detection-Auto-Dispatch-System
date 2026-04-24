// ============================================
// SMART GRID ADMIN DASHBOARD - app.js
// ============================================

// Update current time display
function updateTime() {
    const now = new Date();
    document.getElementById('current-time').textContent = 
        now.toLocaleTimeString('en-IN', { 
            hour: '2-digit', 
            minute: '2-digit',
            second: '2-digit'
        });
}
setInterval(updateTime, 1000);
updateTime();

// ============================================
// LOAD ALL DASHBOARD DATA
// ============================================
async function loadDashboard() {
    console.log('Loading dashboard data...');
    await Promise.all([
        loadStats(),
        loadFaults(),
        loadLinemen()
    ]);
}

// ============================================
// LOAD STATISTICS
// ============================================
async function loadStats() {
    try {
        // Total Poles
        const polesResponse = await supabase
            .from('poles')
            .select('id', { count: 'exact' });
        
        document.getElementById('total-poles').textContent = polesResponse.count || 0;

        // Active Faults
        const activeFaultsResponse = await supabase
            .from('faults')
            .select('id', { count: 'exact' })
            .in('status', ['open', 'assigned']);
        
        document.getElementById('active-faults').textContent = activeFaultsResponse.count || 0;

        // Available Linemen
        const linemenResponse = await supabase
            .from('linemen')
            .select('id', { count: 'exact' })
            .eq('availability_status', 'available');
        
        document.getElementById('available-linemen').textContent = linemenResponse.count || 0;

        // ✅ FIXED: Average Response Time
        const resolvedFaultsResponse = await supabase
            .from('faults')
            .select('created_at, resolved_at')
            .eq('status', 'resolved')
            .not('resolved_at', 'is', null);  // Only get faults with resolved_at timestamp

        if (resolvedFaultsResponse.data && resolvedFaultsResponse.data.length > 0) {
            let totalResponseTime = 0;
            let validCount = 0;

            resolvedFaultsResponse.data.forEach(fault => {
                if (fault.created_at && fault.resolved_at) {
                    const createdAt = new Date(fault.created_at);
                    const resolvedAt = new Date(fault.resolved_at);
                    const responseTime = (resolvedAt - createdAt) / 1000 / 60; // Convert to minutes
                    
                    if (responseTime > 0 && responseTime < 10000) { // Sanity check (less than ~7 days)
                        totalResponseTime += responseTime;
                        validCount++;
                    }
                }
            });

            if (validCount > 0) {
                const avgMinutes = Math.round(totalResponseTime / validCount);
                document.getElementById('avg-response').textContent = `${avgMinutes} min`;
            } else {
                document.getElementById('avg-response').textContent = '0 min';
            }
        } else {
            document.getElementById('avg-response').textContent = '0 min';
        }

    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// Predictive Maintenance Analysis
async function loadPredictiveMaintenance() {
    try {
        // Get all poles
        const polesResponse = await supabase
            .from('poles')
            .select('*');

        if (!polesResponse.data) return;

        const poles = polesResponse.data;
        const predictiveData = [];

        // Analyze each pole
        for (const pole of poles) {
            // Get all faults for this pole
            const faultsResponse = await supabase
                .from('faults')
                .select('*')
                .eq('pole_id', pole.id)
                .order('created_at', { ascending: false });

            if (!faultsResponse.data || faultsResponse.data.length === 0) {
                continue; // Skip poles with no faults
            }

            const faults = faultsResponse.data;
            const faultCount = faults.length;

            // Calculate time-based metrics
            const now = new Date();
            const last30Days = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
            const last7Days = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

            const recentFaults = faults.filter(f => 
                new Date(f.created_at) > last7Days
            ).length;

            const monthlyFaults = faults.filter(f => 
                new Date(f.created_at) > last30Days
            ).length;

            // Count repeating fault types
            const faultTypes = {};
            faults.forEach(f => {
                faultTypes[f.fault_type] = (faultTypes[f.fault_type] || 0) + 1;
            });

            const repeatingTypes = Object.values(faultTypes).filter(count => count >= 3).length;

            // ✅ FIXED RISK SCORE CALCULATION (MAX 10)
            const riskScore = calculateRiskScore(faultCount, recentFaults, monthlyFaults, repeatingTypes);

            // Determine risk level
            let riskLevel, riskClass, prediction, recommendation;

            if (riskScore >= 7) {
                riskLevel = 'HIGH RISK';
                riskClass = 'high-risk';
                prediction = `High risk of failure within 7 days. ${faultCount} faults recorded.`;
                recommendation = 'Schedule immediate inspection and preventive maintenance';
            } else if (riskScore >= 4) {
                riskLevel = 'MEDIUM RISK';
                riskClass = 'medium-risk';
                prediction = `Medium risk. ${faultCount} faults in last 30 days.`;
                recommendation = 'Include in next scheduled maintenance round';
            } else {
                riskLevel = 'LOW RISK';
                riskClass = 'low-risk';
                prediction = `Low risk. ${faultCount} minor issues detected.`;
                recommendation = 'Continue routine monitoring';
            }

            predictiveData.push({
                pole,
                riskScore,
                riskLevel,
                riskClass,
                faultCount,
                recentFaults,
                prediction,
                recommendation
            });
        }

        // Sort by risk score (highest first)
        predictiveData.sort((a, b) => b.riskScore - a.riskScore);

        // Display top risky poles
        displayPredictiveCards(predictiveData.slice(0, 4));

    } catch (error) {
        console.error('Error loading predictive maintenance:', error);
    }
}

// ✅ UPDATED RISK SCORE CALCULATION - ENSURES MAX 10
function calculateRiskScore(totalFaults, recentFaults, monthlyFaults, repeatingTypes) {
    let score = 0;
    
    // Component 1: Total fault count (max 3 points)
    // 1-2 faults = 1 point, 3-5 faults = 2 points, 6+ faults = 3 points
    if (totalFaults >= 6) {
        score += 3;
    } else if (totalFaults >= 3) {
        score += 2;
    } else if (totalFaults >= 1) {
        score += 1;
    }
    
    // Component 2: Recent activity (last 7 days) (max 3 points)
    // 1 fault = 1 point, 2 faults = 2 points, 3+ faults = 3 points
    if (recentFaults >= 3) {
        score += 3;
    } else if (recentFaults >= 2) {
        score += 2;
    } else if (recentFaults >= 1) {
        score += 1;
    }
    
    // Component 3: Monthly pattern (last 30 days) (max 2 points)
    // 3-5 faults = 1 point, 6+ faults = 2 points
    if (monthlyFaults >= 6) {
        score += 2;
    } else if (monthlyFaults >= 3) {
        score += 1;
    }
    
    // Component 4: Repeating fault types (max 2 points)
    // Same fault type occurs 3+ times = chronic issue
    if (repeatingTypes >= 2) {
        score += 2;
    } else if (repeatingTypes >= 1) {
        score += 1;
    }
    
    // Total max score = 3 + 3 + 2 + 2 = 10 points
    // Ensure it never exceeds 10
    return Math.min(score, 10);
}

function displayPredictiveCards(predictiveData) {
    const container = document.getElementById('predictiveCards');
    
    if (!predictiveData || predictiveData.length === 0) {
        container.innerHTML = `
            <div style="
                grid-column: 1 / -1;
                text-align: center;
                padding: 40px;
                color: #27ae60;
                font-size: 16px;
            ">
                <div style="font-size: 48px; margin-bottom: 15px;">✅</div>
                <div style="font-weight: bold; margin-bottom: 8px;">All Poles Healthy</div>
                <div style="color: #7f8c8d; font-size: 14px;">No high-risk poles detected. Continue routine monitoring.</div>
            </div>
        `;
        return;
    }

    container.innerHTML = predictiveData.map(data => {
        const { pole, riskScore, riskLevel, riskClass, prediction, recommendation } = data;
        
        // Determine color based on risk level
        let color;
        if (riskClass === 'high-risk') {
            color = '#e74c3c';
        } else if (riskClass === 'medium-risk') {
            color = '#f39c12';
        } else {
            color = '#27ae60';
        }

        return `
            <div class="predictive-card ${riskClass}" style="border-left: 4px solid ${color}">
                <div style="display: flex; justify-content: space-between; align-items: start;">
                    <div style="flex: 1;">
                        <h4 style="margin: 0 0 8px; font-size: 18px;">${pole.pole_number}</h4>
                        <p style="margin: 4px 0; color: #7f8c8d; font-size: 14px;">
                            📍 ${pole.location_name}
                        </p>
                        <p style="margin: 8px 0; color: #34495e; font-size: 14px;">
                            <strong>Prediction:</strong> ${prediction}
                        </p>
                        <p style="margin: 4px 0; color: #34495e; font-size: 14px;">
                            <strong>Recommendation:</strong> ${recommendation}
                        </p>
                        <p style="margin: 8px 0 0; color: #7f8c8d; font-size: 13px;">
                            <strong>Risk Score:</strong> ${riskScore}/10
                        </p>
                    </div>
                    <div style="text-align: right;">
                        <span class="risk-badge ${riskClass}">${riskLevel}</span>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}



// Call this function on page load
document.addEventListener('DOMContentLoaded', () => {
  // ... existing code ...
  loadPredictiveMaintenance();
  
  // Refresh every 5 minutes
  setInterval(loadPredictiveMaintenance, 5 * 60 * 1000);
});

// ============================================
// LOAD ACTIVE FAULTS TABLE
// ============================================
async function loadFaults() {

    try {
        const tbody = document.getElementById('faults-tbody');
        tbody.innerHTML = '<tr><td colspan="6" class="loading">Loading...</td></tr>';
        console.log('🔍 Attempting to load faults...');
        console.log('🔍 Supabase client:', supabase);
        // Try fetching ALL faults first (no filters)
        const { data: allFaults, error: allError } = await supabase
            .from('faults')
            .select('*');
        
        console.log('🔍 ALL faults query result:', allFaults);
        console.log('🔍 ALL faults error:', allError);

        // Step 1: Get all active faults
        const { data: faults, error: faultsError } = await supabase
            .from('faults')
            .select('*')
            .eq('status', 'assigned')
            .order('priority_score', { ascending: false });
            
        console.log('🔍 Assigned faults query result:', faults);
        console.log('🔍 Assigned faults error:', faultsError);

        if (faultsError) {
            console.error('Faults error:', faultsError);
            tbody.innerHTML = '<tr><td colspan="6" class="loading">Error loading faults</td></tr>';
            return;
        }

        console.log('✅ Faults loaded:', faults?.length || 0);
        document.getElementById('fault-count').textContent = faults?.length || 0;


        if (!faults || faults.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" class="loading">No active faults</td></tr>';
            return;
        }

        // Step 2: Get pole and lineman info for each fault
        const faultsWithDetails = await Promise.all(
            faults.map(async (fault) => {
                // Get pole info
                let poleName = 'Unknown';
                let poleLocation = 'Unknown';
                if (fault.pole_id) {
                    const { data: pole } = await supabase
                        .from('poles')
                        .select('pole_number, location_name')
                        .eq('id', fault.pole_id)
                        .single();
                    if (pole) {
                        poleName = pole.pole_number;
                        poleLocation = pole.location_name;
                    }
                }

                // Get lineman info
                let linemanName = 'Unassigned';
                if (fault.assigned_to) {
                    const { data: lineman } = await supabase
                        .from('linemen')
                        .select('name')
                        .eq('id', fault.assigned_to)
                        .single();
                    if (lineman) linemanName = lineman.name;
                }

                return { ...fault, poleName, poleLocation, linemanName };
            })
        );

        // Step 3: Render the table
        tbody.innerHTML = faultsWithDetails.map(fault => `
            <tr>
                <td>
                    <span class="priority-badge priority-${getPriorityClass(fault.priority_score)}">
                        ${getPriorityLabel(fault.priority_score)}
                    </span>
                </td>
                <td><strong>${fault.poleName}</strong></td>
                <td>${formatFaultType(fault.fault_type)}</td>
                <td>${fault.poleLocation}</td>
                <td>
                    <span style="color: ${fault.assigned_to ? '#4CAF50' : '#f44336'}">
                        ${fault.linemanName}
                    </span>
                </td>
                <td>${formatTime(fault.detected_at)}</td>
            </tr>
        `).join('');

    } catch (error) {
        console.error('Error loading faults:', error);
    }
}

// Load linemen status
async function loadLinemenStatus() {
    try {
        const { data: linemen, error } = await supabase
            .from('linemen')
            .select(`
                *,
                active_faults:faults!assigned_to(count),
                resolved_faults:faults!assigned_to(count)
            `)
            .eq('faults.status', 'assigned')
            .order('name');

        if (error) throw error;

        displayLinemenCards(linemen || []);
    } catch (error) {
        console.error('Error loading linemen:', error);
    }
}

function displayLinemenCards(linemen) {
    const container = document.getElementById('linemenGrid');
    
    if (!linemen || linemen.length === 0) {
        container.innerHTML = `
            <div style="grid-column: 1 / -1; text-align: center; padding: 40px; color: #95a5a6;">
                No linemen found
            </div>
        `;
        return;
    }

    container.innerHTML = linemen.map(lineman => {
        const isAvailable = lineman.availability_status === 'available';
        const statusColor = isAvailable ? '#27ae60' : '#f39c12';
        const statusIcon = isAvailable ? '✅' : '⚠️';
        
        return `
            <div class="lineman-card" style="
                background: white;
                padding: 20px;
                border-radius: 12px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.05);
                border-left: 4px solid ${statusColor};
                cursor: pointer;
                transition: transform 0.2s, box-shadow 0.2s;
            " onclick="showLinemanDetails('${lineman.id}')">
                <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 16px;">
                    <div style="
                        width: 50px;
                        height: 50px;
                        border-radius: 50%;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        color: white;
                        font-size: 24px;
                        font-weight: bold;
                    ">
                        ${lineman.name.charAt(0)}
                    </div>
                    <div style="flex: 1;">
                        <div style="font-weight: bold; font-size: 16px; color: #2c3e50;">
                            ${lineman.name}
                        </div>
                        <div style="color: #7f8c8d; font-size: 12px;">
                            ID: ${lineman.employee_id}
                        </div>
                    </div>
                </div>
                
                <div style="
                    display: inline-block;
                    padding: 4px 12px;
                    border-radius: 16px;
                    background: ${statusColor}20;
                    color: ${statusColor};
                    font-size: 12px;
                    font-weight: 600;
                    margin-bottom: 16px;
                ">
                    ${statusIcon} ${isAvailable ? 'Available' : 'Busy'}
                </div>
                
                <div style="display: flex; justify-content: space-between; margin-top: 12px; padding-top: 12px; border-top: 1px solid #ecf0f1;">
                    <div style="text-align: center; flex: 1;">
                        <div style="font-size: 20px; font-weight: bold; color: #27ae60;">
                            ${lineman.total_faults_resolved || 0}
                        </div>
                        <div style="font-size: 11px; color: #95a5a6;">
                            Resolved
                        </div>
                    </div>
                    <div style="text-align: center; flex: 1;">
                        <div style="font-size: 20px; font-weight: bold; color: #f39c12;">
                            ${lineman.active_faults?.[0]?.count || 0}
                        </div>
                        <div style="font-size: 11px; color: #95a5a6;">
                            Active
                        </div>
                    </div>
                </div>
                
                <div style="
                    margin-top: 12px;
                    padding: 8px;
                    background: #ecf0f1;
                    border-radius: 6px;
                    text-align: center;
                    color: #3498db;
                    font-size: 12px;
                    font-weight: 600;
                ">
                    Click for details →
                </div>
            </div>
        `;
    }).join('');
}

// Show lineman details (you can make this open a modal or navigate)
// Show lineman details - NAVIGATE to detail page
function showLinemanDetails(linemanId) {
    window.location.href = `lineman-detail.html?id=${linemanId}`;
}

// Call this in your init function
loadLinemenStatus();

// ============================================
// ESCALATION SYSTEM
// ============================================

async function loadEscalations() {
    try {
        const { data: escalations, error } = await supabase
            .from('fault_escalations')
            .select(`
                *,
                faults (
                    id,
                    fault_type,
                    priority_score,
                    created_at,
                    poles!faults_pole_id_fkey (
                        pole_number,
                        location_name
                    )
                ),
                linemen:assigned_lineman_id (
                    name,
                    employee_id,
                    phone_number
                )
            `)
            .eq('resolved', false)
            .order('escalated_at', { ascending: false });

        if (error) throw error;

        displayEscalations(escalations || []);
    } catch (error) {
        console.error('Error loading escalations:', error);
        document.getElementById('escalationsContainer').innerHTML = `
            <div style="padding: 40px; text-align: center; color: #e74c3c;">
                <div style="font-size: 48px; margin-bottom: 16px;">❌</div>
                <div style="font-weight: bold; margin-bottom: 8px;">Failed to Load Escalations</div>
                <div style="color: #95a5a6; font-size: 14px;">${error.message}</div>
            </div>
        `;
    }
}

function displayEscalations(escalations) {
    const container = document.getElementById('escalationsContainer');
    const badge = document.getElementById('escalationBadge');
    
    // Update badge count
    badge.textContent = escalations.length;

    if (!escalations || escalations.length === 0) {
        container.innerHTML = `
            <div style="padding: 40px; text-align: center; color: #27ae60;">
                <div style="font-size: 48px; margin-bottom: 16px;">✅</div>
                <div style="font-weight: bold; margin-bottom: 8px;">No Escalated Faults</div>
                <div style="color: #95a5a6; font-size: 14px;">All faults are being handled on time</div>
            </div>
        `;
        return;
    }

    const tableHTML = `
        <table style="width: 100%; border-collapse: collapse;">
            <thead>
                <tr style="background: #fee; border-bottom: 2px solid #e74c3c;">
                    <th style="padding: 14px; text-align: left; color: #e74c3c; font-weight: 600; font-size: 13px;">POLE</th>
                    <th style="padding: 14px; text-align: left; color: #e74c3c; font-weight: 600; font-size: 13px;">LOCATION</th>
                    <th style="padding: 14px; text-align: left; color: #e74c3c; font-weight: 600; font-size: 13px;">FAULT TYPE</th>
                    <th style="padding: 14px; text-align: left; color: #e74c3c; font-weight: 600; font-size: 13px;">ASSIGNED TO</th>
                    <th style="padding: 14px; text-align: left; color: #e74c3c; font-weight: 600; font-size: 13px;">REASON</th>
                    <th style="padding: 14px; text-align: left; color: #e74c3c; font-weight: 600; font-size: 13px;">ESCALATED</th>
                    <th style="padding: 14px; text-align: center; color: #e74c3c; font-weight: 600; font-size: 13px;">ACTION</th>
                </tr>
            </thead>
            <tbody>
                ${escalations.map((esc, index) => {
                    const fault = esc.faults || {};
                    const pole = fault.poles || {};
                    const lineman = esc.linemen || {};
                    const priority = fault.priority_score || 5;
                    const priorityColor = priority >= 9 ? '#e74c3c' : priority >= 7 ? '#f39c12' : '#f1c40f';

                    return `
                        <tr style="
                            border-bottom: 1px solid #ecf0f1;
                            ${index % 2 === 0 ? 'background: #fafafa;' : ''}
                        ">
                            <td style="padding: 16px; font-weight: 600;">
                                ${pole.pole_number || 'Unknown'}
                            </td>
                            <td style="padding: 16px; color: #7f8c8d; font-size: 14px;">
                                📍 ${pole.location_name || 'Unknown location'}
                            </td>
                            <td style="padding: 16px;">
                                <div style="display: flex; flex-direction: column; gap: 4px;">
                                    <span style="
                                        background: ${priorityColor}20;
                                        color: ${priorityColor};
                                        padding: 4px 10px;
                                        border-radius: 6px;
                                        font-size: 12px;
                                        font-weight: 600;
                                        display: inline-block;
                                        width: fit-content;
                                    ">
                                        ${fault.fault_type || 'Unknown'}
                                    </span>
                                    <span style="color: #95a5a6; font-size: 11px;">
                                        Priority: ${priority}/10
                                    </span>
                                </div>
                            </td>
                            <td style="padding: 16px;">
                                <div style="font-weight: 600; color: #2c3e50;">
                                    ${lineman.name || 'Unknown'}
                                </div>
                                <div style="color: #95a5a6; font-size: 12px;">
                                    ${lineman.employee_id || 'N/A'}
                                </div>
                            </td>
                            <td style="padding: 16px; font-size: 13px; color: #e74c3c; max-width: 200px;">
                                <strong>${esc.escalation_reason || 'No reason provided'}</strong>
                            </td>
                            <td style="padding: 16px; font-size: 13px; color: #7f8c8d;">
                                ${formatTimeAgo(esc.escalated_at)}
                            </td>
                            <td style="padding: 16px; text-align: center;">
                                ${esc.acknowledged ? `
                                    <span style="
                                        padding: 6px 12px;
                                        background: #d5f4e6;
                                        color: #27ae60;
                                        border-radius: 6px;
                                        font-size: 12px;
                                        font-weight: 600;
                                    ">
                                        ✓ Acknowledged
                                    </span>
                                ` : `
                                    <button onclick="handleAcknowledge('${esc.id}', ${JSON.stringify(lineman).replace(/"/g, '&quot;')})"
                                    style="
                                        padding: 8px 16px;
                                        background: #3498db;
                                        color: white;
                                        border: none;
                                        border-radius: 6px;
                                        cursor: pointer;
                                        font-size: 13px;
                                        font-weight: 600;
                                        transition: background 0.2s;
                                    " onmouseover="this.style.background='#2980b9'" onmouseout="this.style.background='#3498db'">
                                        Acknowledge
                                    </button>
                                `}
                            </td>
                        </tr>
                    `;
                }).join('')}
            </tbody>
        </table>
    `;
    
    container.innerHTML = tableHTML;
}

function formatTimeAgo(timestamp) {
    const now = new Date();
    const past = new Date(timestamp);
    const diffMs = now - past;
    const diffMins = Math.floor(diffMs / 60000);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins} min ago`;
    
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours} hr${diffHours > 1 ? 's' : ''} ago`;
    
    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
}

async function acknowledgeEscalation(escalationId) {
    if (!confirm('Acknowledge this escalation? This will mark it as reviewed by supervisor.')) {
        return;
    }

    try {
        const { error } = await supabase
            .from('fault_escalations')
            .update({
                acknowledged: true,
                acknowledged_at: new Date().toISOString()
            })
            .eq('id', escalationId);

        if (error) throw error;

        // Show success message
        alert('✅ Escalation acknowledged successfully!');
        
        // Reload escalations
        await loadEscalations();
    } catch (error) {
        console.error('Error acknowledging escalation:', error);
        alert('❌ Failed to acknowledge escalation: ' + error.message);
    }
}

// Manual escalation check button
async function runEscalationCheck() {
    if (!confirm('Run escalation check now? This will check all assigned faults and create escalations for delayed responses.')) {
        return;
    }

    try {
        // Call the escalation function
        const { data, error } = await supabase.rpc('auto_escalate_stale_faults');
        
        if (error) throw error;

        alert('✅ Escalation check completed!');
        await loadEscalations(); // Reload to show new escalations
    } catch (error) {
        console.error('Error running escalation check:', error);
        alert('❌ Failed to run escalation check: ' + error.message);
    }
}

//=====================================
// HELPER FUNCTIONS
// ============================================
function getPriorityClass(score) {
    if (score >= 9) return 'critical';
    if (score >= 7) return 'high';
    if (score >= 5) return 'medium';
    return 'low';
}

function getPriorityLabel(score) {
    if (score >= 9) return 'CRITICAL';
    if (score >= 7) return 'HIGH';
    if (score >= 5) return 'MEDIUM';
    return 'LOW';
}

function formatFaultType(type) {
    const types = {
        'voltage_drop': 'Voltage Drop',
        'current_leakage': 'Current Leakage',
        'wire_break': 'Wire Break',
        'overload': 'Overload',
        'transformer_fault': 'Transformer Fault'
    };
    return types[type] || type;
}

function formatTime(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diff = Math.floor((now - date) / 1000 / 60);
    
    if (diff < 60) return `${diff} min ago`;
    if (diff < 1440) return `${Math.floor(diff / 60)} hr ago`;
    return `${Math.floor(diff / 1440)} days ago`;
}

function refreshMap() {
    console.log('Refreshing dashboard...');
    loadDashboard();
}

// ============================================
// REAL-TIME SUBSCRIPTION
// ============================================
function setupRealtime() {
    console.log('Setting up real-time updates...');
    
    supabase
        .channel('smart-grid-changes')
        .on('postgres_changes', 
            { event: '*', schema: 'public', table: 'faults' },
            (payload) => {

                console.log("🔥 Realtime triggered:", payload);

        // FORCE EMAIL (for testing)
                console.log("📧 Sending email...");
                sendEmailNotification(payload.new);
            }
        )
        .on('postgres_changes',
            { event: '*', schema: 'public', table: 'linemen' },
            (payload) => {
                console.log('Lineman changed:', payload);
                loadLinemen();
                loadStats();
            }
        )
        .subscribe((status) => {
            console.log('Realtime status:', status);
        });
}

// ============================================
// INITIALIZE DASHBOARD
// ============================================
document.addEventListener('DOMContentLoaded', async () => {
    console.log('Dashboard initializing...');
    
    // Initialize map
    initMap();
    
    // Load dashboard data
    await loadDashboard();
    
    // Setup real-time updates
    setupRealtime();
    
    // Refresh every 30 seconds
    setInterval(() => {
        loadDashboard();
        loadMapData();
    }, 30000);
    
    console.log('Dashboard ready!');
});

// ============================================
// LEAFLET MAP (FREE - No API Key needed!)
// ============================================
let map = null;
let markers = [];

function initMap() {
    // Chennai center coordinates
    map = L.map('map').setView([13.0827, 80.2707], 12);

    // OpenStreetMap tiles (FREE!)
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
    }).addTo(map);

    console.log('Map initialized!');
    
    // Load poles and linemen on map
    loadMapData();
}

async function loadMapData() {
    if (!map) return;

    // Clear existing markers
    markers.forEach(m => map.removeLayer(m));
    markers = [];

    // 1. Load poles FIRST (as background layer)
    const { data: poles } = await supabase
        .from('poles')
        .select('*');

    const poleLocations = new Set(); // Track pole locations

    if (poles) {
        poles.forEach(pole => {
            if (pole.latitude && pole.longitude) {
                poleLocations.add(`${pole.latitude},${pole.longitude}`);
                
                const poleIcon = L.divIcon({
                    html: `
                        <div style="
                            background: #4CAF50;
                            color: white;
                            border-radius: 50%;
                            width: 30px;
                            height: 30px;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                            font-size: 14px;
                            border: 2px solid white;
                            box-shadow: 0 2px 4px rgba(0,0,0,0.3);
                        ">📍</div>
                    `,
                    className: '',
                    iconSize: [30, 30],
                    iconAnchor: [15, 15],
                });

                const marker = L.marker(
                    [pole.latitude, pole.longitude],
                    { icon: poleIcon, zIndexOffset: 0 }
                ).addTo(map);

                marker.bindPopup(`
                    <div style="font-family: sans-serif; min-width: 150px;">
                        <strong style="color: #4CAF50;">📍 ${pole.pole_number}</strong><br/>
                        <span>${pole.location_name}</span><br/>
                        <small style="color: #666;">
                            ${pole.latitude.toFixed(4)}, ${pole.longitude.toFixed(4)}
                        </small><br/>
                        <span style="
                            background: #4CAF50;
                            color: white;
                            padding: 2px 8px;
                            border-radius: 10px;
                            font-size: 11px;
                        ">ACTIVE</span>
                    </div>
                `);

                markers.push(marker);
            }
        });
    }

    // 2. Load FAULTS on top (higher z-index, larger icon)
    const { data: faults } = await supabase
        .from('faults')
        .select(`
            *,
            poles!faults_pole_id_fkey (
                latitude,
                longitude,
                pole_number,
                location_name
            )
        `)
        .eq('status', 'assigned');

    console.log('Faults on map:', faults);
    console.log("Supabase URL:", supabase.supabaseUrl);

    if (faults && faults.length > 0) {
        faults.forEach(fault => {
            const pole = fault.poles;
            console.log('Processing fault:', fault.id, 'Pole:', pole);
            
            if (pole && pole.latitude && pole.longitude) {
                // Determine color based on priority
                let bgColor = '#FFC107'; // Yellow
                if (fault.priority_score >= 9) bgColor = '#f44336'; // Red
                else if (fault.priority_score >= 7) bgColor = '#FF9800'; // Orange

                const faultIcon = L.divIcon({
                    html: `
                        <div style="
                            background: ${bgColor};
                            color: white;
                            border-radius: 50%;
                            width: 50px;
                            height: 50px;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                            font-size: 24px;
                            border: 4px solid white;
                            box-shadow: 0 3px 10px rgba(0,0,0,0.5);
                            animation: pulse 1.5s infinite;
                            position: relative;
                            z-index: 1000;
                        ">⚠️</div>
                        <style>
                            @keyframes pulse {
                                0%, 100% { transform: scale(1); opacity: 1; }
                                50% { transform: scale(1.1); opacity: 0.8; }
                            }
                        </style>
                    `,
                    className: '',
                    iconSize: [50, 50],
                    iconAnchor: [25, 25],
                });

                const marker = L.marker(
                    [pole.latitude, pole.longitude],
                    { 
                        icon: faultIcon,
                        zIndexOffset: 1000 // Put faults on top!
                    }
                ).addTo(map);

                marker.bindPopup(`
                    <div style="font-family: sans-serif; min-width: 200px;">
                        <div style="
                            background: ${bgColor};
                            color: white;
                            padding: 8px;
                            margin: -10px -10px 10px -10px;
                            border-radius: 4px 4px 0 0;
                        ">
                            <strong>⚠️ ACTIVE FAULT</strong>
                        </div>
                        <strong style="font-size: 16px;">${pole.pole_number}</strong><br/>
                        <span>${pole.location_name}</span><br/>
                        <hr style="margin: 8px 0; border: 0; border-top: 1px solid #ddd;"/>
                        <div style="display: grid; gap: 4px;">
                            <div><strong>Type:</strong> ${formatFaultType(fault.fault_type)}</div>
                            <div><strong>Priority:</strong> 
                                <span style="
                                    background: ${bgColor};
                                    color: white;
                                    padding: 2px 8px;
                                    border-radius: 10px;
                                    font-size: 11px;
                                    font-weight: bold;
                                ">${getPriorityLabel(fault.priority_score)}</span>
                            </div>
                            <div><strong>Status:</strong> ${fault.status.toUpperCase()}</div>
                            ${fault.voltage_drop ? `<div><strong>Voltage Drop:</strong> ${fault.voltage_drop.toFixed(1)}V</div>` : ''}
                            ${fault.current_spike ? `<div><strong>Current:</strong> ${fault.current_spike.toFixed(1)}A</div>` : ''}
                        </div>
                        <hr style="margin: 8px 0; border: 0; border-top: 1px solid #ddd;"/>
                        <small style="color: #666;">
                            Detected: ${formatTime(fault.detected_at)}
                        </small>
                    </div>
                `);

                markers.push(marker);
                
                console.log('✅ Added fault marker:', fault.id, 'at', pole.latitude, pole.longitude);
            } else {
                console.log('❌ No pole coordinates for fault:', fault.id);
            }
        });
    } else {
        console.log('No active faults to display on map');
    }

    // 3. Load linemen locations (medium z-index)
    const { data: linemen } = await supabase
        .from('linemen')
        .select('*')
        .not('current_latitude', 'is', null);

    if (linemen) {
        linemen.forEach(lineman => {
            if (lineman.current_latitude && lineman.current_longitude) {
                const linemanIcon = L.divIcon({
                    html: `
                        <div style="
                            background: ${lineman.availability_status === 'available' ? '#4CAF50' : '#FF9800'};
                            color: white;
                            border-radius: 50%;
                            width: 40px;
                            height: 40px;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                            font-size: 20px;
                            border: 3px solid white;
                            box-shadow: 0 2px 6px rgba(0,0,0,0.4);
                        ">👷</div>
                    `,
                    className: '',
                    iconSize: [40, 40],
                    iconAnchor: [20, 20],
                });

                const marker = L.marker(
                    [lineman.current_latitude, lineman.current_longitude],
                    { 
                        icon: linemanIcon,
                        zIndexOffset: 500 // Medium priority
                    }
                ).addTo(map);

                marker.bindPopup(`
                    <div style="font-family: sans-serif; min-width: 180px;">
                        <strong style="color: #1976D2; font-size: 16px;">👷 ${lineman.name}</strong><br/>
                        <span style="color: #666;">ID: ${lineman.employee_id}</span><br/>
                        <hr style="margin: 8px 0; border: 0; border-top: 1px solid #ddd;"/>
                        <div style="display: grid; gap: 4px;">
                            <div><strong>Status:</strong> 
                                <span style="
                                    background: ${lineman.availability_status === 'available' ? '#4CAF50' : '#FF9800'};
                                    color: white;
                                    padding: 2px 8px;
                                    border-radius: 10px;
                                    font-size: 11px;
                                ">${lineman.availability_status.toUpperCase()}</span>
                            </div>
                            <div><strong>Phone:</strong> ${lineman.phone}</div>
                            <div><strong>Resolved:</strong> ${lineman.total_faults_resolved} faults</div>
                            ${lineman.avg_response_time ? `<div><strong>Avg Time:</strong> ${lineman.avg_response_time} min</div>` : ''}
                        </div>
                        <hr style="margin: 8px 0; border: 0; border-top: 1px solid #ddd;"/>
                        <small style="color: #4CAF50;">
                            📍 ${lineman.current_latitude.toFixed(5)}, ${lineman.current_longitude.toFixed(5)}
                        </small>
                    </div>
                `);

                markers.push(marker);
            }
        });
    }

    console.log(`✅ Map loaded: ${poles?.length || 0} poles, ${faults?.length || 0} faults, ${linemen?.length || 0} linemen`);
}

function refreshMap() {
    loadMapData();
    loadDashboard();
}
function sendEmailNotification(fault) {
console.log("📧 FUNCTION CALLED");
    emailjs.send(
        "service_5twyjo3",     // your service ID
        "template_iuykqum",    // your template ID
        {
            pole_id: fault.pole_id,
            time: new Date().toLocaleString()
        },
        "Aib29ZmI6z6NNXnTd"    // your public key
    )
    .then(() => {
        console.log("✅ Email sent!");
    })
    .catch((error) => {
        console.error("❌ Email failed:", error);
    });
}
function showLinemanActions(lineman) {
    const modal = `
        <div id="linemanModal" style="
            position: fixed;
            top: 0; left: 0;
            width: 100%; height: 100%;
            background: rgba(0,0,0,0.6);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
        ">
            <div style="
                background: white;
                padding: 25px;
                border-radius: 12px;
                width: 300px;
                text-align: center;
            ">
                <h3 style="margin-bottom: 8px;">${lineman.name}</h3>
                <p style="color:#7f8c8d;">${lineman.employee_id}</p>
                
                 <p style="
                    font-size: 18px;
                    margin: 20px 0;
                    color: #2c3e50;
                    font-weight: bold;
                ">
                    📞 Call this number:
                </p>
                
                <p style="
                    font-size: 20px;
                    color:#3498db;
                    font-weight: bold;
                ">
                    ${lineman.phone_number || 'No phone'}
                </p>

                <button onclick="closeModal()" style="
                    margin-top: 20px;
                    background:#e74c3c;
                    color:white;
                    padding:10px 15px;
                    border:none;
                    border-radius:6px;
                    cursor:pointer;
                ">
                    Close
                </button>
            </div>
        </div>
    `;

    document.body.insertAdjacentHTML('beforeend', modal);
}

function closeModal() {
    const modal = document.getElementById('linemanModal');
    if (modal) {
        modal.remove();
    }
}
document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
        console.log("User returned → reloading escalations...");
        loadEscalations();
    }
});
async function handleAcknowledge(escalationId, lineman) {
    // Step 1: Mark as acknowledged in DB
    await acknowledgeEscalation(escalationId);

    // Step 2: Show lineman contact popup
    showLinemanActions(lineman);
}