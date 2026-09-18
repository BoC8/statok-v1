/// Les clés du projet Supabase.
///
/// Depuis la refonte, l'application pointe sur le projet **statok-v2**,
/// qui porte le schéma en douze tables. L'ancien projet continue de
/// servir la version publiée, sur la branche `main`.
///
/// La clé `anon` est faite pour être publique : c'est la RLS qui protège
/// les données. La clé `service_role`, elle, ne doit JAMAIS figurer ici —
/// elle contourne toutes les politiques.
const supabaseUrl = 'https://hlhisjfwdxkulrkcwkwb.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhsaGlzamZ3ZHhrdWxya2N3a3diIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzOTcxNDYsImV4cCI6MjEwNDk3MzE0Nn0.y9bD7swSvo6MRLxbFHJr0r9GP-pooO2PaeZTn1jVEMI';
