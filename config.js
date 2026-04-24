const SUPABASE_URL = 'https://zjgorwwogcanatbacecm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpqZ29yd3dvZ2NhbmF0YmFjZWNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2NjAxNTksImV4cCI6MjA4NTIzNjE1OX0.5ZwzxK-C9br8htwyLwSqD_aASJNbTZU1lmz--oPu4lg';

const { createClient } = window.supabase;
window.supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

console.log('✅ Supabase client initialized');
console.log('🔑 Key:', SUPABASE_ANON_KEY.substring(0, 50) + '...');