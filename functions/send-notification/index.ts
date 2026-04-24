import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from "https://deno.land/x/djwt/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { fault_id, lineman_id, pole_number, fault_type, priority_score } = await req.json()

    const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: lineman } = await supabase
      .from('linemen')
      .select('name, fcm_token')
      .eq('id', lineman_id)
      .single()

    if (!lineman?.fcm_token) {
      throw new Error("No FCM token")
    }

    // 🔥 Generate JWT
    const jwt = await create(
      { alg: "RS256", typ: "JWT" },
      {
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        exp: getNumericDate(60 * 60),
        iat: getNumericDate(0),
      },
      await crypto.subtle.importKey(
        "pkcs8",
        str2ab(serviceAccount.private_key),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
      )
    )

    // 🔥 Exchange JWT for Access Token
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
    })

    const tokenData = await tokenRes.json()
    const accessToken = tokenData.access_token

    // 🔥 Send Notification
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          message: {
            token: lineman.fcm_token,
            notification: {
              title: `🚨 Fault: ${pole_number}`,
              body: `${fault_type} - Priority ${priority_score}/10`
            }
          }
        })
      }
    )

    const result = await fcmRes.json()

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400
    })
  }
})

// Helper
function str2ab(pem: string) {
  const binary = atob(pem.replace(/-----.*?-----|\n/g, ""))
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}