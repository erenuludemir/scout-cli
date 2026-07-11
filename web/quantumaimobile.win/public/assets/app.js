const currentPage = window.location.pathname.split("/").pop() || "index.html";

for (const link of document.querySelectorAll("[data-nav]")) {
  const target = link.getAttribute("href");
  if (target === currentPage || (currentPage === "" && target === "index.html")) {
    link.classList.add("active");
  }
}

const pageTitleKeyByFile = {
  "index.html": "pageTitleIndex",
  "architecture.html": "pageTitleArchitecture",
  "runtime.html": "pageTitleRuntime",
  "mobile.html": "pageTitleMobile",
  "roadmap.html": "pageTitleRoadmap"
};

const translations = {
  en: {
    siteBrandKicker: "QuantumAI Mobile",
    siteBrandTitle: "Control Surface for mobile ops",
    navOverview: "Overview",
    navArchitecture: "Architecture",
    navRuntime: "Runtime",
    navMobile: "Mobile",
    navRoadmap: "Roadmap",
    footerText: "Static package prepared for Cloudflare Pages and custom domain binding.",
    preparedStampValue: "Prepared for Cloudflare Pages on 2026-04-12",

    pageTitleIndex: "QuantumAI Mobile",
    metaDescriptionIndex: "QuantumAI Mobile control surface, runtime stack, physical-device validation lane, and deployment-ready architecture.",
    indexHeroEyebrow: "Live build, runtime, and deployment lane",
    indexHeroTitle: "QuantumAI Mobile is packaged for device, runtime, and domain.",
    indexHeroLead: "This site mirrors the current QuantumAI Mobile operating model: physical-device validated iOS surfaces, FastAPI runtime, outbox relay, Prometheus and Grafana visibility, and a Cloudflare-ready static presentation layer.",
    indexCTAArchitecture: "Open architecture",
    indexCTAMobile: "See mobile surfaces",
    chipHost: "QuantumAI Host",
    chipQuantumAI: "QuantumAI",
    chipApp: "QuantumAIMobileApp",
    chipStack: "FastAPI + Kafka + Redis + Postgres",
    chipDeviceValidated: "Physical device validated",
    deployStatusTitle: "Deployment status",
    customDomainLabel: "Custom domain",
    customDomainValue: "quantumaimobile.win",
    presentationModeLabel: "Presentation mode",
    presentationModeValue: "Cloudflare Pages",
    validationLaneLabel: "Validation lane",
    validationLaneValue: "Physical iPhone 14 Pro Max",
    preparedStampLabel: "Prepared stamp",
    indexWhatTitle: "What this domain package carries",
    indexWhat1: "Front-page description of the product surface and operations model.",
    indexWhat2: "Architecture page for runtime, queueing, observability, and deployment flow.",
    indexWhat3: "Mobile page for app, host, and device-validated UI lanes.",
    indexWhat4: "Roadmap page for SLO-driven release and hardening milestones.",
    indexWhat5: "Cloudflare Pages config and security headers for direct transfer.",
    releaseTrackTitle: "Release track",
    releaseLane1Label: "Lane 1",
    releaseLane1Text: "QuantumAI Host build, install, and trace validation",
    releaseLane2Label: "Lane 2",
    releaseLane2Text: "QuantumAI device smoke, replay, and navigation checks",
    releaseLane3Label: "Lane 3",
    releaseLane3Text: "Archive, export, domain packaging, and Cloudflare transfer prep",

    pageTitleArchitecture: "QuantumAI Mobile Architecture",
    metaDescriptionArchitecture: "QuantumAI Mobile architecture, runtime spine, observability, queues, and control domains.",
    architectureBrandKicker: "Architecture",
    architectureBrandTitle: "Operational backbone",
    architectureHeroEyebrow: "System map",
    architectureHeroTitle: "One mobile surface, one runtime spine, multiple controlled lanes.",
    architectureHeroLead: "The current architecture is organized around an idempotent API entrypoint, queue-backed relay, audited storage, and a device-first control surface.",
    architectureCoreTitle: "Core topology",
    architectureCore1: "SwiftUI front end for Panel, Markets, Bots, and Settings surfaces.",
    architectureCore2: "FastAPI runtime for health, ready, outbox admin, and runbook APIs.",
    architectureCore3: "Redis and Kafka for relay, retry, and asynchronous delivery paths.",
    architectureCore4: "Postgres for durable order, outbox, and audit persistence.",
    architectureCore5: "Prometheus and Grafana for metrics, trend lanes, and runtime dashboards.",
    architectureDomainsTitle: "Primary control domains",
    architectureDomains1: "TrainingJourney for onboarding, prerequisites, and secure capability checks.",
    architectureDomains2: "MarketBridge for snapshot, bridge, and guide orchestration.",
    architectureDomains3: "Panel and HQ Admin for runtime pulse, outbox pressure, and replay controls.",
    architectureDomains4: "TradeView for DCA, grid, copy-trade rehearsal, and outbox clearing.",

    pageTitleRuntime: "QuantumAI Mobile Runtime",
    metaDescriptionRuntime: "QuantumAI runtime visibility, queues, replay, DLQ, metrics, and operational controls.",
    runtimeBrandKicker: "Runtime",
    runtimeBrandTitle: "Observed, queued, and replayable",
    runtimeHeroEyebrow: "Runtime lane",
    runtimeHeroTitle: "Outbox, replay, DLQ, and metrics all stay visible.",
    runtimeHeroLead: "The runtime stack is built to keep operator visibility high: every queue pressure, replay path, audit count, and readiness signal is meant to be visible both in backend tools and in the app surface.",
    runtimeMetric1Label: "Health endpoints",
    runtimeMetric1Value: "/health + /ready",
    runtimeMetric2Label: "Outbox lanes",
    runtimeMetric2Value: "due / failed / dead_letter",
    runtimeMetric3Label: "Topics",
    runtimeMetric3Value: "incoming / replay / dead_letter",
    runtimeControlsTitle: "Operational controls",
    runtimeControls1: "Transactional outbox and relay worker.",
    runtimeControls2: "Manual replay and replay-all-dead-letters endpoints.",
    runtimeControls3: "Prometheus metrics for attempts, deliveries, failures, DLQ, and queue age.",
    runtimeControls4: "Grafana dashboard for runtime overview and queue state trends.",
    runtimeWhyTitle: "Why this matters",
    runtimeWhy1Label: "Signal",
    runtimeWhy1Text: "Runtime pulse is visible on device and backend at the same time.",
    runtimeWhy2Label: "Safety",
    runtimeWhy2Text: "Replay and DLQ are explicit operator actions, not hidden retries.",
    runtimeWhy3Label: "Delivery",
    runtimeWhy3Text: "Cloudflare presentation layer stays separate from the runtime control plane.",

    pageTitleMobile: "QuantumAI Mobile Surfaces",
    metaDescriptionMobile: "QuantumAI mobile surfaces, device-first validation lane, and physical-device smoke checks.",
    mobileBrandKicker: "Mobile",
    mobileBrandTitle: "Device-first validation lane",
    mobileHeroEyebrow: "Physical lane",
    mobileHeroTitle: "QuantumAI Host and QuantumAI are validated on real hardware first.",
    mobileHeroLead: "The canonical measurement lane is the connected iPhone 14 Pro Max. Simulator remains a fallback tool, not the final truth source.",
    mobileValidatedTitle: "Validated surfaces",
    mobileValidated1: "Panel",
    mobileValidated2: "Markets / Market Bridge",
    mobileValidated3: "Bots",
    mobileValidated4: "Settings",
    mobileValidated5: "HQ Admin runtime cards and detail lanes",
    mobileChecksTitle: "Current smoke checks",
    mobileChecks1: "Primary tab replay on physical device.",
    mobileChecks2: "Panel to Market Bridge navigation.",
    mobileChecks3: "Settings to Market Bridge navigation.",
    mobileChecks4: "Trace capture for Leaks and runtime profiling.",

    pageTitleRoadmap: "QuantumAI Mobile Roadmap",
    metaDescriptionRoadmap: "QuantumAI roadmap, release sequencing, runtime hardening, Cloudflare deployment, and SLO-driven promotion.",
    roadmapBrandKicker: "Roadmap",
    roadmapBrandTitle: "SLO-driven release path",
    roadmapHeroEyebrow: "Release sequencing",
    roadmapHeroTitle: "Ship only after device, runtime, and domain stay aligned.",
    roadmapHeroLead: "The next release path is not only UI polish. It includes queue health, replay safety, physical-device navigation, and domain presentation parity.",
    roadmapPhaseALabel: "Phase A",
    roadmapPhaseAText: "Keep the physical-device UITest lane stable and scriptable with one command.",
    roadmapPhaseBLabel: "Phase B",
    roadmapPhaseBText: "Re-profile with the full connected runtime stack and compare against the baseline leak traces.",
    roadmapPhaseCLabel: "Phase C",
    roadmapPhaseCText: "Deploy this static package to Cloudflare Pages and bind both apex and www domains.",
    roadmapPhaseDLabel: "Phase D",
    roadmapPhaseDText: "Promote the release only when device smoke, runtime readiness, and archive/export evidence all stay green."
  },
  tr: {
    siteBrandKicker: "QuantumAI Mobile",
    siteBrandTitle: "Mobil operasyonlar için kontrol yüzeyi",
    navOverview: "Genel Bakış",
    navArchitecture: "Mimari",
    navRuntime: "Çalışma Zamanı",
    navMobile: "Mobil",
    navRoadmap: "Yol Haritası",
    footerText: "Bu statik paket, Cloudflare Pages ve özel alan adı bağlama için hazırlandı.",
    preparedStampValue: "Cloudflare Pages için hazırlanma tarihi: 2026-04-12",

    pageTitleIndex: "QuantumAI Mobile",
    metaDescriptionIndex: "QuantumAI Mobile kontrol yüzeyi, çalışma zamanı katmanı, fiziksel cihaz doğrulama hattı ve dağıtıma hazır mimari.",
    indexHeroEyebrow: "Canlı derleme, çalışma zamanı ve dağıtım hattı",
    indexHeroTitle: "QuantumAI Mobile cihaz, çalışma zamanı ve alan adı için paketlendi.",
    indexHeroLead: "Bu site, güncel QuantumAI Mobile işletim modelini yansıtır: fiziksel cihazda doğrulanan iOS yüzeyleri, FastAPI çalışma zamanı, outbox relay, Prometheus ve Grafana görünürlüğü ile Cloudflare uyumlu statik sunum katmanı.",
    indexCTAArchitecture: "Mimariyi aç",
    indexCTAMobile: "Mobil yüzeyleri gör",
    chipHost: "QuantumAI Host",
    chipQuantumAI: "QuantumAI",
    chipApp: "QuantumAIMobileApp",
    chipStack: "FastAPI + Kafka + Redis + Postgres",
    chipDeviceValidated: "Fiziksel cihazda doğrulandı",
    deployStatusTitle: "Dağıtım durumu",
    customDomainLabel: "Özel alan adı",
    customDomainValue: "quantumaimobile.win",
    presentationModeLabel: "Sunum modu",
    presentationModeValue: "Cloudflare Pages",
    validationLaneLabel: "Doğrulama hattı",
    validationLaneValue: "Fiziksel iPhone 14 Pro Max",
    preparedStampLabel: "Hazırlık etiketi",
    indexWhatTitle: "Bu alan adı paketinin içeriği",
    indexWhat1: "Ürün yüzeyi ve operasyon modelinin ana sayfa özeti.",
    indexWhat2: "Çalışma zamanı, kuyruklama, gözlemlenebilirlik ve dağıtım akışı için mimari sayfası.",
    indexWhat3: "Uygulama, host ve cihazda doğrulanan arayüz hatları için mobil sayfa.",
    indexWhat4: "SLO odaklı sürüm ve sertleştirme kilometre taşları için yol haritası sayfası.",
    indexWhat5: "Doğrudan aktarım için Cloudflare Pages yapılandırması ve güvenlik başlıkları.",
    releaseTrackTitle: "Sürüm hattı",
    releaseLane1Label: "Hat 1",
    releaseLane1Text: "QuantumAI Host derleme, kurulum ve iz doğrulaması",
    releaseLane2Label: "Hat 2",
    releaseLane2Text: "QuantumAI cihaz smoke, replay ve gezinme kontrolleri",
    releaseLane3Label: "Hat 3",
    releaseLane3Text: "Arşiv, export, alan adı paketleme ve Cloudflare aktarım hazırlığı",

    pageTitleArchitecture: "QuantumAI Mobile Mimarisi",
    metaDescriptionArchitecture: "QuantumAI Mobile mimarisi, çalışma zamanı omurgası, gözlemlenebilirlik, kuyruklar ve kontrol alanları.",
    architectureBrandKicker: "Mimari",
    architectureBrandTitle: "Operasyonel omurga",
    architectureHeroEyebrow: "Sistem haritası",
    architectureHeroTitle: "Tek mobil yüzey, tek çalışma zamanı omurgası, çoklu kontrollü hatlar.",
    architectureHeroLead: "Mevcut mimari; idempotent API giriş noktası, kuyruk destekli relay, denetimli depolama ve cihaz öncelikli kontrol yüzeyi etrafında düzenlenmiştir.",
    architectureCoreTitle: "Temel topoloji",
    architectureCore1: "Panel, Piyasalar, Botlar ve Ayarlar yüzeyleri için SwiftUI ön uç.",
    architectureCore2: "Health, ready, outbox yönetimi ve runbook API'leri için FastAPI çalışma zamanı.",
    architectureCore3: "Relay, retry ve asenkron teslimat yolları için Redis ve Kafka.",
    architectureCore4: "Kalıcı emir, outbox ve audit saklama için Postgres.",
    architectureCore5: "Metrikler, trend hatları ve runtime panoları için Prometheus ve Grafana.",
    architectureDomainsTitle: "Birincil kontrol alanları",
    architectureDomains1: "Onboarding, önkoşullar ve güvenli yetenek kontrolleri için TrainingJourney.",
    architectureDomains2: "Snapshot, bridge ve rehber orkestrasyonu için MarketBridge.",
    architectureDomains3: "Runtime nabzı, outbox baskısı ve replay kontrolleri için Panel ve HQ Admin.",
    architectureDomains4: "DCA, grid, copy-trade prova ve outbox temizleme için TradeView.",

    pageTitleRuntime: "QuantumAI Mobile Çalışma Zamanı",
    metaDescriptionRuntime: "QuantumAI çalışma zamanı görünürlüğü, kuyruklar, replay, DLQ, metrikler ve operasyonel kontroller.",
    runtimeBrandKicker: "Çalışma Zamanı",
    runtimeBrandTitle: "Gözlemlenebilir, kuyruklu ve yeniden oynatılabilir",
    runtimeHeroEyebrow: "Çalışma zamanı hattı",
    runtimeHeroTitle: "Outbox, replay, DLQ ve metriklerin tamamı görünür kalır.",
    runtimeHeroLead: "Çalışma zamanı yığını, operatör görünürlüğünü yüksek tutmak için kuruldu: her kuyruk baskısı, replay yolu, audit sayısı ve readiness sinyali hem backend araçlarında hem de uygulama yüzeyinde görünür olacak şekilde tasarlandı.",
    runtimeMetric1Label: "Sağlık endpoint'leri",
    runtimeMetric1Value: "/health + /ready",
    runtimeMetric2Label: "Outbox hatları",
    runtimeMetric2Value: "due / failed / dead_letter",
    runtimeMetric3Label: "Konular",
    runtimeMetric3Value: "incoming / replay / dead_letter",
    runtimeControlsTitle: "Operasyonel kontroller",
    runtimeControls1: "Transactional outbox ve relay worker.",
    runtimeControls2: "Manuel replay ve tüm dead letter kayıtlarını yeniden oynatma endpoint'leri.",
    runtimeControls3: "Attempt, delivery, failure, DLQ ve kuyruk yaşı için Prometheus metrikleri.",
    runtimeControls4: "Çalışma zamanı genel görünümü ve kuyruk durum trendleri için Grafana panosu.",
    runtimeWhyTitle: "Bu neden önemli",
    runtimeWhy1Label: "Sinyal",
    runtimeWhy1Text: "Çalışma zamanı nabzı cihaz ve backend üzerinde aynı anda görünür.",
    runtimeWhy2Label: "Güvenlik",
    runtimeWhy2Text: "Replay ve DLQ gizli retry'lar değil, açık operatör aksiyonlarıdır.",
    runtimeWhy3Label: "Teslimat",
    runtimeWhy3Text: "Cloudflare sunum katmanı, çalışma zamanı kontrol düzleminden ayrı kalır.",

    pageTitleMobile: "QuantumAI Mobile Yüzeyleri",
    metaDescriptionMobile: "QuantumAI mobil yüzeyleri, cihaz öncelikli doğrulama hattı ve fiziksel cihaz smoke kontrolleri.",
    mobileBrandKicker: "Mobil",
    mobileBrandTitle: "Cihaz öncelikli doğrulama hattı",
    mobileHeroEyebrow: "Fiziksel hat",
    mobileHeroTitle: "QuantumAI Host ve QuantumAI önce gerçek donanım üzerinde doğrulanır.",
    mobileHeroLead: "Kanoni̇k ölçüm hattı, bağlı iPhone 14 Pro Max cihazıdır. Simulator yalnızca yedek araçtır; nihai doğruluk kaynağı değildir.",
    mobileValidatedTitle: "Doğrulanan yüzeyler",
    mobileValidated1: "Panel",
    mobileValidated2: "Piyasalar / Market Bridge",
    mobileValidated3: "Botlar",
    mobileValidated4: "Ayarlar",
    mobileValidated5: "HQ Admin runtime kartları ve detay hatları",
    mobileChecksTitle: "Güncel smoke kontrolleri",
    mobileChecks1: "Fiziksel cihazda ana sekme replay testi.",
    mobileChecks2: "Panelden Market Bridge'e gezinme.",
    mobileChecks3: "Ayarlardan Market Bridge'e gezinme.",
    mobileChecks4: "Leaks ve runtime profiling için trace yakalama.",

    pageTitleRoadmap: "QuantumAI Mobile Yol Haritası",
    metaDescriptionRoadmap: "QuantumAI yol haritası, sürüm sıralaması, çalışma zamanı sertleştirme, Cloudflare dağıtımı ve SLO odaklı yayın.",
    roadmapBrandKicker: "Yol Haritası",
    roadmapBrandTitle: "SLO odaklı sürüm yolu",
    roadmapHeroEyebrow: "Sürüm sıralaması",
    roadmapHeroTitle: "Sadece cihaz, çalışma zamanı ve alan adı aynı hizada kaldığında yayınla.",
    roadmapHeroLead: "Bir sonraki sürüm yolu yalnızca arayüz cilası değildir. Kuyruk sağlığı, replay güvenliği, fiziksel cihaz navigasyonu ve alan adı sunum uyumu da buna dahildir.",
    roadmapPhaseALabel: "Faz A",
    roadmapPhaseAText: "Fiziksel cihaz UITest hattını tek komutla kararlı ve script edilebilir halde tut.",
    roadmapPhaseBLabel: "Faz B",
    roadmapPhaseBText: "Tam bağlı çalışma zamanı yığını ile yeniden profil çıkar ve temel leak izleriyle karşılaştır.",
    roadmapPhaseCLabel: "Faz C",
    roadmapPhaseCText: "Bu statik paketi Cloudflare Pages'e dağıt ve hem apex hem www alan adlarını bağla.",
    roadmapPhaseDLabel: "Faz D",
    roadmapPhaseDText: "Yalnız cihaz smoke, runtime readiness ve arşiv/export kanıtları yeşil kaldığında sürümü terfi ettir."
  }
};

function detectInitialLanguage() {
  const stored = localStorage.getItem("qai-lang");
  if (stored === "tr" || stored === "en") return stored;
  const docLang = document.documentElement.lang;
  if (docLang === "tr" || docLang === "en") return docLang;
  const navLang = (navigator.language || "en").toLowerCase();
  return navLang.startsWith("tr") ? "tr" : "en";
}

function applyLanguage(lang) {
  const dict = translations[lang] || translations.en;

  document.documentElement.lang = lang;

  document.querySelectorAll("[data-i18n]").forEach((node) => {
    const key = node.getAttribute("data-i18n");
    if (dict[key]) {
      node.textContent = dict[key];
    }
  });

  document.querySelectorAll("[data-i18n-meta]").forEach((node) => {
    const key = node.getAttribute("data-i18n-meta");
    if (dict[key]) {
      node.setAttribute("content", dict[key]);
    }
  });

  document.querySelectorAll("[data-i18n-stamp]").forEach((node) => {
    node.textContent = dict.preparedStampValue || translations.en.preparedStampValue;
  });

  document.querySelectorAll("[data-lang]").forEach((button) => {
    button.classList.toggle("active", button.getAttribute("data-lang") === lang);
  });

  const titleKey = pageTitleKeyByFile[currentPage] || "pageTitleIndex";
  document.title = dict[titleKey] || translations.en[titleKey] || translations.en.pageTitleIndex;
  localStorage.setItem("qai-lang", lang);
}

const initialLanguage = detectInitialLanguage();
applyLanguage(initialLanguage);

document.querySelectorAll("[data-lang]").forEach((button) => {
  button.addEventListener("click", () => {
    const lang = button.getAttribute("data-lang");
    applyLanguage(lang);
  });
});
