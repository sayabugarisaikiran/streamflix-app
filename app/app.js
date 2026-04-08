// ================================================================
//  StreamFlix — AWS Demo Application
//  Frontend JavaScript: API Demo, WAF Simulation, UI Interactions
// ================================================================

// ─── CONFIGURATION ───────────────────────────────────────────────
// STUDENTS: Replace this URL with your API Gateway Invoke URL.
// Example: 'https://abc123.execute-api.us-east-1.amazonaws.com/prod/hello'
const API_GATEWAY_URL = 'https://REPLACE_WITH_YOUR_API_GATEWAY_URL/prod/hello';


// ─── PARTICLE BACKGROUND ─────────────────────────────────────────
class ParticleField {
    constructor(canvas) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.particles = [];
        this.mouse = { x: null, y: null };
        this.resize();
        this.init();

        window.addEventListener('resize', () => this.resize());
        window.addEventListener('mousemove', (e) => {
            this.mouse.x = e.clientX;
            this.mouse.y = e.clientY;
        });
    }

    resize() {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
    }

    init() {
        const count = Math.min(Math.floor((this.canvas.width * this.canvas.height) / 18000), 80);
        this.particles = [];
        for (let i = 0; i < count; i++) {
            this.particles.push({
                x: Math.random() * this.canvas.width,
                y: Math.random() * this.canvas.height,
                vx: (Math.random() - 0.5) * 0.4,
                vy: (Math.random() - 0.5) * 0.4,
                radius: Math.random() * 1.5 + 0.5,
                opacity: Math.random() * 0.5 + 0.1,
            });
        }
        this.animate();
    }

    animate() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        this.particles.forEach((p) => {
            p.x += p.vx;
            p.y += p.vy;

            if (p.x < 0 || p.x > this.canvas.width) p.vx *= -1;
            if (p.y < 0 || p.y > this.canvas.height) p.vy *= -1;

            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
            this.ctx.fillStyle = `rgba(229, 9, 20, ${p.opacity})`;
            this.ctx.fill();
        });

        // Draw connection lines between nearby particles
        for (let i = 0; i < this.particles.length; i++) {
            for (let j = i + 1; j < this.particles.length; j++) {
                const dx = this.particles[i].x - this.particles[j].x;
                const dy = this.particles[i].y - this.particles[j].y;
                const dist = Math.sqrt(dx * dx + dy * dy);

                if (dist < 120) {
                    this.ctx.beginPath();
                    this.ctx.moveTo(this.particles[i].x, this.particles[i].y);
                    this.ctx.lineTo(this.particles[j].x, this.particles[j].y);
                    this.ctx.strokeStyle = `rgba(229, 9, 20, ${0.06 * (1 - dist / 120)})`;
                    this.ctx.lineWidth = 0.5;
                    this.ctx.stroke();
                }
            }
        }

        requestAnimationFrame(() => this.animate());
    }
}


// ─── DOM READY ──────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {

    // Initialize particle background
    const canvas = document.getElementById('particleCanvas');
    if (canvas) new ParticleField(canvas);

    // ── Navbar scroll effect
    const navbar = document.getElementById('navbar');
    window.addEventListener('scroll', () => {
        navbar.classList.toggle('scrolled', window.scrollY > 50);
    });

    // ── Mobile menu toggle
    const mobileBtn = document.getElementById('mobileMenuBtn');
    const navLinks = document.querySelector('.nav-links');
    if (mobileBtn) {
        mobileBtn.addEventListener('click', () => {
            navLinks.classList.toggle('open');
        });
    }

    // ── Animated stat counters
    const statNumbers = document.querySelectorAll('.stat-number[data-target]');
    const animateCounters = () => {
        statNumbers.forEach((el) => {
            const target = parseInt(el.dataset.target, 10);
            const current = parseInt(el.textContent, 10);
            const increment = Math.ceil(target / 60);
            if (current < target) {
                el.textContent = Math.min(current + increment, target);
                requestAnimationFrame(animateCounters);
            }
        });
    };
    // Start counter animation when hero is in view
    const heroObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                animateCounters();
                heroObserver.disconnect();
            }
        });
    }, { threshold: 0.3 });
    const heroSection = document.getElementById('hero');
    if (heroSection) heroObserver.observe(heroSection);

    // ── Scroll-reveal for architecture steps
    const archSteps = document.querySelectorAll('.arch-step');
    const archObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry, i) => {
            if (entry.isIntersecting) {
                setTimeout(() => entry.target.classList.add('visible'), i * 150);
                archObserver.unobserve(entry.target);
            }
        });
    }, { threshold: 0.2 });
    archSteps.forEach((step) => archObserver.observe(step));


    // ── API DEMO ─────────────────────────────────────────────────
    const testApiBtn = document.getElementById('testApiBtn');
    const terminalBody = document.getElementById('terminalBody');

    function termLog(text, className = '') {
        const line = document.createElement('p');
        line.className = `terminal-line ${className}`;
        line.textContent = text;
        terminalBody.appendChild(line);
        terminalBody.scrollTop = terminalBody.scrollHeight;
    }

    function clearTerminal() {
        terminalBody.innerHTML = '';
    }

    if (testApiBtn) {
        testApiBtn.addEventListener('click', async () => {
            clearTerminal();
            testApiBtn.disabled = true;

            // Step 1: Check URL configuration
            termLog('$ curl -X GET ' + API_GATEWAY_URL, 'dim');
            termLog('');

            if (API_GATEWAY_URL.includes('REPLACE_WITH')) {
                termLog('⚠ ERROR: API Gateway URL not configured!', 'error');
                termLog('');
                termLog('To fix this:', 'info');
                termLog('  1. Deploy API Gateway + Lambda (see lab guide)', 'dim');
                termLog('  2. Open app.js', 'dim');
                termLog('  3. Replace API_GATEWAY_URL with your invoke URL', 'dim');
                termLog('  4. Re-upload app.js to S3', 'dim');
                termLog('  5. Invalidate CloudFront cache: /*', 'dim');
                testApiBtn.disabled = false;
                return;
            }

            // Step 2: Make the request
            termLog('Connecting to API Gateway...', 'info');
            termLog('');

            try {
                const startTime = performance.now();
                const response = await fetch(API_GATEWAY_URL, {
                    method: 'GET',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-App-Platform': 'StreamFlix-Web',
                    },
                });
                const latency = Math.round(performance.now() - startTime);

                if (response.status === 403) {
                    termLog('❌ 403 FORBIDDEN', 'error');
                    termLog('   → AWS WAF blocked this request!', 'error');
                    termLog('   → Possible causes: rate-limited, geo-blocked, or suspicious payload', 'dim');
                    testApiBtn.disabled = false;
                    return;
                }

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status} ${response.statusText}`);
                }

                const data = await response.json();

                termLog('✅ 200 OK', 'success');
                termLog(`   Latency: ${latency}ms`, 'dim');
                termLog('');
                termLog('── Response Headers ──', 'highlight');
                termLog(`   content-type: application/json`, 'dim');
                termLog(`   access-control-allow-origin: *`, 'dim');
                termLog('');
                termLog('── Response Body ──', 'highlight');
                termLog(JSON.stringify(data, null, 2), 'success');

            } catch (error) {
                termLog('❌ REQUEST FAILED', 'error');
                termLog(`   ${error.message}`, 'error');
                termLog('');

                if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
                    termLog('Troubleshooting:', 'info');
                    termLog('  • Is CORS enabled in API Gateway?', 'dim');
                    termLog('  • Is the Lambda function deployed?', 'dim');
                    termLog('  • Is AWS WAF blocking this origin?', 'dim');
                    termLog('  • Check browser DevTools → Network tab', 'dim');
                }
            } finally {
                testApiBtn.disabled = false;
            }
        });
    }


    // ── WAF ATTACK SIMULATIONS ─────────────────────────────────
    // These are CLIENT-SIDE simulations for classroom teaching.
    // They show what WOULD happen if WAF received these requests.

    function showWafResult(elementId, message, type) {
        const el = document.getElementById(elementId);
        if (!el) return;
        el.textContent = message;
        el.className = `waf-result ${type}`;
    }

    // SQL Injection Simulation
    const sqliBtn = document.getElementById('wafSqliBtn');
    if (sqliBtn) {
        sqliBtn.addEventListener('click', () => {
            sqliBtn.disabled = true;
            showWafResult('wafSqliResult', '🔄 Sending: ?id=1\' OR \'1\'=\'1 ...', '');

            setTimeout(() => {
                showWafResult('wafSqliResult',
                    '🚫 BLOCKED by WAF: AWSManagedRulesCommonRuleSet → SQLi_QUERYARGUMENTS detected. Action: BLOCK (403)',
                    'blocked'
                );
                sqliBtn.disabled = false;
            }, 1500);
        });
    }

    // XSS Simulation
    const xssBtn = document.getElementById('wafXssBtn');
    if (xssBtn) {
        xssBtn.addEventListener('click', () => {
            xssBtn.disabled = true;
            showWafResult('wafXssResult', '🔄 Sending: <script>alert("xss")</script> ...', '');

            setTimeout(() => {
                showWafResult('wafXssResult',
                    '🚫 BLOCKED by WAF: CrossSiteScripting_BODY rule matched. Action: BLOCK (403)',
                    'blocked'
                );
                xssBtn.disabled = false;
            }, 1500);
        });
    }

    // Rate Limit Simulation
    const rateLimitBtn = document.getElementById('wafRateLimitBtn');
    if (rateLimitBtn) {
        rateLimitBtn.addEventListener('click', () => {
            rateLimitBtn.disabled = true;
            const rateBar = document.getElementById('rateBar');
            const resultEl = document.getElementById('wafRateLimitResult');
            let count = 0;
            const maxRequests = 50;

            resultEl.textContent = '';
            resultEl.className = 'waf-result';

            const interval = setInterval(() => {
                count++;
                const pct = (count / maxRequests) * 100;
                if (rateBar) rateBar.style.width = pct + '%';

                if (count <= 30) {
                    showWafResult('wafRateLimitResult', `✅ Request #${count} — 200 OK`, 'allowed');
                } else if (count <= 40) {
                    if (rateBar) rateBar.style.background = '#f59e0b';
                    showWafResult('wafRateLimitResult', `⚠️ Request #${count} — 200 OK (approaching threshold)`, 'allowed');
                } else {
                    if (rateBar) rateBar.style.background = '#ef4444';
                    showWafResult('wafRateLimitResult',
                        `🚫 Request #${count} — 403 FORBIDDEN (Rate limit exceeded: >100 req/5min)`,
                        'blocked'
                    );
                }

                if (count >= maxRequests) {
                    clearInterval(interval);
                    rateLimitBtn.disabled = false;
                }
            }, 60);
        });
    }

    // Geo-Blocking Simulation
    const geoBtn = document.getElementById('wafGeoBtn');
    if (geoBtn) {
        geoBtn.addEventListener('click', () => {
            geoBtn.disabled = true;
            showWafResult('wafGeoResult', '🔄 Checking origin: Country = [BLOCKED_REGION] ...', '');

            setTimeout(() => {
                showWafResult('wafGeoResult',
                    '🚫 BLOCKED by WAF: GeoRestriction rule — source country not in allowed list. Action: BLOCK (403)',
                    'blocked'
                );
                geoBtn.disabled = false;
            }, 1800);
        });
    }

    // ── DNS LOOKUP SIMULATOR ──────────────────────────────────
    const dnsLookupBtn = document.getElementById('dnsLookupBtn');
    const dnsTerminalBody = document.getElementById('dnsTerminalBody');

    const dnsSimulations = {
        'a': {
            title: 'A Record — Maps domain to IPv4 address',
            lines: [
                { text: '$ dig streamflix.com A', cls: 'dim' },
                { text: '' },
                { text: ';; QUESTION SECTION:', cls: 'highlight' },
                { text: ';streamflix.com.              IN      A', cls: 'dim' },
                { text: '' },
                { text: ';; ANSWER SECTION:', cls: 'highlight' },
                { text: 'streamflix.com.     300    IN    A    54.230.10.42', cls: 'success' },
                { text: '' },
                { text: ';; EXPLANATION:', cls: 'info' },
                { text: '   Record Type: A (Address)', cls: 'dim' },
                { text: '   Direction: Domain Name → IPv4 Address', cls: 'dim' },
                { text: '   Use Case: Point domain to an EC2 Elastic IP', cls: 'dim' },
                { text: '   TTL: 300 seconds (5 minutes)', cls: 'dim' },
            ]
        },
        'cname': {
            title: 'CNAME Record — Maps DNS name to another DNS name',
            lines: [
                { text: '$ dig www.streamflix.com CNAME', cls: 'dim' },
                { text: '' },
                { text: ';; QUESTION SECTION:', cls: 'highlight' },
                { text: ';www.streamflix.com.          IN      CNAME', cls: 'dim' },
                { text: '' },
                { text: ';; ANSWER SECTION:', cls: 'highlight' },
                { text: 'www.streamflix.com.  300  IN  CNAME  streamflix.com.', cls: 'success' },
                { text: '' },
                { text: ';; EXPLANATION:', cls: 'info' },
                { text: '   Record Type: CNAME (Canonical Name)', cls: 'dim' },
                { text: '   Direction: DNS Name → DNS Name (not IP!)', cls: 'dim' },
                { text: '   ⚠️  CANNOT be used at zone apex (streamflix.com)', cls: 'error' },
                { text: '   ⚠️  CNAME replaces ALL other records at that name', cls: 'error' },
                { text: '   ✅ Use for: www.streamflix.com → streamflix.com', cls: 'dim' },
            ]
        },
        'alias-cf': {
            title: 'ALIAS Record → CloudFront Distribution',
            lines: [
                { text: '$ dig streamflix.com A  (ALIAS is resolved server-side by Route 53)', cls: 'dim' },
                { text: '' },
                { text: ';; Route 53 internally resolves ALIAS:', cls: 'highlight' },
                { text: '   streamflix.com → ALIAS → d3abc.cloudfront.net', cls: 'info' },
                { text: '   d3abc.cloudfront.net → 54.230.10.42', cls: 'info' },
                { text: '' },
                { text: ';; ANSWER SECTION (what the client sees):', cls: 'highlight' },
                { text: 'streamflix.com.  60  IN  A  54.230.10.42', cls: 'success' },
                { text: '' },
                { text: ';; WHY ALIAS INSTEAD OF CNAME?', cls: 'info' },
                { text: '   ✅ Works at zone apex (streamflix.com)', cls: 'dim' },
                { text: '   ✅ Free — no Route 53 query charges', cls: 'dim' },
                { text: '   ✅ AWS resolves it for you (faster)', cls: 'dim' },
                { text: '   ❌ CNAME cannot do this at root domain', cls: 'error' },
            ]
        },
        'alias-alb': {
            title: 'ALIAS Record → Application Load Balancer',
            lines: [
                { text: '$ dig api.streamflix.com A', cls: 'dim' },
                { text: '' },
                { text: ';; Route 53 ALIAS resolution chain:', cls: 'highlight' },
                { text: '   api.streamflix.com', cls: 'info' },
                { text: '     → ALIAS → my-alb-1234.us-east-1.elb.amazonaws.com', cls: 'info' },
                { text: '     → 10.0.1.55, 10.0.2.88 (ALB IPs in 2 AZs)', cls: 'info' },
                { text: '' },
                { text: ';; ANSWER SECTION:', cls: 'highlight' },
                { text: 'api.streamflix.com.  60  IN  A  10.0.1.55', cls: 'success' },
                { text: 'api.streamflix.com.  60  IN  A  10.0.2.88', cls: 'success' },
                { text: '' },
                { text: ';; KEY POINT:', cls: 'info' },
                { text: '   ALB has a DNS name, NOT a static IP!', cls: 'dim' },
                { text: '   That\'s why you MUST use ALIAS, not an A record.', cls: 'dim' },
                { text: '   ALB IPs change dynamically as it scales.', cls: 'dim' },
            ]
        },
        'alias-s3': {
            title: 'ALIAS Record → S3 Static Website',
            lines: [
                { text: '$ dig static.streamflix.com A', cls: 'dim' },
                { text: '' },
                { text: ';; Route 53 ALIAS resolution:', cls: 'highlight' },
                { text: '   static.streamflix.com', cls: 'info' },
                { text: '     → ALIAS → streamflix-bucket.s3-website-us-east-1.amazonaws.com', cls: 'info' },
                { text: '' },
                { text: ';; ANSWER SECTION:', cls: 'highlight' },
                { text: 'static.streamflix.com.  60  IN  A  52.216.133.77', cls: 'success' },
                { text: '' },
                { text: ';; NOTE:', cls: 'info' },
                { text: '   S3 bucket name MUST match domain name for website hosting!', cls: 'dim' },
                { text: '   This uses the OLD S3 static website hosting (not OAC).', cls: 'dim' },
                { text: '   For production, prefer CloudFront + OAC instead.', cls: 'dim' },
            ]
        },
        'mx': {
            title: 'MX Record — Mail Exchange',
            lines: [
                { text: '$ dig streamflix.com MX', cls: 'dim' },
                { text: '' },
                { text: ';; ANSWER SECTION:', cls: 'highlight' },
                { text: 'streamflix.com.  300  IN  MX  1  ASPMX.L.GOOGLE.COM.', cls: 'success' },
                { text: 'streamflix.com.  300  IN  MX  5  ALT1.ASPMX.L.GOOGLE.COM.', cls: 'success' },
                { text: 'streamflix.com.  300  IN  MX  10 ALT2.ASPMX.L.GOOGLE.COM.', cls: 'success' },
                { text: '' },
                { text: ';; EXPLANATION:', cls: 'info' },
                { text: '   Priority 1 = highest priority (tried first)', cls: 'dim' },
                { text: '   Priority 10 = lowest priority (backup)', cls: 'dim' },
                { text: '   Used by: Gmail, Outlook, AWS SES', cls: 'dim' },
            ]
        },
        'weighted': {
            title: 'Weighted Routing — 70/30 Traffic Split',
            lines: [
                { text: '$ dig streamflix.com A (Weighted routing policy)', cls: 'dim' },
                { text: '' },
                { text: ';; Route 53 has 2 records for streamflix.com:', cls: 'highlight' },
                { text: '   Record 1: A → 10.0.1.10 (Weight: 70, SetId: "v2")', cls: 'info' },
                { text: '   Record 2: A → 10.0.2.20 (Weight: 30, SetId: "v1")', cls: 'info' },
                { text: '' },
                { text: ';; 70% of DNS queries return:', cls: 'highlight' },
                { text: 'streamflix.com.  60  IN  A  10.0.1.10  ← v2.0 (new)', cls: 'success' },
                { text: '' },
                { text: ';; 30% of DNS queries return:', cls: 'highlight' },
                { text: 'streamflix.com.  60  IN  A  10.0.2.20  ← v1.0 (old)', cls: 'dim' },
                { text: '' },
                { text: ';; USE CASE: Canary deployment, A/B testing, blue-green', cls: 'info' },
            ]
        },
        'failover': {
            title: 'Failover Routing — Primary server is DOWN',
            lines: [
                { text: '$ dig streamflix.com A (Failover routing policy)', cls: 'dim' },
                { text: '' },
                { text: ';; Route 53 Health Check says:', cls: 'highlight' },
                { text: '   Primary (us-east-1): ❌ UNHEALTHY — /health returned 503', cls: 'error' },
                { text: '   Secondary (eu-west-1): ✅ HEALTHY', cls: 'success' },
                { text: '' },
                { text: ';; Route 53 automatically switches to secondary:', cls: 'highlight' },
                { text: 'streamflix.com.  60  IN  A  34.245.100.50  ← eu-west-1 (standby)', cls: 'success' },
                { text: '' },
                { text: ';; AUTOMATIC! No manual intervention needed.', cls: 'info' },
                { text: '   Health checks run every 10 or 30 seconds.', cls: 'dim' },
                { text: '   After 3 consecutive failures → failover triggers.', cls: 'dim' },
                { text: '   USE CASE: Disaster recovery across regions.', cls: 'dim' },
            ]
        },
        'latency': {
            title: 'Latency-Based Routing — User in India',
            lines: [
                { text: '$ dig streamflix.com A (from India 🇮🇳)', cls: 'dim' },
                { text: '' },
                { text: ';; Route 53 checks latency from user\'s resolver:', cls: 'highlight' },
                { text: '   → ap-south-1 (Mumbai):   ~12ms  ✅ LOWEST', cls: 'success' },
                { text: '   → us-east-1 (Virginia):  ~210ms', cls: 'dim' },
                { text: '   → eu-west-1 (Ireland):   ~180ms', cls: 'dim' },
                { text: '' },
                { text: ';; ANSWER (routed to Mumbai):', cls: 'highlight' },
                { text: 'streamflix.com.  60  IN  A  13.235.50.100  ← ap-south-1', cls: 'success' },
                { text: '' },
                { text: ';; NOTE:', cls: 'info' },
                { text: '   Latency data is maintained by AWS, not measured live.', cls: 'dim' },
                { text: '   This is how Netflix/Amazon serve content globally!', cls: 'dim' },
            ]
        },
        'geolocation': {
            title: 'Geolocation Routing — Content by Country',
            lines: [
                { text: '$ dig streamflix.com A (from India 🇮🇳)', cls: 'dim' },
                { text: '' },
                { text: ';; Route 53 Geolocation rules:', cls: 'highlight' },
                { text: '   Country = India      → 13.235.50.100 (Mumbai ALB)', cls: 'info' },
                { text: '   Country = Japan      → 13.112.80.200 (Tokyo ALB)', cls: 'dim' },
                { text: '   Continent = Europe   → 34.245.100.50 (Ireland ALB)', cls: 'dim' },
                { text: '   Default (catch-all)  → 54.230.10.42  (Virginia ALB)', cls: 'dim' },
                { text: '' },
                { text: ';; ANSWER (user is in India → matched India rule):', cls: 'highlight' },
                { text: 'streamflix.com.  60  IN  A  13.235.50.100', cls: 'success' },
                { text: '' },
                { text: ';; DIFFERENT FROM LATENCY-BASED:', cls: 'info' },
                { text: '   Geolocation = physical location (country/continent)', cls: 'dim' },
                { text: '   Latency = network speed (which is faster)', cls: 'dim' },
                { text: '   Use Geo for: legal compliance, content licensing, GDPR', cls: 'dim' },
            ]
        },
    };

    function dnsLog(container, text, className = '') {
        const line = document.createElement('p');
        line.className = `terminal-line ${className}`;
        line.textContent = text;
        container.appendChild(line);
    }

    if (dnsLookupBtn && dnsTerminalBody) {
        dnsLookupBtn.addEventListener('click', () => {
            const type = document.getElementById('dnsRecordType').value;
            const sim = dnsSimulations[type];
            if (!sim) return;

            dnsTerminalBody.innerHTML = '';
            dnsLookupBtn.disabled = true;

            dnsLog(dnsTerminalBody, `── ${sim.title} ──`, 'highlight');
            dnsLog(dnsTerminalBody, '');

            // Animate lines appearing one by one
            sim.lines.forEach((line, i) => {
                setTimeout(() => {
                    dnsLog(dnsTerminalBody, line.text, line.cls || '');
                    dnsTerminalBody.scrollTop = dnsTerminalBody.scrollHeight;
                    if (i === sim.lines.length - 1) {
                        dnsLookupBtn.disabled = false;
                    }
                }, (i + 1) * 80);
            });
        });
    }

    // ── EC2 INSTANCE METADATA BANNER ─────────────────────────────
    // The user-data script creates /metadata.json on EC2 instances.
    // If we're on EC2, show the banner so students can see load balancing.
    (async function loadEC2Metadata() {
        try {
            const resp = await fetch('/metadata.json', { cache: 'no-store' });
            if (!resp.ok) return;
            const meta = await resp.json();

            document.getElementById('ec2InstanceId').textContent = meta.instance_id || '—';
            document.getElementById('ec2Az').textContent = `AZ: ${meta.availability_zone || '—'}`;
            document.getElementById('ec2PrivateIp').textContent = `IP: ${meta.private_ip || '—'}`;
            document.getElementById('ec2AmiId').textContent = `AMI: ${meta.ami_id || '—'}`;

            const banner = document.getElementById('ec2Banner');
            if (banner) {
                banner.style.display = 'block';
                document.body.classList.add('has-ec2-banner');
            }

            const footerInfo = document.getElementById('ec2FooterInfo');
            if (footerInfo) {
                footerInfo.style.display = 'block';
                footerInfo.textContent = `Serving from ${meta.instance_id} in ${meta.availability_zone}`;
            }
        } catch (e) {
            // Not on EC2 — silently ignore
        }
    })();

});
