// Edge Function: Assign Nearest Available Lineman to Fault

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

console.log("Auto-dispatch function started!")

serve(async (req) => {
  try {
    // Get fault data from request
    const { faultId, faultLatitude, faultLongitude, priority } = await req.json()

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 1. Get all available linemen with their GPS locations
    const { data: linemen, error: linemenError } = await supabase
      .from('linemen')
      .select('id, name, phone, current_latitude, current_longitude')
      .eq('availability_status', 'available')

    if (linemenError) throw linemenError
    if (!linemen || linemen.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No linemen available' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // 2. Calculate distance to each lineman (Haversine formula)
    const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number) => {
      const R = 6371 // Earth radius in km
      const dLat = (lat2 - lat1) * Math.PI / 180
      const dLon = (lon2 - lon1) * Math.PI / 180
      const a = 
        Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon/2) * Math.sin(dLon/2)
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
      return R * c // Distance in km
    }

    // 3. Find nearest lineman
    let nearestLineman = null
    let shortestDistance = Infinity

    for (const lineman of linemen) {
      const distance = calculateDistance(
        faultLatitude,
        faultLongitude,
        lineman.current_latitude,
        lineman.current_longitude
      )
      
      if (distance < shortestDistance) {
        shortestDistance = distance
        nearestLineman = { ...lineman, distance }
      }
    }

    if (!nearestLineman) {
      return new Response(
        JSON.stringify({ error: 'Could not find suitable lineman' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // 4. Assign fault to nearest lineman
    const { error: updateError } = await supabase
      .from('faults')
      .update({ 
        assigned_to: nearestLineman.id,
        status: 'assigned'
      })
      .eq('id', faultId)

    if (updateError) throw updateError

    // 5. Update lineman status to busy
    const { error: linemanUpdateError } = await supabase
      .from('linemen')
      .update({ availability_status: 'busy' })
      .eq('id', nearestLineman.id)

    if (linemanUpdateError) throw linemanUpdateError

    // 6. Return success response
    return new Response(
      JSON.stringify({
        success: true,
        assigned_to: nearestLineman.name,
        lineman_id: nearestLineman.id,
        distance: Math.round(shortestDistance * 100) / 100, // Round to 2 decimals
        message: `Fault assigned to ${nearestLineman.name} (${shortestDistance.toFixed(2)} km away)`
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
