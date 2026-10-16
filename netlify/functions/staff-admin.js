// Staff login banana / password reset / delete — sirf ADMIN kar sakta hai.
// Service-role key sirf yahan (Netlify environment variable) rehti hai, browser me kabhi nahi jaati.
// Env vars: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
const MAIL = "@omlogistics.app";
const json = (code, obj) => ({ statusCode: code, headers: { "Content-Type": "application/json" }, body: JSON.stringify(obj) });

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") return json(405, { error: "POST only" });
  const URL_ = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!URL_ || !KEY) return json(500, { error: "Netlify me SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY set nahi hain" });
  const H = { apikey: KEY, Authorization: "Bearer " + KEY, "Content-Type": "application/json" };

  try {
    // 1) caller kaun hai? (uska login token verify)
    const token = (event.headers.authorization || event.headers.Authorization || "").replace(/^Bearer\s+/i, "");
    if (!token) return json(401, { error: "Login zaroori hai" });
    const ur = await fetch(URL_ + "/auth/v1/user", { headers: { apikey: KEY, Authorization: "Bearer " + token } });
    if (!ur.ok) return json(401, { error: "Session expire — dobara login karein" });
    const me = await ur.json();
    const pr = await fetch(`${URL_}/rest/v1/profiles?id=eq.${encodeURIComponent(me.id)}&select=role`, { headers: H });
    const prof = (await pr.json())[0];
    if (!prof || prof.role !== "admin") return json(403, { error: "Sirf admin ye kar sakta hai" });

    // 2) request
    const b = JSON.parse(event.body || "{}");
    const username = String(b.username || "").trim().toLowerCase();
    if (!/^[a-z0-9._-]{3,30}$/.test(username)) return json(400, { error: "Username 3-30 chars: a-z 0-9 . _ -" });
    if (username === "admin") return json(400, { error: "Ye username reserved hai" });

    if (b.action === "create") {
      if (String(b.password || "").length < 6) return json(400, { error: "Password kam se kam 6 characters" });
      const r = await fetch(URL_ + "/auth/v1/admin/users", {
        method: "POST", headers: H,
        body: JSON.stringify({ email: username + MAIL, password: b.password, email_confirm: true,
          user_metadata: { username, name: String(b.name || username).slice(0, 80) } })
      });
      const j = await r.json();
      if (!r.ok) return json(400, { error: /already|registered|exists/i.test(JSON.stringify(j)) ? "Ye username pehle se hai" : (j.msg || j.message || "Create fail") });
      return json(200, { ok: true });
    }

    // delete / reset: target ka profile dhoondo
    const tr = await fetch(`${URL_}/rest/v1/profiles?username=eq.${encodeURIComponent(username)}&select=id,role`, { headers: H });
    const target = (await tr.json())[0];
    if (!target) return json(404, { error: "User nahi mila" });
    if (target.role === "admin") return json(403, { error: "Admin par ye action allowed nahi" });

    if (b.action === "delete") {
      const r = await fetch(`${URL_}/auth/v1/admin/users/${target.id}`, { method: "DELETE", headers: H });
      if (!r.ok) return json(400, { error: "Delete fail" });
      return json(200, { ok: true });
    }
    if (b.action === "reset") {
      if (String(b.password || "").length < 6) return json(400, { error: "Password kam se kam 6 characters" });
      const r = await fetch(`${URL_}/auth/v1/admin/users/${target.id}`, { method: "PUT", headers: H, body: JSON.stringify({ password: b.password }) });
      if (!r.ok) return json(400, { error: "Reset fail" });
      return json(200, { ok: true });
    }
    return json(400, { error: "Unknown action" });
  } catch (e) {
    return json(500, { error: "Server error: " + e.message });
  }
};
