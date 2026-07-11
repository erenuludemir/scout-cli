function triggerHQCelebration(partnerName, type) {
  console.log(`[HQ] ${partnerName} etkinligi alindi. Tip: ${type}`);

  const overlay = document.createElement("div");
  overlay.className = "hq-announcement-overlay";
  overlay.innerHTML = `<h1>YENI PARTNER: ${partnerName}</h1><p>Bursa Operasyon Ekosistemine Hos Geldiniz</p>`;
  document.body.appendChild(overlay);

  if (typeof window.launchFireworks === "function") {
    window.launchFireworks();
  }

  setTimeout(() => overlay.remove(), 10000);
}
