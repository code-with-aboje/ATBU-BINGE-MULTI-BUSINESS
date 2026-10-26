# ATBU BINGE MULTI BUSINESS - Loan Site

Static site (HTML + Tailwind CDN) with a Supabase backend.

## Files
- `index.html` - public site, signup/login, loan application
- `account.html` - user's loan requests and their status (pending / approved / rejected)
- `admin.html` - admin dashboard: see bank details, send money, then click Approve (or Reject)
- `config.js` - your Supabase URL + anon key
- `supabase/schema.sql` - tables, security rules, admin functions

## Setup
1. Create a project at supabase.com.
2. SQL Editor > paste `supabase/schema.sql` > Run.
3. Project Settings > API: copy **Project URL** and **anon public key** into `config.js`.
4. (Optional, for testing) Authentication > Providers > Email: turn off "Confirm email" so signups log in instantly.
5. Open the site, sign up with your admin email, then run in the SQL Editor:
   `update public.profiles set is_admin = true where email = 'you@example.com';`
6. Go to `/admin.html` and log in.

## Deploy to GitHub Pages
1. Push these files to a GitHub repo.
2. Repo Settings > Pages > Deploy from branch > `main` / root.
3. In Supabase: Authentication > URL Configuration > set Site URL to your GitHub Pages link.

## Notes
- Never put the `service_role` key in this repo. Only the anon key goes in `config.js`.
- Payouts are manual: the admin sends the money from their bank app, then clicks **Approve**. The site does not move money itself. Paystack/Flutterwave could automate it later.
- NIN/BVN and ID documents are sensitive. They are protected by row-level security and a private bucket, but if you go live, follow NDPR rules and register with the FCCPC as a digital lender.
